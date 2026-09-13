// The board a session sits at before it has a body, and the card it is
// left with when the body it had stops answering.
import type { UiNode } from "@lunatic/ui";
import { Pane, Stack } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { bind, entry, press, row, screen, some, text } from "./view";
import { preparationPanels } from "./lobby-character";
import * as S from "./strings";

export function crewPanels(view: GameplayView): UiNode[] {
  const state = view.state ?? {};
  if (state.round?.phase === "preparing") return preparationPanels(view);
  const out: UiNode[] = [];
  const jobs = state.jobs?.jobs;
  const hasOwnedBody = state.identity?.you != null;
  const latejoinPrep = state.round?.phase === "playing" && !hasOwnedBody && state.preparation?.can_edit
    ? state.preparation
    : undefined;
  const latejoinPending = state.preparationPending === true;
  const joinPending = latejoinPending && !state.preparationCanQueue;
  if (jobs)
    out.push(
      // A screen as tall as its roster, up to the cap, and then scrolling.
      screen("lobby", {
        toolbar: [Stack("lobby-head", [
          text("lobby-title", S.LOBBY_TITLE, ["titlebar-title"]),
          text("lobby-hint", S.LOBBY_HINT, ["hint"]),
        ], { dir: "column", gap: 2, cls: ["grow"] })],
        body: [
          ...(latejoinPrep ? [
            text("preparation/latejoin-hint", S.tfs("ui.lobby.preparation.latejoin_hint"), ["hint"]),
            row("preparation/name-row", [
              text("preparation/name-label", S.tfs("ui.lobby.preparation.name"), ["lobby-field-label"]),
              entry("preparation/name", latejoinPrep.draft.name, (value) => value === latejoinPrep.draft.name ? undefined : ({
                kind: "character_draft",
                round: latejoinPrep.round,
                revision: latejoinPrep.revision,
                draft: { ...latejoinPrep.draft, name: value },
              }), {
                label: S.tfs("ui.lobby.preparation.name"),
                disabled: latejoinPending,
                cls: ["lobby-name-entry"],
              }),
            ], { cls: ["lobby-field"] }),
            ...(latejoinPending ? [text("preparation/pending", S.tfs("ui.lobby.preparation.updating"), ["lobby-pending"])] : []),
          ] : []),
          Stack(
            "lobby-jobs",
            jobs.length ? jobs.map((job) => {
              const id = `job/${job.key}`;
              const full = job.slots !== null && job.taken >= job.slots;
              const playing = !state.round || state.round.phase === "playing";
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
                    label: job.name,
                    class: ["choice-hit"],
                    event: bind(id, { kind: "join", job: job.key }),
                    ...(!playing || full || joinPending ? { disabled: true } : {}),
                  },
                ],
                { cls: !playing || full || joinPending ? ["job", "full"] : ["job"] },
              );
            }) : [text("lobby-empty", S.tfs("ui.lobby.empty"), ["hint"])],
            { dir: "column", gap: 4 },
          ),
        ],
        ...(state.round ? { footer: [
          row("lobby/round-status", [
            text("lobby/round-status/phase", state.round.phase === "ending"
              ? S.tfs("ui.lobby.phase.ending")
              : S.tfs("ui.lobby.phase.playing"), ["lobby-phase"]),
            ...(state.round.paused
              ? [text("lobby/round-status/paused", S.tfs("ui.lobby.paused"), ["lobby-paused"])]
              : []),
          ], { cls: ["lobby-status-footer"] }),
        ] } : {}),
      }, { cls: ["pane", "lobby-board"], fit: true, style: { width: 380, maxHeight: "76%" } }),
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
        { cls: ["centered"], style: { width: 320 } },
      ),
    );
  return out;
}
