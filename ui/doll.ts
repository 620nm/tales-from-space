// The body-target figure: the plan's own art, the highlight over
// whichever part this session is aimed at, and one press per declared
// rectangle. The rectangles are the roster's, in the unit square, so
// the pack never spells a body part in this file. It is a HUD region of
// its own, beside the hand cluster rather than inside it, as tg places
// the zone selector (ui_zonesel, code/__DEFINES/hud.dm:238; added at
// code/_onclick/hud/human.dm:19); `main.tsx` says where.
import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { GameplayView, TargetZone } from "./model";
import { bind, icon, panel, press, some, text, type Box } from "./view";
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
export function bodyTarget(view: GameplayView, place: Box = {}): UiNode | null {
  const zones = view.state.targets?.zones ?? [];
  if (!view.body || !zones.length) return null;
  const cls = ["hudgroup", ...(place.cls ?? [])];
  const at = view.state.target?.zone ?? -1;
  const aimed = zones[at];
  const base = view.state.targets?.base;
  const label = text("doll-label", aimed?.label ?? "", ["chipval"]);
  if (!base)
    return Stack(
      "doll-block",
      [
        text("doll-caption", S.TARGET, ["caption"]),
        Stack(
          "zones",
          zones.map((zone, index) =>
            press(`zone/${zone.id}`, zone.label, {
              kind: "zone",
              zone: zone.id,
            }, { variant: index === at ? "selected" : "default" }),
          ),
          { gap: 4, wrap: true },
        ),
      ],
      { dir: "column", gap: 4, cls, style: place.style },
    );
  return Stack(
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
    { dir: "column", align: "center", gap: 3, cls, style: place.style },
  );
}
