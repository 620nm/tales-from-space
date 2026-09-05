import { documentAction } from "./document-action";
import type { Json } from "@lunatic/ui";
import type { GameplayView } from "./model";
import type {
  DocumentIdentity,
  DocumentState,
  BuildState,
  ScriptState,
  ModuleState,
} from "./document-model";
import { button, column, icon, input, node, pane, row, text } from "./view";
import type { UiNode } from "@lunatic/ui";
import { files, retainOpenFileBuffers } from "./files";

export function documents(view: GameplayView): UiNode[] {
  const openDocuments = Object.values(view.documents ?? {});
  retainOpenFileBuffers(openDocuments);
  return openDocuments.map((doc) => {
    const id = `doc/${doc.id}/${doc.generation}`;
    // A provider that sent no state, or one that is not a record, still
    // gets its frame and its close button rather than taking the
    // interface down.
    const state: Partial<DocumentState> = doc.state ?? {};
    const active = state.status === undefined || state.status >= 2;
    const children: UiNode[] = [
      row(`${id}/title`, [
        text(`${id}/name`, doc.title),
        button(`${id}/close`, "✕", {
          kind: "close",
          document: doc.id,
          generation: doc.generation,
        }),
      ]),
    ];
    if (state.document === "build") {
      children.push(...buildRows(id, doc, state, view.state?.armed));
    } else if (state.document === "script") {
      children.push(...scriptRows(id, doc, state, active));
    } else {
      // Anything a provider does not name is read as a module document,
      // which is what every field below is optional for.
      children.push(
        ...moduleRows(id, doc, state as Partial<ModuleState>, active),
      );
    }
    return pane(id, children, { maxHeight: 440 });
  });
}

function dataRows(id: string, value: Json, depth = 0): UiNode[] {
  if (depth > 4 || value == null) return [];
  if (typeof value !== "object") return [text(id, value)];
  return Object.entries(value)
    .slice(0, 32)
    .flatMap(([key, entry], index) => {
      const child = `${id}/${index}`;
      if (entry && typeof entry === "object")
        return [
          column(child, [
            text(`${child}/label`, key),
            ...dataRows(`${child}/value`, entry, depth + 1),
          ]),
        ];
      return [
        row(child, [
          text(`${child}/label`, key),
          text(`${child}/value`, entry),
        ]),
      ];
    });
}

function buildRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<BuildState>,
  armed: number | undefined,
): UiNode[] {
  const children: UiNode[] = [];

  children.push(
    ...(state.recipes ?? []).map((recipe, index: number) =>
      row(`${id}/recipe/${index}`, [
        icon(`${id}/recipe/${index}/icon`, recipe.sprite),
        button(
          `${id}/recipe/${index}/arm`,
          `${armed === index ? "● " : ""}${recipe.label} · have ${recipe.have} · costs ${recipe.cost} · ${recipe.secs}s`,
          {
            kind: "arm",
            document: doc.id,
            generation: doc.generation,
            index,
          },
          recipe.have < recipe.cost,
        ),
      ]),
    ),
  );

  return children;
}

function scriptRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ScriptState>,
  active: boolean,
): UiNode[] {
  const children: UiNode[] = [];

  children.push(...dataRows(`${id}/data`, state.data ?? null));
  children.push(
    ...(state.actions ?? []).map((action, index: number) =>
      action.input
        ? row(`${id}/action/${index}`, [
            text(`${id}/action/${index}/label`, action.id),
            input(`${id}/action/${index}/value`, "", (value) =>
              documentAction(doc, action.id, { value }),
            ),
          ])
        : button(
            `${id}/action/${index}`,
            action.id,
            documentAction(doc, action.id, {}),
            !active,
          ),
    ),
  );

  return children;
}

function moduleRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode[] {
  const children: UiNode[] = [];

  if (state.notice) children.push(text(`${id}/notice`, state.notice));
  if (state.gauge !== null && state.gauge !== undefined)
    children.push(
      node("progress", `${id}/gauge`, { value: String(state.gauge) }),
    );
  children.push(
    ...(state.readouts ?? []).map((reading, index: number) =>
      row(`${id}/reading/${index}`, [
        text(
          `${id}/reading/${index}/label`,
          `${reading.section ? `${reading.section} · ` : ""}${reading.label}`,
        ),
        text(`${id}/reading/${index}/value`, reading.value),
      ]),
    ),
  );
  children.push(
    ...(state.toggles ?? []).map((toggle, index: number) =>
      button(
        `${id}/toggle/${index}`,
        `${toggle.label}: ${toggle.on ? toggle.on_text : toggle.off_text}`,
        documentAction(doc, "toggle", {
          field: toggle.field,
          ...(toggle.option == null ? {} : { option: toggle.option }),
        }),
        !active,
      ),
    ),
  );
  children.push(
    ...(state.labels ?? []).map((label, index: number) => {
      const key = `${id}/label/${index}`;
      const labelNode = text(`${key}/title`, label.label);
      if (label.row === "press")
        return row(key, [
          labelNode,
          button(
            `${key}/button`,
            label.text,
            documentAction(doc, "toggle", {
              field: label.field,
              ...(label.option == null ? {} : { option: label.option }),
            }),
            !active || !label.enabled,
          ),
        ]);
      if (label.row === "input")
        return row(key, [
          labelNode,
          input(`${key}/value`, "", (value) =>
            documentAction(doc, "action", { action: label.action, value }),
          ),
        ]);
      return row(key, [labelNode, text(`${key}/word`, label.text)]);
    }),
  );
  children.push(
    ...(state.setpoints ?? []).map((set, index: number) =>
      row(`${id}/set/${index}`, [
        text(`${id}/set/${index}/label`, `${set.label} (${set.unit})`),
        input(`${id}/set/${index}/value`, String(set.value), (value) => {
          const number = Number(value);
          return Number.isFinite(number)
            ? documentAction(doc, "set", {
                field: set.field,
                value: Math.max(set.min, Math.min(set.max, number)),
              })
            : undefined;
        }),
      ]),
    ),
  );
  children.push(
    ...(state.products ?? []).map((product, index: number) =>
      row(`${id}/product/${index}`, [
        icon(`${id}/product/${index}/icon`, product.sprite),
        button(
          `${id}/product/${index}/vend`,
          `${product.category ? `${product.category} · ` : ""}${product.label} (${product.stock})`,
          documentAction(doc, product.act, product.payload),
          !active || product.stock <= 0,
        ),
      ]),
    ),
  );
  if (state.matter) children.push(...dataRows(`${id}/matter`, state.matter));
  if (state.stores) children.push(...files(id, doc, state));

  return children;
}
