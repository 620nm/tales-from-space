// One pane per open document. The discriminator picks the body — build,
// script, or the generic module document — and a module document's
// `presentation` picks the SHAPE it is drawn in, never a renderer and
// never an act (docs/tgui/documents.md).
import type { Json, UiNode } from "@lunatic/ui";
import { Section, Table } from "@lunatic/ui";
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
import { computerPane, desktopPane, isDesktop, lockParts, programmingTool, programmingWallpaper } from "./documents-desktop";
import { filePanes, guard, retainOpenFileBuffers, retainWorkspaces } from "./files";
import { linkMeta, refusalDialog, retainRefusals } from "./documents-device";
import { bind, column, entry, icon, press, row, screen, some, text } from "./view";
import * as S from "./strings";
import { labelText } from "./labels";
import { actionSurface } from "./actions";

const WIDTH: Record<Presentation, number> = {
  modules: 420,
  choices: 460,
  visual_choices: 520,
  shelf: 460,
  panes: 640,
};

export function documents(view: GameplayView): UiNode[] {
  const open = Object.values(view.documents ?? {}).filter((doc) => !actionSurface(doc));
  retainOpenFileBuffers(open);
  retainWorkspaces(open);
  retainRefusals(open);
  return open.map((doc) => {
    const id = `doc/${doc.id}/${doc.generation}`;
    // A provider that sent no state, or one that is not a record, still
    // gets its frame and its close press rather than taking the
    // interface down.
    const state: Partial<DocumentState> = doc.state ?? {};
    const active = state.status === undefined || state.status >= 2;
    // The close lives in the host's title bar, named by the window
    // descriptor below. No node draws it, so only the meaning is
    // registered: the host's press arrives under this id.
    bind(`${id}/close`, guard(id, {
      kind: "close",
      document: doc.id,
      generation: doc.generation,
    }));
    let body: UiNode[];
    let width = WIDTH.modules;
    if (state.document === "build") {
      body = buildRows(id, doc, state, view.state?.armed, active);
    } else if (state.document === "script") {
      if (isDesktop(state.data)) return desktopPane(id, doc, state, active);
      body = scriptRows(id, doc, state, active);
    } else {
      // Anything a provider does not name is read as a module document,
      // which is what every field below is optional for.
      const module = state as Partial<ModuleState>;
      if (module.script && isDesktop(module.script.data))
        return desktopPane(id, doc, module.script, active, module);
      // A contact's window is titled with the tool it is worked through
      // (below); its workspace bar names the target it reaches.
      const tool = programmingTool(module.script?.data);
      if (module.contact_locked) return computerPane(id, lockParts(id, doc, module, active), programmingWallpaper(module.script?.data));
      if (module.stores) return computerPane(id, filePanes(id, doc, module, active, [], tool), programmingWallpaper(module.script?.data));
      width = WIDTH[module.presentation ?? "modules"] ?? WIDTH.modules;
      body = [
        ...moduleBody(id, doc, module, active, false, false),
        ...(module.products !== undefined
          ? shelfRows(id, doc, module.products, active)
          : []),
      ];
    }
    // The host window's body is bare: the padding a document reads at
    // belongs to the document, not to every surface the pack opens.
    const module = state as Partial<ModuleState>;
    const footer = module.notice ? labelText(module.notice) : S.tfs(active ? "ui.document.available" : "ui.document.unavailable");
    const heading = text(`${id}/heading`, module.name ?? doc.title, ["doc-heading"]);
    const refusal = refusalDialog(id, doc, module);
    return screen(id, {
      toolbar: [module.link ? row(`${id}/head`, some(heading, linkMeta(id, module, ["doc-heading-meta"], ["doc-heading-state"])), { cls: ["doc-head"] }) : heading],
      body: [column(`${id}/document`, body.length ? body : [text(`${id}/empty`, S.tfs("ui.document.empty"), ["hint"])], { cls: ["doc-body"] })],
      footer: [text(`${id}/status`, footer, [active ? "doc-status" : "doc-unavailable"])],
      ...(refusal ? { overlay: [refusal] } : {}),
    }, {
      cls: ["pane", "doc-pane"],
      style: { width, maxWidth: "100%", maxHeight: 540 },
    });
  }).map((node, index) => {
    const doc = open[index]!;
    const module = doc.state as Partial<ModuleState>;
    // A contact's window wears the tool in hand; its workspace bar names
    // the device (ui/files.ts `workspaceHeading`).
    const tool = programmingTool(module?.script?.data);
    const titleAsset = tool?.sprite ?? doc.owner_sprite ?? module?.owner_sprite;
    return { ...node, ...(module?.open && !module.editor?.read_only ? { primarySave: `doc/${doc.id}/${doc.generation}/editor/save` } : {}), window: {
      ...(node.class?.includes("computer-screen") ? { contentAspectRatio: 16 / 9, minWidth: 740, maximizable: true, titleAsset } : {}),
      key: `document/${doc.id}/${doc.generation}`, title: tool?.name ?? doc.title, source: "status",
      close: `doc/${doc.id}/${doc.generation}/close`,
      document: doc.id, generation: doc.generation, height: 520, width: Number(node.style?.width) || 520 } };
  });
}

/** The construction roster: what a recipe costs, and which one is armed. */
function buildRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<BuildState>,
  armed: number | undefined,
  active: boolean,
): UiNode[] {
  const rows = (state.recipes ?? []).map((recipe, index) => {
    const key = `${id}/recipe/${index}`;
    return [
      icon(`${key}/icon`, recipe.sprite) ?? text(`${key}/icon`, ""),
      column(`${key}/description`, some(
        text(`${key}/name`, recipe.label, ["pname"]),
        (recipe.have ?? 0) < (recipe.cost ?? 0) ? text(`${key}/unavailable`, S.tfs("ui.document.materials"), ["hint"]) : null,
      )),
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
          disabled: !active || (recipe.have ?? 0) < (recipe.cost ?? 0),
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
          entry(box, "", () => undefined, { submitOnly: true, disabled: !active, label: action.id }),
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
