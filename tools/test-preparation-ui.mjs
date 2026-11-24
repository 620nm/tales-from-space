import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: "export { default as ui } from './main';", resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { ui } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const view = JSON.parse(await readFile(new URL("../ui/fixtures/preparation/preparation.json", import.meta.url)));
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];

test("the footer waits for ready players instead of a frozen countdown", async () => {
  const timerOf = async (name) => {
    const { view } = JSON.parse(await readFile(new URL(`../ui/fixtures/preparation/${name}.json`, import.meta.url)));
    return flatten(ui.render(view)).find((node) => node.id === "lobby/status-footer/timer").text;
  };
  assert.equal(await timerOf("preparation"), "Waiting for players",
    "zero ready players hold the countdown at its full length; say so");
  assert.equal(await timerOf("preparation-ready"), "Starts in 97s",
    "a running countdown keeps its seconds");
});
test("a locked setup says unready only to a ready player", () => {
  const noticeOf = (prep) => flatten(ui.render(draftView(131, 0,
    { name: "Ada", ranked_jobs: ["assistant"], fallback: false }, null, prep)))
    .find((node) => node.id === "preparation/issue")?.text;
  assert.equal(noticeOf({ issue: "locked", ready: true }),
    "Your setup is locked. Unready before making changes.");
  assert.equal(noticeOf({ issue: "locked", ready: false }),
    "Setup is closed for this round. Wait for the next round to change it.");
});
test("an empty name says why Ready stays disabled", () => {
  const unnamed = draftView(130, 0, { name: "", ranked_jobs: ["assistant"], fallback: false }, null);
  const hint = flatten(ui.render(unnamed)).find((node) => node.id === "preparation/name-empty");
  assert.equal(hint?.text, "Enter a name to ready up.");
  const named = draftView(130, 0, { name: "Ada", ranked_jobs: ["assistant"], fallback: false }, null);
  assert.equal(flatten(ui.render(named)).some((node) => node.id === "preparation/name-empty"), false);
});
test("preparation name commits only a complete field change or Enter submission", () => {
  const tree = ui.render(view.view);
  const name = flatten(tree).find((node) => node.id === "preparation/name");
  assert(name, "preparation exposes its name input");

  const expected = {
    kind: "character_draft",
    round: 12,
    revision: 3,
    draft: { name: "Mira Pike", ranked_jobs: ["assistant", "engineer"], fallback: false },
  };
  for (const type of ["change", "submit"]) {
    ui.render(view.view);
    assert.deepEqual(ui.onEvent({ id: name.id, type, value: "Mira Pike" }, view.view).action, expected);
  }
});

test("a later blur does not resubmit an acknowledged name", async () => {
  for (const fixture of ["preparation/preparation", "preparation/preparation-playing"]) {
    const { view } = JSON.parse(await readFile(new URL(`../ui/fixtures/${fixture}.json`, import.meta.url)));
    const accepted = structuredClone(view);
    accepted.state.preparation.revision++;
    accepted.state.preparation.draft.name = "Mira Pike";
    ui.render(accepted);
    assert.equal(ui.onEvent({ id: "preparation/name", type: "change", value: "Mira Pike" }, accepted)?.action,
      undefined, `${fixture}: blur after acceptance must not start another save`);
  }
});

test("readiness capability controls Ready and Unready during a queued save", () => {
  for (const ready of [false, true]) {
    const state = structuredClone(view.view);
    state.state.preparation.ready = ready;
    state.state.preparation.can_ready = false;
    state.state.preparationPending = true;
    state.state.preparationCanQueue = true;
    const button = flatten(ui.render(state)).find((node) => node.id === "preparation/ready");
    assert.equal(button.disabled, true);
  }
});

// The lobby keeps the accepted draft in the package record and offers it
// back only over an untouched server draft, a bounded number of times.
const EMPTY = { name: "", ranked_jobs: [], fallback: false };
const SAVED = { name: "Ada", ranked_jobs: ["engineer", "gone"], fallback: true };
/** A fresh copy of the fixture view at `round`/`revision` with these drafts. */
function draftView(round, revision, draft, stored, prep = {}) {
  const next = JSON.parse(JSON.stringify(view.view));
  Object.assign(next.state.preparation, { round, revision, draft, issue: null, ...prep });
  next.state.round.round = round;
  next.state.packageRecord = { value: stored ? { version: 1, draft: stored } : null, persistent: true, fault: null };
  return next;
}
const act = (v) => ui.onView(v).action;

const pending = (v) => { v.state.preparationPending = true; return v; };

test("an untouched draft is restored, filtered to the roster, and a refusal ends it", () => {
  assert.deepEqual(act(draftView(101, 0, EMPTY, SAVED)), {
    kind: "character_draft", round: 101, revision: 0,
    draft: { name: "Ada", ranked_jobs: ["engineer"], fallback: true },
  });
  assert.equal(act(pending(draftView(101, 0, EMPTY, SAVED))), undefined);
  // The server refused the restored name: the issue stops any resend.
  assert.equal(act(draftView(101, 0, EMPTY, SAVED, { issue: "invalid_draft" })), undefined);
});
test("sends dropped under an open menu keep the round's restore, within a cap", () => {
  const dropped = Array.from({ length: 10 }, () => act(draftView(102, 0, EMPTY, SAVED)));
  assert(dropped.every(Boolean), "a send the server never saw is resent on the next view");
  const rest = Array.from({ length: 100 }, () => act(draftView(102, 0, EMPTY, SAVED))).filter(Boolean);
  assert.equal(10 + rest.length, 64);
});
test("server-seen restores stop after three; a new round starts over", () => {
  let seen = 0;
  for (let view = 0; view < 12; view++) {
    if (act(draftView(109, 0, EMPTY, SAVED))) {
      seen++;
      act(pending(draftView(109, 0, EMPTY, SAVED)));
    }
  }
  assert.equal(seen, 3);
  assert(act(draftView(110, 0, EMPTY, SAVED)));
});
test("a dropped write shows no notice and is resent", () => {
  const edited = { name: "Di", ranked_jobs: [], fallback: true };
  assert.equal(act(draftView(111, 4, edited, SAVED)).kind, "package_record_write");
  const back = draftView(111, 4, edited, SAVED);
  back.state.packageRecord = { ...back.state.packageRecord, fault: "invalid" };
  assert.equal(flatten(ui.render(back)).some((node) => node.id === "preparation/storage-unavailable"), false);
  assert.deepEqual(act(back).value.draft, edited);
});
test("a cleared or edited draft is saved, never restored over", () => {
  assert.deepEqual(act(draftView(103, 2, EMPTY, SAVED)), {
    kind: "package_record_write", value: { version: 1, draft: EMPTY },
  });
  const edited = { name: "Bo", ranked_jobs: ["assistant"], fallback: false };
  assert.deepEqual(act(draftView(103, 3, edited, SAVED)).value.draft, edited);
  assert.equal(act(draftView(103, 3, edited, edited)), undefined);
});
test("no restore when ready, locked, already drafted or without a record", () => {
  assert.equal(act(draftView(104, 0, EMPTY, SAVED, { ready: true })), undefined);
  assert.equal(act(draftView(105, 0, EMPTY, SAVED, { can_edit: false })), undefined);
  assert.equal(act(draftView(106, 0, { ...EMPTY, name: "Cy" }, SAVED)), undefined);
  const bare = draftView(107, 0, EMPTY, SAVED);
  delete bare.state.packageRecord;
  assert.equal(act(bare), undefined);
});
test("a stored draft the server would refuse is never restored", () => {
  const dup = { name: "Ada", ranked_jobs: ["engineer", "engineer"], fallback: false };
  assert.deepEqual(act(draftView(120, 0, EMPTY, dup)), {
    kind: "character_draft", round: 120, revision: 0,
    draft: { name: "Ada", ranked_jobs: ["engineer"], fallback: false },
  });
  const blank = { name: "   ", ranked_jobs: ["engineer"], fallback: false };
  assert.equal(act(draftView(121, 0, EMPTY, blank)), undefined);
  const long = { name: "A".repeat(65), ranked_jobs: [], fallback: true };
  assert.equal(act(draftView(122, 0, EMPTY, long)), undefined);
  const control = { name: "Ada" + String.fromCharCode(7), ranked_jobs: [], fallback: true };
  assert.equal(act(draftView(123, 0, EMPTY, control)), undefined);
  // The restore trims like the server (Rust str::trim), not like
  // JavaScript: a leading U+0085 is server whitespace, so the name
  // restores trimmed, while a trailing U+FEFF is kept verbatim.
  const nel = { name: "\u0085Ada", ranked_jobs: ["engineer"], fallback: false };
  assert.deepEqual(act(draftView(126, 0, EMPTY, nel)), {
    kind: "character_draft", round: 126, revision: 0,
    draft: { name: "Ada", ranked_jobs: ["engineer"], fallback: false },
  });
  const feff = { name: "Ada\uFEFF", ranked_jobs: ["engineer"], fallback: false };
  assert.deepEqual(act(draftView(127, 0, EMPTY, feff)), {
    kind: "character_draft", round: 127, revision: 0,
    draft: { name: "Ada\uFEFF", ranked_jobs: ["engineer"], fallback: false },
  });
  const capped = draftView(124, 0, EMPTY, SAVED);
  const jobs = Array.from({ length: 130 }, (_, i) => ({ key: `job${i}`, name: `Job ${i}` }));
  capped.state.jobs.jobs = jobs;
  capped.state.packageRecord.value.draft = { name: "Ada", ranked_jobs: jobs.map((job) => job.key), fallback: false };
  assert.equal(act(capped), undefined);
});
test("an unusable saved setup says so in the editor", () => {
  const blank = { name: "   ", ranked_jobs: ["engineer"], fallback: false };
  const tree = flatten(ui.render(draftView(125, 0, EMPTY, blank)));
  assert(tree.some((node) => node.id === "preparation/saved-unusable"));
  const usable = flatten(ui.render(draftView(125, 0, EMPTY, SAVED)));
  assert.equal(usable.some((node) => node.id === "preparation/saved-unusable"), false);
});
test("a refused latejoin name edit says so on the job board", async () => {
  const { view: playing } = JSON.parse(await readFile(new URL("../ui/fixtures/preparation/preparation-playing.json", import.meta.url)));
  assert.equal(flatten(ui.render(playing)).some((node) => node.id === "preparation/issue"), false);
  playing.state.preparation.issue = "invalid_draft";
  const notice = flatten(ui.render(playing)).find((node) => node.id === "preparation/issue");
  assert.equal(notice.text, "Your setup is invalid. Choose a name and a role or fallback.");
});
test("a record fault shows the saving notice without closing the lobby", () => {
  const faulted = draftView(108, 3, view.view.state.preparation.draft, view.view.state.preparation.draft);
  faulted.state.packageRecord.fault = "write";
  const tree = flatten(ui.render(faulted));
  assert(tree.some((node) => node.id === "preparation/storage-unavailable"));
  assert(tree.some((node) => node.id === "preparation/ready" && !node.disabled));
});
