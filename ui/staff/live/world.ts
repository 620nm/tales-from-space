import type { UiNode } from "@lunatic/ui";
import { Card, Stack } from "@lunatic/ui";
import type { StaffEntity, StaffSession } from "../model";
import { press, text } from "../../view";
import * as S from "../strings";
import { catalogRequest, seedAmbientCatalog } from "./catalog";
import { spawnDrawer, spawnKind } from "./spawn";
import { liveState } from "./state";

/** The native world canvas remains underneath this transparent surface. */
export function nativeWorldOverlay(session: StaffSession, entity: StaffEntity | null): UiNode {
  const state = liveState(session);
  const station = session.station ?? {};
  return {
    id: "staff/live/world-overlay",
    type: "column",
    class: ["staff-live-stage"],
    children: [
      Stack("staff/live/stage-heading", [
        { id: "staff/live/live-mark", type: "panel", class: ["staff-live-mark"] },
        {
          id: "staff/live/stage-title",
          type: "column",
          class: ["staff-world-title"],
          children: [
            textNode("staff/live/kicker", `${station.shift ?? S.SHIFT} · ${station.name ?? S.STATION}`, "staff-eyebrow"),
            textNode("staff/live/title", S.LIVE, "staff-title"),
          ],
        },
        textNode("staff/live/clock", station.clock ?? S.RUNNING, "staff-mono"),
      ], { cls: ["staff-world-heading"], gap: 8, align: "center" }),
      Stack("staff/live/tools", [
        press("staff/live/spawn", S.SPAWN, () => {
          if (state.spawnOpen) {
            state.spawnOpen = false;
            return undefined;
          }
          state.spawnOpen = true;
          seedAmbientCatalog(session, state);
          const kind = spawnKind(state);
          return catalogRequest(session, state, kind, state.catalog.search, null, { preserveItems: true });
        }, { variant: "primary" }),
      ], { cls: ["staff-toolbar"], gap: 5, align: "center" }),
      Card("staff/live/target-bar", [
        entity
          ? Stack("staff/live/target-bar/selected", [
            textNode("staff/live/target-bar/label", S.INSPECTOR, "staff-eyebrow"),
            textNode("staff/live/target-bar/name", `${entity.name} · ${entity.id}`, "staff-stage-selection"),
          ], { gap: 3 })
          : textNode("staff/live/target-bar/empty", S.PICK_TARGET, "staff-muted"),
        textNode("staff/live/target-bar/access", S.SERVER_GRANTED, "staff-mono"),
      ], { cls: ["staff-stage-status"], gap: 5 }),
      ...(state.spawnOpen ? [spawnDrawer(session, entity)] : []),
    ],
  };
}

function textNode(id: string, value: unknown, cls?: string): UiNode {
  return text(id, value, cls ? [cls] : undefined);
}
