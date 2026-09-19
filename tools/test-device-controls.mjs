import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Set LUNATIC_ENGINE or pass the absolute engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: {
    contents: `export { controlWorkspace } from './documents-controls';
      export { begin, event } from './view';`,
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url), "utf8")),
};
const U = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const fixture = JSON.parse(await readFile(new URL("../ui/fixtures/device-workspace/air-alarm-controls.json", import.meta.url), "utf8"));
const fixtureState = fixture.view.documents["1"].state;

const doc = { id: 7, generation: 2, title: "Air alarm" };
const label = (text) => text;
const panel = (address, name, extra = {}) => ({
  address, name, online: true,
  readouts: [
    { section: label("Power"), label: label("Room pressure"), value: label("101.3 kPa"), tone: "on" },
    { section: label("Power"), label: label("Supply line pressure"), value: label("300 kPa") },
    { section: label("Power"), label: label("Power supply"), value: label("On"), tone: "on" },
  ],
  toggles: [
    { section: label("Power"), field: `${address}/power`, label: label("Power"), on: true, on_text: label("On"), off_text: label("Off") },
    { section: label("Reach"), field: `${address}/service`, option: "1", group: `${address}/service`, label: label("Tile (1×)"), on: true, on_text: label("Selected"), off_text: label("Select") },
    { section: label("Reach"), field: `${address}/service`, option: "4", group: `${address}/service`, label: label("Cardinals (4×)"), on: false, on_text: label("Selected"), off_text: label("Select") },
    { section: label("Gas"), field: `${address}/filter`, option: "carbon_dioxide", label: label("Carbon dioxide"), on: true, on_text: label("Selected"), off_text: label("Select") },
    { section: label("Gas"), field: `${address}/filter`, option: "plasma", label: label("Plasma"), on: false, on_text: label("Selected"), off_text: label("Select") },
  ],
  labels: [
    { section: label("Power"), row: "word", label: label("Output"), text: label("Running") },
  ],
  setpoints: [
    { section: label("Pressure"), field: `${address}/hold`, label: label("Hold at"), unit: "kPa", value: 101.33, min: 0, max: 4500, step: 0.01, decimals: 2 },
  ],
  notice: label("Provider notice"),
  matter: [{ section: "Air", volume_l: 10, headspace_l: 8, temperature_k: 293, states: [{ phase: "gas", moles: 1, measure: 101, mass_g: 0, rows: [{ key: "oxygen", name: "Oxygen", moles: 1, measure: 21, mass_g: 32 }] }] }],
  ...extra,
});

const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const render = (state, active = true) => {
  U.begin();
  return U.controlWorkspace("doc/7/2", doc, state, active).flatMap(flatten);
};
const command = (id, extra = {}) => U.event({ id, ...extra }).action;

test("same-address controls stay under their source panel and keep scoped payloads", () => {
  const nodes = render({ document: "modules", control_panels: [panel("vnt-01", "Vent pump"), panel("scr-02", "Air scrubber")] });
  const ids = nodes.map((node) => node.id);
  assert.equal(new Set(ids).size, ids.length);
  assert(nodes.some((node) => node.id === "doc/7/2/controls/vnt-01/name"));
  assert(nodes.some((node) => node.id === "doc/7/2/controls/scr-02/name"));
  const buttons = nodes.filter((node) => node.type === "button" && node.id.includes("toggle"));
  assert(buttons.some((node) => node.id.includes("vnt-01")));
  assert(buttons.some((node) => node.id.includes("scr-02")));
  assert(ids.every((id) => id.length <= 120), "control ids stay within the protocol budget");
  const first = buttons.find((node) => node.id.includes("vnt-01"));
  assert.deepEqual(command(first.id), { kind: "document", document: 7, generation: 2, act: "toggle", payload: { field: "vnt-01/power" } });
});

test("empty reach is disclosed without invented targets or counts", () => {
  const nodes = render({ document: "modules", control_panels: [] });
  assert(nodes.some((node) => node.id === "doc/7/2/controls/empty"));
  assert.equal(nodes.filter((node) => node.id.includes("/controls/") && node.id.endsWith("/name")).length, 0);
  const empty = nodes.find((node) => node.id === "doc/7/2/controls/empty");
  assert(empty?.text);
  assert.notEqual(empty.text, "lunatic/tfs:ui.workspace.controls_empty");
});

test("inactive documents disclose sections but expose no active controls", () => {
  const nodes = render({ document: "modules", control_panels: [panel("vnt-01", "Vent pump")] }, false);
  const controls = nodes.filter((node) => node.id.includes("/controls/vnt-01/") && ["button", "input"].includes(node.type));
  assert(controls.length > 0);
  assert(controls.every((node) => node.disabled === true));
});

test("panel sections retain readouts, choice groups, setpoints, notice and matter", () => {
  const nodes = render({ document: "modules", control_panels: [panel("scr-02", "Air scrubber")] });
  for (const word of ["Power", "Reach", "Gas", "Room pressure", "Cardinals (4×)", "Hold at", "Provider notice", "Oxygen"]) {
    assert(nodes.some((node) => node.text === word), `missing ${word}`);
  }
  const selection = nodes.find((node) => node.type === "button" && command(node.id)?.payload?.option === "carbon_dioxide");
  assert(selection);
  assert.deepEqual(command(selection.id), {
    kind: "document", document: 7, generation: 2, act: "toggle",
    payload: { field: "scr-02/filter", option: "carbon_dioxide" },
  });
});

test("the full disclosed gas roster keeps every provider row and section", () => {
  const target = fixtureState.control_panels.find((panel) => panel.toggles.some((toggle) => toggle.field.endsWith("/filter")));
  const nodes = render(fixtureState);
  const gases = target.toggles.filter((toggle) => toggle.field.endsWith("/filter"));
  assert(gases.length >= 15, "native fixture should exercise the full roster");
  for (const gas of gases) assert(nodes.some((node) => node.text === gas.label.text), `missing ${gas.label.text}`);
  for (const section of ["Station atmosphere", "Atmospheric poisons", "Volatiles"])
    assert(nodes.some((node) => node.text === section), `missing ${section}`);
  const firstGas = nodes.find((node) => node.type === "button" && command(node.id)?.payload?.option === "o2");
  assert(firstGas);
  assert.deepEqual(command(firstGas.id), {
    kind: "document", document: 7, generation: 2, act: "toggle",
    payload: { field: gases.find((gas) => gas.option === "o2").field, option: "o2" },
  });
});

test("panel status follows native online state and explains disabled controls", () => {
  const nodes = render({ document: "modules", control_panels: [
    panel("offline", "Offline unit", { online: false }),
    panel("gone", "Gone unit", { online: null }),
    panel("unknown", "Unreported unit", { online: undefined }),
  ] });
  for (const address of ["offline", "gone"]) {
    const controls = nodes.filter((node) => node.id.includes(`/controls/${address}/`) && ["button", "input"].includes(node.type));
    assert(controls.length > 0);
    assert(controls.every((node) => node.disabled === true), `${address} controls are disabled`);
    assert(nodes.some((node) => node.id === `doc/7/2/controls/${address}/disabled`));
    assert(nodes.some((node) => node.id === `doc/7/2/controls/${address}/status`));
  }
  assert(!nodes.some((node) => node.id === "doc/7/2/controls/unknown/status"));
});

test("same rendered section text keeps distinct native label identities", () => {
  const nodes = render({ document: "modules", control_panels: [panel("labels", "Label unit", {
    readouts: [
      { section: "Same heading", label: "one", value: "1" },
      { section: { text: "Same heading" }, label: "two", value: "2" },
    ],
    toggles: [], labels: [], setpoints: [], matter: [],
  })] });
  assert.equal(nodes.filter((node) => node.text === "Same heading").length, 2);
  assert(nodes.some((node) => node.text === "one"));
  assert(nodes.some((node) => node.text === "two"));
});

test("setpoint input and step buttons retain native set payloads", () => {
  const nodes = render({ document: "modules", control_panels: [panel("vnt-01", "Vent pump")] });
  const input = nodes.find((node) => node.type === "input" && node.id.endsWith("/set/vnt-01/hold/value"));
  assert(input);
  assert.deepEqual(command(input.id, { type: "submit", value: "102.5" }), {
    kind: "document", document: 7, generation: 2, act: "set", payload: { field: "vnt-01/hold", value: 102.5 },
  });
  const down = nodes.find((node) => node.type === "button" && node.id.endsWith("/set/vnt-01/hold/down"));
  assert(down);
  assert.deepEqual(command(down.id), {
    kind: "document", document: 7, generation: 2, act: "set", payload: { field: "vnt-01/hold", adjust: -0.01 },
  });
});

test("roster remains one native switch and gas rows remain individually actionable", () => {
  const nodes = render(fixtureState);
  const roster = nodes.filter((node) => node.type === "button" && command(node.id)?.payload?.field?.endsWith("/roster"));
  assert.equal(roster.length, 1);
  assert(nodes.some((node) => node.text === "oxygen"));
  assert(nodes.some((node) => node.text === "ammonia"));
});

test("long keys and duplicate provider identities retain bounded unique node ids", () => {
  const long = "x".repeat(110);
  const repeated = panel("same", "Repeated");
  repeated.setpoints.push({ ...repeated.setpoints[0] });
  const lengthy = panel("y".repeat(64), "Long", {
    toggles: [{ field: long, label: "Switch", on: true },
      { field: long, option: "one", label: "Choice", on: false }],
    setpoints: [{ ...repeated.setpoints[0], field: long }],
    labels: [{ row: "input", action: long, label: "Input", text: "Send", max_length: 20 }],
  });
  const nodes = render({ control_panels: [repeated, panel("same", "Other"),
    panel("bad/address", "Unsafe"), panel("address-2", "Lookalike"), lengthy] });
  const ids = nodes.map((node) => node.id);
  assert.equal(new Set(ids).size, ids.length);
  assert(ids.every((id) => id.length <= 120), ids.filter((id) => id.length > 120).join("\n"));
  const fields = nodes.filter((node) => node.type === "input").map((node) => command(node.id, { value: "1" })?.payload?.field).filter(Boolean);
  assert(fields.includes(long), "fallback ids retain the original native action field");
});
