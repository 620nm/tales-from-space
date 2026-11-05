// The gas turbine console (content/lib/power/gas_turbine_console.luau): the
// linked rotor's readout, its power switch and its intake valve. Layout
// after tg's TurbineComputer.tsx; every word is this pack's own.
import type { ListRow, UiNode } from "@lunatic/ui";
import { Gauge, LabeledList, Section, Stack } from "@lunatic/ui";
import type { DocumentIdentity, TurbineState } from "./document-model";
import { documentAction, scriptAction } from "./document-action";
import { entry, press, row, text } from "./view";
import * as S from "./strings";

// The valve as tg's `regulate` fraction (turbine_computer.dm:118), stepped
// by tg's NumberInput step of one percent; the server clamps what it is sent.
const VALVE_MIN = 0.01;
const VALVE_MAX = 1;
const VALVE_STEP = 0.01;
const spell = (fraction: number): string => fraction.toFixed(2);

const finite = (value: number | undefined): number =>
  typeof value === "number" && Number.isFinite(value) ? value : 0;
const whole = (value: number | undefined): string => Math.round(finite(value)).toString();

/** The readings a linked, whole line discloses. */
function readings(state: TurbineState): ListRow[] {
  return [
    { label: S.tfs("ui.turbine.rpm"), value: S.tfs("ui.turbine.rpm_value", { value: whole(state.rpm) }) },
    { label: S.tfs("ui.turbine.max_rpm"), value: S.tfs("ui.turbine.rpm_value", { value: whole(state.max_rpm) }) },
    { label: S.tfs("ui.turbine.intake_k"), value: S.tfs("ui.turbine.kelvin", { value: whole(state.intake_k) }) },
    { label: S.tfs("ui.turbine.max_temperature"), value: S.tfs("ui.turbine.kelvin", { value: whole(state.max_temperature_k) }) },
    { label: S.tfs("ui.turbine.power"), value: S.tfs("ui.turbine.kilowatts", { value: (finite(state.power_w) / 1000).toFixed(1) }) },
  ];
}

function valve(id: string, doc: DocumentIdentity, state: TurbineState, active: boolean): UiNode {
  const clamp = (to: number): number =>
    Math.max(VALVE_MIN, Math.min(VALVE_MAX, Math.round(to * 100) / 100));
  const value = clamp(finite(state.intake));
  const send = (to: number) => scriptAction(doc, "regulate", spell(clamp(to)));
  return Stack(`${id}/valve`, [
    row(`${id}/head`, [
      text(`${id}/label`, S.tfs("ui.turbine.intake"), ["grow", "list-label"]),
      text(`${id}/range`, S.range(spell(VALVE_MIN), spell(VALVE_MAX), ""), ["hint"]),
    ], { cls: ["list-row"] }),
    Stack(`${id}/controls`, [
      press(`${id}/down`, S.LOWER, send(value - VALVE_STEP), { disabled: !active || value <= VALVE_MIN }),
      entry(id, spell(value), (typed) => {
        const wanted = Number(typed);
        return Number.isFinite(wanted) ? send(wanted) : undefined;
      }, { cls: ["num"], disabled: !active, label: S.tfs("ui.turbine.intake") }),
      press(`${id}/up`, S.RAISE, send(value + VALVE_STEP), { disabled: !active || value >= VALVE_MAX }),
    ], { align: "center", gap: 4 }),
  ], { dir: "column", gap: 4, cls: ["card"] });
}

export function turbineBody(id: string, doc: DocumentIdentity, state: TurbineState, active: boolean): UiNode[] {
  if (state.linked !== true)
    return [text(`${id}/unlinked`, S.tfs("ui.turbine.unlinked"), ["notice"])];
  if (state.connected !== true)
    return [text(`${id}/disconnected`, S.tfs("ui.turbine.disconnected"), ["notice"])];
  const running = state.active === true;
  const integrity = Math.max(0, Math.min(100, finite(state.integrity)));
  return [
    // Not `/status`: ui/documents.ts draws the window's footer under that id.
    Section(`${id}/turbine`, S.tfs("ui.turbine.status"), [
      row(`${id}/power`, [
        text(`${id}/power/state`, S.tfs(running ? "ui.turbine.running" : "ui.turbine.stopped"), ["grow", "list-label"]),
        // No input: `toggle_power` is declared with no value (limit 0), and the
        // engine drops an act carrying one, so the press sends `{}`.
        press(`${id}/toggle_power`, S.tfs(running ? "ui.turbine.stop" : "ui.turbine.start"), documentAction(doc, "toggle_power", {}), {
          variant: running ? "selected" : "primary", disabled: !active,
        }),
      ], { cls: ["list-row"] }),
      valve(`${id}/regulate`, doc, state, active),
      row(`${id}/integrity`, [
        text(`${id}/integrity/label`, S.tfs("ui.turbine.integrity"), ["grow", "list-label"]),
        text(`${id}/integrity/value`, S.tfs("ui.turbine.percent", { value: integrity.toFixed(0) }), ["list-value"]),
      ], { cls: ["list-row"] }),
      Gauge(`${id}/integrity/gauge`, integrity / 100, {
        tone: integrity >= 60 ? "on" : integrity >= 40 ? "idle" : "off",
      }),
      LabeledList(`${id}/readings`, readings(state)),
    ]),
  ];
}
