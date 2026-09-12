// Character setup and out-of-character communication during round
// preparation. The server snapshot is the only source of draft truth.
import type { UiNode } from "@lunatic/ui";
import type {
  CharacterDraft,
  GameplayView,
  PreparationIssue,
  PreparationState,
  RoundStatus,
} from "./model";
import { column, entry, panel, press, row, screen, select, some, text, type Command } from "./view";
import { chatPanel } from "./chat";
import * as S from "./strings";

type LobbyView = GameplayView;

const EMPTY_DRAFT: CharacterDraft = { name: "", ranked_jobs: [], fallback: false };

const ISSUE_LABELS: Record<PreparationIssue, string> = {
  invalid_draft: S.tfs("ui.lobby.issue.invalid_draft"),
  stale: S.tfs("ui.lobby.issue.stale"),
  locked: S.tfs("ui.lobby.issue.locked"),
  allocation_failed: S.tfs("ui.lobby.issue.allocation_failed"),
  no_assignments: S.tfs("ui.lobby.issue.no_assignments"),
};

function roundOf(view: LobbyView): RoundStatus | undefined {
  return view.state.round;
}

function preparationOf(view: LobbyView): PreparationState | undefined {
  return view.state.preparation;
}

function preparationPending(view: LobbyView): boolean {
  return view.state.preparationPending === true;
}

function starting(view: LobbyView): boolean {
  const round = roundOf(view);
  return round?.phase === "preparing"
    && round.remaining_seconds === 0
    && round.ready > 0
    && !round.paused
    && !round.fault;
}

function setupLocked(view: LobbyView): boolean {
  return preparationPending(view) || starting(view);
}

function draftOf(view: LobbyView): CharacterDraft {
  const draft = preparationOf(view)?.draft;
  if (!draft) return EMPTY_DRAFT;
  return {
    name: draft.name ?? "",
    ranked_jobs: Array.isArray(draft.ranked_jobs) ? draft.ranked_jobs : [],
    fallback: draft.fallback === true,
  };
}

function preparationCommand(
  view: LobbyView,
  draft: CharacterDraft,
): Command | undefined {
  const prep = preparationOf(view);
  const round = roundOf(view);
  if (!prep) return undefined;
  return {
    kind: "character_draft",
    round: prep.round ?? round?.round ?? 0,
    revision: prep.revision,
    draft,
  };
}

function changeDraft(
  view: LobbyView,
  change: (draft: CharacterDraft) => CharacterDraft,
): Command | undefined {
  return preparationCommand(view, change(draftOf(view)));
}

function jobRows(view: LobbyView): { key: string; name: string }[] {
  const jobs = view.state.jobs?.jobs ?? [];
  return jobs.map((job) => ({ key: job.key, name: job.name }));
}

function issueNotice(view: LobbyView): UiNode | null {
  const issue = preparationOf(view)?.issue ?? roundOf(view)?.fault;
  if (!issue) return null;
  return text("preparation/issue", ISSUE_LABELS[issue], ["lobby-notice"]);
}

function rankRows(view: LobbyView, editable: boolean): UiNode[] {
  const draft = draftOf(view);
  const names = new Map(jobRows(view).map((job) => [job.key, job.name]));
  return draft.ranked_jobs.map((job, index) => {
    const id = `preparation/ranked/${job}`;
    const label = names.get(job) ?? job;
    return row(id, [
      text(`${id}/number`, `${index + 1}`, ["lobby-rank-number"]),
      text(`${id}/name`, label, ["lobby-rank-name"]),
      row(`${id}/controls`, [
        press(`${id}/up`, S.tfs("ui.tray.mark_throw"), changeDraft(view, (current) => {
          const jobs = [...current.ranked_jobs];
          if (index > 0) [jobs[index - 1], jobs[index]] = [jobs[index], jobs[index - 1]];
          return { ...current, ranked_jobs: jobs };
        }) ?? (() => undefined), { label: S.tfs("ui.lobby.rank_up"), disabled: !editable || setupLocked(view) || index === 0, cls: ["lobby-rank-button"] }),
        press(`${id}/down`, S.tfs("ui.tray.mark_drop"), changeDraft(view, (current) => {
          const jobs = [...current.ranked_jobs];
          if (index + 1 < jobs.length) [jobs[index], jobs[index + 1]] = [jobs[index + 1], jobs[index]];
          return { ...current, ranked_jobs: jobs };
        }) ?? (() => undefined), { label: S.tfs("ui.lobby.rank_down"), disabled: !editable || setupLocked(view) || index + 1 >= draft.ranked_jobs.length, cls: ["lobby-rank-button"] }),
        press(`${id}/remove`, S.CLOSE_MARK, changeDraft(view, (current) => ({
          ...current,
          ranked_jobs: current.ranked_jobs.filter((_, choice) => choice !== index),
        })) ?? (() => undefined), { label: S.tfs("ui.lobby.rank_remove"), disabled: !editable || setupLocked(view), cls: ["lobby-rank-button"] }),
      ], { cls: ["lobby-rank-controls"] }),
    ], { cls: ["lobby-rank-row"] });
  });
}

function characterEditor(view: LobbyView): UiNode {
  const prep = preparationOf(view);
  const draft = draftOf(view);
  const editable = !!prep?.can_edit && !prep.ready && !starting(view);
  const jobs = jobRows(view);
  const ranked = new Set(draft.ranked_jobs);
  const addChoices = [
    { value: "", text: S.tfs("ui.lobby.rank_add") },
    ...jobs.filter((job) => !ranked.has(job.key)).map((job) => ({ value: job.key, text: job.name })),
  ];
  const fallback = prep?.fallback_job;
  const fallbackName = fallback
    ? jobs.find((job) => job.key === fallback)?.name ?? fallback
    : undefined;
  const fallbackValue = draft.fallback && fallback ? fallback : "__lobby__";
  const fallbackChoices = [
    { value: "__lobby__", text: S.tfs("ui.lobby.fallback_lobby") },
    ...(fallback ? [{ value: fallback, text: S.tfs("ui.lobby.fallback_job", { job: fallbackName }) }] : []),
  ];
  return column("preparation/editor", some(
    text("preparation/editor/title", S.tfs("ui.lobby.preparation.character"), ["lobby-section-title"]),
    text("preparation/editor/hint", S.tfs("ui.lobby.preparation.hint"), ["hint"]),
    row("preparation/name-row", [
      text("preparation/name-label", S.tfs("ui.lobby.preparation.name"), ["lobby-field-label"]),
      entry("preparation/name", draft.name, (value) => changeDraft(view, (current) => ({ ...current, name: value })), {
        label: S.tfs("ui.lobby.preparation.name"),
        disabled: !editable || setupLocked(view),
        debounceMs: 120,
        cls: ["lobby-name-entry"],
      }),
    ], { cls: ["lobby-field"] }),
    text("preparation/ranked-title", S.tfs("ui.lobby.preparation.ranked"), ["lobby-section-title"]),
    column("preparation/ranked", rankRows(view, editable), { cls: ["lobby-ranked"] }),
    draft.ranked_jobs.length
      ? null
      : text("preparation/ranked-empty", S.tfs("ui.lobby.preparation.ranked_empty"), ["hint"]),
    row("preparation/add-row", [
      text("preparation/add-label", S.tfs("ui.lobby.rank_add"), ["lobby-field-label"]),
      select("preparation/add", "", addChoices, (value) => {
        if (!value || ranked.has(value)) return undefined;
        return changeDraft(view, (current) => ({
          ...current,
          ranked_jobs: [...current.ranked_jobs, value],
        }));
      }, { disabled: !editable || setupLocked(view), cls: ["lobby-add-select"] }),
    ], { cls: ["lobby-field"] }),
    text("preparation/fallback-title", S.tfs("ui.lobby.preparation.fallback"), ["lobby-section-title"]),
    row("preparation/fallback-row", [
      select("preparation/fallback", fallbackValue, fallbackChoices, (value) => changeDraft(view, (current) => ({
        ...current,
        fallback: value !== "__lobby__" && !!fallback,
      })), { disabled: !editable || setupLocked(view), cls: ["lobby-fallback-select"] }),
    ], { cls: ["lobby-field"] }),
    issueNotice(view),
    preparationPending(view)
      ? text("preparation/pending", S.tfs("ui.lobby.preparation.updating"), ["lobby-pending"])
      : null,
    view.state.preparationStorage?.available === false
      ? text("preparation/storage-unavailable", S.tfs("ui.lobby.preparation.saving_unavailable"), ["lobby-notice"])
      : null,
  ), { cls: ["lobby-editor"] });
}

/** The chat owner supplies the OOC filter and persistent `chat` composer. */
function oocPanel(view: LobbyView): UiNode {
  const panels = chatPanel(view, { mode: "ooc", layout: "lobby" });
  const chat = panels[0];
  if (chat) return {
    ...chat,
    class: chat.class?.includes("lobby-ooc-screen")
      ? chat.class
      : [...(chat.class ?? []), "lobby-ooc-screen"],
    style: { ...(chat.style ?? {}), height: "100%", maxHeight: "100%", minHeight: 0 },
  };
  return panel("lobby-ooc", [text("lobby/ooc/empty", S.tfs("ui.comms.empty"), ["hint"])], {
    cls: ["pane", "lobby-ooc-screen"],
  });
}

function footer(view: LobbyView): UiNode[] {
  const round = roundOf(view);
  const prep = preparationOf(view);
  if (!round) return [];
  const phase = round.phase === "preparing"
    ? S.tfs("ui.lobby.phase.preparing")
    : round.phase === "playing"
      ? S.tfs("ui.lobby.phase.playing")
      : S.tfs("ui.lobby.phase.ending");
  const timer = starting(view)
    ? S.tfs("ui.lobby.starting")
    : round.remaining_seconds === null
    ? round.waiting
      ? S.tfs("ui.lobby.waiting")
      : S.tfs("ui.lobby.countdown_waiting")
    : S.tfs("ui.lobby.countdown", { seconds: round.remaining_seconds });
  return [
    row("lobby/status-footer", [
      text("lobby/status-footer/phase", phase, ["lobby-phase"]),
      text("lobby/status-footer/timer", timer, ["lobby-timer"]),
      ...(round.paused
        ? [text("lobby/status-footer/paused", S.tfs("ui.lobby.paused"), ["lobby-paused"])]
        : []),
    ], { cls: ["lobby-status-footer"] }),
    row("lobby/readiness-footer", [
      text("lobby/readiness-footer/ready", S.tfs("ui.lobby.ready_count", { ready: round.ready }), ["lobby-ready-count"]),
      text("lobby/readiness-footer/connected", S.tfs("ui.lobby.connected_count", { connected: round.connected }), ["lobby-connected-count"]),
      prep?.ready
        ? press("preparation/ready", S.tfs("ui.lobby.unready"), {
            kind: "ready", round: prep.round, revision: prep.revision, ready: false,
        }, { variant: "selected", disabled: setupLocked(view), cls: ["lobby-ready-button"] })
        : press("preparation/ready", S.tfs("ui.lobby.ready"), {
            kind: "ready", round: prep?.round ?? round.round, revision: prep?.revision ?? 0, ready: true,
          }, { variant: "primary", disabled: !prep?.can_ready || setupLocked(view), cls: ["lobby-ready-button"] }),
    ], { cls: ["lobby-readiness-footer"] }),
  ];
}

/** The bounded preparation shell: OOC owns the left column and setup the right. */
export function preparationPanels(view: GameplayView): UiNode[] {
  const lobby = view as LobbyView;
  return [panel("lobby-preparation", [
    oocPanel(lobby),
    screen("lobby-setup", {
      toolbar: [
        text("lobby/setup/title", S.tfs("ui.lobby.preparation.title"), ["titlebar-title"]),
        text("lobby/setup/round", S.tfs("ui.lobby.round", { round: roundOf(lobby)?.round ?? preparationOf(lobby)?.round ?? 0 }), ["lobby-round"]),
      ],
      body: [characterEditor(lobby)],
      footer: footer(lobby),
    }, { cls: ["pane", "lobby-setup-screen"] }),
  ], { cls: ["pane", "lobby-shell"] })];
}
