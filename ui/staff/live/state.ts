import type { StaffCatalogEntry, StaffRef, StaffSession } from "../model";

export type SpawnKind = "item" | "structure" | "machine" | "mob" | "body";

export interface CatalogPage {
  items: StaffCatalogEntry[];
  next: string | null;
}

export interface SpawnCatalogState {
  category: SpawnKind | null;
  search: string;
  draftSearch: string;
  after: string | null;
  next: string | null;
  items: StaffCatalogEntry[];
  requestId: string | null;
  queryKey: string | null;
  pending: boolean;
  loaded: boolean;
  seeded: boolean;
  error: string | null;
  pages: Record<string, CatalogPage>;
}

export interface LiveLocalState {
  roundId: string;
  inspector: "read" | "edit" | "audit";
  query: string;
  review: { verb: "kill" | "delete" | "gib"; target: StaffRef } | null;
  spawnOpen: boolean;
  spawnKind: string;
  spawnPrototype: string;
  spawnX: string;
  spawnY: string;
  editTarget: string;
  spawnTarget: string;
  spawnProperties: string;
  spawnPropertyDrafts: Record<string, string>;
  spawnPropertyDraftOrder: string[];
  catalog: SpawnCatalogState;
  inspectorOpen: boolean;
  drafts: Record<string, string>;
}

const fresh = (roundId: string): LiveLocalState => ({
  roundId,
  inspector: "read",
  query: "",
  review: null,
  spawnOpen: false,
  spawnKind: "",
  spawnPrototype: "",
  spawnX: "0",
  spawnY: "0",
  editTarget: "",
  spawnTarget: "",
  spawnProperties: "{}",
  spawnPropertyDrafts: {},
  spawnPropertyDraftOrder: [],
  catalog: {
    category: null, search: "", draftSearch: "", after: null, next: null,
    items: [], requestId: null, queryKey: null, pending: false, loaded: false, seeded: false,
    error: null, pages: {},
  },
  inspectorOpen: true,
  drafts: {},
});

let local = fresh("");

export function liveState(session: StaffSession): LiveLocalState {
  if (local.roundId !== session.roundId) local = fresh(session.roundId);
  return local;
}

export function selectedRef(session: StaffSession): StaffRef | null {
  const inspection = session.inspector;
  return inspection?.found ? inspection.target : null;
}

/** Keep draft eviction deterministic while retaining the currently edited prototype. */
export const MAX_SPAWN_PROPERTY_DRAFTS = 24;

export function rememberSpawnPropertyDraft(state: LiveLocalState, key: string, value: string, protectedKey?: string): void {
  state.spawnPropertyDrafts[key] = value;
  state.spawnPropertyDraftOrder = state.spawnPropertyDraftOrder.filter((item) => item !== key);
  state.spawnPropertyDraftOrder.push(key);
  while (state.spawnPropertyDraftOrder.length > MAX_SPAWN_PROPERTY_DRAFTS) {
    const oldestIndex = state.spawnPropertyDraftOrder.findIndex((item) => item !== protectedKey);
    if (oldestIndex < 0) break;
    const [oldest] = state.spawnPropertyDraftOrder.splice(oldestIndex, 1);
    if (oldest) delete state.spawnPropertyDrafts[oldest];
  }
}

export function currentSpawnPropertyDraftKey(state: LiveLocalState): string | null {
  return isSpawnKind(state.spawnKind) && state.spawnPrototype
    ? `${state.spawnKind}:${state.spawnPrototype}`
    : null;
}

function isSpawnKind(value: string): boolean {
  return value === "item" || value === "structure" || value === "machine" || value === "mob" || value === "body";
}
