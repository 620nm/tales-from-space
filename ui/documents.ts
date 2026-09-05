// One pane per open document. The discriminator picks the body — build,
// script, or the generic module document — and a module document's
// `presentation` picks the SHAPE it is drawn in, never a renderer and
// never an act (docs/tgui/documents.md).
import type { Json, UiNode } from "@lunatic/ui";
import { Pane, Section, Table, TitleBar } from "@lunatic/ui";
import type { GameplayView } from "./model";
import type {
  BuildState,
  DocumentIdentity,
  DocumentState,
  ModuleState,
  Presentation,
  ScriptState,
} from "./document-model";
import { documentAction } from "./document-action";
import { moduleBody } from "./documents-modules";
import { shelfRows } from "./documents-shelf";
import { filePanes, retainOpenFileBuffers } from "./files";
import { bind, entry, icon, press, row, some, text } from "./view";
import * as S from "./strings";

const WIDTH: Record<Presentation, number> = {
  modules: 420,
  choices: 460,
  visual_choices: 520,
  shelf: 460,
  panes: 640,
};

export function documents(view: GameplayView): UiNode[] {
  const open = Object.values(view.documents ?? {});
  retainOpenFileBuffers(open);
  return open.map((doc) => {
    const id = `doc/${doc.id}/${doc.generation}`;
    // A provider that sent no state, or one that is not a record, still
    // gets its frame and its close press rather than taking the
    // interface down.
    const state: Partial<DocumentState> = doc.state ?? {};
    const active = state.status === undefined || state.status >= 2;
    const head = TitleBar(`${id}/title`, doc.title, {
      closeEvent: bind(`${id}/close`, {
        kind: "close",
        document: doc.id,
        generation: doc.generation,
      }),
    });
    let body: UiNode[];
    let width = WIDTH.modules;
    if (state.document === "build") {
      body = buildRows(id, doc, state, view.state?.armed);
    } else if (state.document === "script") {
      body = scriptRows(id, doc, state, active);
    } else {
      // Anything a provider does not name is read as a module document,
      // which is what every field below is optional for.
      const module = state as Partial<ModuleState>;
      width = WIDTH[module.presentation ?? "modules"] ?? WIDTH.modules;
      body = [
        ...moduleBody(id, doc, module, active),
        ...(module.products?.length
          ? shelfRows(id, doc, module.products, active)
          : []),
        ...(module.stores ? filePanes(id, doc, module, active) : []),
      ];
    }
    return Pane(id, [head, ...body], {
      style: { width, maxWidth: "100%", maxHeight: 540 },
    });
  });
}

/** The construction roster: what a recipe costs, and which one is armed. */
function buildRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<BuildState>,
  armed: number | undefined,
): UiNode[] {
  const rows = (state.recipes ?? []).map((recipe, index) => {
    const key = `${id}/recipe/${index}`;
    return [
      icon(`${key}/icon`, recipe.sprite) ?? text(`${key}/icon`, ""),
      text(`${key}/name`, recipe.label, ["pname"]),
      text(
        `${key}/cost`,
        S.recipeCost(recipe.have ?? 0, recipe.cost ?? 0, recipe.secs ?? 0),
        ["stock"],
      ),
      press(
        `${key}/arm`,
        armed === index ? S.ARMED : S.ARM,
        { kind: "arm", document: doc.id, generation: doc.generation, index },
        {
          variant: armed === index ? "selected" : "primary",
          disabled: (recipe.have ?? 0) < (recipe.cost ?? 0),
        },
      ),
    ];
  });
  return rows.length
    ? [Table(`${id}/recipes`, [32, "1fr", "auto", "auto"], rows)]
    : [];
}

/** A script view model: its data as readings, its offers as presses. */
function scriptRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ScriptState>,
  active: boolean,
): UiNode[] {
  return [
    ...(state.data == null ? [] : dataRows(`${id}/data`, state.data)),
    ...(state.actions ?? []).map((action, index) => {
      const key = `${id}/action/${index}`;
      if (!action.input)
        return press(key, action.id, documentAction(doc, action.id, {}), {
          disabled: !active,
        });
      const box = `${key}/value`;
      return row(
        key,
        [
          text(`${key}/label`, action.id, ["grow", "list-label"]),
          entry(box, "", () => undefined, { submitOnly: true }),
          press(
            `${key}/send`,
            S.SET,
            (e) => documentAction(doc, action.id, { value: e.value ?? "" }),
            { submit: box, variant: "primary", disabled: !active },
          ),
        ],
        { cls: ["list-row"] },
      );
    }),
  ];
}

function dataRows(id: string, value: Json, depth = 0): UiNode[] {
  if (depth > 4 || value == null) return [];
  if (typeof value !== "object") return [text(id, value, ["list-value"])];
  return Object.entries(value)
    .slice(0, 32)
    .flatMap(([key, held], index) => {
      const child = `${id}/${index}`;
      if (held && typeof held === "object")
        return [
          Section(child, key, dataRows(`${child}/value`, held, depth + 1)),
        ];
      return [
        row(
          child,
          some(
            text(`${child}/label`, key, ["grow", "list-label"]),
            text(`${child}/value`, held, ["list-value"]),
          ),
          { cls: ["list-row"] },
        ),
      ];
    });
}
