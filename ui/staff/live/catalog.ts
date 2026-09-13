import type { Json } from "@lunatic/ui";
import type { StaffCatalogEntry, StaffSession } from "../model";
import { staffRequest } from "../shared/actions";
import { nullablePropertyOptions, parsePropertyOption, type PropertyOption } from "../shared/property-values";
import type { LiveLocalState, SpawnCatalogState, SpawnKind } from "./state";

export const SPAWN_KINDS: SpawnKind[] = ["item", "structure", "machine", "mob", "body"];
const PAGE_LIMIT = 64;
const MAX_CACHED_PAGES = 24;
export const MAX_CATALOG_ROWS = PAGE_LIMIT * MAX_CACHED_PAGES;

export interface CatalogRequestOptions {
  preserveItems?: boolean;
}

/** Issue one native catalog query and retain its exact request identity. */
export function catalogRequest(
  session: StaffSession,
  state: LiveLocalState,
  category: SpawnKind | null,
  search: string,
  after: string | null = null,
  options: CatalogRequestOptions = {},
): Record<string, Json> {
  const normalizedSearch = search.trim();
  const query = { kind: "catalog", category, search: normalizedSearch, after, limit: PAGE_LIMIT };
  const action = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  const catalog = state.catalog;
  const cached = after === null ? catalog.pages[pageKey(category, normalizedSearch, null)] : undefined;
  catalog.category = category;
  catalog.search = normalizedSearch;
  catalog.draftSearch = normalizedSearch;
  catalog.after = after;
  catalog.next = cached?.next ?? (after === null ? null : catalog.next);
  catalog.items = cached ? boundedRows(cached.items, state) : after === null && !options.preserveItems ? [] : boundedRows(catalog.items, state);
  catalog.loaded = !!cached || (after !== null && catalog.loaded) || (after === null && options.preserveItems === true && catalog.loaded);
  catalog.pending = true;
  catalog.error = null;
  catalog.requestId = requestId(action);
  catalog.queryKey = canonical(query);
  return action as Record<string, Json>;
}

/** Make the ambient roster useful immediately without treating it as complete. */
export function seedAmbientCatalog(session: StaffSession, state: LiveLocalState): void {
  const catalog = state.catalog;
  if (catalog.seeded) return;
  catalog.seeded = true;
  const rows: StaffCatalogEntry[] = [];
  const roster = session.roster;
  if (roster) {
    const rawRoster = roster as Record<string, unknown>;
    for (const kind of SPAWN_KINDS) {
      const key = rosterKey(kind);
      const source = roster[key];
      if (Array.isArray(source)) {
        const categoryRows: StaffCatalogEntry[] = [];
        for (const value of source) {
          const row = catalogEntry(value, kind);
          if (row) {
            rows.push(row);
            categoryRows.push(row);
          }
        }
        if (rawRoster[`${key}_truncated`] !== true) {
          const pageItems = boundedRows(uniqueRows(categoryRows), state);
          catalog.pages[pageKey(kind, "", null)] = {
            items: pageItems,
            next: pageItems.length >= MAX_CATALOG_ROWS ? null : cursor(rawRoster[`${key}_next`]),
          };
        }
      }
    }
  }
  if (!catalog.items.length && rows.length) {
    catalog.items = boundedRows(uniqueRows(rows), state);
    catalog.loaded = true;
    const firstKind = SPAWN_KINDS.find((kind) => catalog.items.some((row) => row.kind === kind));
    catalog.next = firstKind ? catalog.pages[pageKey(firstKind, "", null)]?.next ?? null : null;
  }
}

/** Accept only a reply for the currently displayed query/page. */
export function syncCatalog(session: StaffSession, state: LiveLocalState): void {
  seedAmbientCatalog(session, state);
  const catalog = state.catalog;
  const response = session.records?.response;
  const responseId = response && typeof response.request_id === "string" ? response.request_id : "";
  if (!responseId || responseId !== catalog.requestId) return;
  const query = object(response?.query);
  if (!query || canonical(query) !== catalog.queryKey) return;
  const result = object(response?.result);
  const rows = result?.kind === "catalog" ? catalogRows(result.items) : null;
  if (rows) {
    const next = cursor(result!.next);
    const page = pageKey(catalog.category, catalog.search, catalog.after);
    const items = catalog.after === null ? boundedRows(rows, state) : boundedRows([...catalog.items, ...rows], state);
    const bounded = items.length >= MAX_CATALOG_ROWS;
    catalog.pages[page] = { items: rows.slice(0, MAX_CATALOG_ROWS), next: bounded ? null : next };
    prunePages(catalog);
    catalog.items = items;
    catalog.next = bounded ? null : next;
    catalog.loaded = true;
    catalog.error = typeof response?.error === "string" ? response.error : null;
  } else {
    catalog.error = typeof response?.error === "string" ? response.error : null;
  }
  catalog.pending = false;
  catalog.requestId = null;
  catalog.queryKey = null;
}

/** Rows for the selected spawn kind, including only exact kind/prototype keys. */
export function catalogRowsFor(state: LiveLocalState, kind: SpawnKind): StaffCatalogEntry[] {
  return state.catalog.items.filter((row) => row.kind === kind);
}

/** Return a stable identity for draft/property preservation. */
export function catalogEntryKey(row: Pick<StaffCatalogEntry, "kind" | "prototype">): string {
  return `${row.kind}:${row.prototype}`;
}

export function isSpawnKind(value: string): value is SpawnKind {
  return SPAWN_KINDS.includes(value as SpawnKind);
}

function rosterKey(kind: SpawnKind): "items" | "structures" | "machines" | "mobs" | "bodies" {
  if (kind === "item") return "items";
  if (kind === "structure") return "structures";
  if (kind === "machine") return "machines";
  if (kind === "mob") return "mobs";
  return "bodies";
}

function catalogRows(value: unknown): StaffCatalogEntry[] | null {
  return Array.isArray(value)
    ? uniqueRows(value.slice(0, PAGE_LIMIT).map((item) => catalogEntry(item)).filter((item): item is StaffCatalogEntry => !!item))
    : null;
}

function catalogEntry(value: unknown, expectedKind?: SpawnKind): StaffCatalogEntry | null {
  const raw = object(value);
  if (!raw) return null;
  const kind = typeof raw.kind === "string" && isSpawnKind(raw.kind) ? raw.kind : expectedKind;
  const prototype = typeof raw.prototype === "string" && raw.prototype.length ? raw.prototype : "";
  if (!kind || !prototype) return null;
  const name = typeof raw.name === "string" && raw.name.length ? raw.name : prototype;
  const defaults = object(raw.default_properties) ?? {};
  const properties = Array.isArray(raw.properties)
    ? raw.properties.map(property).filter((item): item is StaffCatalogEntry["properties"][number] => !!item)
    : [];
  return { kind, prototype, name, default_properties: defaults, properties };
}

function property(value: unknown): StaffCatalogEntry["properties"][number] | null {
  const raw = object(value);
  if (!raw || typeof raw.path !== "string" || !raw.path || typeof raw.label !== "string" || typeof raw.type !== "string" || typeof raw.editable !== "boolean") return null;
  const nullable = typeof raw.nullable === "boolean" ? raw.nullable : undefined;
  const options = Array.isArray(raw.options)
    ? nullablePropertyOptions(nullable && raw.type === "enum", raw.options.map(parsePropertyOption).filter((item): item is PropertyOption => item !== undefined))
    : undefined;
  return {
    path: raw.path,
    label: raw.label,
    type: raw.type,
    ...(raw.value === null || typeof raw.value === "string" || typeof raw.value === "number" || typeof raw.value === "boolean" ? { value: raw.value } : {}),
    ...(options === undefined ? {} : { options }),
    ...(nullable === undefined ? {} : { nullable }),
    editable: raw.editable,
    ...(typeof raw.min === "number" ? { min: raw.min } : {}),
    ...(typeof raw.max === "number" ? { max: raw.max } : {}),
    ...(typeof raw.step === "number" ? { step: raw.step } : {}),
  };
}

function uniqueRows(rows: StaffCatalogEntry[]): StaffCatalogEntry[] {
  const seen = new Set<string>();
  return rows.filter((row) => {
    const key = catalogEntryKey(row);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function boundedRows(rows: StaffCatalogEntry[], state: LiveLocalState): StaffCatalogEntry[] {
  const unique = uniqueRows(rows);
  if (unique.length <= MAX_CATALOG_ROWS) return unique;
  const activeKey = isSpawnKind(state.spawnKind) && state.spawnPrototype
    ? `${state.spawnKind}:${state.spawnPrototype}`
    : null;
  const active = activeKey ? unique.find((row) => `${row.kind}:${row.prototype}` === activeKey) : undefined;
  const retained = active ? unique.filter((row) => row !== active).slice(0, MAX_CATALOG_ROWS - 1) : unique.slice(0, MAX_CATALOG_ROWS);
  return active ? [...retained, active] : retained;
}

function prunePages(catalog: SpawnCatalogState): void {
  const keys = Object.keys(catalog.pages);
  while (keys.length > MAX_CACHED_PAGES) {
    const key = keys.shift();
    if (key) delete catalog.pages[key];
  }
}

function pageKey(category: SpawnKind | null, search: string, after: string | null): string {
  return `${category ?? "*"}\u0000${search}\u0000${after ?? ""}`;
}

function cursor(value: unknown): string | null {
  return typeof value === "string" && value.length ? value : null;
}

function requestId(action: Json): string | null {
  const raw = object(action);
  const request = object(raw?.request);
  return typeof request?.request_id === "string" ? request.request_id : null;
}

function object(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value as Record<string, unknown>).sort().map((key) => `${JSON.stringify(key)}:${canonical((value as Record<string, unknown>)[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
