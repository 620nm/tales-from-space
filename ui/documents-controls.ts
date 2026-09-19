// Reachable device cards in a Controls workspace. Each card owns only the
// device identity and chrome; its rows stay in documents-control-rows.ts.
import type { UiNode } from "@lunatic/ui";
import { Gauge } from "@lunatic/ui";
import type { ControlPanel, DocumentIdentity, ModuleState } from "./document-model";
import { labelId, labelText } from "./labels";
import { controlPanelRows } from "./documents-control-rows";
import { column, icon, row, some, text } from "./view";
import * as S from "./strings";

const PANEL_ID_LIMIT = 52;

function addressPart(address: string, index: number): string {
  return /^[a-zA-Z0-9_:.-]{1,64}$/.test(address) && !address.includes("..")
    ? address
    : `index/${index}`;
}

function panelStatus(id: string, panel: ControlPanel): UiNode | null {
  if (panel.online === undefined) return null;
  if (panel.online === true)
    return text(`${id}/status`, S.tfs("module.link.state.online"), ["workspace-control-status", "tone-on"]);
  if (panel.online === false)
    return text(`${id}/status`, S.tfs("ui.device.offline"), ["workspace-control-status", "tone-off"]);
  return text(`${id}/status`, S.tfs("ui.device.gone"), ["workspace-control-status", "workspace-control-status-gone"]);
}

function controlCard(
  id: string,
  doc: DocumentIdentity,
  panel: ControlPanel,
  active: boolean,
  index: number,
  unique: boolean,
): UiNode {
  const address = addressPart(panel.address, index);
  const prefix = `${id}/controls/`;
  const key = unique && `${prefix}${address}`.length <= PANEL_ID_LIMIT ? `${prefix}${address}` : `${prefix}index/${index}`;
  const panelActive = active && panel.online !== false && panel.online !== null;
  const sprite = icon(`${key}/sprite`, panel.sprite, panel.name, ["workspace-control-icon"]);
  const status = panelStatus(key, panel);
  const identity = column(`${key}/identity`, [
    text(`${key}/name`, panel.name, ["workspace-control-name"]),
    row(`${key}/address`, [
      text(`${key}/address/value`, panel.address, ["workspace-control-address"]),
      ...(status ? [status] : []),
    ], { cls: ["workspace-control-address-row"] }),
  ], { cls: ["workspace-control-identity"] });
  const children: UiNode[] = [
    row(`${key}/header`, some(sprite, identity), { cls: ["workspace-control-header"] }),
    ...(panel.gauge === null || panel.gauge === undefined ? [] : [Gauge(`${key}/gauge`, panel.gauge)]),
    ...(!panelActive ? [text(`${key}/disabled`, S.tfs("ui.document.unavailable"), ["workspace-control-disabled"])] : []),
    ...(panel.notice === null || panel.notice === undefined ? [] : [text(`${key}/notice`, labelText(panel.notice), ["workspace-control-notice"])]),
    ...controlPanelRows(`${key}/details`, doc, panel, panelActive),
  ];
  return column(key, children, { cls: ["workspace-control-card"] });
}

function reachDisclosure(id: string, state: Partial<ModuleState>): UiNode[] {
  return (state.labels ?? []).flatMap((entry, index) =>
    entry.row === "word" && labelId(entry.label) === "reach.reach"
      ? [row(`${id}/controls/reach/${index}`, [
          text(`${id}/controls/reach/${index}/label`, labelText(entry.label), ["workspace-control-label", "grow"]),
          text(`${id}/controls/reach/${index}/value`, labelText(entry.text), ["workspace-control-value"]),
        ], { cls: ["workspace-control-row", "workspace-control-disclosure"] })]
      : [],
  );
}

/** Draw only child panels. The owning document renders its own module rows in Details. */
export function controlWorkspace(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode[] {
  const panels = state.control_panels;
  if (panels === undefined) return [];
  const disclosure = reachDisclosure(id, state);
  if (!panels.length)
    return [...disclosure, text(`${id}/controls/empty`, S.tfs("ui.workspace.controls_empty"), ["hint"] )];
  return [...disclosure, row(`${id}/controls/grid`, panels.map((panel, index) => controlCard(id, doc, panel, active, index,
    panels.filter((other) => other.address === panel.address).length === 1)), {
    cls: ["workspace-control-grid"],
  })];
}
