// What the crew heard, and the one box a crewman answers with.
import type { UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { column, entry, row, some, text } from "./view";
import * as S from "./strings";

export function chatPanel(view: GameplayView): UiNode[] {
  const lines = (view.log ?? []).slice(-40).map((line, index) => {
    const key = `log/${index}`;
    const system = !line?.name && !line?.channel;
    return row(
      key,
      some(
        line?.channel ? text(`${key}/chan`, S.channel(line.channel), ["chan"]) : null,
        line?.name ? text(`${key}/who`, S.speaker(line.name), ["who"]) : null,
        text(`${key}/text`, line?.text ?? "", system ? ["said", "sys"] : ["said"]),
      ),
      { cls: ["line"] },
    );
  });
  return [
    Pane(
      "chat-pane",
      some(
        text("chat-title", S.CHAT_TITLE, ["caption"]),
        column("log", lines.length ? lines : [text("log-empty", S.CHAT_EMPTY, ["hint"])], {
          cls: ["log"], style: { minHeight: 0, maxHeight: 280, flexGrow: 1 },
        }),
        view.body
          ? entry(
              "chat",
              "",
              (value) => (value.trim() ? { kind: "say", text: value } : undefined),
              { submitOnly: true, clearOnSubmit: true, blurOnSubmit: true,
                style: { height: 24, minHeight: 24, flexGrow: 0, flexShrink: 0 } },
            )
          : null,
      ),
      {
        cls: ["floating-chat"],
        style: {
          position: "absolute",
          left: 14,
          bottom: 12,
          width: 500,
          height: 340,
          maxWidth: "33%",
          maxHeight: "48%",
        },
      },
    ),
  ];
}
