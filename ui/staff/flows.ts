import type { Json } from "@lunatic/ui";
import type { StaffCase, StaffRef, StaffSession } from "./model";
import type { StaffLocalState } from "./actions";
import {
  cachedCase,
  caseAnchorRefs,
  caseRef,
  queryJson,
  recordResponse,
  rememberRecordResponse,
  readRef as readRecordRef,
  responseCase,
  sameRef,
  uniqueRefs,
} from "./cases/records";
import { freezeReference, recordsRequest, staffRequest } from "./shared/actions";

type ObjectValue = Record<string, unknown>;
type ReadKind = "case" | "context";

interface PendingRead {
  kind: ReadKind;
  body: ObjectValue;
  bodyKey: string;
  requestId: string;
  retries: number;
  anchor?: StaffRef;
}

interface FlowState {
  roundId: string;
  openedCase: StaffRef | null;
  /** Apply the next opened case to the local workspace exactly once. */
  navigate: boolean;
  anchors: StaffRef[];
  anchorIndex: number;
  pending: PendingRead | null;
  createRequestId: string | null;
  acknowledged: Set<string>;
}

const MAX_ACKNOWLEDGED = 128;

let state: FlowState = fresh("");

function fresh(roundId: string): FlowState {
  return {
    roundId,
    openedCase: null,
    navigate: false,
    anchors: [],
    anchorIndex: 0,
    pending: null,
    createRequestId: null,
    acknowledged: new Set(),
  };
}

function flow(session: StaffSession): FlowState {
  if (state.roundId !== session.roundId) state = fresh(session.roundId);
  return state;
}

export function resetStaffFlows(): void {
  state = fresh("");
}

/** Start a case creation request and remember its envelope id for the reply. */
export function createCaseRequest(session: StaffSession, anchor: StaffRef): Json {
  const current = flow(session);
  current.pending = null;
  const frozen = freezeReference(anchor);
  const action = staffRequest(session, recordsRequest("create_case", {
    anchor: frozen,
    ...(anchor.label ? { label: anchor.label } : {}),
  }));
  const requestId = requestIdOf(action);
  current.createRequestId = requestId;
  return action;
}

/** A case selection has one bounded case query before context pages begin. */
export function openCaseRequest(session: StaffSession, item: StaffCase): Json {
  const reference = caseRef(session, item);
  if (!reference) return staffRequest(session, { kind: "query", query: queryJson("case", { case: item.reference, limit: 64 }) });
  const current = flow(session);
  beginOpening(current, reference);
  return issueRead(session, "case", { case: freezeReference(reference), limit: 64 });
}

/** The workspace applies this after `onView` has seen a created/opened case. */
export function applyFlowLocal(session: StaffSession, local: StaffLocalState): void {
  const current = flow(session);
  if (!current.openedCase || !current.navigate) return;
  local.workspace = "cases";
  local.selectedCaseId = current.openedCase.id;
  local.selectedRef = freezeReference(current.openedCase);
  local.recordFilter = null;
  current.navigate = false;
}

export function openedCaseRef(session: StaffSession): StaffRef | null {
  return flow(session).openedCase;
}

export function openedCase(session: StaffSession): StaffCase | null {
  const reference = openedCaseRef(session);
  if (!reference) return null;
  return session.cases.find((item) => sameRef(caseRef(session, item) ?? undefined, reference))
    ?? responseCase(session, reference)
    ?? cachedCase(session, reference)
    ?? emptyCase(reference);
}

/** Profile reads wait while a case create/open chain owns the response slot. */
export function caseFlowPending(session: StaffSession): boolean {
  const current = flow(session);
  return current.createRequestId !== null || current.pending !== null;
}

export const isCaseFlowPending = caseFlowPending;

/**
 * One response chain drives the case opening. Every context request uses only
 * the case's direct anchors; rows discovered in a context never become new
 * anchors. A pending read waits for its exact response envelope. Only a
 * server-denied bound or stale-revision response gets a bounded retry.
 */
export function staffViewAction(session: StaffSession | null): Json | undefined {
  if (!session) return undefined;
  const current = flow(session);
  rememberRecordResponse(session);
  const response = recordResponse(session);
  const result = objectValue(response?.result);
  const responseKey = response && responseIdentity(response);

  if (response && responseKey && !current.acknowledged.has(responseKey)) {
    const requestId = stringValue(response.request_id);
    if (result?.kind === "case_created" && requestId && current.createRequestId === requestId) {
      const reference = readCaseReference(result.case, session.roundId);
      if (reference) {
        acknowledge(current, responseKey);
        current.createRequestId = null;
        beginOpening(current, reference);
        return issueRead(session, "case", { case: freezeReference(reference), limit: 64 });
      }
    }
    const pending = current.pending;
    const matchesPending = !!pending
      && responseQueryKey(response) === pending.bodyKey
      && stringValue(response.request_id) === pending.requestId;
    if (matchesPending && pending) {
      acknowledge(current, responseKey);
      if (retryableReadError(response)) {
        if (pending.retries >= MAX_READ_RETRIES) {
          current.pending = null;
          return undefined;
        }
        return issueRead(session, pending.kind, pending.body, pending.anchor, pending.retries + 1);
      }
      // A response carrying another terminal error belongs to this read too:
      // stop the chain so the visible page controls remain available.
      if (response.error || readResponseKind(result) !== pending.kind) {
        current.pending = null;
        return undefined;
      }
      current.pending = null;
      if (pending.kind === "case") return continueCase(session, current, response);
      current.anchorIndex += 1;
      return nextContext(session, current);
    }
  }

  // Update frames do not invalidate a submitted read. The trusted host retains
  // staff Query updates until their exact response is available.
  return undefined;
}

function beginOpening(current: FlowState, reference: StaffRef): void {
  current.openedCase = freezeReference(reference);
  current.navigate = true;
  current.anchors = [];
  current.anchorIndex = 0;
  current.pending = null;
}

/** Keep replay protection bounded while retaining recent response envelopes. */
function acknowledge(current: FlowState, responseKey: string): void {
  current.acknowledged.delete(responseKey);
  current.acknowledged.add(responseKey);
  while (current.acknowledged.size > MAX_ACKNOWLEDGED) {
    const oldest = current.acknowledged.values().next().value;
    if (oldest === undefined) break;
    current.acknowledged.delete(oldest);
  }
}

function continueCase(session: StaffSession, current: FlowState, response: ObjectValue): Json | undefined {
  const reference = current.openedCase;
  if (!reference) return undefined;
  const item = responseCase(session, reference) ?? emptyCase(reference);
  // Read the canonical direct-anchor array only. Derived participants in a
  // Context result are evidence, never inputs for another Context request.
  current.anchors = uniqueRefs(caseAnchorRefs(session, item)).map(freezeReference);
  current.anchorIndex = 0;
  return nextContext(session, current);
}

function nextContext(session: StaffSession, current: FlowState): Json | undefined {
  const anchor = current.anchors[current.anchorIndex];
  if (!anchor) return undefined;
  return issueRead(session, "context", contextBody(anchor), anchor);
}

function contextBody(anchor: StaffRef): ObjectValue {
  return { anchor: freezeReference(anchor), limit: 64, op: "context" };
}

const MAX_READ_RETRIES = 3;

function issueRead(session: StaffSession, kind: ReadKind, body: ObjectValue, anchor?: StaffRef, retries = 0): Json {
  const query = { op: kind, ...body };
  const action = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  const current = flow(session);
  const bodyKey = canonical(query);
  const requestId = requestIdOf(action);
  if (!requestId) {
    current.pending = null;
    return action;
  }
  current.pending = {
    kind,
    body: query,
    bodyKey,
    requestId,
    retries,
    ...(anchor ? { anchor: freezeReference(anchor) } : {}),
  };
  return action;
}

function readCaseReference(value: unknown, round: string): StaffRef | null {
  const raw = objectValue(value);
  if (!raw) return null;
  const parsed = readRecordRef(raw, round);
  return parsed?.kind === "case" ? parsed : null;
}

function readResponseKind(result: ObjectValue | null): ReadKind | null {
  return result?.kind === "case" || result?.kind === "context" ? result.kind : null;
}

function responseQueryKey(response: ObjectValue): string {
  const query = objectValue(response.query);
  return query ? canonical(query) : "";
}

function retryableReadError(response: ObjectValue): boolean {
  const result = objectValue(response.result);
  return [response.error, result?.error, result?.code, result?.reason, result?.kind]
    .some((value) => retryableError(stringValue(value)));
}

function retryableError(value: string): boolean {
  const error = value.toLowerCase().replace(/[.\- ]/g, "_");
  return error === "bound"
    || error.endsWith("_bound")
    || error === "stale_revision"
    || error.endsWith("_stale_revision")
    || error === "revision_stale"
    || error.endsWith("_revision_stale");
}

function responseIdentity(response: ObjectValue): string {
  const id = stringValue(response.request_id);
  return id ? `request:${id}` : `response:${canonical(response)}`;
}

function requestIdOf(action: Json): string | null {
  const raw = objectValue(action);
  const request = objectValue(raw?.request);
  const id = request?.request_id;
  return typeof id === "string" ? id : null;
}

function objectValue(value: unknown): ObjectValue | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as ObjectValue : null;
}

function stringValue(value: unknown): string {
  return typeof value === "string" || typeof value === "number" ? String(value) : "";
}

function emptyCase(reference: StaffRef): StaffCase {
  return {
    reference: freezeReference(reference),
    id: reference.id,
    title: reference.label ?? reference.id,
    anchorHistory: [],
    addressedEvents: [],
    attachments: [],
    notes: [],
    statuses: [],
    outcomes: [],
  };
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value as ObjectValue).sort().map((key) => `${JSON.stringify(key)}:${canonical((value as ObjectValue)[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
