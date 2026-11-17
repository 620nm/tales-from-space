import type { UiNode, SlotOpts } from "@lunatic/ui";
import { Slot } from "@lunatic/ui";

// tgstation code/_onclick/hud/human.dm:85-142 supplies the empty silhouettes
// and occupied template variants; inventory_slot.dm:19-21 owns the layering.
const silhouettes = new Set(["uniform", "suit", "id", "mask", "back", "belt", "gloves", "shoes", "ears", "head", "eyes"]);
const small = new Set(["id", "back", "belt"]);

// A hand cell names itself in its top-left corner. The caption is the
// SLOT, not what is in it, so it neither moves nor changes as items come
// and go.
const handCaption = { position: "absolute", left: 5, right: 5, top: 4, bottom: "auto", width: "auto" } as const;

export function hudSlot(id: string, opts: SlotOpts, slot = "", cls?: string): UiNode {
  const node = Slot(id, opts);
  const silhouette = !!opts.empty && silhouettes.has(slot);
  const frame = silhouette ? slot : small.has(slot) ? "template_small" : "template";
  const boxId = `${id}/box`;
  const cellChildren = (node.children ?? [])
    .filter((child) => !(silhouette && child.id === `${id}/label`));
  const box = (node.id === boxId ? node : cellChildren.find((child) => child.id === boxId))!;
  const label = cellChildren.find((child) => child.id === `${id}/label`);
  const contents = (box.children ?? []).map((child) =>
    cls === "hand-slot" && child.id === `${id}/fill`
      ? { ...child, style: { ...(child.style ?? {}), left: 14, top: 14 } }
      : child);
  const framedBox = {
    ...box,
    children: [
      ...(opts.active ? [{ id: `${id}/active`, type: "panel" as const, class: ["slot-active-ring"] }] : []),
      { id: `${id}/frame`, type: "image" as const, asset: `hud_${frame}`, class: ["slot-frame"] },
      ...contents,
      ...(label ? [{ ...label, style: cls === "hand-slot"
        ? { ...(label.style ?? {}), ...handCaption }
        : label.style }] : []),
    ],
  };
  const classes = [...(node.class ?? []), "midnight-slot", ...(cls ? [cls] : [])];
  return node.id === boxId
    ? { ...framedBox, class: classes }
    : { ...node, class: classes, children: [framedBox] };
}
