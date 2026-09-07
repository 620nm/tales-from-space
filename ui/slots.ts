import type { UiNode, SlotOpts } from "@lunatic/ui";
import { Slot } from "@lunatic/ui";

// tgstation code/_onclick/hud/human.dm:85-142 supplies the empty silhouettes
// and occupied template variants; inventory_slot.dm:19-21 owns the layering.
const silhouettes = new Set(["uniform", "suit", "id", "mask", "back", "belt", "gloves", "shoes", "ears", "head"]);
const small = new Set(["id", "back", "belt"]);

export function hudSlot(id: string, opts: SlotOpts, slot = "", cls?: string): UiNode {
  const node = Slot(id, opts);
  const frame = opts.empty && silhouettes.has(slot) ? slot : small.has(slot) ? "template_small" : "template";
  return {
    ...node,
    class: [...(node.class ?? []), "midnight-slot", ...(cls ? [cls] : [])],
    children: [
      { id: `${id}/frame`, type: "image", asset: `hud_${frame}`, class: ["slot-frame"] },
      ...(node.children ?? []).map((child) => cls === "hand-slot" && child.id === `${id}/fill`
        ? { ...child, style: { left: 14, top: 14 } } : child),
    ],
  };
}
