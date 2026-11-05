// The gas turbine console (content/lib/power/gas_turbine_console.luau): the
// linked rotor's readout, its power switch and its intake valve. Layout
// after tg's TurbineComputer.tsx; every word is this pack's own.
import type { ListRow, UiNode } from "@lunatic/ui";
import { Gauge, LabeledList, Section, Stack } from "@lunatic/ui";
import type { DocumentIdentity, TurbineState } from "./document-model";
import { scriptAction } from "./document-action";
import { entry, press, row, text } from "./view";
import * as S from "./strings";

// The valve in whole percent, tg's NumberInput (1..100, step 1); the
// server clamps the fraction it is sent.
const VALVE_MIN = 1;
const VALVE_MAX = 100;
const VALVE_STEP = 1;

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
  const percent = Math.max(VALVE_MIN, Math.min(VALVE_MAX, Math.round(finite(state.intake) * 100)));
  const send = (to: number) => {
    const clamped = Math.max(VALVE_MIN, Math.min(VALVE_MAX, Math.round(to)));
    return scriptAction(doc, "regulate", (clamped / 100).toFixed(2));
  };
  return Stack(id, [
    row(`${id}/head`, [
      text(`${id}/label`, S.tfs("ui.turbine.intake"), ["grow", "list-label"]),
      text(`${id}/range`, S.range(`${VALVE_MIN}`, `${VALVE_MAX}`, "%"), ["hint"]),
    ], { cls: ["list-row"] }),
    Stack(`${id}/controls`, [
      press(`${id}/down`, S.LOWER, send(percent - VALVE_STEP), { disabled: !active || percent <= VALVE_MIN }),
      entry(`${id}/value`, `${percent}`, (value) => {
        const wanted = Number(value);
        return Number.isFinite(wanted) ? send(wanted) : undefined;
      }, { cls: ["num"], disabled: !active, label: S.tfs("ui.turbine.intake") }),
      press(`${id}/up`, S.RAISE, send(percent + VALVE_STEP), { disabled: !active || percent >= VALVE_MAX }),
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
    Section(`${id}/status`, S.tfs("ui.turbine.status"), [
      row(`${id}/power`, [
        text(`${id}/power/state`, S.tfs(running ? "ui.turbine.running" : "ui.turbine.stopped"), ["grow", "list-label"]),
        press(`${id}/power/switch`, S.tfs(running ? "ui.turbine.stop" : "ui.turbine.start"), scriptAction(doc, "power"), {
          variant: running ? "selected" : "primary", disabled: !active,
        }),
      ], { cls: ["list-row"] }),
      valve(`${id}/intake`, doc, state, active),
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
