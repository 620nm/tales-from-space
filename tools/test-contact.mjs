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
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };

const fixture = JSON.parse(await readFile(new URL("../ui/fixtures/contact-inbox.json", import.meta.url))).view;
const deniedFixture = JSON.parse(await readFile(new URL("../ui/fixtures/contact-denied.json", import.meta.url))).view;
const nodes = (node) => [node, ...(node.children ?? []).flatMap(nodes)];
const copy = (value) => JSON.parse(JSON.stringify(value));
const contact = fixture.state.staff_contact;

assert.equal("threads" in contact, false);
assert.deepEqual(contact.conversations[0].ref, { round: "4", kind: "conversation", id: "26" });
assert.deepEqual(contact.conversations[0].messages[1].ref, { round: "4", kind: "message", id: "40" });
assert.equal(contact.conversations[0].messages[0].delivered, true);
assert.equal(contact.conversations[0].messages[0].fresh, false);
assert.equal("threads" in deniedFixture.state.staff_contact, false);
assert.deepEqual(deniedFixture.state.staff_contact.conversations, []);

test("contact reads displayed messages sequentially and merges older pages", () => {
  // A fresh view while closed does not read anything. Opening fetches the
  // canonical inbox, and its response immediately displays conversation 26.
  assert.equal(ui.onView(fixture).action, undefined);
  ui.render(fixture);
  const inbox = ui.onEvent({ id: "contact/entry", type: "activate" }, fixture).action;
  assert.equal(inbox.kind, "staff_contact");
  assert.equal(inbox.request.action.Inbox.after, null);
  ui.render(fixture);
  const rendered = nodes(ui.render(fixture));
  assert(rendered.some((node) => node.id === "contact/history/0/text" && node.text === "Earlier location check."));
  assert(rendered.some((node) => node.id === "contact/history/1/text" && node.text === "Please confirm your location."));
  assert(rendered.some((node) => node.id === "contact/history/2/text" && node.text === "I am in engineering."));

  const first = ui.onView(fixture).action;
  assert.deepEqual(first.request.action.Delivered.message, { round: "4", kind: "message", id: "40" });
  assert.equal(ui.onEvent({ id: "contact/list/0", type: "activate" }, fixture).action, undefined);

  // Trusted delivery retains exact receipts across coalesced views. Wait for
  // the acknowledgement while other updates arrive.
  const twoUnread = copy(fixture);
  twoUnread.revision = 5;
  twoUnread.state.staff_contact.revision = "5";
  twoUnread.state.staff_contact.unread = 2;
  twoUnread.state.staff_contact.conversations[0].unread = 2;
  twoUnread.state.staff_contact.conversations[0].messages.push({
    ref: { round: "4", kind: "message", id: "42" },
    from: "staff", body: "Please report to the access desk.", second: 30,
    delivered: false, unread: true, fresh: false,
  });
  for (let revision = 5; revision < 25; revision++) {
    twoUnread.revision = revision;
    assert.equal(ui.onView(twoUnread).action, undefined, "queued views cannot duplicate the pending receipt");
  }

  const firstRead = copy(twoUnread);
  firstRead.state.staff_contact.unread = 1;
  firstRead.state.staff_contact.conversations[0].unread = 1;
  firstRead.state.staff_contact.conversations[0].messages[1].delivered = true;
  firstRead.state.staff_contact.conversations[0].messages[1].unread = false;
  const second = ui.onView(firstRead).action;
  assert.deepEqual(second.request.action.Delivered.message, { round: "4", kind: "message", id: "42" });

  const allRead = copy(firstRead);
  allRead.state.staff_contact.unread = 0;
  allRead.state.staff_contact.conversations[0].unread = 0;
  allRead.state.staff_contact.conversations[0].messages.at(-1).delivered = true;
  allRead.state.staff_contact.conversations[0].messages.at(-1).unread = false;
  assert.equal(ui.onView(allRead).action, undefined);

  // Inbox pagination replaces the native page. The pack cache retains the
  // newer page and keeps the older cursor on the selected conversation.
  const older = copy(allRead);
  older.revision = 3;
  older.state.staff_contact.revision = "3";
  older.state.staff_contact.cursor = "30";
  older.state.staff_contact.conversations[0].cursor = "30";
  older.state.staff_contact.conversations[0].messages = [
    { ref: { round: "4", kind: "message", id: "27" }, from: "staff", body: "Initial check-in.", second: 4, delivered: true, unread: false, fresh: false },
    { ref: { round: "4", kind: "message", id: "28" }, from: "player", body: "Acknowledged.", second: 8, delivered: true, unread: false, fresh: false },
  ];
  ui.onView(older);
  const olderRendered = nodes(ui.render(older));
  assert(olderRendered.some((node) => node.text === "Initial check-in."));
  assert(olderRendered.some((node) => node.text === "Please confirm your location."));
  assert(olderRendered.some((node) => node.id === "contact/history/load"));
  const load = ui.onEvent({ id: "contact/history/load", type: "activate" }, older).action;
  assert.equal(load.request.action.Inbox.after, "30");

  // Reply bodies are bounded by native UTF-8 bytes, and keep exact refs.
  ui.render(allRead);
  const reply = ui.onEvent({ id: "contact/composer", type: "submit", value: "é".repeat(3000) }, allRead).action;
  assert.equal(reply.request.action.Reply.conversation.id, "26");
  assert.equal(Buffer.byteLength(reply.request.action.Reply.body), 4096);
});

test("historical contacts retain cross-round messages and exact refs", () => {
  const current = copy(fixture);
  current.revision = 16;
  current.state.round.round = 5;
  current.state.staff_contact.revision = "16";
  current.state.staff_contact.unread = 1;
  current.state.staff_contact.conversations[0] = {
    ref: { round: "4", kind: "conversation", id: "6" },
    messages: [
      { ref: { round: "5", kind: "message", id: "16" }, from: "staff", body: "Current contact.", second: 2, delivered: false, unread: true, fresh: true },
      { ref: { round: "5", kind: "message", id: "17" }, from: "player", body: "Current reply.", second: 3, delivered: true, unread: false, fresh: false },
    ],
    cursor: null,
    unread: 1,
  };
  const historyTexts = (view) => nodes(ui.render(view))
    .filter((node) => /^contact\/history\/\d+\/text$/.test(node.id))
    .map((node) => node.text);

  ui.render(current);
  const inbox = ui.onEvent({ id: "contact/entry", type: "activate" }, current).action;
  assert.equal(inbox.request.action.Inbox.after, null);
  const first = ui.onView(current).action;
  assert.deepEqual(first.request.action.Delivered.conversation, { round: "4", kind: "conversation", id: "6" });
  assert.deepEqual(first.request.action.Delivered.message, { round: "5", kind: "message", id: "16" });
  for (let revision = 17; revision < 25; revision++) {
    current.revision = revision;
    current.state.staff_contact.revision = String(revision);
    assert.equal(ui.onView(current).action, undefined, "queued views cannot duplicate the pending receipt");
  }

  const older = copy(current);
  older.revision = 14;
  older.state.staff_contact.revision = "14";
  older.state.staff_contact.conversations[0].messages = [
    { ref: { round: "4", kind: "message", id: "14" }, from: "staff", body: "Older contact.", second: 90, delivered: true, unread: false, fresh: false },
    { ref: { round: "4", kind: "message", id: "15" }, from: "player", body: "Older reply.", second: 91, delivered: true, unread: false, fresh: false },
  ];
  older.state.staff_contact.unread = 0;
  older.state.staff_contact.conversations[0].unread = 0;
  assert.deepEqual(historyTexts(older), ["Older contact.", "Older reply.", "Current contact.", "Current reply."]);
  assert.equal(ui.onView(older).action, undefined, "the pending current-round receipt survives an older page");

  const acknowledged = copy(older);
  acknowledged.revision = 18;
  acknowledged.state.staff_contact.revision = "18";
  acknowledged.state.staff_contact.conversations[0].messages.push({
    ref: { round: "5", kind: "message", id: "16" }, from: "staff", body: "Current contact.", second: 2, delivered: true, unread: false, fresh: false,
  });
  acknowledged.state.staff_contact.conversations[0].messages.push({
    ref: { round: "5", kind: "message", id: "17" }, from: "player", body: "Current reply.", second: 3, delivered: true, unread: false, fresh: false,
  });
  acknowledged.state.staff_contact.unread = 0;
  acknowledged.state.staff_contact.conversations[0].unread = 0;
  assert.equal(ui.onView(acknowledged).action, undefined);

  ui.render(acknowledged);
  const reply = ui.onEvent({ id: "contact/composer", type: "submit", value: "Follow-up" }, acknowledged).action;
  assert.deepEqual(reply.request.action.Reply.conversation, { round: "4", kind: "conversation", id: "6" });

  const sameId = copy(acknowledged);
  sameId.state.staff_contact.conversations[0].messages.push({
    ref: { round: "4", kind: "message", id: "17" }, from: "staff", body: "Round four message.", second: 100, delivered: true, unread: false, fresh: false,
  });
  assert(historyTexts(sameId).includes("Current reply."));
  assert(historyTexts(sameId).includes("Round four message."));

  sameId.state.staff_contact.conversations[0].messages.push(
    { ref: { round: "5", kind: "message", id: "9007199254740993" }, from: "staff", body: "Journal high.", second: 1, delivered: true, unread: false, fresh: false },
    { ref: { round: "5", kind: "message", id: "9007199254740992" }, from: "staff", body: "Journal low.", second: 99, delivered: true, unread: false, fresh: false },
  );
  assert.deepEqual(historyTexts(sameId).slice(-2), ["Journal low.", "Journal high."]);
});

test("denied contact uses the canonical denial projection", () => {
  ui.render(deniedFixture);
  const inbox = ui.onEvent({ id: "contact/entry", type: "activate" }, deniedFixture).action;
  assert.equal(inbox.kind, "staff_contact");
  const rendered = nodes(ui.render(deniedFixture));
  assert(rendered.some((node) => node.id === "contact/window/unavailable"));
});

test("contact entry remains available during round preparation", () => {
  const preparing = copy(fixture);
  preparing.revision = 12;
  preparing.body = false;
  preparing.state.round = {
    round: 12, phase: "preparing", remaining_seconds: 120, ready: 0,
    connected: 2, paused: false, waiting: true, fault: null,
  };
  const rendered = nodes(ui.render(preparing));
  assert(rendered.some((node) => node.id === "contact/entry"));
  assert(rendered.some((node) => node.id === "preparation-contact"));
  assert(rendered.some((node) => node.id === "lobby-preparation"));
  preparing.state.staff_view = true;
  const staffView = nodes(ui.render(preparing));
  assert(!staffView.some((node) => node.id === "preparation-contact"));
  assert(!staffView.some((node) => node.id === "lobby-preparation"));
  assert(staffView.some((node) => node.id === "contact/entry"));
});
