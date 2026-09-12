import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: "export { chatPanel } from './chat'; export { begin, event } from './view';", resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const UI = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const catalog = JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url), "utf8"));
Object.assign(catalog, {
  "lunatic/tfs:ui.comms.tab_ooc": "OOC",
  "lunatic/tfs:ui.comms.ooc_speaker": "Player {name}:",
  "lunatic/tfs:ui.comms.channel_label": "Channel",
  "lunatic/tfs:ui.comms.compose_ooc": "OOC ›",
});
globalThis.__lunaticLocale = { tag: "en", catalog };

const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const nodes = (view) => { UI.begin(); return UI.chatPanel(view).flatMap(flatten); };
const node = (list, id) => list.find((entry) => entry.id === id);
const logView = {
  body: false,
  state: {},
  log: [
    { kind: "speech", name: "Nearby", text: "Can you hear me?" },
    { kind: "speech", channel: "common", name: "Radio", text: "Common channel." },
    { kind: "ooc", channel: "ignored", name: "A7K2", text: "Outside the station." },
    { kind: "system", text: "The airlock is sealed." },
  ],
};

test("OOC tab uses explicit kind even if a line has a channel", () => {
  let rendered = nodes(logView);
  assert.equal(node(rendered, "log/2/who").text, "Player A7K2:");
  assert.equal(node(rendered, "log/2/chan"), undefined);
  assert.equal(node(rendered, "log/2/text").text, "Outside the station.");

  UI.event({ id: "chat-tab/ooc", type: "activate" });
  rendered = nodes(logView);
  assert(node(rendered, "log/2/text"));
  assert.equal(node(rendered, "log/0/text"), undefined);
  assert.equal(node(rendered, "log/1/text"), undefined);
  assert.equal(node(rendered, "log/3/text"), undefined);
});

test("bodyless chat is an OOC composer and keeps the chat binding", () => {
  const rendered = nodes({ ...logView, body: true, state: { identity: { you: null } } });
  assert.equal(node(rendered, "chat").type, "input");
  assert.equal(node(rendered, "chat-channel"), undefined);
  assert.deepEqual(UI.event({ id: "chat", type: "input", value: "Hello outside." }).action,
    { kind: "ooc", text: "Hello outside." });
});

test("gameplay chat selects local speech or OOC without changing the input id", () => {
  const view = { body: true, state: { identity: { you: 1 } }, log: [], documents: {} };
  let rendered = nodes(view);
  assert.equal(node(rendered, "chat").id, "chat");
  assert.equal(node(rendered, "chat-channel").value, "local");
  assert.deepEqual(UI.event({ id: "chat", type: "input", value: "Local words." }).action,
    { kind: "say", text: "Local words." });
  UI.event({ id: "chat-channel", type: "change", value: "ooc" });
  rendered = nodes(view);
  assert.equal(node(rendered, "chat").id, "chat");
  assert.equal(node(rendered, "chat-channel").value, "ooc");
  assert.deepEqual(UI.event({ id: "chat", type: "input", value: "OOC words." }).action,
    { kind: "ooc", text: "OOC words." });
});

test("lobby composition reuses chat identity with an OOC-only layout", () => {
  const view = { body: true, state: { identity: { you: null } }, log: [], documents: {} };
  const rendered = (() => { UI.begin(); return UI.chatPanel(view, { mode: "ooc", layout: "lobby" }).flatMap(flatten); })();
  assert.deepEqual(node(rendered, "chat-tabs").children.map((tab) => tab.id), ["chat-tabs/ooc"]);
  assert.equal(node(rendered, "chat-channel"), undefined);
  assert.equal(node(rendered, "chat").id, "chat");
  assert(node(rendered, "chat-pane").class.includes("lobby-ooc-screen"));
  assert.deepEqual(UI.event({ id: "chat", type: "input", value: "Lobby OOC." }).action,
    { kind: "ooc", text: "Lobby OOC." });
});
