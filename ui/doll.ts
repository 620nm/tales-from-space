// The body-target figure: the plan's own art, the highlight over
// whichever part this session is aimed at, and one press per declared
// rectangle. The rectangles are the roster's, in the unit square, so
// the pack never spells a body part in this file.
import type { UiNode } from "@lunatic/ui";
import type { GameplayView, TargetZone } from "./model";
import { bind, column, icon, panel, press, row, some, text } from "./view";
import * as S from "./strings";

const pct = (value: number): string =>
  `${Math.max(0, Math.min(100, value * 100)).toFixed(1)}%`;

function hit(id: string, zone: TargetZone, selected: boolean): UiNode | null {
  const rect = zone.rect;
  if (!rect || rect.length !== 4) return null;
  const [x, y, w, h] = rect;
  return {
    id,
    type: "button",
    text: "",
    class: selected ? ["dollhit", "dollon"] : ["dollhit"],
    event: bind(id, { kind: "zone", zone: zone.id }),
    style: {
      left: pct(x),
      top: pct(y),
      width: pct(w),
      height: pct(h),
    },
  };
}

/** The figure, or a plain block of presses for a plan that ships no art. */
export function bodyTarget(view: GameplayView): UiNode | null {
  const zones = view.state.targets?.zones ?? [];
  if (!zones.length) return null;
  const at = view.state.target?.zone ?? -1;
  const aimed = zones[at];
  const base = view.state.targets?.base;
  const label = text("doll-label", aimed?.label ?? "", ["chipval"]);
  if (!base)
    return column(
      "doll-block",
      [
        text("doll-caption", S.TARGET, ["caption"]),
        row(
          "zones",
          zones.map((zone, index) =>
            press(`zone/${zone.id}`, zone.label, {
              kind: "zone",
              zone: zone.id,
            }, { variant: index === at ? "selected" : "default" }),
          ),
          { style: { gap: 4, flexWrap: "wrap" } },
        ),
      ],
      { cls: ["trayset"] },
    );
  return column(
    "doll-block",
    [
      text("doll-caption", S.TARGET, ["caption"]),
      panel(
        "doll",
        some(
          icon("doll-base", base, "", ["dollart"]),
          aimed?.sprite ? icon("doll-target", aimed.sprite, "", ["dollart"]) : null,
          ...zones.map((zone, index) =>
            hit(`zone/${zone.id}`, zone, index === at),
          ),
        ),
        { cls: ["doll"] },
      ),
      label,
    ],
    { cls: ["trayset"], style: { alignItems: "center", gap: 3 } },
  );
}
