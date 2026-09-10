import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, SocketRowState } from "./document-model";
import { documentAction } from "./document-action";
import { labelText } from "./labels";
import { column, press, row, some, text } from "./view";
import * as S from "./strings";
const SOURCE_EXTS = new Set(["disl"]);
export function socketRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode {
  const loadable = (state.files ?? []).filter(
    (file) => file.store === "host" && SOURCE_EXTS.has(file.ext),
  );
  const rows = (state.sockets ?? []).map((socket: SocketRowState, index) => {
    const key = `${id}/socket/${index}`;
    return column(
      key,
      some(
        row(
          `${key}/head`,
          some(
            text(`${key}/id`, socket.id, ["grow", "list-label"]),
            text(`${key}/state`, labelText(socket.state), ["hint"]),
            socket.file ? text(`${key}/file`, socket.file, ["fname"]) : null,
            text(
              `${key}/stats`,
              S.socketStats(socket.runs ?? 0, socket.faults ?? 0),
              ["fsize"],
            ),
            socket.uid !== null && socket.uid !== undefined
              ? press(
                  `${key}/unload`,
                  S.UNLOAD,
                  documentAction(doc, "toggle", {
                    field: "socket_unload",
                    option: `${socket.id}:${state.stores?.find((store) => store.key === "host")?.binding ?? ""}`,
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
                  S.socketLoad(S.fileName(file.name, file.ext)),
                  documentAction(doc, "toggle", {
                    field: "socket_load",
                    option: `${socket.id}:${file.uid}:${file.binding}`,
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
  return column(`${id}/sockets`, rows, { cls: ["card"] });
}

