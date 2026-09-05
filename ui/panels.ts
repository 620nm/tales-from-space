import type { GameplayView } from "./model";
import type { UiNode } from "@lunatic/ui";
import { button, column, icon, input, pane, row, text } from "./view";

export function crewPanels(view: GameplayView): UiNode[] {
  const children: UiNode[] = [];
  const state = view.state ?? {};
  const jobs = state.jobs?.jobs;
  if (jobs)
    children.push(
      pane(
        "lobby",
        [
          text("lobby-title", "Charter crew manifest — choose a role"),
          ...jobs.map((job) =>
            button(
              `job/${job.key}`,
              `${job.name} · ${job.taken}${job.slots === null ? " aboard" : `/${job.slots}`}`,
              { kind: "join", job: job.key },
              job.slots !== null && job.taken >= job.slots,
            ),
          ),
        ],
        {
          position: "absolute",
          left: 24,
          top: 24,
          width: 360,
          maxHeight: 450,
        },
      ),
    );
  const body = state.bodyStatus;
  if (body && (!body.state.controllable || !body.state.animate))
    children.push(
      pane(
        "body-state",
        [
          text("body-label", body.state.label),
          ...(body.can_respawn
            ? [button("respawn", "Respawn", { kind: "respawn" })]
            : []),
        ],
        { position: "absolute", left: 24, top: 24, width: 360 },
      ),
    );
  return children;
}

export function chatPanel(view: GameplayView): UiNode[] {
  const children: UiNode[] = [];
  const chat = (view.log ?? [])
    .slice(-24)
    .map((line, index: number) =>
      text(
        `log/${index}`,
        `${line.channel ? `[${line.channel}] ` : ""}${line.name ? `${line.name}: ` : ""}${line.text}`,
      ),
    );
  children.push(
    pane(
      "chat-pane",
      [
        column("log", chat, { maxHeight: 180, overflow: "auto" }),
        ...(view.body
          ? [
              input("chat", "", (value) =>
                value.trim() ? { kind: "say", text: value } : undefined,
              ),
            ]
          : []),
      ],
      {
        position: "absolute",
        left: 14,
        bottom: 0,
        width: 390,
        maxHeight: 240,
      },
    ),
  );
  return children;
}

export function inspectionPanels(view: GameplayView): UiNode[] {
  const children: UiNode[] = [];
  const state = view.state;
  if (state.examine)
    children.push(
      pane(
        "examine",
        [
          row("examine-title", [
            icon("examine-icon", state.examine.sprite),
            text("examine-heading", state.examine.title),
            button("examine-close", "Close", {
              kind: "dismiss",
              panel: "examine",
            }),
          ]),
          ...state.examine.lines.map((line, index: number) =>
            text(
              `examine-line/${index}`,
              line.spans.map((span) => span.text).join(""),
            ),
          ),
        ],
        {
          position: "absolute",
          left: 14,
          top: 14,
          width: 340,
          maxHeight: 320,
        },
      ),
    );
  if (state.context)
    children.push(
      pane(
        "context",
        [
          text("context-title", "On this tile"),
          button("context-close", "Close", {
            kind: "dismiss",
            panel: "context",
          }),
          ...state.context.map((target, index: number) =>
            row(`context/${index}`, [
              icon(`context/${index}/icon`, target.sprite),
              button(`context/${index}/use`, target.name, {
                kind: "context",
                target: target.target,
              }),
            ]),
          ),
        ],
        {
          position: "absolute",
          left: 14,
          top: 24,
          width: 340,
          maxHeight: 320,
        },
      ),
    );
  return children;
}
