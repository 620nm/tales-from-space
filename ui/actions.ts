import type { Json, UiNode } from "@lunatic/ui";
import type { GameplayView } from "./model";
import type { PanelDocument, ScriptState } from "./document-model";
import { documentAction } from "./document-action";
import { column, icon, panel, press, some, text } from "./view";
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
        const button = press(id, action.label, documentAction(doc, action.id, {}), {
          variant: action.state === "on" ? "selected" : "default",
          disabled: doc.state?.status !== undefined && doc.state.status < 2,
          cls: ["action-button"],
        });
        merged.buttons.push({ ...button,
          actionKey: `${group.id}/${action.id}`,
          actionDocument: doc.id, actionGeneration: doc.generation,
          ...(action.sprite ? { children: some(icon(`${id}/icon`, action.sprite), text(`${id}/label`, action.label, ["action-label"])) } : {}),
        });
      }
    }
  }
  const actions: UiNode[] = [];
  const intents: UiNode[] = [];
  for (const [key, group] of groups) {
    const pane = column(`actions/${key}`, [
      text(`actions/${key}/title`, group.label, ["caption"]),
      { ...panel(`actions/${key}/buttons`, group.buttons, { cls: ["action-buttons"], style: { display: "flex", gap: 4 } }), actionGroup: key },
    ], { cls: ["hudgroup"], style: { minWidth: 320 } });
    (group.intent ? intents : actions).push(pane);
  }
  if (view.body) actions.push({
    ...panel("item-actions", [
      ...(view.state.inventory ? [press("use_other", S.USE_OTHER, { kind: "use_other" }, { cls: ["action-button"] }),
      press("equip", S.EQUIP, { kind: "equip" }, { cls: ["action-button"] }),
      press("throw_mode", view.state.throwing ? S.THROWING : S.THROW, { kind: "throw_mode" }, {
        cls: ["action-button"], variant: view.state.throwing ? "selected" : "default",
      })] : []),
      press("open_build", S.BUILD, { kind: "open_build" }, { cls: ["action-button"] }),
    ], { cls: ["hudgroup"], style: { display: "flex", gap: 4, minWidth: 260 } }), actionGroup: "item-controls",
  });
  return some(
    actions.length ? column("action-groups", actions, { cls: ["hudgroup"], style: { position: "absolute", right: 110, width: 0, alignItems: "start", bottom: 180, gap: 8 } }) : null,
    intents.length ? column("intent", intents, { cls: ["hudgroup"], style: { position: "absolute", left: 202, bottom: 40 } }) : null,
  );
}
