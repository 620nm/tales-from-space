// The chrome both of this pack's packages share: the kit drawn with the
// station's roles, the few kit classes whose geometry the roles cannot
// reach, and the typed controls and row vocabulary of this pack's own.
// A later rule for a class wins, so each restatement carries only what
// differs (docs/pack-ui/components.md).
import type { UiStyleRule } from "@lunatic/ui";
import { kitTheme, rule } from "@lunatic/ui";
import { roles } from "./roles";
import { edge, press, shade, sprite } from "./parts";
import {
  alpha, amber, amberLine, bright, dim, faint, field, ink, line, redLine, ruleLine, teal,
} from "./tokens";

export const kitRules: UiStyleRule[] = [
  ...kitTheme(roles),

  // A floating surface: one flat fill, one hairline, one soft drop.
  // A pane still scrolls its own overflow until its screens lay out
  // with `Scroll`; the kit's pane clips.
  rule("pane", {
    fontFamily: "sans", lineHeight: 1.4, minWidth: 200, maxWidth: 560,
    border: edge(line), boxShadow: shade, overflow: "auto",
  }),
  rule("titlebar", { gap: 8, paddingBottom: 5, marginBottom: 4, borderBottom: edge(ruleLine) }),
  rule("titlebar-title", { color: bright }),
  rule("section-title", { fontFamily: "mono", fontSize: 9, letterSpacing: 1, borderBottom: edge(ruleLine) }),
  rule("list-row", { paddingTop: 3, paddingBottom: 3, borderBottom: edge(ruleLine) }),
  rule("list-label", { fontSize: 11 }),
  rule("list-value", { fontSize: 11, fontWeight: 700 }),
  rule("notice", { color: teal, fontStyle: "normal" }),
  rule("cell", { paddingTop: 2, paddingBottom: 2 }),
  rule("card", { gap: 5, padding: 8, backgroundColor: alpha(field, 0.8), border: edge(ruleLine), borderRadius: 3 }),
  // Presses: a flat face, a hairline, a 2px corner; the accented ones
  // keep a darker edge than their ink.
  rule("btn", { paddingTop: 4, paddingBottom: 4, paddingLeft: 8, paddingRight: 8, ...press }),
  rule("btn", { color: bright }, "hover"),
  rule("btn-primary", { border: edge(amberLine) }),
  rule("btn-danger", { border: edge(redLine) }),
  rule("btn-selected", { backgroundColor: alpha(teal, 0.4) }, "hover"),
  // pointer-events inherits, so a press in a group the station shows
  // through hands every click to the floor unless it says otherwise.
  rule("choice-hit", press),

  // Typed fields: a well with the pane's frame colour.
  rule("entry", {
    flexGrow: 1, minWidth: 0, color: ink, fontSize: 11,
    backgroundColor: field, border: edge(line), borderRadius: 2,
    paddingTop: 4, paddingBottom: 4, paddingLeft: 6, paddingRight: 6,
    ...press,
  }),
  // Focus lights the edge in place: an outline over the rest border,
  // never a border a state turns on (docs/pack-ui/box-model.md).
  rule("entry", { outline: edge(teal), outlineOffset: -1 }, "focus"),
  rule("num", { flexGrow: 0, width: 88, textAlign: "right" }),
  rule("area", {
    width: "100%", minHeight: 220, color: ink,
    fontFamily: "mono", fontSize: 11, lineHeight: 1.45,
    backgroundColor: field, border: edge(line), borderRadius: 2,
    paddingTop: 5, paddingBottom: 5, paddingLeft: 6, paddingRight: 6,
    userSelect: "text",
    ...press,
  }),
  rule("area", { outline: edge(teal), outlineOffset: -1 }, "focus"),

  // Words and pictures in a row.
  rule("hint", { color: dim, fontSize: 11, fontStyle: "italic" }),
  rule("marker", { color: amber, fontSize: 11 }),
  rule("grow", { flexGrow: 1, minWidth: 0 }),
  rule("mono", { fontFamily: "mono" }),
  rule("icon", sprite),
  rule("fname", { flexGrow: 1, minWidth: 0, textAlign: "left" }),
  rule("fsize", { color: faint, fontSize: 10, flexShrink: 0 }),
  rule("pname", { color: ink, fontSize: 12, textAlign: "left" }),
  rule("stock", { color: dim, fontSize: 11, textAlign: "right" }),
  // Placement a node asks for by name rather than inline.
  rule("centered", { alignItems: "center", justifyContent: "center" }),
  rule("at-end", { marginLeft: "auto" }),
];
