import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { CopierState, DocumentIdentity, WritingFragment } from "./document-model";
import { scriptAction } from "./document-action";
import { fragmentList, writingPreview } from "./writing-text";
import { press, row, select, text } from "./view";
import * as S from "./strings";

const originalOf = (state: CopierState): WritingFragment[] =>
  fragmentList(state.original);

export function copierBody(id: string, doc: DocumentIdentity, state: CopierState, active: boolean): UiNode[] {
  const original = originalOf(state);
  const count = Math.max(1, Math.min(10, Math.floor(state.count ?? 1)));
  const mode = state.mode === "color" ? "color" : "bw";
  const busy = state.busy === true;
  const paper = state.paper === undefined ? undefined : Math.max(0, Math.floor(state.paper));
  const toner = state.toner === undefined ? undefined : Math.max(0, Math.floor(state.toner));
  const supplied = (paper === undefined || paper >= count) && (toner === undefined || toner >= count);
  const countAction = "set_count";
  const modeAction = "set_color";
  const copyAction = "copy";
  const ejectAction = "eject";
  return [
    row(`${id}/identity`, [
      text(`${id}/identity/name`, state.name ?? doc.title, ["paper-title"]),
      text(`${id}/identity/power`, state.powered === false ? S.tfs("ui.copier.off") : S.tfs("ui.copier.ready"), ["hint"]),
      ...(paper === undefined ? [] : [text(`${id}/identity/paper`, S.tfs("ui.copier.paper", { value: paper }), ["hint"])]),
      ...(toner === undefined ? [] : [text(`${id}/identity/toner`, S.tfs("ui.copier.toner", { value: toner }), ["hint"])]),
    ], { cls: ["copier-identity"] }),
    row(`${id}/controls`, [
      select(`${id}/count`, String(count), Array.from({ length: 10 }, (_, i) => ({ value: String(i + 1), text: String(i + 1) })), (value) => {
        const next = Number(value);
        return Number.isInteger(next) ? scriptAction(doc, countAction, String(Math.max(1, Math.min(10, next)))) : undefined;
      }, { disabled: !active || busy, cls: ["copier-count"] }),
      select(`${id}/mode`, mode, [
        { value: "bw", text: S.tfs("ui.copier.bw") },
        { value: "color", text: S.tfs("ui.copier.color") },
      ], (value) => scriptAction(doc, modeAction, value === "color" ? "color" : "bw"), { disabled: !active || busy, cls: ["copier-mode"] }),
      press(`${id}/copy`, S.tfs("ui.copier.copy"), scriptAction(doc, copyAction), {
        variant: "primary", disabled: !active || busy || !original.length || !supplied,
      }),
      press(`${id}/eject`, S.tfs("ui.copier.eject"), scriptAction(doc, ejectAction), {
        disabled: !active || busy,
      }),
    ], { cls: ["copier-controls"] }),
    Stack(`${id}/original`, original.length ? writingPreview(`${id}/original`, original) : [text(`${id}/original/empty`, S.tfs("ui.copier.empty"), ["hint"])], {
      cls: ["copier-paper"], style: { width: "100%", maxHeight: 330 },
    }),
    ...(busy ? [
      text(`${id}/busy`, S.tfs("ui.copier.busy"), ["notice"]),
      ...(state.progress === undefined ? [] : [{ id: `${id}/progress`, type: "progress" as const, value: String(Math.max(0, Math.min(1, state.progress))) }]),
    ] : []),
    ...(state.failed ? [text(`${id}/failure`, S.tfs("ui.copier.failed"), ["notice"])] : []),
  ];
}
