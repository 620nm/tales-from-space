import type { Json, UiNode } from "@lunatic/ui";
import { Card, Field, Stack } from "@lunatic/ui";
import { localButton, staffRequest } from "../shared/actions";
import type { StaffCatalogEntry, StaffEntity, StaffProperty, StaffSession } from "../model";
import { nullablePropertyOptions, parsePropertyOption, propertyDraftValue, propertyOptionChoices, propertyOptionDraft, propertyOptionValue, type PropertyOption } from "../shared/property-values";
import { entry, press, select, text } from "../../view";
import * as S from "../strings";
import { currentSpawnPropertyDraftKey, liveState, rememberSpawnPropertyDraft, type SpawnKind } from "./state";
import { catalogEntryKey, catalogRequest, catalogRowsFor, isSpawnKind, MAX_CATALOG_ROWS, seedAmbientCatalog, SPAWN_KINDS, syncCatalog } from "./catalog";

interface SpawnProperty extends Omit<StaffProperty, "options"> {
  options?: PropertyOption[];
  min?: number;
  max?: number;
  step?: number;
}

interface SpawnOption {
  kind: string;
  id: string;
  label: string;
  row: StaffCatalogEntry;
  properties: SpawnProperty[];
}

export function spawnDrawer(session: StaffSession, target: StaffEntity | null): UiNode {
  const state = liveState(session);
  seedAmbientCatalog(session, state);
  syncCatalog(session, state);
  const kind = spawnKind(state);
  const prototypes = catalogRowsFor(state, kind).map(optionFrom);
  const option = prototypes.find((item) => item.id === state.spawnPrototype)
    ?? (state.catalog.pending ? undefined : prototypes[0]);
  if (option && state.spawnPrototype !== option.id) {
    state.spawnPrototype = option.id;
    state.spawnProperties = state.spawnPropertyDrafts[catalogEntryKey(option.row)] ?? seedProperties(option.properties);
    rememberSpawnPropertyDraft(state, catalogEntryKey(option.row), state.spawnProperties, catalogEntryKey(option.row));
  } else if (!option && !state.catalog.pending && state.spawnPrototype) {
    state.spawnPrototype = "";
    state.spawnProperties = "{}";
  }
  const spawnTarget = `${target?.ref.round ?? session.roundId}:${target?.ref.kind ?? "tile"}:${target?.ref.id ?? `${session.camera?.x ?? 0}:${session.camera?.y ?? 0}`}`;
  if (state.spawnTarget !== spawnTarget) {
    state.spawnTarget = spawnTarget;
    const pos = target?.pos ?? session.camera;
    if (pos) {
      state.spawnX = String(pos.x);
      state.spawnY = String(pos.y);
    }
  }
  const properties = option?.properties ?? [];
  const propertyValidation = option ? validateSpawnProperties(option.properties, state.spawnProperties) : undefined;
  const placeDisabled = !option || !propertyValidation?.valid;
  return Card("staff/live/spawn-drawer", [
    Stack("staff/live/spawn-drawer/head", [
      textNode("staff/live/spawn-drawer/title", S.SPAWN_DRAWER, "staff-section-title"),
      localButton("staff/live/spawn-drawer/close", S.CANCEL, () => { state.spawnOpen = false; }, { variant: "ghost" }),
    ], { cls: ["staff-drawer-head"], gap: 5, align: "center" }),
    textNode("staff/live/spawn-drawer/copy", S.PREPARE, "staff-muted"),
    Stack("staff/live/spawn/catalog-controls", [
      Field("staff/live/spawn/kind/field", S.KIND, select("staff/live/spawn/kind", kind, SPAWN_KINDS.map((value) => ({ value, text: kindLabel(value) })), (value) => {
        if (!isSpawnKind(value)) return undefined;
        retainActiveDraft(state);
        state.spawnKind = value;
        state.spawnPrototype = "";
        state.spawnProperties = "{}";
        return catalogRequest(session, state, value, state.catalog.search, null);
      }, { cls: ["staff-property-control"] })),
      Stack("staff/live/spawn/search-row", [
        entry("staff/live/spawn/search", state.catalog.draftSearch, (value) => { retainActiveDraft(state); return catalogRequest(session, state, kind, value, null); }, { label: S.SEARCH, submitOnly: true, cls: ["staff-catalog-search"] }),
        press("staff/live/spawn/search/submit", S.SEARCH, (event) => { retainActiveDraft(state); return catalogRequest(session, state, kind, event.value ?? state.catalog.draftSearch, null); }, { submit: "staff/live/spawn/search", variant: "primary" }),
      ], { cls: ["staff-catalog-search-row"], gap: 5, align: "center" }),
    ], { cls: ["staff-catalog-controls"], gap: 5 }),
    Field("staff/live/spawn/prototype/field", S.PROTOTYPE, select("staff/live/spawn/prototype", option?.id ?? "", prototypes.map((item) => ({ value: item.id, text: item.label })), (value) => {
      retainActiveDraft(state);
      state.spawnPrototype = value;
      const next = prototypes.find((item) => item.id === value);
      if (next) {
        state.spawnProperties = state.spawnPropertyDrafts[catalogEntryKey(next.row)] ?? seedProperties(next.properties);
        rememberSpawnPropertyDraft(state, catalogEntryKey(next.row), state.spawnProperties, catalogEntryKey(next.row));
      }
      return undefined;
    }, { cls: ["staff-property-control"], disabled: !prototypes.length })),
    state.catalog.pending
      ? textNode("staff/live/spawn/catalog/loading", S.CATALOG_LOADING, "staff-muted")
      : state.catalog.error
        ? textNode("staff/live/spawn/catalog/error", S.CATALOG_ERROR(state.catalog.error), "staff-warning")
        : !prototypes.length
          ? textNode("staff/live/spawn/catalog/empty", S.CATALOG_EMPTY, "staff-muted")
      : properties.length
      ? Stack("staff/live/spawn/properties", properties.map((property, index) => spawnProperty(`staff/live/spawn/property/${index}`, property, state, option)), { gap: 5 })
      : textNode("staff/live/spawn/no-properties", S.NO_PROPERTIES, "staff-muted"),
    state.catalog.items.length >= MAX_CATALOG_ROWS
      ? textNode("staff/live/spawn/catalog/limit", S.CATALOG_LIMIT, "staff-muted")
      : null,
    state.catalog.next
      ? press("staff/live/spawn/catalog/more", S.LOAD_MORE, () => { retainActiveDraft(state); return catalogRequest(session, state, state.catalog.category ?? kind, state.catalog.search, state.catalog.next); }, { variant: "ghost", disabled: state.catalog.pending, cls: ["staff-catalog-more"] })
      : null,
    Stack("staff/live/spawn/coords", [
      entry("staff/live/spawn/x", state.spawnX, (value) => { state.spawnX = value; return undefined; }, { label: S.X, cls: ["staff-coordinate"] }),
      entry("staff/live/spawn/y", state.spawnY, (value) => { state.spawnY = value; return undefined; }, { label: S.Y, cls: ["staff-coordinate"] }),
    ], { cls: ["staff-coordinate-row"], gap: 4 }),
    Stack("staff/live/spawn/actions", [
      ...(propertyValidation && !propertyValidation.valid
        ? [textNode("staff/live/spawn/place/reason", S.READ_ONLY, "staff-warning")]
        : []),
      press("staff/live/spawn/place", S.PLACE, () => {
        const current = currentSpawnOption(state);
        const validated = current ? validateSpawnProperties(current.properties, state.spawnProperties) : undefined;
        if (!current || !validated?.valid) return undefined;
        return staffRequest(session, {
          kind: "edit",
          edit: { kind: "spawn", spawnKind: current.kind as SpawnKind, prototype: current.id, pos: coordinates(state), properties: validated.properties },
        });
      }, { variant: "primary", disabled: placeDisabled }),
    ], { cls: ["staff-action-row"], gap: 5 }),
  ].filter(Boolean) as UiNode[], { cls: ["staff-spawn-drawer"] });
}

function spawnProperty(id: string, property: SpawnProperty, state: ReturnType<typeof liveState>, option: SpawnOption | undefined): UiNode {
  const current = propertyValue(state.spawnProperties, property);
  const callback = (next: string): Json | undefined => {
    if (property.editable === false || property.type === "enum" && !property.options?.length) return undefined;
    const values = readProperties(state.spawnProperties);
    const nextValue = typed(next, property);
    if (nextValue === undefined) return undefined;
    values[property.path] = nextValue;
    state.spawnProperties = JSON.stringify(values);
    if (option) rememberSpawnPropertyDraft(state, catalogEntryKey(option.row), state.spawnProperties, catalogEntryKey(option.row));
    return undefined;
  };
  let control: UiNode;
  const unavailableEnum = property.type === "enum" && !property.options?.length;
  if ((property.type === "enum" || property.type === "json") && property.options?.length) {
    control = select(id, current, propertyOptionChoices(property.options), callback, { cls: ["staff-property-control"], disabled: property.editable === false });
  } else if (property.type === "boolean") {
    control = select(id, current, [{ value: "false", text: S.FALSE }, { value: "true", text: S.TRUE }], callback, { cls: ["staff-property-control"], disabled: property.editable === false });
  } else {
    control = entry(id, current, callback, { cls: ["staff-property-control"], disabled: property.editable === false || unavailableEnum });
  }
  return Stack(`${id}/field`, [
    Field(`${id}/label`, property.label ?? property.path, control),
    property.unit ? textNode(`${id}/unit`, property.unit, "staff-unit") : null,
    property.editable === false || unavailableEnum ? textNode(`${id}/reason`, property.reason ?? S.READ_ONLY, "staff-muted") : null,
  ].filter(Boolean) as UiNode[], { cls: ["staff-property"], gap: 3 });
}

export function spawnKind(state: ReturnType<typeof liveState>): SpawnKind {
  if (isSpawnKind(state.spawnKind)) return state.spawnKind;
  const first = SPAWN_KINDS.find((kind) => catalogRowsFor(state, kind).length);
  const kind = first ?? SPAWN_KINDS[0] ?? "item";
  state.spawnKind = kind;
  return kind;
}

function optionFrom(row: StaffCatalogEntry): SpawnOption {
  return { kind: row.kind, id: row.prototype, label: row.name, row, properties: row.properties.map((item) => ({
    path: item.path,
    label: item.label,
    type: propertyType(item.type, item.value),
    value: item.value,
    nullable: item.nullable,
    options: item.options === undefined
      ? undefined
      : nullablePropertyOptions(item.nullable && item.type === "enum", item.options.map(parsePropertyOption).filter((value): value is PropertyOption => value !== undefined)),
    editable: item.editable,
    min: item.min,
    max: item.max,
    step: item.step,
  })) };
}

function propertyType(type: string, value: unknown): StaffProperty["type"] {
  if (type === "string") return "string";
  if (type === "integer") return "integer";
  if (type === "text") return "text";
  if (type === "enum") return "enum";
  if (type === "json") return "json";
  if (type === "reference") return "reference";
  if (type === "number" || typeof value === "number") return "number";
  if (type === "boolean" || typeof value === "boolean") return "boolean";
  return "text";
}

function kindLabel(kind: string): string {
  if (kind === "item") return S.KIND_ITEM;
  if (kind === "structure") return S.KIND_STRUCTURE;
  if (kind === "machine") return S.KIND_MACHINE;
  if (kind === "mob") return S.KIND_MOB;
  return S.KIND_BODY;
}

function seedProperties(properties: SpawnProperty[]): string {
  const values: Record<string, Json> = {};
  for (const property of properties) if (property.value !== undefined && property.value !== null) values[property.path] = property.value;
  return JSON.stringify(values);
}

function readProperties(raw: string): Record<string, Json> {
  try {
    const value = JSON.parse(raw);
    return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, Json> : {};
  } catch {
    return {};
  }
}

function propertyValue(raw: string, property: SpawnProperty): string {
  const values = readProperties(raw);
  const value = Object.hasOwn(values, property.path) ? values[property.path] : property.value;
  if (property.options?.length && (property.type === "enum" || property.type === "json")
    && (value === null || typeof value === "string" || typeof value === "number" || typeof value === "boolean")) {
    return propertyOptionDraft(value, property.options);
  }
  return value === undefined || value === null ? "" : String(value);
}

function typed(value: string, property: SpawnProperty): Json | undefined {
  if (property.type === "enum" && !property.options?.length) return undefined;
  if (property.options?.length && (property.type === "enum" || property.type === "json")) {
    return propertyDraftValue(property.type, value, property.options);
  }
  return propertyDraftValue(property.type, value, property.options);
}

interface SpawnPropertyValidation {
  valid: boolean;
  properties: string;
}

function validateSpawnProperties(properties: SpawnProperty[], raw: string): SpawnPropertyValidation {
  let parsed: Record<string, Json>;
  try {
    const value = JSON.parse(raw);
    if (!value || typeof value !== "object" || Array.isArray(value)) return { valid: false, properties: "{}" };
    parsed = value as Record<string, Json>;
  } catch {
    return { valid: false, properties: "{}" };
  }
  const descriptors = new Map(properties.map((property) => [property.path, property]));
  const values: Record<string, Json> = {};
  for (const [path, value] of Object.entries(parsed)) {
    const property = descriptors.get(path);
    if (!property || !propertyValueValid(property, value)
      || property.editable === false && !Object.is(property.value, value)) {
      return { valid: false, properties: "{}" };
    }
    values[path] = value;
  }
  return { valid: true, properties: JSON.stringify(values) };
}

function propertyValueValid(property: SpawnProperty, value: unknown): value is Json {
  if (property.type === "enum") {
    if (!property.options?.length || value === null && property.nullable !== true) return false;
    return property.options.some((option) => Object.is(propertyOptionValue(option), value));
  }
  if (value === null) return property.nullable === true;
  if (property.type === "boolean") return typeof value === "boolean";
  if (property.type === "integer") return typeof value === "number" && Number.isSafeInteger(value);
  if (property.type === "number") return typeof value === "number" && Number.isFinite(value);
  if (property.type === "json" && property.options?.length) {
    return property.options.some((option) => Object.is(propertyOptionValue(option), value));
  }
  if (property.type === "json") return isPrimitive(value);
  return typeof value === "string";
}

function isPrimitive(value: unknown): value is null | string | number | boolean {
  return value === null || typeof value === "string" || typeof value === "boolean"
    || typeof value === "number" && Number.isFinite(value);
}

function currentSpawnOption(state: ReturnType<typeof liveState>): SpawnOption | undefined {
  if (!isSpawnKind(state.spawnKind) || !state.spawnPrototype) return undefined;
  return catalogRowsFor(state, state.spawnKind).map(optionFrom).find((item) => item.id === state.spawnPrototype);
}

function retainActiveDraft(state: ReturnType<typeof liveState>): void {
  const key = currentSpawnPropertyDraftKey(state);
  if (key) rememberSpawnPropertyDraft(state, key, state.spawnProperties, key);
}

function coordinates(state: ReturnType<typeof liveState>): Json {
  const number = (value: string): number => Number.isFinite(Number(value)) ? Number(value) : 0;
  return { x: number(state.spawnX), y: number(state.spawnY) };
}

function textNode(id: string, value: unknown, cls?: string): UiNode {
  return text(id, value, cls ? [cls] : undefined);
}
