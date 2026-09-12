// What the crew heard, and the one box a crewman answers with. The well
// is a darkened corner of the station rather than a framed panel: a
// screen whose toolbar is the tabs, whose body is the words and whose
// footer is the say line.
import type { UiNode } from "@lunatic/ui";
import { Tabs } from "@lunatic/ui";
import type { GameplayView, LogLine } from "./model";
import { bind, entry, press, row, screen, select, some, text, type Command } from "./view";
import * as S from "./strings";

type Tab = "all" | "local" | "radio" | "ooc" | "system";
type ComposeChannel = "local" | "ooc";
export interface ChatPanelOptions {
  mode?: "all" | "ooc";
  layout?: "hud" | "lobby";
  width?: number | string;
}
// Which words are showing, and how far the well is opened. Both are the
// viewer's own choice about a surface, so they live here and never
// travel: the server is not told which tab a crewman is reading.
let tab: Tab = "all";
let historyOpen = false;
let composeChannel: ComposeChannel = "local";

const TABS: [Tab, string][] = [
  ["all", S.CHAT_ALL],
  ["local", S.CHAT_LOCAL],
  ["radio", S.CHAT_RADIO],
  ["ooc", S.tfs("ui.comms.tab_ooc")],
  ["system", S.CHAT_SYSTEM],
];

/** OOC is an explicit line kind; channel and speaker fields classify the
 *  older local, radio and system records only. */
function belongs(line: LogLine | undefined, which: Tab): boolean {
  if (which === "all") return true;
  if (line?.kind === "ooc") return which === "ooc";
  if (line?.channel) return which === "radio";
  if (line?.name) return which === "local";
  return which === "system";
}

function logLine(line: LogLine | undefined, index: number): UiNode {
  const key = `log/${index}`;
  const ooc = line?.kind === "ooc";
  const system = !ooc && !line?.name && !line?.channel;
  return row(
    key,
    some(
      typeof line?.second === "number"
        ? text(`${key}/at`, S.stamp(line.second), ["stamp"])
        : null,
      !ooc && line?.channel ? text(`${key}/chan`, S.channel(line.channel), ["chan"]) : null,
      line?.name
        ? text(`${key}/who`, ooc
          ? S.tfs("ui.comms.ooc_speaker", { name: line.name })
          : S.speaker(line.name), ooc ? ["who", "who-ooc"] : line.channel ? ["who", "who-radio"] : ["who"])
        : null,
      text(`${key}/text`, line?.text ?? "", ooc ? ["said", "ooc"] : system ? ["said", "sys"] : ["said"]),
    ),
    { cls: ["line"] },
  );
}

function composer(view: GameplayView, mode: ChatPanelOptions["mode"]): UiNode[] {
  // Preparation may still disclose the generic body grammar while the
  // session has no admitted Mind. Only an identity with `you` can speak
  // locally; every other phase gets the bodyless OOC composer.
  const embodied = view.body && view.state.identity?.you != null;
  const ooc = mode === "ooc" || !embodied || composeChannel === "ooc";
  const send = (value: string): Command | undefined => {
    if (!value.trim()) return undefined;
    return ooc ? { kind: "ooc", text: value } : { kind: "say", text: value };
  };
  return [
    ...(embodied ? [
      text("chat-channel-label", S.tfs("ui.comms.channel_label"), ["chat-channel-label"]),
      select("chat-channel", composeChannel, [
        { value: "local", text: S.CHAT_LOCAL },
        { value: "ooc", text: S.tfs("ui.comms.tab_ooc") },
      ], (value) => {
        if (value === "local" || value === "ooc") composeChannel = value;
        return undefined;
      }, { cls: ["chat-channel"] }),
    ] : []),
    text("composer-label", ooc ? S.tfs("ui.comms.compose_ooc") : S.CHAT_SAY, ["composer-label"]),
    entry("chat", "", send, {
      label: ooc ? S.tfs("ui.comms.compose_ooc") : S.CHAT_SAY,
      submitOnly: true,
      clearOnSubmit: true,
      blurOnSubmit: true,
      cls: ["composer-entry"],
    }),
  ];
}

export function chatPanel(view: GameplayView, options: ChatPanelOptions = {}): UiNode[] {
  // Rows keep their place in the whole log, so a new line re-keys nothing.
  const activeTab = options.mode === "ooc" ? "ooc" : tab;
  const tabs = options.mode === "ooc" ? TABS.filter(([which]) => which === "ooc") : TABS;
  const heard = (view.log ?? []).map((line, index) => [line, index] as const).filter(([line]) => belongs(line, activeTab));
  const lines = heard.slice(-(historyOpen ? 200 : 40)).map(([line, index]) => logLine(line, index));
  const lobby = options.layout === "lobby";
  return [
    screen("chat-pane", {
      toolbar: [
        Tabs("chat-tabs", tabs.map(([which, label]) => ({
          key: which, label, selected: which === activeTab,
          event: bind(`chat-tab/${which}`, () => { tab = which; return undefined; }),
        }))),
        // The way into the whole record: a tab of its own, at the far end.
        press("chat-history", S.CHAT_HISTORY, () => { historyOpen = !historyOpen; return undefined; }, {
          variant: "ghost",
          cls: historyOpen ? ["tab", "tab-on", "at-end"] : ["tab", "at-end"],
        }),
      ],
      body: lines.length ? lines : [text("log-empty", S.CHAT_EMPTY, ["hint"])],
      footer: composer(view, options.mode),
    }, {
      cls: ["pane", "floating-chat", ...(lobby ? ["lobby-ooc-screen"] : []), ...(historyOpen ? ["chat-open"] : [])],
      style: {
        ...(options.width !== undefined ? { width: options.width } : lobby ? {} : { width: "100%" }),
        height: lobby ? "100%" : historyOpen ? 420 : 250,
        minHeight: lobby ? 0 : 205,
        maxHeight: "100%",
      },
    }),
  ];
}
