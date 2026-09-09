import type { UiNode, SlotOpts } from "@lunatic/ui";
import { Slot } from "@lunatic/ui";

// tgstation code/_onclick/hud/human.dm:85-142 supplies the empty silhouettes
// and occupied template variants; inventory_slot.dm:19-21 owns the layering.
const silhouettes = new Set(["uniform", "suit", "id", "mask", "back", "belt", "gloves", "shoes", "ears", "head"]);
const small = new Set(["id", "back", "belt"]);

// A hand cell names itself in its top-left corner. The caption is the
// SLOT, not what is in it, so it neither moves nor changes as items come
// and go.
const handCaption = { left: 5, top: 4, bottom: "auto" } as const;

export function hudSlot(id: string, opts: SlotOpts, slot = "", cls?: string): UiNode {
  const node = Slot(id, opts);
  const silhouette = !!opts.empty && silhouettes.has(slot);
  const frame = silhouette ? slot : small.has(slot) ? "template_small" : "template";
  return {
    ...node,
    class: [...(node.class ?? []), "midnight-slot", ...(cls ? [cls] : [])],
    children: [
      ...(opts.active ? [{ id: `${id}/active`, type: "panel" as const, class: ["slot-active-ring"] }] : []),
      { id: `${id}/frame`, type: "image", asset: `hud_${frame}`, class: ["slot-frame"] },
      // The drawn silhouette already says which slot this is; a caption
      // over it repeats the art it sits on.
      ...(node.children ?? [])
        .filter((child) => !(silhouette && child.id === `${id}/label`))
        .map((child) => {
          if (cls !== "hand-slot") return child;
          if (child.id === `${id}/fill`) return { ...child, style: { left: 14, top: 14 } };
          if (child.id === `${id}/label`)
            return { ...child, style: { ...(child.style ?? {}), ...handCaption } };
          return child;
        }),
    ],
  };
}
