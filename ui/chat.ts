// What the crew heard, and the one box a crewman answers with. The well
// is a darkened corner of the station rather than a framed panel: a
// screen whose toolbar is the tabs, whose body is the words and whose
// footer is the say line.
import type { UiNode } from "@lunatic/ui";
import { Tabs } from "@lunatic/ui";
import type { GameplayView, LogLine } from "./model";
import { bind, entry, press, row, screen, some, text } from "./view";
import * as S from "./strings";

type Tab = "all" | "local" | "radio" | "system";
// Which words are showing, and how far the well is opened. Both are the
// viewer's own choice about a surface, so they live here and never
// travel: the server is not told which tab a crewman is reading.
let tab: Tab = "all";
let historyOpen = false;

const TABS: [Tab, string][] = [
  ["all", S.CHAT_ALL],
  ["local", S.CHAT_LOCAL],
  ["radio", S.CHAT_RADIO],
  ["system", S.CHAT_SYSTEM],
];

/** A line is on a radio if it names a channel, spoken if it names only a
 *  speaker, and the station's own voice when it names neither. */
function belongs(line: LogLine | undefined, which: Tab): boolean {
  if (which === "all") return true;
  if (line?.channel) return which === "radio";
  if (line?.name) return which === "local";
  return which === "system";
}

function logLine(line: LogLine | undefined, index: number): UiNode {
  const key = `log/${index}`;
  const system = !line?.name && !line?.channel;
  return row(
    key,
    some(
      typeof line?.second === "number"
        ? text(`${key}/at`, S.stamp(line.second), ["stamp"])
        : null,
      line?.channel ? text(`${key}/chan`, S.channel(line.channel), ["chan"]) : null,
      line?.name
        ? text(`${key}/who`, S.speaker(line.name), line.channel ? ["who", "who-radio"] : ["who"])
        : null,
      text(`${key}/text`, line?.text ?? "", system ? ["said", "sys"] : ["said"]),
    ),
    { cls: ["line"] },
  );
}

export function chatPanel(view: GameplayView): UiNode[] {
  // Rows keep their place in the whole log, so a new line re-keys nothing.
  const heard = (view.log ?? []).map((line, index) => [line, index] as const).filter(([line]) => belongs(line, tab));
  const lines = heard.slice(-(historyOpen ? 200 : 40)).map(([line, index]) => logLine(line, index));
  return [
    screen("chat-pane", {
      toolbar: [
        Tabs("chat-tabs", TABS.map(([which, label]) => ({
          key: which, label, selected: which === tab,
          event: bind(`chat-tab/${which}`, () => { tab = which; return undefined; }),
        }))),
        // The way into the whole record: a tab of its own, at the far end.
        press("chat-history", S.CHAT_HISTORY, () => { historyOpen = !historyOpen; return undefined; }, {
          variant: "ghost",
          cls: historyOpen ? ["tab", "tab-on", "at-end"] : ["tab", "at-end"],
        }),
      ],
      body: lines.length ? lines : [text("log-empty", S.CHAT_EMPTY, ["hint"])],
      ...(view.body ? { footer: [
        text("composer-label", S.CHAT_SAY, ["composer-label"]),
        entry(
          "chat",
          "",
          (value) => (value.trim() ? { kind: "say", text: value } : undefined),
          { submitOnly: true, clearOnSubmit: true, blurOnSubmit: true, cls: ["composer-entry"] },
        ),
      ] } : {}),
    }, {
      cls: historyOpen ? ["pane", "floating-chat", "chat-open"] : ["pane", "floating-chat"],
      style: {
        position: "absolute",
        left: 18,
        bottom: 18,
        width: "32%",
        height: historyOpen ? "58%" : "28%",
        minWidth: 240,
        minHeight: 205,
        maxWidth: "50%",
        maxHeight: historyOpen ? 620 : 340,
      },
    }),
  ];
}
