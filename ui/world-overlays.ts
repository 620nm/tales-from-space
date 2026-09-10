// What is drawn over the station itself: the bar under a job this body
// is working, and what whoever spoke is saying. Both follow a disclosed
// entity through `anchor`; neither ever learns a coordinate.
//
// Speech is lettering, not a panel: tgstation's runechat, whose look is
// `interface/skin.dmf:79` (`.maptext`) and whose life is
// `code/datums/chatmessage.dm:1-18`. Sizes and colours live in
// `theme.ts`; what a speaker's words are painted is `voice.ts`.
import type { UiNode } from "@lunatic/ui";
import { Stack, color } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { row, some, text } from "./view";
import { voiceColor } from "./voice";
import * as S from "./strings";

const bounded = (ms: number): number => Math.max(1, Math.min(3600000, ms));

// tg CHAT_MESSAGE_SPAWN_TIME (0.2s) as this kit spells it: the words
// fade up while they rise off the head. tg CHAT_MESSAGE_LIFESPAN is 5s
// and CHAT_MESSAGE_EOL_FADE the last 0.7s of it, which is exactly what
// the host does to an expiring node — so the lifetime is the whole 5s.
const SPAWN = [
  { name: "fade-in" as const, ms: 200 },
  { name: "rise" as const, ms: 200 },
];
const LIFESPAN = 5000;

export function worldOverlays(view: GameplayView): UiNode[] {
  const out: UiNode[] = [];
  const state = view.state;
  if (state.identity?.you != null && state.progress?.length)
    out.push({
      ...Stack(
        "progress",
        state.progress.map((job) => ({
          id: `progress/${job.job}/${job.sequence}`,
          type: "progress" as const,
          value: "0",
          class: ["gauge"],
          duration: bounded(job.ms),
          expires: bounded(job.ms),
        })),
        { dir: "column", gap: 2, style: { width: 120 } },
      ),
      anchor: String(state.identity.you),
    });
  for (const speech of state.speech ?? []) {
    // A voice keeps one hue wherever it is heard; a name the wire left
    // empty falls back to the speaker's own id so the hue is still theirs.
    const paint = color(voiceColor(speech.name || String(speech.id)));
    out.push({
      ...row(
        `speech/${speech.id}/${speech.sequence}`,
        some(
          speech.channel
            ? text(`speech/${speech.id}/chan`, S.channel(speech.channel), [
                "rune-chan",
              ])
            : null,
          // theme-lint: allow the speaker's own hue
          text(`speech/${speech.id}/text`, speech.text, ["rune-said"], {
            ...(paint ? { color: paint } : {}),
          }),
        ),
        { cls: ["rune"], style: { animation: SPAWN } },
      ),
      anchor: String(speech.id),
      expires: LIFESPAN,
    });
  }
  return out;
}
