// What is drawn over the station itself: the bar under a job this body
// is working, and a speech bubble over whoever spoke. Both follow a
// disclosed entity through `anchor`; neither ever learns a coordinate.
import type { UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { column, some, text } from "./view";
import * as S from "./strings";

const bounded = (ms: number): number => Math.max(1, Math.min(3600000, ms));

export function worldOverlays(view: GameplayView): UiNode[] {
  const out: UiNode[] = [];
  const state = view.state;
  if (state.identity?.you != null && state.progress?.length)
    out.push({
      ...column(
        "progress",
        state.progress.map((job) => ({
          id: `progress/${job.job}/${job.sequence}`,
          type: "progress" as const,
          value: "0",
          class: ["gauge"],
          duration: bounded(job.ms),
          expires: bounded(job.ms),
        })),
        { style: { width: 120, gap: 2 } },
      ),
      anchor: String(state.identity.you),
    });
  for (const speech of state.speech ?? [])
    out.push({
      ...Pane(
        `speech/${speech.id}/${speech.sequence}`,
        some(
          speech.channel
            ? text(`speech/${speech.id}/chan`, S.channel(speech.channel), [
                "chan",
              ])
            : null,
          text(`speech/${speech.id}/text`, speech.text, ["said"]),
        ),
        {
          style: {
            width: 260,
            minWidth: 60,
            padding: 6,
            gap: 2,
            textAlign: "center",
          },
        },
      ),
      anchor: String(speech.id),
      expires: 5000,
    });
  return out;
}
