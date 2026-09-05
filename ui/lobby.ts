// The board a session sits at before it has a body, and the card it is
// left with when the body it had stops answering.
import type { UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { bind, column, press, row, some, text } from "./view";
import * as S from "./strings";

export function crewPanels(view: GameplayView): UiNode[] {
  const state = view.state ?? {};
  const out: UiNode[] = [];
  const jobs = state.jobs?.jobs;
  if (jobs)
    out.push(
      Pane(
        "lobby",
        [
          text("lobby-title", S.LOBBY_TITLE, ["titlebar-title"]),
          text("lobby-hint", S.LOBBY_HINT, ["hint"]),
          column(
            "lobby-jobs",
            jobs.map((job) => {
              const id = `job/${job.key}`;
              const full = job.slots !== null && job.taken >= job.slots;
              return row(
                `${id}/box`,
                [
                  text(`${id}/name`, job.name, ["grow"]),
                  text(`${id}/count`, S.jobCount(job.taken, job.slots), [
                    "stock",
                  ]),
                  {
                    id,
                    type: "button",
                    text: "",
                    class: ["choice-hit"],
                    event: bind(id, { kind: "join", job: job.key }),
                    ...(full ? { disabled: true } : {}),
                  },
                ],
                { cls: full ? ["job", "full"] : ["job"] },
              );
            }),
            { style: { gap: 4 } },
          ),
        ],
        { style: { width: 380, maxHeight: "76%" } },
      ),
    );
  const body = state.bodyStatus;
  if (body && (!body.state?.controllable || !body.state?.animate))
    out.push(
      Pane(
        "body-state",
        some(
          text("body-title", S.BODY_TITLE, ["caption"]),
          text("body-label", body.state?.label, ["mstate"]),
          body.can_respawn
            ? press("respawn", S.RESPAWN, { kind: "respawn" }, {
                variant: "primary",
              })
            : null,
        ),
        { style: { width: 320, alignItems: "center" } },
      ),
    );
  return out;
}
