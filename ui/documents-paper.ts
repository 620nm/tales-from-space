import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { DocumentIdentity, PaperState } from "./document-model";
import { scriptAction } from "./document-action";
import { entry, press, text } from "./view";
import { fragmentList, sliceUtf8, utf8Length, writingPreview, TEXT_LIMIT } from "./writing-text";
import * as S from "./strings";

const fragmentsOf = (state: PaperState) =>
  fragmentList(state.committed);

/** Writing continues on the sheet after its existing marks. */
export function paperBody(id: string, doc: DocumentIdentity, state: PaperState, active: boolean): UiNode[] {
  const committed = fragmentsOf(state);
  const committedPreview = writingPreview(`${id}/paper/committed`, committed);
  const sourceDraft = typeof state.draft === "string" ? state.draft
    : "";
  const draft = sliceUtf8(sourceDraft, TEXT_LIMIT);
  const draftTruncated = utf8Length(sourceDraft) > TEXT_LIMIT;
  const body = `${id}/paper`;
  const draftId = `${body}/draft`;
  const writeAction = "write";
  const style = state.writer_style;
  return [
    Stack(`${body}/committed`, [
      ...committedPreview,
      entry(draftId, draft, (value) => scriptAction(doc, writeAction, sliceUtf8(value, TEXT_LIMIT)),
        { multiline: true, flow: true, submitOnly: true, revision: state.revision, disabled: !active,
          // theme-lint: allow -- native writer style is pack-authored content.
          cls: ["paper-line"], label: S.tfs("ui.writing.draft"), style: {
            ...(style?.font_family ? { fontFamily: style.font_family } : {}),
            ...(style?.color ? { color: style.color } : {}),
            ...(style?.weight ? { fontWeight: style.weight } : {}),
          } }),
    ], { dir: "row", cls: ["paper-sheet"], style: { width: "100%" } }),
    ...(draftTruncated ? [text(`${body}/draft-truncated`, S.tfs("ui.writing.truncated"), ["hint"])] : []),
    ...(active ? [
      press(`${body}/commit`, S.tfs("ui.writing.commit"), (event) =>
        scriptAction(doc, writeAction, sliceUtf8(event.value ?? draft, TEXT_LIMIT)),
        { submit: draftId, variant: "primary" }),
      text(`${body}/hint`, S.tfs("ui.writing.commit_hint"), ["hint"]),
    ] : []),
  ];
}
