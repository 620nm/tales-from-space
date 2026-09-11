// A module document, drawn section by section. Each heading is drawn
// once where its first row appears and its rows underneath in the order
// they were sent, so the SERVER's row order is the layout and the
// document grows no nesting level (docs/tgui/documents.md).
import type { ListRow, Tone, UiNode } from "@lunatic/ui";
import { Choice, Gauge, LabeledList, Section, Stack } from "@lunatic/ui";
import type {
  DocumentIdentity,
  LabelRow,
  ModuleState,
  Setpoint,
} from "./document-model";
import { documentAction } from "./document-action";
import { labelText } from "./labels";
import { matterBlock } from "./matter-block";
import { subjectCard, toggleRows } from "./documents-choices";
import { column, entry, press, row, some, text } from "./view";
import * as S from "./strings";

// A value longer than the row's cap is refused outright by
// `Sim::ui_act`, and no node in the vocabulary carries a length limit,
// so an over-long entry is cut here rather than pressed into silence.
const capped = (value: string, max: number | undefined): string =>
  max === undefined ? value : [...value].slice(0, Math.max(0, max)).join("");

const TONES: Tone[] = ["on", "off", "idle"];
const toneOf = (tone: string | null | undefined): Tone | undefined =>
  TONES.find((known) => known === tone);

/** A label on the left and one thing on the right, in the order sent. */
function labelRow(
  id: string,
  doc: DocumentIdentity,
  entryRow: LabelRow,
  active: boolean,
): UiNode {
  const caption = text(`${id}/label`, labelText(entryRow.label), [
    "grow",
    "list-label",
  ]);
  if (entryRow.row === "press")
    return row(
      id,
      [
        caption,
        press(
          `${id}/press`,
          labelText(entryRow.text),
          documentAction(doc, "toggle", {
            field: entryRow.field,
            ...(entryRow.option == null ? {} : { option: entryRow.option }),
          }),
          { disabled: !active || !entryRow.enabled, cls: ["mod-pill"] },
        ),
      ],
      { cls: ["module-row"] },
    );
  if (entryRow.row === "input") {
    const box = `${id}/value`;
    return row(
      id,
      [
        caption,
        entry(box, "", () => undefined, { submitOnly: true, disabled: !active, label: labelText(entryRow.label) }),
        press(
          `${id}/send`,
          labelText(entryRow.text) || S.SET,
          (e) =>
            documentAction(doc, "action", {
              action: entryRow.action,
              value: capped(e.value ?? "", entryRow.max_length),
            }),
          { submit: box, variant: "primary", disabled: !active },
        ),
      ],
      { cls: ["list-row"] },
    );
  }
  return row(
    id,
    [caption, text(`${id}/word`, labelText(entryRow.text), ["list-value"])],
    { cls: ["list-row"] },
  );
}

/**
 * A dial with its range under it. Nothing here does the arithmetic the
 * server owns: a step press sends the STEP it wants and the end stops
 * send `min`/`max`, and `Setpoint::resolve` decides what that comes to
 * (docs/tgui/action-boundary.md).
 */
function setpointRow(
  id: string,
  doc: DocumentIdentity,
  point: Setpoint,
  active: boolean,
): UiNode {
  const places = point.decimals ?? 0;
  const step = point.step && point.step > 0 ? point.step : 1;
  const spell = (value: number): string => value.toFixed(places);
  const move = (to: number) =>
    documentAction(doc, "set", { field: point.field, value: to });
  const stepBy = (by: number) =>
    documentAction(doc, "set", { field: point.field, adjust: by });
  const box = `${id}/value`;
  return column(
    id,
    [
      row(
        `${id}/head`,
        [
          text(`${id}/label`, labelText(point.label), ["grow", "list-label"]),
          text(
            `${id}/range`,
            S.range(spell(point.min), spell(point.max), point.unit),
            ["hint"],
          ),
        ],
        { cls: ["list-row"] },
      ),
      Stack(
        `${id}/controls`,
        some(
          press(`${id}/down`, S.LOWER, stepBy(-step), {
            disabled: !active,
          }),
          entry(
            box,
            spell(point.value),
            (value) => {
              const wanted = Number(value);
              return Number.isFinite(wanted) ? move(wanted) : undefined;
            },
            { cls: ["num"], disabled: !active, label: labelText(point.label) },
          ),
          point.unit ? text(`${id}/unit`, point.unit, ["mod-unit"]) : null,
          press(`${id}/up`, S.RAISE, stepBy(step), {
            disabled: !active,
          }),
        ),
        { align: "center", gap: 4 },
      ),
    ],
    { cls: ["card"] },
  );
}

/** Every generic row of a module document, grouped under its headings. */
export function moduleBody(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
  heading = true,
  footer = true,
): UiNode[] {
  const readouts = state.readouts ?? [];
  const toggles = state.toggles ?? [];
  const labels = state.labels ?? [];
  const setpoints = state.setpoints ?? [];
  const blocks = state.matter ?? [];
  const order: string[] = [];
  const see = (section: string): void => {
    if (!order.includes(section)) order.push(section);
  };
  // A reading about another node joins its section's cards, so it
  // places that section no earlier than the switches do.
  for (const reading of readouts) if (!reading.subject) see(labelText(reading.section));
  for (const toggle of toggles) see(labelText(toggle.section));
  for (const reading of readouts) if (reading.subject) see(labelText(reading.section));
  for (const entryRow of labels) see(labelText(entryRow.section));
  for (const point of setpoints) see(labelText(point.section));
  for (const block of blocks) see(labelText(block.section));

  // The demo's hierarchy: the document names itself small, the machine
  // names itself large, and its leading readings are the block a reader
  // takes in from across the room.
  const out: UiNode[] = heading ? [
    row(`${id}/eyebrow`, [text(`${id}/eyebrow/title`, doc.title)], { cls: ["mod-eyebrow"] }),
  ] : [];
  if (heading && state.name) out.push(text(`${id}/heading`, state.name, ["mod-head"]));
  if (state.gauge !== null && state.gauge !== undefined)
    out.push(Gauge(`${id}/gauge`, state.gauge));
  for (const [place, section] of order.entries()) {
    const key = `${id}/part/${place}`;
    const here = readouts.filter((reading) => labelText(reading.section) === section);
    // A reading about another node is a card beside its section's
    // device choices, pressable by nobody (engine `subject`).
    const cards = here.flatMap((reading, index) => reading.subject
      ? [Choice(`${key}/card/${index}`, { ...subjectCard(reading.subject, reading.label, labelText(reading.label)), disabled: true })]
      : []);
    const rows: ListRow[] = here
      .filter((reading) => !reading.subject)
      .map((reading) => ({
        label: labelText(reading.label),
        value: labelText(reading.value),
        ...(toneOf(reading.tone) ? { tone: toneOf(reading.tone)! } : {}),
      }));
    const children: UiNode[] = [];
    // The first section's leading readings are the document's headline;
    // everything after it stays a labelled list.
    const stats = place === 0 ? rows.slice(0, 4) : [];
    if (stats.length) children.push(statBlocks(`${key}/stats`, stats));
    if (rows.length > stats.length)
      children.push(LabeledList(`${key}/readouts`, rows.slice(stats.length)));
    children.push(
      ...toggleRows(
        key,
        doc,
        toggles.filter((toggle) => labelText(toggle.section) === section),
        active,
        toggles,
        cards,
      ),
    );
    for (const [index, entryRow] of labels.entries())
      if (labelText(entryRow.section) === section)
        children.push(labelRow(`${id}/label/${entryRow.row === "input" ? entryRow.action : index}`, doc, entryRow, active));
    for (const point of setpoints)
      if (labelText(point.section) === section)
        children.push(setpointRow(`${id}/set/${point.field}`, doc, point, active));
    for (const [index, block] of blocks.entries())
      if (labelText(block.section) === section)
        children.push(matterBlock(`${id}/matter/${index}`, block));
    if (!children.length) continue;
    out.push(
      section
        ? Section(key, section, children)
        : Stack(key, children, { dir: "column", gap: 4 }),
    );
  }
  // What the machine is saying about itself, under a rule: the demo's
  // footer, and the only document-wide line a provider writes.
  if (footer && state.notice)
    out.push(row(`${id}/foot`, [text(`${id}/foot/word`, labelText(state.notice))], {
      cls: ["mod-foot"],
    }));
  return out;
}

/** A reading drawn to be read at a distance: its word over its number. */
function statBlocks(id: string, rows: ListRow[]): UiNode {
  return row(id, rows.map((reading, index) => Stack(`${id}/${index}`, [
    text(`${id}/${index}/label`, reading.label, ["mod-eyebrow"]),
    text(`${id}/${index}/value`, reading.value, ["mod-stat-value"]),
  ], { dir: "column", gap: 7 })), { cls: ["mod-stats"] });
}
