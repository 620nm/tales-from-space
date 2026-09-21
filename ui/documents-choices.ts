// Switches and dials. A toggle with no `option` is a switch of its own
// and ends the block before it; toggles sharing a `field` and a `group`
// are one block of choices, which is how the server says "these are
// positions of one selector" (docs/tgui/documents.md).
import type { ChoiceOpts, UiNode } from "@lunatic/ui";
import { Choice, ChoiceGrid } from "@lunatic/ui";
import type { DocumentIdentity, Subject, Toggle } from "./document-model";
import { documentAction } from "./document-action";
import { labelId, labelText, type Label } from "./labels";
import { tfs } from "./strings";
import { bind, row, text } from "./view";

type Badge = NonNullable<ChoiceOpts["badge"]>;

/** Columns wide enough for a device card's address and role on one line. */
const CARD_MIN = 248;

/** What a device card says about its node's state: the engine's
 *  diagnosis (`link.state.*`), or gone once the forest forgot it. A node
 *  merely not joined (`unbound`) is neither good nor bad news: no tone. */
export function subjectBadge(subject: Subject): Badge {
  const text = subject.state == null ? tfs("ui.device.gone") : labelText(subject.state);
  if (labelId(subject.state) === "link.state.unbound") return { text };
  return { text, tone: subject.online ? "on" : "off" };
}

/** A row about another node as a two-line card: its name and sprite over
 *  its address (or `detail`) and `badge` (engine `subject`). */
export function subjectCard(subject: Subject, fallback: Label, detail?: string,
  badge: Badge = subjectBadge(subject)): Pick<ChoiceOpts, "label" | "sprite" | "detail" | "badge"> {
  return {
    label: subject.name || labelText(fallback),
    ...(subject.sprite ? { sprite: subject.sprite } : {}),
    detail: detail ?? subject.address,
    badge,
  };
}

/** A joinable row's detail is its own label, the address with the kind
 *  of node it is; a member's is its bare address. */
const cardDetail = (toggle: Toggle): string | undefined =>
  labelId(toggle.label)?.startsWith("link.candidate.") ? labelText(toggle.label) : undefined;

/** A row the server drew without a press to take: the reason it names,
 *  in the badge, toned off. Undefined for an ordinary control, and the
 *  bare id for a reason this pack has no word for. */
export function unavailableBadge(toggle: Toggle): Badge | undefined {
  if (!toggle.unavailable) return undefined;
  return { text: labelText({ id: toggle.unavailable }), tone: "off" };
}

/** Such a card also LOOKS unavailable, which its own class paints: a
 *  `disabled` row node reaches the `disabled` state of no rule, since
 *  that state is a form control's (ui/theme/kit.ts). */
export function greyedCard(card: UiNode, blocked: Badge | undefined): UiNode {
  if (!blocked) return card;
  return { ...card, class: [...(card.class ?? []), "choice-unavailable"] };
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
  const blocked = unavailableBadge(toggle);
  return row(
    `${id}/box`,
    [
      text(`${id}/label`, labelText(toggle.label), ["grow", "list-label"]),
      ...(blocked ? [text(`${id}/unavailable`, blocked.text, ["hint"])] : []),
      {
        id,
        type: "button",
        text: word,
        class: ["btn", toggle.on ? "btn-selected" : "btn-default"],
        ...(blocked ? {} : { event: bind(id, toggleAction(doc, toggle)) }),
        ...(active && !blocked ? {} : { disabled: true }),
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
    const blocked = unavailableBadge(toggle);
    open.choices.push(greyedCard(
      Choice(key, {
        label: labelText(toggle.label),
        ...(toggle.icon ? { sprite: toggle.icon } : {}),
        ...(toggle.color ? { color: toggle.color } : {}),
        ...(toggle.subject
          ? subjectCard(toggle.subject, toggle.label, cardDetail(toggle), blocked)
          : blocked ? { detail: blocked.text } : {}),
        selected: toggle.on,
        ...(blocked ? {} : { event: bind(key, toggleAction(doc, toggle)) }),
        disabled: !active || blocked != null,
      }),
      blocked,
    ));
  }
  if (pending.length) out.unshift(ChoiceGrid(`${id}/cards`, pending, { min: CARD_MIN }));
  return out;
}
