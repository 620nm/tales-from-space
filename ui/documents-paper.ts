import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { DocumentIdentity, PaperState } from "./document-model";
import { scriptAction } from "./document-action";
import { entry, press, row, text } from "./view";
import { fragmentList, sliceUtf8, utf8Length, writingPreview, TEXT_LIMIT } from "./writing-text";
import * as S from "./strings";

const fragmentsOf = (state: PaperState) =>
  fragmentList(state.committed);

/** The physical sheet: committed marks stay separate from the draft. */
export function paperBody(id: string, doc: DocumentIdentity, state: PaperState, active: boolean): UiNode[] {
  const committed = fragmentsOf(state);
  const sourceDraft = typeof state.draft === "string" ? state.draft
    : "";
  const draft = sliceUtf8(sourceDraft, TEXT_LIMIT);
  const draftTruncated = utf8Length(sourceDraft) > TEXT_LIMIT;
  const body = `${id}/paper`;
  const draftId = `${body}/draft`;
  const writeAction = "write";
  return [
    row(`${body}/identity`, [
      text(`${body}/identity/title`, state.name ?? doc.title, ["paper-title"]),
      text(`${body}/identity/count`, S.tfs("ui.writing.fragments", { count: committed.length }), ["hint"]),
    ], { cls: ["paper-identity"] }),
    Stack(`${body}/committed`, writingPreview(`${body}/committed`, committed), { dir: "row",
      cls: ["paper-sheet"], style: { maxHeight: 220, width: "100%" },
    }),
    Stack(`${body}/draft-area`, [
      text(`${body}/draft-label`, S.tfs("ui.writing.draft"), ["paper-label"]),
      entry(draftId, draft, (value) => scriptAction(doc, writeAction, sliceUtf8(value, TEXT_LIMIT)),
        { multiline: true, submitOnly: true, revision: state.revision, disabled: !active, cls: ["paper-draft"], label: S.tfs("ui.writing.draft") }),
      ...(draftTruncated ? [text(`${body}/draft-truncated`, S.tfs("ui.writing.truncated"), ["hint"])] : []),
      press(`${body}/commit`, S.tfs("ui.writing.commit"), (event) =>
        scriptAction(doc, writeAction, sliceUtf8(event.value ?? draft, TEXT_LIMIT)),
        { submit: draftId, variant: "primary", disabled: !active }),
      text(`${body}/hint`, S.tfs("ui.writing.commit_hint"), ["hint"]),
    ], { dir: "column", cls: ["paper-draft-area"] }),
  ];
}
