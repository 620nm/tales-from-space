import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, ProgramSlotRowState } from "./document-model";
import { documentAction } from "./document-action";
import { labelText } from "./labels";
import { column, press, row, some, text } from "./view";
import * as S from "./strings";
const SOURCE_EXTS = new Set(["disl"]);
export function programSlotRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode {
  const loadable = (state.files ?? []).filter(
    (file) => file.store === "host" && SOURCE_EXTS.has(file.ext),
  );
  const rows = (state.program_slots ?? []).map((slot: ProgramSlotRowState, index) => {
    const key = `${id}/program/${index}`;
    return column(
      key,
      some(
        row(
          `${key}/head`,
          some(
            text(`${key}/id`, slot.id, ["grow", "list-label"]),
            text(`${key}/state`, labelText(slot.state), ["hint"]),
            slot.file ? text(`${key}/file`, slot.file, ["fname"]) : null,
            text(
              `${key}/stats`,
              S.programStats(slot.runs ?? 0, slot.faults ?? 0),
              ["fsize"],
            ),
            slot.uid !== null && slot.uid !== undefined
              ? press(
                  `${key}/unload`,
                  S.UNLOAD,
                  documentAction(doc, "toggle", {
                    field: "program_unload",
                    option: `${slot.id}:${state.stores?.find((store) => store.key === "host")?.binding ?? ""}`,
                  }),
                  { variant: "ghost", disabled: !active },
                )
              : null,
          ),
          { cls: ["list-row"] },
        ),
        loadable.length
          ? Stack(
              `${key}/load`,
              loadable.map((file, i) =>
                press(
                  `${key}/load/${i}`,
                  S.programLoad(S.fileName(file.name, file.ext)),
                  documentAction(doc, "toggle", {
                    field: "program_load",
                    option: `${slot.id}:${file.uid}:${file.binding}`,
                  }),
                  { variant: "ghost", disabled: !active },
                ),
              ),
              { gap: 4, wrap: true },
            )
          : null,
      ),
    );
  });
  return column(
    `${id}/programs`,
    [text(`${id}/programs/title`, S.PROGRAM, ["section-title"]), ...rows],
    { cls: ["card"] },
  );
}
