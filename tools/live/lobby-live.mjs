#!/usr/bin/env node
// Live browser check for Tales from Space lobby preparation and in-round chat
// on the real /gui/ GPUI wasm client using real keyDown/keyUp-with-text:
// (0) zero ready holds the full countdown as waiting, (1) name + Add role at
// once keeps both (draft rebase), (2) edit existing name + Ready at once keeps
// the edit (Leave before Activate), (4) the ready countdown spends seconds,
// (3) focus.chat + bound gameplay letters delivers chat with zero world actions.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const PACK = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const argv = process.argv.slice(2);
const ENGINE = resolve(argv[0] ?? process.env.LUNATIC_ENGINE ?? join(PACK, "../lunatic"));
const webIdx = argv.indexOf("--web");
const PACK_WEB = resolve(webIdx >= 0 ? argv[webIdx + 1] : process.env.LUNATIC_PACK_WEB ?? join(PACK, "target/web"));

const delay = (ms) => new Promise((done) => setTimeout(done, ms));
const ARROW_DOWN = { code: "ArrowDown", key: "ArrowDown", windowsVirtualKeyCode: 40, nativeVirtualKeyCode: 40 };

for (const file of ["gui_bg.wasm", "protocol-stamp.json", "index.html"]) {
  const full = join(ENGINE, "target/gui-web", file);
  if (!existsSync(full)) {
    throw Error(`missing stamped GUI client (${full}): build it with \`cd ${ENGINE} && sh tools/build-gui-web.sh\``);
  }
}

const { Cdp, launchChrome } = await import(pathToFileURL(join(ENGINE, "tools/ui-lab/cdp.mjs")).href);
const {
  API_LINE,
  OPEN_LINE,
  clickAt,
  fetchState,
  packGeometry,
  pressEnter,
  stopChild,
  tapKey,
  waitForLaidControl,
} = await import(pathToFileURL(join(ENGINE, "tools/gui-web-join.mjs")).href);

async function fetchLedger(apiOrigin, secret, since = 0) {
  const res = await fetch(`${apiOrigin}/ledger?since=${since}`, {
    headers: { authorization: `Bearer ${secret}` },
    signal: AbortSignal.timeout(3000),
  });
  if (!res.ok) throw Error(`GET ${apiOrigin}/ledger answered HTTP ${res.status}`);
  return res.json();
}

async function typeKeyDown(cdp, text) {
  for (const ch of text) {
    const upper = ch.toUpperCase();
    const isDigit = /^[0-9]$/.test(ch);
    const code = ch === " " ? "Space" : isDigit ? `Digit${ch}` : `Key${upper}`;
    const keyCode = ch === " " ? 32 : upper.charCodeAt(0);
    await cdp.call("Input.dispatchKeyEvent", {
      type: "keyDown",
      code,
      key: ch,
      windowsVirtualKeyCode: keyCode,
      nativeVirtualKeyCode: keyCode,
      text: ch,
      unmodifiedText: ch,
    });
    await delay(10);
    await cdp.call("Input.dispatchKeyEvent", {
      type: "keyUp",
      code,
      key: ch,
      windowsVirtualKeyCode: keyCode,
      nativeVirtualKeyCode: keyCode,
    });
    await delay(15);
  }
}

async function startDev(runDir, tag, mode, mapRel) {
  const apiSecret = randomBytes(32).toString("hex");
  const apiKeys = join(runDir, `keys-${tag}.txt`);
  await writeFile(apiKeys, `k ${createHash("sha256").update(apiSecret).digest("hex")}\n`, { mode: 0o600 });
  const auditDir = join(runDir, `audit-${tag}`);
  await mkdir(auditDir, { recursive: true });
  const env = { ...process.env, LUNATIC_PACK: PACK };
  delete env.CARGO_TARGET_DIR;
  const child = spawn(
    process.execPath,
    [
      join(ENGINE, "tools/dev.mjs"),
      "--development-http", "--bind", "127.0.0.1:0", "--no-open", "--no-build",
      "--mode", mode, "--map", join(PACK, mapRel),
      "--web", PACK_WEB, "--audit-dir", auditDir, "--api-keys", apiKeys,
    ],
    { cwd: ENGINE, env, stdio: ["ignore", "pipe", "pipe"] },
  );
  let buf = "";
  const origins = await new Promise((res, rej) => {
    const t = setTimeout(() => rej(Error(`dev.mjs (${tag}) timeout:\n${buf}`)), 90_000);
    const on = (chunk) => {
      buf += chunk.toString();
      const mo = buf.match(OPEN_LINE);
      const ma = buf.match(API_LINE);
      if (mo && ma) { clearTimeout(t); res({ gatewayOrigin: mo[1], apiOrigin: ma[1] }); }
    };
    child.stdout.on("data", on);
    child.stderr.on("data", on);
    child.once("exit", (code) => { clearTimeout(t); rej(Error(`dev.mjs (${tag}) exited ${code}:\n${buf}`)); });
  });
  return { child, apiSecret, ...origins };
}

async function openGui(chrome, gatewayOrigin) {
  const warnings = [];
  const cdp = await Cdp.tab(chrome.endpoint, { timeout: 15_000 });
  await cdp.call("Emulation.setDeviceMetricsOverride", { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false });
  cdp.listeners.add((msg) => {
    if (msg.method === "Runtime.consoleAPICalled") {
      const ev = msg.params;
      if (ev.type === "error" || ev.type === "warning") {
        const txt = (ev.args ?? []).map((a) => a.value ?? a.description ?? "").join(" ");
        if (!/WebGPU|Dual-source/.test(txt)) warnings.push(txt);
      }
    }
  });
  await cdp.call("Page.addScriptToEvaluateOnNewDocument", {
    source: `(() => {
      globalThis.__prepSnapshots = [];
      globalThis.__roundSnapshots = [];
      const orig = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function(msg, ...rest) {
        if (typeof msg === "string" && msg.includes("view_json")) {
          try {
            const req = JSON.parse(msg);
            if (typeof req?.view_json === "string" && req.view_json.includes('"preparation"')) {
              const prep = JSON.parse(req.view_json)?.state?.preparation;
              if (prep?.draft) globalThis.__prepSnapshots.push(prep);
            }
            if (typeof req?.view_json === "string" && req.view_json.includes('"round"')) {
              const round = JSON.parse(req.view_json)?.state?.round;
              if (round) globalThis.__roundSnapshots.push(round);
            }
          } catch {}
        }
        return orig.call(this, msg, ...rest);
      };
    })()`,
  });
  await cdp.call("Page.navigate", { url: `${gatewayOrigin}/gui/?session-trace` });
  await delay(2000);
  await cdp.evaluate(`(() => {
    const c = document.querySelector("canvas");
    const ta = [...(c?.parentElement?.children ?? [])].find((e) => e.tagName === "TEXTAREA");
    (ta ?? c)?.focus();
  })()`);
  await pressEnter(cdp);
  return { cdp, warnings };
}

async function waitForBoxKey(cdp, pattern, label, timeoutMs = 15_000) {
  for (const end = Date.now() + timeoutMs; Date.now() < end; await delay(80)) {
    const g = await packGeometry(cdp);
    const keys = g ? Object.keys(JSON.parse(g.rects)?.boxes ?? {}) : [];
    const hit = keys.find((k) => pattern.test(k));
    if (hit) return hit;
  }
  throw Error(`timed out waiting for ${label}`);
}

async function waitForLedger(apiOrigin, secret, predicate, label, timeoutMs = 15_000) {
  let rows = [];
  for (const end = Date.now() + timeoutMs; Date.now() < end; await delay(80)) {
    rows = await fetchLedger(apiOrigin, secret);
    if (predicate(rows)) return rows;
  }
  throw Error(`timed out waiting for ${label}; last rows=${JSON.stringify(rows.slice(-6))}`);
}

async function waitForPrep(cdp, predicate, label, timeoutMs = 15_000) {
  let last = null;
  for (const end = Date.now() + timeoutMs; Date.now() < end; await delay(80)) {
    const snaps = await cdp.evaluate("globalThis.__prepSnapshots ?? []");
    last = snaps.at(-1) ?? null;
    for (let i = snaps.length - 1; i >= 0; i--) {
      if (predicate(snaps[i])) return snaps[i];
    }
  }
  throw Error(`timed out waiting for ${label}; last preparation=${JSON.stringify(last)}`);
}

async function waitForRound(cdp, predicate, label, timeoutMs = 15_000) {
  let last = null;
  for (const end = Date.now() + timeoutMs; Date.now() < end; await delay(80)) {
    const snaps = await cdp.evaluate("globalThis.__roundSnapshots ?? []");
    last = snaps.at(-1) ?? null;
    for (let i = snaps.length - 1; i >= 0; i--) {
      if (predicate(snaps[i])) return snaps[i];
    }
  }
  throw Error(`timed out waiting for ${label}; last round=${JSON.stringify(last)}`);
}

async function runLobbyFlows(chrome, runDir) {
  const srv = await startDev(runDir, "lobby", "space_station", "tests/maps/Box.ron");
  let cdp;
  try {
    const tab = await openGui(chrome, srv.gatewayOrigin);
    cdp = tab.cdp;
    const nameCtrl = await waitForLaidControl(cdp, /\/preparation\/name$/, {}, 12_000);
    const addCtrl = await waitForLaidControl(cdp, /\/preparation\/add$/, {}, 5_000);

    // Flow 0: nobody ready yet — the round holds its full countdown and
    // says it is waiting instead of silently spending it.
    const held = await waitForRound(
      cdp,
      (r) => r.phase === "preparing" && r.waiting === true && r.ready === 0,
      "held countdown with zero ready",
    );
    assert.equal(held.remaining_seconds, 120,
      `Flow 0: held countdown names its full length, got ${JSON.stringify(held)}`);
    const typingSeq = (await fetchLedger(srv.apiOrigin, srv.apiSecret)).at(-1)?.seq ?? 0;

    // Flow 1: type name with keydown, click Add role at once -> keeps both.
    await clickAt(cdp, nameCtrl.x, nameCtrl.y);
    await delay(200);
    await typeKeyDown(cdp, "Alex");
    await delay(150);
    const typedDrafts = (await fetchLedger(srv.apiOrigin, srv.apiSecret, typingSeq))
      .filter((e) => e.event === "draft_accepted");
    console.log(`lobby-live: draft_accepted rows while typing (before Add click): ${typedDrafts.length}`);
    await clickAt(cdp, addCtrl.x, addCtrl.y);
    await delay(250);
    await tapKey(cdp, ARROW_DOWN);
    await delay(150);
    await pressEnter(cdp);
    const prep1 = await waitForPrep(
      cdp,
      (p) => (p.draft?.name === "Alex" && p.draft?.ranked_jobs?.includes("assistant")) || Boolean(p.issue),
      "accepted draft (Alex + assistant) after Add role",
    );
    assert.equal(
      prep1.draft?.name,
      "Alex",
      `Flow 1: expected accepted draft name "Alex" after Add role, got ${JSON.stringify(prep1.draft)} (issue=${prep1.issue ?? "none"})`,
    );
    assert.ok(
      prep1.draft?.ranked_jobs?.includes("assistant"),
      `Flow 1: expected ranked_jobs to include "assistant", got ${JSON.stringify(prep1.draft)}`,
    );
    await waitForBoxKey(cdp, /\/preparation\/ranked\/assistant$/, "ranked assistant row");
    const refusals = tab.warnings.filter((w) => /package action refused/.test(w));
    assert.deepEqual(refusals, [], `unexpected package action refusal: ${JSON.stringify(refusals)}`);

    // Flow 2: edit existing name with keydown (no Enter), click enabled Ready at once -> keeps edit.
    const readyCtrl = await waitForLaidControl(cdp, /\/preparation\/ready$/, {}, 5_000);
    const revBefore = (await fetchLedger(srv.apiOrigin, srv.apiSecret))
      .filter((e) => e.event === "draft_accepted")
      .at(-1)?.revision ?? 0;
    await clickAt(cdp, nameCtrl.x, nameCtrl.y);
    await delay(200);
    await typeKeyDown(cdp, "2");
    await delay(150);
    await clickAt(cdp, readyCtrl.x, readyCtrl.y);
    const rows = await waitForLedger(
      srv.apiOrigin,
      srv.apiSecret,
      (r) => r.some((e) => e.event === "ready_changed" && e.ready === true),
      "ready_changed(true)",
    );
    const prep2 = await waitForPrep(cdp, (p) => p.ready === true, "ready preparation snapshot");
    assert.equal(
      prep2.draft?.name,
      "Alex2",
      `Flow 2: expected accepted draft name "Alex2" before Ready, got ${JSON.stringify(prep2.draft)} (rev=${prep2.revision})`,
    );
    const draftAfter = rows.find((e) => e.event === "draft_accepted" && e.revision > revBefore);
    const readyRow = rows.find((e) => e.event === "ready_changed" && e.ready === true);
    assert.ok(
      draftAfter,
      `expected draft_accepted (revision > ${revBefore}) for Alex2 before Ready; rows=${JSON.stringify(rows.slice(-8))}`,
    );
    assert.ok(
      readyRow && draftAfter.seq < readyRow.seq,
      `edited draft_accepted (${draftAfter?.seq}) must precede ready_changed (${readyRow?.seq})`,
    );

    // Flow 4: with a ready player the countdown actually spends its
    // seconds (the full spawn walk waits out or forces the remainder).
    const ticking = await waitForRound(
      cdp,
      (r) => r.phase === "preparing" && r.waiting === false
        && typeof r.remaining_seconds === "number" && r.remaining_seconds < 120,
      "countdown spending seconds after Ready",
    );
    assert.ok(ticking.ready >= 1, `Flow 4: countdown runs with a ready cohort, got ${JSON.stringify(ticking)}`);
  } finally {
    cdp?.close();
    await stopChild(srv.child).catch(() => {});
  }
}

async function runChatFlow(chrome, runDir) {
  const srv = await startDev(runDir, "chat", "free_build", "tests/maps/cold_outpost.ron");
  let cdp;
  try {
    const tab = await openGui(chrome, srv.gatewayOrigin);
    cdp = tab.cdp;
    await waitForLaidControl(cdp, /\/chat$/, {}, 12_000);
    let seated;
    for (const end = Date.now() + 10_000; Date.now() < end; await delay(80)) {
      const st = await fetchState(srv.apiOrigin, srv.apiSecret);
      const id = st?.sessions?.[0]?.entity;
      seated = (st?.entities ?? []).find((e) => e.entity === id);
      if (seated?.at) break;
    }
    assert.ok(seated?.at, "seated entity present on cold_outpost.ron");
    const beforePos = { x: seated.at.x, y: seated.at.y };
    const beforeSeq = (await fetchLedger(srv.apiOrigin, srv.apiSecret)).at(-1)?.seq ?? 0;

    // Flow 3: focus.chat via Enter, type bound gameplay letters ("wdrh") ->
    // assert no movement or wire world command BEFORE Enter, then submit arrives.
    await pressEnter(cdp);
    await delay(200);
    await typeKeyDown(cdp, "wdrh");
    await delay(250);
    const stAfter = await fetchState(srv.apiOrigin, srv.apiSecret);
    const entAfter = (stAfter?.entities ?? []).find((e) => e.entity === stAfter?.sessions?.[0]?.entity);
    assert.deepEqual(
      { x: entAfter?.at?.x, y: entAfter?.at?.y },
      beforePos,
      "bound movement letters must not move player while chat composer focused",
    );
    const wireDuringType = (await fetchLedger(srv.apiOrigin, srv.apiSecret, beforeSeq)).filter(
      (r) => r.origin === "wire" && r.event === "played",
    );
    assert.deepEqual(wireDuringType, [], `world wire command fired while chat focused: ${JSON.stringify(wireDuringType)}`);

    await pressEnter(cdp);
    await waitForLedger(
      srv.apiOrigin,
      srv.apiSecret,
      (r) => r.some((e) => e.seq > beforeSeq && e.event === "said" && e.text === "wdrh"),
      'said("wdrh") after chat Enter',
    );
    await waitForBoxKey(cdp, /\/log\/0/, "chat log line 0");
  } finally {
    cdp?.close();
    await stopChild(srv.child).catch(() => {});
  }
}

async function main() {
  const wd = setTimeout(() => { console.error("FATAL: lobby-live 180s watchdog"); process.exit(2); }, 180_000);
  wd.unref();
  await mkdir(join(PACK, "target"), { recursive: true });
  const runDir = await mkdtemp(join(PACK, "target/lobby-live-"));
  const chrome = await launchChrome({ profileDir: join(runDir, "chrome") });
  try {
    await runLobbyFlows(chrome, runDir);
    await runChatFlow(chrome, runDir);
    console.log("ok    lobby-live (held countdown, name+add-role, edit+ready, ticking countdown, focus.chat wdrh)");
  } finally {
    await chrome.stop().catch(() => {});
    clearTimeout(wd);
  }
}

main().catch((err) => {
  console.error(`FAIL  lobby-live: ${err.message}`);
  process.exitCode = 1;
});
