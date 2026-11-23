import type { Json } from "@lunatic/ui";
import { refKey } from "../../refs";
import { objectValue, readRef } from "../cases/records";
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

interface FreezeSelection {
  target: StaffRef;
  acknowledged?: boolean;
  pending?: { id: string; on: boolean; command: Json };
  lastInspect?: string;
}

export interface LiveLocalState {
  freeze: FreezeSelection | null;
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
  freeze: null,
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

/** A Freeze receipt sets the caption until a fresh Inspect supplies the selected entity again. */
export function observeFreezeReply(session: StaffSession | null): void {
  if (!session?.active) {
    local.freeze = null;
    return;
  }
  const state = liveState(session);
  const selected = session.inspector;
  // The active view can omit the inspection between the edit and its receipt.
  if (selected) {
    if (!selected.found || selected.tombstone || selected.target.round !== session.roundId) {
      state.freeze = null;
      return;
    }
    if (!state.freeze || refKey(state.freeze.target) !== refKey(selected.target)) {
      state.freeze = { target: { ...selected.target } };
    }
  }
  const freeze = state.freeze;
  const reply = session.records?.response;
  if (!freeze || !reply) return;

  const query = objectValue(reply.query);
  if (freeze.pending && reply.request_id === freeze.pending.id) {
    const { on } = freeze.pending;
    delete freeze.pending;
    const echo = objectValue(query?.Freeze);
    // Large numeric echoes round in JS. The request id and selected reference retain exact identity.
    if (reply.error == null && reply.result?.action === "freeze" && echo?.on === on
      && (echo.target === freeze.target.id || echo.target === Number(freeze.target.id))) {
      freeze.acknowledged = on;
    }
  } else if (reply.error == null && query?.Inspect && reply.result?.found === true && reply.request_id !== freeze.lastInspect
    && refKey(readRef(objectValue(query.Inspect)?.target, session.roundId)) === refKey(freeze.target)
    && refKey(readRef(reply.result.target, session.roundId)) === refKey(freeze.target)) {
    freeze.lastInspect = reply.request_id;
    delete freeze.acknowledged;
  }
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
