import type { GameplayView } from "./model";
import type { UiNode } from "@lunatic/ui";
import { column, node, pane, text } from "./view";

export function worldOverlays(view: GameplayView): UiNode[] {
  const children: UiNode[] = [];
  const state = view.state;
  if (state.identity?.you != null && state.progress?.length)
    children.push({
      ...column(
        "progress",
        state.progress.map((job) =>
          node("progress", `progress/${job.job}/${job.sequence}`, {
            value: "0",
            duration: Math.max(1, Math.min(3600000, job.ms)),
            expires: Math.max(1, Math.min(3600000, job.ms)),
          }),
        ),
        { width: 120, gap: 2 },
      ),
      anchor: String(state.identity.you),
    });
  for (const speech of state.speech ?? [])
    children.push({
      ...pane(
        `speech/${speech.id}/${speech.sequence}`,
        [
          text(
            `speech/${speech.id}/text`,
            `${speech.channel ? `[${speech.channel}] ` : ""}${speech.text}`,
          ),
        ],
        { width: 280, padding: 4 },
      ),
      anchor: String(speech.id),
      expires: 5000,
    });
  return children;
}
