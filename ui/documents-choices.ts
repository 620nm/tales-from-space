// Switches and dials. A toggle with no `option` is a switch of its own
// and ends the block before it; toggles sharing a `field` and a `group`
// are one block of choices, which is how the server says "these are
// positions of one selector" (docs/tgui/documents.md).
import type { UiNode } from "@lunatic/ui";
import { Choice, ChoiceGrid } from "@lunatic/ui";
import type { DocumentIdentity, Toggle } from "./document-model";
import { documentAction } from "./document-action";
import { labelText } from "./labels";
import { bind, row, text } from "./view";

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
 * two proxied devices' rosters never merge into one.
 */
export function toggleRows(
  id: string,
  doc: DocumentIdentity,
  toggles: Toggle[],
  active: boolean,
): UiNode[] {
  const out: UiNode[] = [];
  let open: { key: string; choices: UiNode[] } | null = null;
  for (const [index, toggle] of toggles.entries()) {
    const key = `${id}/toggle/${index}`;
    if (toggle.option == null) {
      open = null;
      out.push(switchRow(key, doc, toggle, active));
      continue;
    }
    const group = labelText(toggle.group);
    const blockKey = `${toggle.field} ${group}`;
    if (!open || open.key !== blockKey) {
      if (group) out.push(text(`${key}/group`, group, ["section-title"]));
      open = { key: blockKey, choices: [] };
      out.push(ChoiceGrid(`${key}/grid`, open.choices));
    }
    open.choices.push(
      Choice(key, {
        label: labelText(toggle.label),
        ...(toggle.icon ? { sprite: toggle.icon } : {}),
        ...(toggle.color ? { color: toggle.color } : {}),
        selected: toggle.on,
        event: bind(key, toggleAction(doc, toggle)),
        disabled: !active,
      }),
    );
  }
  return out;
}
