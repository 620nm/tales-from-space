// A module document, drawn section by section. Each heading is drawn
// once where its first row appears and its rows underneath in the order
// they were sent, so the SERVER's row order is the layout and the
// document grows no nesting level (docs/tgui/documents.md).
import type { ListRow, Tone, UiNode } from "@lunatic/ui";
import { Gauge, LabeledList, Notice, Section } from "@lunatic/ui";
import type {
  DocumentIdentity,
  LabelRow,
  ModuleState,
  Setpoint,
} from "./document-model";
import { documentAction } from "./document-action";
import { labelText } from "./labels";
import { matterBlock } from "./matter-block";
import { toggleRows } from "./documents-choices";
import { column, entry, press, row, some, text } from "./view";
import * as S from "./strings";

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
          { disabled: !active || !entryRow.enabled },
        ),
      ],
      { cls: ["list-row"] },
    );
  if (entryRow.row === "input") {
    const box = `${id}/value`;
    return row(
      id,
      [
        caption,
        entry(box, "", () => undefined, { submitOnly: true }),
        press(
          `${id}/send`,
          labelText(entryRow.text) || S.SET,
          (e) =>
            documentAction(doc, "action", {
              action: entryRow.action,
              value: e.value ?? "",
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
      row(
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
            { cls: ["num"] },
          ),
          point.unit ? text(`${id}/unit`, point.unit, ["hint"]) : null,
          press(`${id}/up`, S.RAISE, stepBy(step), {
            disabled: !active,
          }),
        ),
        { style: { alignItems: "center", gap: 4 } },
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
  for (const reading of readouts) see(labelText(reading.section));
  for (const toggle of toggles) see(labelText(toggle.section));
  for (const entryRow of labels) see(labelText(entryRow.section));
  for (const point of setpoints) see(labelText(point.section));
  for (const block of blocks) see(labelText(block.section));

  const out: UiNode[] = [];
  if (state.notice)
    out.push(Notice(`${id}/notice`, labelText(state.notice)));
  if (state.gauge !== null && state.gauge !== undefined)
    out.push(Gauge(`${id}/gauge`, state.gauge));
  for (const [place, section] of order.entries()) {
    const key = `${id}/part/${place}`;
    const rows: ListRow[] = readouts
      .filter((reading) => labelText(reading.section) === section)
      .map((reading) => ({
        label: labelText(reading.label),
        value: labelText(reading.value),
        ...(toneOf(reading.tone) ? { tone: toneOf(reading.tone)! } : {}),
      }));
    const children: UiNode[] = [];
    if (rows.length) children.push(LabeledList(`${key}/readouts`, rows));
    children.push(
      ...toggleRows(
        key,
        doc,
        toggles.filter((toggle) => labelText(toggle.section) === section),
        active,
      ),
    );
    for (const [index, entryRow] of labels.entries())
      if (labelText(entryRow.section) === section)
        children.push(labelRow(`${id}/label/${index}`, doc, entryRow, active));
    for (const [index, point] of setpoints.entries())
      if (labelText(point.section) === section)
        children.push(setpointRow(`${id}/set/${index}`, doc, point, active));
    for (const [index, block] of blocks.entries())
      if (labelText(block.section) === section)
        children.push(matterBlock(`${id}/matter/${index}`, block));
    if (!children.length) continue;
    out.push(
      section
        ? Section(key, section, children)
        : column(key, children, { style: { gap: 4 } }),
    );
  }
  return out;
}
