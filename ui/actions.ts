import type { Json, UiNode } from "@lunatic/ui";
import type { GameplayView } from "./model";
import type { PanelDocument, ScriptState } from "./document-model";
import { documentAction } from "./document-action";
import { column, icon, panel, press, row, some, text } from "./view";
import * as S from "./strings";

interface Action { id: string; label: Json; sprite?: string; state?: string; pinned?: boolean }
interface Group { id: string; label: Json; actions: Action[] }
interface Surface { presentation?: string; groups?: Group[] }

export function actionSurface(doc: PanelDocument): Surface | undefined {
  const state = doc.state;
  if (state?.document !== "script") return undefined;
  const data = (state as Partial<ScriptState>).data;
  if (!data || typeof data !== "object" || Array.isArray(data)) return undefined;
  if (data.presentation !== "actions" && data.presentation !== "intent") return undefined;
  return data as unknown as Surface;
}

/** Item-owned script documents grant the actions; the host remembers their order. */
export function actionGroups(view: GameplayView): UiNode[] {
  const groups = new Map<string, { label: Json; buttons: UiNode[]; intent: boolean }>();
  for (const doc of Object.values(view.documents ?? {})) {
    const data = actionSurface(doc);
    if (!data) continue;
    for (const group of data.groups ?? []) {
      let merged = groups.get(group.id);
      if (!merged) { merged = { label: group.label, buttons: [], intent: data.presentation === "intent" }; groups.set(group.id, merged); }
      for (const action of group.actions ?? []) {
        const id = `action/${doc.id}/${doc.generation}/${action.id}`;
        // A sprite says what the action is; the word under it would not
        // fit the 34px square the strip gives each one.
        const button = press(id, action.label, documentAction(doc, action.id, {}), {
          variant: action.state === "on" ? "selected" : "default",
          disabled: doc.state?.status !== undefined && doc.state.status < 2,
          cls: [action.sprite ? "ability" : "action-button"],
        });
        merged.buttons.push({ ...button,
          actionKey: `${group.id}/${action.id}`,
          actionDocument: doc.id, actionGeneration: doc.generation,
          ...(action.sprite ? { children: some(icon(`${id}/icon`, action.sprite, "", ["ability-icon"])) } : {}),
        });
      }
    }
  }
  const actions: UiNode[] = [];
  const intents: UiNode[] = [];
  for (const [key, group] of groups)
    (group.intent ? intents : actions).push(strip(`actions/${key}`, key, group.label, group.buttons));
  // The controls that belong to no document: what the held item does,
  // and the build roster.
  if (view.body) actions.push(strip("item-actions", "item-controls", S.ITEMS, [
    ...(view.state.inventory ? [
      press("use_other", S.USE_OTHER, { kind: "use_other" }, { cls: ["action-button"] }),
      press("use_self", S.USE, { kind: "use_self" }, { cls: ["action-button"] }),
      press("equip", S.EQUIP, { kind: "equip" }, { cls: ["action-button"] }),
    ] : []),
    press("open_build", S.BUILD, { kind: "open_build" }, { cls: ["action-button"] }),
  ]));
  return some(
    actions.length
      ? row("action-strip", actions, { cls: ["hudgroup", "action-strip"] })
      : null,
    intents.length ? column("intent", intents, { cls: ["hudgroup"], style: { position: "absolute", left: 202, bottom: 40 } }) : null,
  );
}

/** One group in the strip: its word above it, its presses in a host row. */
function strip(id: string, key: string, label: Json, buttons: UiNode[]): UiNode {
  return column(id, [
    text(`${id}/title`, label, ["group-label"]),
    { ...panel(`${id}/buttons`, buttons, { cls: ["action-buttons"] }), actionGroup: key },
  ], { cls: ["hudgroup", "action-group"] });
}
