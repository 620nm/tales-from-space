// One body of matter, drawn: the shell, its warmth, and one block per
// state present. The magnitude ladders mirror lunatic-core's
// `matter_format` so a beaker on this screen reads as it does in
// examine prose (docs/tgui/matter-block.md).
import type { UiNode } from "@lunatic/ui";
import { color, LabeledList } from "@lunatic/ui";
import type { MatterBlock, MatterRow, MatterStateBlock } from "./document-model";
import { column, row, some, text } from "./view";
import * as S from "./strings";

const T0C = 273.15;
const fixed = (value: number, places: number): string =>
  Number.isFinite(value) ? value.toFixed(places) : "—";

export function kpa(value: number): string {
  const size = Math.abs(value);
  if (size >= 1000) return `${fixed(value, 0)} kPa`;
  if (size >= 10) return `${fixed(value, 1)} kPa`;
  return `${fixed(value, 2)} kPa`;
}
export function litres(value: number): string {
  const size = Math.abs(value);
  if (size < 1) return `${fixed(value * 1000, 1)} mL`;
  if (size < 100) return `${fixed(value, 2)} L`;
  return `${fixed(value, 0)} L`;
}
export function mass(grams: number): string {
  const size = Math.abs(grams);
  if (size >= 1000) return `${fixed(grams / 1000, 2)} kg`;
  if (size >= 1) return `${fixed(grams, 2)} g`;
  if (size >= 1e-3) return `${fixed(grams * 1e3, 1)} mg`;
  return `${fixed(grams * 1e6, 1)} µg`;
}
export function moles(value: number): string {
  const size = Math.abs(value);
  if (size >= 100) return `${fixed(value, 0)} mol`;
  if (size >= 1) return `${fixed(value, 2)} mol`;
  return `${fixed(value, 3)} mol`;
}
export function kelvin(value: number): string {
  return `${fixed(value, 1)} K · ${fixed(value - T0C, 0)} °C`;
}
const measure = (phase: string, value: number): string =>
  phase === "gas" ? kpa(value) : litres(value);
const weighed = (grams: number): string => (grams > 0 ? mass(grams) : "");

/** The substance's own colour, or nothing where the pack declared none. */
function dot(id: string, hex: string | null | undefined): UiNode | null {
  const paint = hex ? color(hex) : undefined;
  return paint
    ? { id, type: "panel", class: ["dot"], style: { backgroundColor: paint } }
    : null;
}

function stateHeading(state: MatterStateBlock): string {
  const reading = measure(state.phase, state.measure ?? 0);
  if (state.phase === "gas")
    return S.gasHeading(reading, moles(state.moles ?? 0));
  if (state.phase === "liquid") return S.liquidHeading(reading);
  return S.solidHeading(weighed(state.mass_g ?? 0), reading);
}

function rowLine(phase: string, entry: MatterRow): string {
  const reading = measure(phase, entry.measure ?? 0);
  const amount = moles(entry.moles ?? 0);
  return S.matterRow(
    phase === "solid" ? weighed(entry.mass_g ?? 0) : "",
    reading,
    amount,
  );
}

/** The block itself: the shell's readings, then a heading per state. */
export function matterBlock(id: string, block: MatterBlock): UiNode {
  const shell = LabeledList(`${id}/shell`, [
    { label: S.SHELL, value: litres(block.volume_l ?? 0) },
    { label: S.HEADSPACE, value: litres(block.headspace_l ?? 0) },
    { label: S.TEMPERATURE, value: kelvin(block.temperature_k ?? 0) },
    ...(block.sealed === undefined || block.sealed === null
      ? []
      : [
          {
            label: S.SEAL,
            value: block.sealed ? S.SEALED : S.OPEN_SHELL,
            tone: (block.sealed ? "on" : "idle") as "on" | "idle",
          },
        ]),
  ]);
  const states = (block.states ?? []).flatMap((state, index) => {
    const key = `${id}/state/${index}`;
    return [
      text(`${key}/head`, stateHeading(state), ["mstate"]),
      ...(state.rows ?? []).map((entry, place) =>
        row(
          `${key}/row/${place}`,
          some(
            dot(`${key}/row/${place}/dot`, entry.color),
            text(`${key}/row/${place}/name`, entry.name, ["mname"]),
            text(`${key}/row/${place}/value`, rowLine(state.phase, entry), [
              "mval",
            ]),
          ),
          { cls: ["mrow"] },
        ),
      ),
    ];
  });
  return column(id, [shell, ...states], { cls: ["matter"] });
}
