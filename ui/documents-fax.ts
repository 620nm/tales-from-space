import type { UiNode } from "@lunatic/ui";
import { Dialog, Stack } from "@lunatic/ui";
import type { DocumentIdentity, FaxDirectoryEntry, FaxState, WritingFragment } from "./document-model";
import { scriptAction } from "./document-action";
import { fragmentList, sliceUtf8, writingPreview } from "./writing-text";
import { entry, press, row, text } from "./view";
import * as S from "./strings";

const PAGE_SIZE = 32;
const directoryOf = (state: FaxState): FaxDirectoryEntry[] =>
  Array.isArray(state.directory) ? state.directory.slice(0, PAGE_SIZE) : [];
const loadedOf = (state: FaxState): WritingFragment[] =>
  fragmentList(state.loadedpaper);

function status(id: string, state: FaxState): UiNode {
  return row(id, [
    text(`${id}/power`, S.tfs("ui.fax.power", { state: state.powered ? S.tfs("ui.fax.on") : S.tfs("ui.fax.off") })),
    text(`${id}/network`, S.tfs("ui.fax.network", { value: state.network ?? "" }), ["hint"]),
    text(`${id}/address`, S.tfs("ui.fax.address", { value: state.address ?? "" }), ["hint"]),
    text(`${id}/name`, S.tfs("ui.fax.name", { value: state.name ?? "" }), ["hint"]),
  ], { cls: ["fax-identity"] });
}

function controls(id: string, doc: DocumentIdentity, state: FaxState, active: boolean): UiNode {
  const advertiseAction = "advertise";
  const nameAction = "name";
  const toggle = (field: string, action: string, value: boolean, label: string) => press(
    `${id}/${field}`, label,
    scriptAction(doc, action, value ? "off" : "on"),
    { variant: value ? "selected" : "ghost", disabled: !active },
  );
  return row(id, [
    toggle("advertise", advertiseAction, state.advertised === true, S.tfs("ui.fax.advertise")),
    entry(`${id}/name`, state.name ?? "", (value) => scriptAction(doc, nameAction, sliceUtf8(value, 64)), {
      submitOnly: true, disabled: !active, label: S.tfs("ui.fax.name_label"), cls: ["fax-name-entry"],
    }),
    press(`${id}/name/set`, S.tfs("ui.fax.name_set"), (event) =>
      scriptAction(doc, nameAction, sliceUtf8(event.value ?? state.name ?? "", 64)), {
      submit: `${id}/name`, disabled: !active,
    }),
    text(`${id}/toner`, S.tfs("ui.fax.toner", { value: Math.max(0, state.toner ?? 0) }), ["fax-count"]),
    text(`${id}/paper`, S.tfs("ui.fax.paper", { value: Math.max(0, state.paper ?? 0) }), ["fax-count"]),
    press(`${id}/eject`, S.tfs("ui.fax.eject"), scriptAction(doc, "eject"), {
      disabled: !active || !!state.busy,
    }),
  ], { cls: ["fax-controls"] });
}

function directory(id: string, doc: DocumentIdentity, state: FaxState, active: boolean): UiNode {
  const entries = directoryOf(state);
  const pageAction = "page";
  const page = Math.max(0, Math.min(31, Math.floor(state.directory_page ?? 0)));
  const hasNext = state.directory_more === true;
  const pages = hasNext ? page + 2 : page + 1;
  const visible = entries.slice(0, PAGE_SIZE);
  const rows = visible.map((entry, index) => {
    const target = entry.id ?? entry.address ?? entry.name ?? "";
    const selected = target && target === state.target;
    return row(`${id}/entry/${page * PAGE_SIZE + index}`, [
      text(`${id}/entry/${page * PAGE_SIZE + index}/name`, entry.name ?? entry.address ?? "", ["fax-directory-name"]),
      press(`${id}/entry/${page * PAGE_SIZE + index}/target`, selected ? S.tfs("ui.fax.selected") : S.tfs("ui.fax.target"),
        scriptAction(doc, "confirm", sliceUtf8(target, 64)), { variant: selected ? "selected" : "ghost", disabled: !active || !target, cls: ["fax-directory-target"] }),
    ], { cls: ["fax-directory-row"] });
  });
  const nav = row(`${id}/nav`, [
    press(`${id}/previous`, S.tfs("ui.fax.previous"), scriptAction(doc, pageAction, String(page - 1)), { disabled: !active || page === 0, cls: ["fax-directory-previous"] }),
    text(`${id}/page`, S.tfs("ui.fax.page", { page: page + 1, pages }), ["hint", "fax-directory-page"]),
    press(`${id}/next`, S.tfs("ui.fax.next"), scriptAction(doc, pageAction, String(page + 1)), { disabled: !active || !hasNext || page >= 31, cls: ["fax-directory-next"] }),
  ], { cls: ["fax-directory-nav"] });
  return Stack(id, [text(`${id}/title`, S.tfs("ui.fax.directory"), ["paper-label"]), ...rows, nav,
  ], { dir: "column", cls: ["fax-directory"] });
}

export function faxBody(id: string, doc: DocumentIdentity, state: FaxState, active: boolean): UiNode[] {
  const loaded = loadedOf(state);
  const target = state.target ?? "";
  const confirmAction = "confirm";
  const cancelAction = "cancel";
  const sendAction = "send";
  const confirming = state.confirming === true && target.length > 0 && !state.busy;
  const send = press(`${id}/send`, S.tfs("ui.fax.send"), scriptAction(doc, confirmAction, sliceUtf8(target, 64)), {
    variant: "primary", disabled: !active || !target.length || !!state.busy,
  });
  const overlay = state.refusal ? text(`${id}/refusal`, state.refusal, ["notice"]) : null;
  const dialog = confirming ? Dialog(`${id}/confirm`, {
    title: S.tfs("ui.fax.confirm_title"),
    body: [text(`${id}/confirm/target`, S.tfs("ui.fax.confirm_target", { target }))],
    actions: [
      press(`${id}/confirm/cancel`, S.tfs("ui.fax.cancel"), scriptAction(doc, cancelAction), { variant: "ghost" }),
      press(`${id}/confirm/send`, S.tfs("ui.fax.confirm_send"), scriptAction(doc, sendAction, sliceUtf8(target, 64)), { variant: "primary", disabled: !active }),
    ],
  }, { dismissEvent: `${id}/confirm/cancel`, dismissLabel: S.tfs("ui.fax.cancel") }) : null;
  return [
    status(`${id}/identity`, state),
    controls(`${id}/controls`, doc, state, active),
    row(`${id}/content`, [
      Stack(`${id}/loaded`, loaded.length ? writingPreview(`${id}/loaded`, loaded) : [text(`${id}/loaded/empty`, S.tfs("ui.fax.empty"), ["hint"])], {
        cls: ["fax-paper"], style: { width: "44%", maxHeight: 300 },
      }),
      Stack(`${id}/directory-side`, [directory(`${id}/directory`, doc, state, active), send], { dir: "column", cls: ["fax-directory-side"], style: { width: "51%" } }),
    ], { cls: ["fax-body"] }),
    ...(state.busy ? [text(`${id}/busy`, S.tfs("ui.fax.busy"), ["notice"])] : []),
    ...(state.progress !== undefined ? [{ id: `${id}/progress`, type: "progress" as const, value: String(Math.max(0, Math.min(1, state.progress))) }] : []),
    ...(overlay ? [overlay] : []),
    ...(dialog ? [dialog] : []),
  ];
}
