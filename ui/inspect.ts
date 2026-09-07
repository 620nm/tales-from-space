// Looking at things: the examine pane, whose runs wear the colours the
// server wrote them in, and the menu over what stands on a tile.
import type { UiNode } from "@lunatic/ui";
import { color, Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { column, icon, panel, press, row, some, text } from "./view";
import * as S from "./strings";
import { gesture } from "./gesture";
import { hintText } from "./labels";

type Inspection = NonNullable<GameplayView["state"]["inspections"]>[number];
let historyOpen = false;
const pins = new Set<number>();
const dismissed = new Set<number>();
const opened = new Set<number>();
let identity: number | null | undefined;
let toastSequences: number[] = [];
let lastSequence = -1;

function inspectionCard(look: Inspection, history = false): UiNode {
  const id = `${history ? "history" : "inspect"}/${look.sequence}`;
  const pinned = pins.has(look.sequence);
  // A toast shows the opening of a reading and offers the rest; the
  // history window is where a whole one belongs, so it never clamps.
  const open = history || opened.has(look.sequence);
  const lines = look.lines ?? [];
  return {
    ...Pane(id, some(
      row(`${id}/head`, some(
        // The whole thing as it stands, when the client composed one for
        // this receipt; its base sprite otherwise. Never a blank frame:
        // with neither, the header keeps its 24px square, so every title
        // in the stack starts on the same line.
        look.appearance
          ? {
              id: `${id}/icon`, type: "image" as const,
              appearance: look.appearance, class: ["inspect-icon"],
            }
          : look.sprite
            ? icon(`${id}/icon`, look.sprite, "", ["inspect-icon"])
            : panel(`${id}/icon`, [], { cls: ["inspect-blank"] }),
        text(`${id}/title`, look.title, ["inspect-title"]),
        press(`${id}/pin`, S.tfs(pinned ? "ui.look.unpin" : "ui.look.pin"), () => {
          if (pinned) pins.delete(look.sequence); else if (pins.size < 3) {
            pins.add(look.sequence);
            dismissed.delete(look.sequence);
            if (!toastSequences.includes(look.sequence)) toastSequences.push(look.sequence);
          }
          return undefined;
        }, { variant: pinned ? "selected" : "ghost" }),
        press(`${id}/close`, S.CLOSE_MARK, () => {
          dismissed.add(look.sequence); pins.delete(look.sequence); opened.delete(look.sequence);
          return undefined;
        }, { variant: "ghost" }),
      ), { cls: ["inspect-head"] }),
      column(`${id}/lines`, examineLines(lines, id), open ? { style: { gap: 3 } } : { cls: ["inspect-body"] }),
      !history && lines.length > 3
        ? press(`${id}/full`, S.tfs(open ? "ui.look.read_less" : "ui.look.read_full"), () => {
            if (open) opened.delete(look.sequence); else opened.add(look.sequence);
            return undefined;
          }, { variant: "ghost", cls: ["inspect-full"] })
        : null,
    ), { cls: ["inspect-toast"] }),
    // An opened toast is being read: it waits for the close press.
    ...(!pinned && !history && !open ? { expires: 8450, fade: 450, pauseExpiry: true } : {}),
  };
}

export function inspectionPanels(view: GameplayView): UiNode[] {
  const state = view.state ?? {};
  const out: UiNode[] = [];
  if (identity !== state.identity?.you || !state.inspections?.length) {
    pins.clear(); dismissed.clear(); opened.clear(); historyOpen = false;
    identity = state.identity?.you;
    toastSequences = []; lastSequence = -1;
  }
  const records = state.inspections ?? [];
  const live = new Set(records.map((look) => look.sequence));
  for (const sequence of pins) if (!live.has(sequence)) pins.delete(sequence);
  for (const sequence of dismissed) if (!live.has(sequence)) dismissed.delete(sequence);
  for (const sequence of opened) if (!live.has(sequence)) opened.delete(sequence);
  const newest = [...records].reverse();
  for (const sequence of [...pins]) {
    const pinned = records.find((look) => look.sequence === sequence);
    const refreshed = pinned && newest.find((look) => look.title === pinned.title && look.sprite === pinned.sprite);
    if (refreshed && refreshed.sequence !== sequence) { pins.delete(sequence); pins.add(refreshed.sequence); }
  }
  for (const look of records) if (look.sequence > lastSequence) {
    toastSequences = toastSequences.filter((sequence) => {
      const held = records.find((record) => record.sequence === sequence);
      return held && (held.title !== look.title || held.sprite !== look.sprite);
    });
    toastSequences.push(look.sequence); lastSequence = look.sequence;
  }
  const candidates = newest.filter((look) => toastSequences.includes(look.sequence) && !dismissed.has(look.sequence));
  const recent = [...candidates.filter((look) => pins.has(look.sequence)), ...candidates.filter((look) => !pins.has(look.sequence))].slice(0, 3);
  toastSequences = recent.map((look) => look.sequence);
  // The way back into the shift's whole record sits UNDER the stack: a
  // toast arriving must not push the row a hand is already reaching for.
  if (records.length) out.push(column("inspection-stack", [
    ...recent.map((look) => inspectionCard(look)),
    press("inspection-history", S.inspectHistory(records.length), () => { historyOpen = !historyOpen; return undefined; }, {
      variant: "ghost", cls: ["inspect-history-row"],
    }),
  ], { cls: ["hudgroup"], style: { position: "absolute", left: 16, top: 18, width: 320, maxHeight: "72%", overflowY: "auto", gap: 7, alignItems: "start" } }));
  if (historyOpen) out.push({
    ...Pane("inspection-history-window", [
      press("inspection-history-close", S.CLOSE_MARK, () => { historyOpen = false; return undefined; }, { variant: "ghost" }),
      ...newest.map((look) => inspectionCard(look, true)),
    ], { style: { gap: 6 } }),
    window: { key: "inspection-history", title: S.tfs("ui.look.history"), width: 360, height: 520 },
  });
  if (state.hover) {
    const hover = state.hover;
    const hints = hover.hints.some((hint) => hint.gesture === "primary") ? hover.hints
      : [{ gesture: "primary", label: S.tfs("ui.look.interact") }, ...hover.hints];
    // The header's image and every hint's key cell are both the first
    // child of a full-width row inside one padding, so their left edges
    // are the same edge: the card reads as one column, not two.
    out.push({ ...Pane("hover", [
      row("hover/title", [
        { id: "hover/preview", type: "image", appearance: hover.appearance, class: ["hover-preview"] },
        text("hover/name", hover.name, ["hover-title"]),
      ], { cls: ["hover-head"] }),
      ...[...hints, { gesture: "examine", label: S.tfs("ui.look.examine") }].map((hint, index) => row(`hover/hint/${index}`, [
        gesture(`hover/key/${index}`, hint.gesture),
        text(`hover/label/${index}`, hintText(hint.label), ["hover-description"]),
      ], { cls: ["hover-row"] })),
    ], { cls: ["hover-card"] }), anchor: "@cursor" });
  }
  if (state.context)
    out.push({
      // The menu opens where the right-click landed. `@context` is the
      // host's own point for that click: the package names it and is
      // never told a coordinate, and the host puts the menu's top-left
      // there, keeps its presses live and clamps it into the slot. The
      // point stands only while this projection does, so the close press
      // still ends the menu (docs/pack-ui/sdk.md, "Spatial overlays").
      anchor: "@context",
      ...Pane(
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
        { style: { width: 300, maxHeight: "60%" } },
      ),
    });
  return out;
}

/** One row per line, one text run per span, each in the colour sent. */
function examineLines(
  lines: { spans: { text: string; color?: string | null }[] }[],
  id: string,
): UiNode[] {
  if (!lines.length) return [text(`${id}/empty`, S.NOTHING_MORE, ["hint"])];
  return lines.map((line, index) =>
    row(
      `${id}/line/${index}`,
      (line?.spans ?? []).map((span, place) => {
        const paint = span?.color ? color(span.color) : undefined;
        return {
          id: `${id}/line/${index}/${place}`,
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
