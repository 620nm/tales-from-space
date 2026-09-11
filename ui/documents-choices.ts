// Switches and dials. A toggle with no `option` is a switch of its own
// and ends the block before it; toggles sharing a `field` and a `group`
// are one block of choices, which is how the server says "these are
// positions of one selector" (docs/tgui/documents.md).
import type { ChoiceOpts, UiNode } from "@lunatic/ui";
import { Choice, ChoiceGrid } from "@lunatic/ui";
import type { DocumentIdentity, Subject, Toggle } from "./document-model";
import { documentAction } from "./document-action";
import { labelText, type Label } from "./labels";
import { tfs } from "./strings";
import { bind, row, text } from "./view";

/** Columns wide enough for a device card's name over its address. */
const CARD_MIN = 200;

/** A row about another node as a two-line card: its name, sprite,
 *  address and whether it is online (engine `subject`). */
export function subjectCard(subject: Subject, fallback: Label, detail?: string): Pick<ChoiceOpts, "label" | "sprite" | "detail" | "badge"> {
  const badge = subject.online == null ? { text: tfs("ui.device.gone"), tone: "off" as const }
    : { text: tfs(subject.online ? "ui.device.online" : "ui.device.offline"), tone: subject.online ? "on" as const : "off" as const };
  return {
    label: subject.name || labelText(fallback),
    ...(subject.sprite ? { sprite: subject.sprite } : {}),
    detail: detail ?? subject.address,
    badge,
  };
}

const toggleAction = (doc: DocumentIdentity, toggle: Toggle) =>
  documentAction(doc, "toggle", {
    field: toggle.field,
    ...(toggle.option == null ? {} : { option: toggle.option }),
  });

/** The caption row: a word, and the position it is in as a press. */
function switchRow(
  id: string,
  doc: DocumentIdentity,
  toggle: Toggle,
  active: boolean,
): UiNode {
  const word = labelText(toggle.on ? toggle.on_text : toggle.off_text);
  return row(
    `${id}/box`,
    [
      text(`${id}/label`, labelText(toggle.label), ["grow", "list-label"]),
      {
        id,
        type: "button",
        text: word,
        class: ["btn", toggle.on ? "btn-selected" : "btn-default"],
        event: bind(id, toggleAction(doc, toggle)),
        ...(active ? {} : { disabled: true }),
      },
    ],
    { cls: ["list-row"] },
  );
}

/**
 * Every toggle of one section, in the order the server sent them. The
 * field and the group together are what make two blocks two blocks, so
 * two proxied devices' rosters never merge into one. `cards` (readouts
 * about other nodes) lead the section's first block of device cards.
 */
export function toggleRows(
  id: string,
  doc: DocumentIdentity,
  toggles: Toggle[],
  active: boolean,
  allToggles: Toggle[] = toggles,
  cards: UiNode[] = [],
): UiNode[] {
  const out: UiNode[] = [];
  let pending = cards;
  let open: { key: string; choices: UiNode[] } | null = null;
  for (const toggle of toggles) {
    const option = toggle.option ?? "switch";
    const semantic = `${id}/toggle/${toggle.field}/${option}`;
    const safe = [toggle.field, option].every((part) => /^[a-zA-Z0-9_:.-]+$/.test(part) && !part.includes(".."));
    const unique = allToggles.filter((other) => other.field === toggle.field && (other.option ?? "switch") === option).length === 1;
    // Arbitrary values stay in the callback; node IDs reserve room for kit children.
    const key = safe && unique && semantic.length <= 120 ? semantic : `${id}/toggle-index/${allToggles.indexOf(toggle)}`;
    if (toggle.option == null) {
      open = null;
      out.push(switchRow(key, doc, toggle, active));
      continue;
    }
    const group = labelText(toggle.group);
    const blockKey = `${toggle.field} ${group}`;
    if (!open || open.key !== blockKey) {
      if (group) out.push(text(`${key}/group`, group, ["section-title"]));
      open = { key: blockKey, choices: toggle.subject ? pending : [] };
      if (toggle.subject) pending = [];
      out.push(ChoiceGrid(`${key}/grid`, open.choices, toggle.subject ? { min: CARD_MIN } : {}));
    }
    open.choices.push(
      Choice(key, {
        label: labelText(toggle.label),
        ...(toggle.icon ? { sprite: toggle.icon } : {}),
        ...(toggle.color ? { color: toggle.color } : {}),
        ...(toggle.subject ? subjectCard(toggle.subject, toggle.label) : {}),
        selected: toggle.on,
        event: bind(key, toggleAction(doc, toggle)),
        disabled: !active,
      }),
    );
  }
  if (pending.length) out.unshift(ChoiceGrid(`${id}/cards`, pending, { min: CARD_MIN }));
  return out;
}
