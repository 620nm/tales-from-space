// Compact rows for one disclosed control panel. The provider's kind ordering
// and contiguous toggle groups remain the layout; only structural refs select
// vocabulary-specific branches.
import type { UiLabel, UiNode } from "@lunatic/ui";
import { Choice, ChoiceGrid, Swatch } from "@lunatic/ui";
import type {
  DocumentIdentity,
  LabelRow,
  MatterBlock,
  Readout,
  Setpoint,
  Toggle,
} from "./document-model";
import { documentAction } from "./document-action";
import { readoutText, renderLabel, structuralLabelId } from "./labels";
import { matterBlock } from "./matter-block";
import { setpointDisplay } from "./documents-modules";
import { grayedCard, subjectBadge, subjectCard, unavailableBadge } from "./documents-choices";
import { bind, column, entry, press, row, text } from "./view";
import * as S from "./strings";

// Reserve room for kit descendants and control/group suffixes.
const ID_LIMIT = 88;

type Indexed<T> = { value: T; index: number };

interface ControlSection {
  identity: string;
  label?: UiLabel | null;
  readouts: Indexed<Readout>[];
  toggles: Indexed<Toggle>[];
  labels: Indexed<LabelRow>[];
  setpoints: Indexed<Setpoint>[];
  matter: Indexed<MatterBlock>[];
}

function stableJson(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  return `{${Object.entries(value as Record<string, unknown>)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, held]) => `${JSON.stringify(key)}:${stableJson(held)}`)
    .join(",")}}`;
}

/** Translated text may match across locales; UiLabel structure must not. */
function sectionIdentity(label: UiLabel | null | undefined): string {
  return label == null ? "" : stableJson(label);
}

function safePart(value: string, fallback: string): string {
  return /^[a-zA-Z0-9_:./-]+$/.test(value) && !value.includes("..") ? value : fallback;
}

function bounded(base: string, suffix: string, index: number): string {
  const candidate = `${base}/${suffix}`;
  return candidate.length <= ID_LIMIT && !suffix.startsWith("index/")
    ? candidate : `${base}/index/${index}`;
}

function sections(panel: {
  readouts: Readout[];
  toggles: Toggle[];
  labels: LabelRow[];
  setpoints: Setpoint[];
  matter?: MatterBlock[];
}): ControlSection[] {
  const out: ControlSection[] = [];
  const get = (label: UiLabel | null | undefined): ControlSection => {
    const identity = sectionIdentity(label);
    let found = out.find((section) => section.identity === identity);
    if (!found) {
      found = { identity, label, readouts: [], toggles: [], labels: [], setpoints: [], matter: [] };
      out.push(found);
    }
    return found;
  };
  panel.readouts.forEach((value, index) => get(value.section).readouts.push({ value, index }));
  panel.toggles.forEach((value, index) => get(value.section).toggles.push({ value, index }));
  panel.labels.forEach((value, index) => get(value.section).labels.push({ value, index }));
  panel.setpoints.forEach((value, index) => get(value.section).setpoints.push({ value, index }));
  (panel.matter ?? []).forEach((value, index) => get(value.section).matter.push({ value, index }));
  const primary = out.findIndex((section) => section.identity === "");
  if (primary > 0) out.unshift(...out.splice(primary, 1));
  return out;
}

function toneClass(tone: string | null | undefined): string | undefined {
  return tone === "on" || tone === "off" || tone === "idle" ? `tone-${tone}` : undefined;
}

function readoutNodes(id: string, readouts: Indexed<Readout>[]): UiNode[] {
  const plain = readouts.filter(({ value }) => !value.subject);
  const subjects = readouts.filter(({ value }) => value.subject);
  const out: UiNode[] = [];
  if (plain.length) {
    out.push(column(`${id}/readouts`, plain.map(({ value, index }) => {
      const tone = toneClass(value.tone);
      return column(`${id}/readouts/${index}`, [
        text(`${id}/readouts/${index}/label`, renderLabel(value.label), ["workspace-readout-label"]),
        text(`${id}/readouts/${index}/value`, readoutText(value.value), ["workspace-readout-value", ...(tone ? [tone] : [])]),
      ], { cls: ["workspace-readout-tile"] });
    }), { cls: ["workspace-readout-grid"] }));
  }
  if (subjects.length) {
    const cards = subjects.map(({ value, index }) => {
      const subject = value.subject!;
      const choiceId = `${id}/subjects/${index}`;
      return Choice(choiceId, {
        ...subjectCard(subject, value.label, undefined,
          structuralLabelId(value.label) === "link.member.hardwired"
            ? { ...subjectBadge(subject), text: S.tfs("ui.device.wired", { state: subjectBadge(subject).text }) }
            : undefined),
        selected: false,
        disabled: true,
      });
    });
    out.push(ChoiceGrid(`${id}/subjects`, cards, { min: 140 }));
  }
  return out;
}

function toggleKey(
  base: string,
  toggle: Toggle,
  index: number,
  all: Indexed<Toggle>[],
): string {
  const option = toggle.option == null ? "switch" : safePart(toggle.option, `option-${index}`);
  const same = all.filter(({ value }) => value.field === toggle.field && (value.option ?? "switch") === (toggle.option ?? "switch"));
  const suffix = `${safePart(toggle.field, `field-${index}`)}/${option}`;
  return bounded(base, same.length === 1 ? `toggle/${suffix}` : `toggle-index/${index}`, index);
}

function switchRow(id: string, doc: DocumentIdentity, toggle: Toggle, active: boolean): UiNode {
  const swatch = toggle.color ? Swatch(`${id}/swatch`, toggle.color) : null;
  const blocked = unavailableBadge(toggle);
  const caption = renderLabel(toggle.on ? toggle.on_text : toggle.off_text);
  return row(id, [
    ...(swatch ? [swatch] : []),
    text(`${id}/label`, renderLabel(toggle.label), ["workspace-control-label", "grow"]),
    ...(blocked ? [text(`${id}/unavailable`, blocked.text, ["workspace-control-value", "tone-off"])] : []),
    press(`${id}/press`, caption, documentAction(doc, "toggle", {
      field: toggle.field,
      ...(toggle.option == null ? {} : { option: toggle.option }),
    }), {
      disabled: !active || blocked != null,
      variant: toggle.on ? "selected" : "default",
      ...(toggle.icon ? { icon: toggle.icon } : {}),
      label: caption,
      cls: ["workspace-control-action"],
    }),
  ], { cls: ["workspace-control-row", "workspace-switch-row"] });
}

function choiceGroup(
  base: string,
  doc: DocumentIdentity,
  toggles: Indexed<Toggle>[],
  all: Indexed<Toggle>[],
  active: boolean,
  index: number,
): UiNode[] {
  const first = toggles[0];
  if (!first) return [];
  const firstId = toggleKey(base, first.value, first.index, all);
  const choices = toggles.map(({ value, index: sourceIndex }) => {
    const id = toggleKey(base, value, sourceIndex, all);
    const blocked = unavailableBadge(value);
    const metadata = value.subject ? subjectCard(value.subject, value.label, undefined, blocked) : {};
    return grayedCard(Choice(id, {
      label: metadata.label ?? renderLabel(value.label),
      ...(metadata.sprite ? { sprite: metadata.sprite } : value.icon ? { sprite: value.icon } : {}),
      ...(value.color ? { color: value.color } : {}),
      ...(metadata.detail ? { detail: metadata.detail } : blocked ? { detail: blocked.text } : {}),
      ...(metadata.badge ? { badge: metadata.badge } : {}),
      selected: value.on,
      ...(blocked ? {} : {
        event: bind(id, documentAction(doc, "toggle", {
          field: value.field,
          ...(value.option == null ? {} : { option: value.option }),
        })),
      }),
      disabled: !active || blocked != null,
    }), blocked);
  });
  const strip = choices.length <= 3
    ? row(`${firstId}/group/${index}`, choices, { cls: ["workspace-choice-strip"] })
    : { ...ChoiceGrid(`${firstId}/group/${index}`, choices, { min: 140 }), class: ["choice-grid", "workspace-choice-grid"] };
  return [
    ...(first.value.group == null ? [] : [text(`${firstId}/group/${index}/label`, first.value.group, ["workspace-control-group-label"])]),
    strip,
  ];
}

function toggleRows(base: string, doc: DocumentIdentity, toggles: Indexed<Toggle>[], active: boolean): UiNode[] {
  const out: UiNode[] = [];
  let cursor = 0;
  let group = 0;
  while (cursor < toggles.length) {
    const first = toggles[cursor]!;
    if (first.value.option == null) {
      out.push(switchRow(toggleKey(base, first.value, first.index, toggles), doc, first.value, active));
      cursor += 1;
      continue;
    }
    const groupIdentity = `${first.value.field}\u0000${first.value.group ?? ""}`;
    let end = cursor + 1;
    while (end < toggles.length) {
      const next = toggles[end]!.value;
      if (next.option == null || `${next.field}\u0000${next.group ?? ""}` !== groupIdentity) break;
      end += 1;
    }
    out.push(...choiceGroup(base, doc, toggles.slice(cursor, end), toggles, active, group));
    group += 1;
    cursor = end;
  }
  return out;
}

function labelRows(base: string, doc: DocumentIdentity, labels: Indexed<LabelRow>[], active: boolean): UiNode[] {
  return labels.map(({ value, index }) => {
    const suffix = value.row === "input" ? safePart(value.action, `input-${index}`) : `${value.row}-${index}`;
    const id = bounded(`${base}/label`, suffix, index);
    const rowLabel = renderLabel(value.label);
    const caption = text(`${id}/label`, rowLabel, ["workspace-control-label", "grow"]);
    if (value.row === "press") {
      const pressCaption = renderLabel(value.text);
      return row(id, [caption, press(`${id}/press`, pressCaption, documentAction(doc, "toggle", {
        field: value.field,
        ...(value.option == null ? {} : { option: value.option }),
      }), { disabled: !active || !value.enabled, label: pressCaption, cls: ["workspace-control-action"] })], { cls: ["workspace-control-row"] });
    }
    if (value.row === "input") {
      const box = `${id}/value`;
      const submitCaption = value.text ? renderLabel(value.text) : S.SET;
      return row(id, [caption, entry(box, "", () => undefined, {
        submitOnly: true,
        disabled: !active,
        label: rowLabel,
        cls: ["workspace-control-input"],
      }), press(`${id}/send`, submitCaption, (event) => documentAction(doc, "action", {
        action: value.action,
        value: [...(event.value ?? "")].slice(0, value.max_length ?? Number.MAX_SAFE_INTEGER).join(""),
      }), {
        submit: box,
        disabled: !active,
        ...(value.text ? { label: submitCaption } : {}),
        cls: ["workspace-control-action"],
      })], { cls: ["workspace-control-row"] });
    }
    return row(id, [caption, text(`${id}/word`, renderLabel(value.text), ["workspace-control-value"])], { cls: ["workspace-control-row"] });
  });
}

function setpointRow(base: string, doc: DocumentIdentity, point: Setpoint, sourceIndex: number, active: boolean, unique: boolean): UiNode {
  const key = bounded(`${base}/set`, unique ? safePart(point.field, `index/${sourceIndex}`) : `index/${sourceIndex}`, sourceIndex);
  const { spell, unit, stored, range } = setpointDisplay(point);
  const label = renderLabel(point.label);
  const step = point.step && point.step > 0 ? point.step : 1;
  const box = `${key}/value`;
  return row(key, [
    column(`${key}/description`, [
      text(`${key}/label`, label, ["workspace-control-label"]),
      ...(range === null ? [] : [text(`${key}/range`, range, ["workspace-control-range"])]),
    ], { cls: ["workspace-control-label-block"] }),
    row(`${key}/controls`, [
      press(`${key}/down`, S.LOWER, documentAction(doc, "set", { field: point.field, adjust: -step }), { disabled: !active, cls: ["workspace-control-step-button"] }),
      entry(box, spell(point.value), (value) => {
        const wanted = Number(value);
        return Number.isFinite(wanted) ? documentAction(doc, "set", { field: point.field, value: stored(wanted) }) : undefined;
      }, { cls: ["workspace-setpoint-input"], disabled: !active, label }),
      text(`${key}/unit`, unit, ["workspace-control-unit"]),
      press(`${key}/up`, S.RAISE, documentAction(doc, "set", { field: point.field, adjust: step }), { disabled: !active, cls: ["workspace-control-step-button"] }),
    ], { cls: ["workspace-setpoint-controls"] }),
  ], { cls: ["workspace-control-row", "workspace-setpoint-row"] });
}

function sectionRows(base: string, doc: DocumentIdentity, section: ControlSection, active: boolean): UiNode[] {
  const children: UiNode[] = [
    ...readoutNodes(base, section.readouts),
    ...toggleRows(base, doc, section.toggles, active),
    ...labelRows(base, doc, section.labels, active),
    ...section.setpoints.map(({ value, index }) => setpointRow(base, doc, value, index, active,
      section.setpoints.filter((other) => other.value.field === value.field).length === 1)),
    ...section.matter.map(({ value, index }) => matterBlock(`${base}/matter/${index}`, value)),
  ];
  if (!children.length) return [];
  return [column(base, [
    ...(section.label == null ? [] : [text(`${base}/title`, renderLabel(section.label), ["workspace-control-section-title"])]),
    ...children,
  ], { cls: ["workspace-control-section"] })];
}

export function controlPanelRows(
  id: string,
  doc: DocumentIdentity,
  panel: {
    readouts: Readout[];
    toggles: Toggle[];
    labels: LabelRow[];
    setpoints: Setpoint[];
    matter?: MatterBlock[];
  },
  active: boolean,
): UiNode[] {
  return sections(panel).flatMap((section, index) => sectionRows(`${id}/part/${index}`, doc, section, active));
}
