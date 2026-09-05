// Looking at things: the examine pane, whose runs wear the colours the
// server wrote them in, and the menu over what stands on a tile.
import type { UiNode } from "@lunatic/ui";
import { color, Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { column, icon, press, row, some, text } from "./view";
import * as S from "./strings";

export function inspectionPanels(view: GameplayView): UiNode[] {
  const state = view.state ?? {};
  const out: UiNode[] = [];
  if (state.examine) {
    const look = state.examine;
    out.push(
      Pane(
        "examine",
        [
          row(
            "examine-title",
            some(
              icon("examine-icon", look.sprite),
              text("examine-heading", look.title ?? "", [
                "titlebar-title",
                "grow",
              ]),
              press(
                "examine-close",
                S.CLOSE_MARK,
                { kind: "dismiss", panel: "examine" },
                { variant: "ghost" },
              ),
            ),
            { cls: ["titlebar"] },
          ),
          column("examine-lines", examineLines(look.lines ?? []), {
            style: { gap: 3 },
          }),
        ],
        {
          style: {
            position: "absolute",
            left: 14,
            top: 14,
            width: 340,
            maxHeight: "60%",
          },
        },
      ),
    );
  }
  if (state.context)
    out.push(
      Pane(
        "context",
        [
          row(
            "context-title",
            [
              text("context-heading", S.TILE_TITLE, [
                "titlebar-title",
                "grow",
              ]),
              press(
                "context-close",
                S.CLOSE_MARK,
                { kind: "dismiss", panel: "context" },
                { variant: "ghost" },
              ),
            ],
            { cls: ["titlebar"] },
          ),
          ...(state.context ?? []).map((target, index) =>
            row(
              `context/${index}`,
              some(
                icon(`context/${index}/icon`, target?.sprite),
                press(
                  `context/${index}/use`,
                  target?.name ?? "",
                  { kind: "context", target: target?.target ?? null },
                  { variant: "ghost", cls: ["fname"] },
                ),
              ),
              { cls: ["filerow"] },
            ),
          ),
        ],
        {
          style: {
            position: "absolute",
            left: 372,
            top: 14,
            width: 300,
            maxHeight: "60%",
          },
        },
      ),
    );
  return out;
}

/** One row per line, one text run per span, each in the colour sent. */
function examineLines(
  lines: { spans: { text: string; color?: string | null }[] }[],
): UiNode[] {
  if (!lines.length) return [text("examine-empty", S.NOTHING_MORE, ["hint"])];
  return lines.map((line, index) =>
    row(
      `examine-line/${index}`,
      (line?.spans ?? []).map((span, place) => {
        const paint = span?.color ? color(span.color) : undefined;
        return {
          id: `examine-line/${index}/${place}`,
          type: "text" as const,
          text: span?.text ?? "",
          class: ["said"],
          ...(paint ? { style: { color: paint } } : {}),
        };
      }),
      { cls: ["line"], style: { gap: 0 } },
    ),
  );
}
