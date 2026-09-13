import type { Json } from "@lunatic/ui";
import type { StaffRef, StaffSession } from "../model";
import { isProfileId } from "../model";
import { conversationQuery, objectValue, profileQuery, readRef, recordResponse, refKey, sameRef, stringValue } from "../cases/records";
import { caseFlowPending } from "../flows";
import { freezeReference, recordsRequest, staffRequest } from "../shared/actions";
import { resetProfileCaches, seedConversation, rememberConversationResponse, rememberProfileResponse } from "./cache";

type ObjectValue = Record<string, unknown>;
type WriteOp = "warning" | "profile_note" | "conversation" | "message";
type ReadKind = "profile" | "conversation";

interface PendingRead {
  kind: ReadKind;
  body: ObjectValue;
  bodyKey: string;
  requestId: string | null;
  retries: number;
}

interface PendingWrite {
  op: WriteOp;
  body: ObjectValue;
  bodyKey: string;
  requestId: string;
  account: StaffRef;
  conversation?: StaffRef;
  draftKey?: string;
  submittedValue?: string;
  read: PendingRead | null;
}

interface ProfileFlowState {
  roundId: string;
  write: PendingWrite | null;
  displayed: { account: StaffRef; conversation: StaffRef | null } | null;
  incoming: Map<string, IncomingRefresh>;
  seenUpdates: Set<string>;
}

const MAX_READ_RETRIES = 3;
const MAX_INCOMING_REFRESHES = 64;
const MAX_SEEN_UPDATES = 128;

interface IncomingRefresh {
  account: StaffRef;
  conversation: StaffRef;
  latestChange: StaffRef;
  latestChangeKey: string;
  sentChangeKey: string | null;
  kind: ReadKind;
  body: ObjectValue | null;
  bodyKey: string;
  requestId: string | null;
  retries: number;
  needsConversation: boolean;
}

let state: ProfileFlowState = freshFlow("");

function flow(session: StaffSession): ProfileFlowState {
  if (state.roundId !== session.roundId) state = freshFlow(session.roundId);
  return state;
}

function freshFlow(roundId: string): ProfileFlowState {
  return { roundId, write: null, displayed: null, incoming: new Map(), seenUpdates: new Set() };
}

export function resetProfileFlows(): void {
  state = freshFlow("");
}

/** The profile inspector calls this once at the start of each render. */
export function beginProfileRender(session: StaffSession): void {
  flow(session).displayed = null;
}

/** Remember which account the current inspector actually displays. */
export function observeDisplayedProfile(session: StaffSession, account: StaffRef): void {
  const current = flow(session);
  const target = validAccount(account, session.roundId);
  if (!target) return;
  for (const [key, pending] of current.incoming) {
    if (!sameRef(pending.account, target)) current.incoming.delete(key);
  }
  if (!current.displayed || !sameRef(current.displayed.account, target)) {
    current.displayed = { account: freezeReference(target), conversation: null };
  }
}

/** Bind the visible conversation, including an explicit empty state. */
export function observeDisplayedConversation(session: StaffSession, account: StaffRef, conversation: StaffRef | null): void {
  observeDisplayedProfile(session, account);
  const current = flow(session);
  const displayed = current.displayed;
  if (!displayed) return;
  const target = conversation && validConversation(conversation, session.roundId);
  displayed.conversation = target ? freezeReference(target) : null;
  if (!target) return;
  const pending = current.incoming.get(refKey(target));
  if (pending && sameRef(pending.account, displayed.account)) {
    pending.needsConversation = true;
    if (!pending.requestId) pending.kind = "conversation";
  }
}

/** Start a staff profile write; its request id is the only success authority. */
export function profileWriteRequest(
  session: StaffSession,
  op: WriteOp,
  fields: Record<string, Json>,
  account: StaffRef,
  draftKey?: string,
  submittedValue?: string,
): Json {
  const target = validAccount(account, session.roundId);
  const body = { op, ...fields } as ObjectValue;
  const action = staffRequest(session, recordsRequest(op, fields));
  const requestId = requestIdOf(action);
  const current = flow(session);
  if (!target || !requestId) {
    current.write = null;
    return action;
  }
  const conversation = op === "message" ? validConversation(fields.conversation, session.roundId) : undefined;
  if (op === "message" && !conversation) {
    current.write = null;
    return action;
  }
  current.write = {
    op, body, bodyKey: canonical(body), requestId, account: target,
    ...(conversation ? { conversation } : {}), ...(draftKey ? { draftKey } : {}),
    ...(submittedValue === undefined ? {} : { submittedValue }), read: null,
  };
  return action;
}

export function warningRequest(session: StaffSession, account: StaffRef, text: string, draftKey?: string): Json {
  return profileWriteRequest(session, "warning", { target: freezeReference(account), text }, account, draftKey, text);
}

export function profileNoteRequest(session: StaffSession, account: StaffRef, text: string, draftKey?: string): Json {
  return profileWriteRequest(session, "profile_note", { target: freezeReference(account), text }, account, draftKey, text);
}

export function conversationRequest(session: StaffSession, account: StaffRef): Json {
  return profileWriteRequest(session, "conversation", { account: freezeReference(account) }, account);
}

export function messageRequest(session: StaffSession, account: StaffRef, conversation: StaffRef, body: string, draftKey?: string): Json {
  return profileWriteRequest(session, "message", { conversation: freezeReference(conversation), body }, account, draftKey, body);
}

/** Profile reads stay behind the case chain, including a queued case read. */
export function profileViewAction(session: StaffSession | null): Json | undefined {
  if (!session || !session.allowed) {
    resetProfileFlows();
    resetProfileCaches();
    return undefined;
  }
  rememberProfileResponse(session);
  rememberConversationResponse(session);
  const current = flow(session);
  observeContactUpdates(session, current);
  if (!current.displayed) {
    current.incoming.clear();
    current.seenUpdates.clear();
  }
  const response = recordResponse(session);
  if (current.write) consumeResponse(session, current, response);
  if (current.write) {
    const read = current.write.read;
    if (!read || caseFlowPending(session) || read.requestId) return undefined;
    return issueRead(session, current.write, read);
  }
  if (caseFlowPending(session)) return undefined;
  return incomingAction(session, current, response);
}

function observeContactUpdates(session: StaffSession, current: ProfileFlowState): void {
  const displayed = current.displayed;
  if (!displayed || !Array.isArray(session.contact_updates)) return;
  const latest = new Map<string, { account: StaffRef; conversation: StaffRef; change: StaffRef }>();
  for (const value of session.contact_updates.slice(0, MAX_INCOMING_REFRESHES)) {
    const row = objectValue(value);
    const account = validAccount(row?.account, session.roundId);
    const conversation = validConversation(row?.conversation, session.roundId);
    const change = readRef(row?.change, session.roundId);
    if (!account || !conversation || !change) continue;
    latest.set(refKey(conversation), { account, conversation, change });
  }
  for (const update of latest.values()) {
    if (!sameRef(update.account, displayed.account)) continue;
    const updateKey = `${refKey(update.account)}\u0000${refKey(update.conversation)}\u0000${refKey(update.change)}`;
    if (current.seenUpdates.has(updateKey)) continue;
    rememberUpdate(current.seenUpdates, updateKey);
    queueIncoming(current, update, !!displayed.conversation && sameRef(displayed.conversation, update.conversation));
  }
}

function rememberUpdate(seen: Set<string>, key: string): void {
  seen.delete(key);
  seen.add(key);
  while (seen.size > MAX_SEEN_UPDATES) {
    const oldest = seen.values().next().value;
    if (oldest === undefined) break;
    seen.delete(oldest);
  }
}

function queueIncoming(
  current: ProfileFlowState,
  update: { account: StaffRef; conversation: StaffRef; change: StaffRef },
  conversationVisible: boolean,
): void {
  const key = refKey(update.conversation);
  const changeKey = refKey(update.change);
  const existing = current.incoming.get(key);
  if (existing && !sameRef(existing.account, update.account)) current.incoming.delete(key);
  const pending = current.incoming.get(key);
  if (pending) {
    if (pending.latestChangeKey === changeKey) return;
    pending.latestChange = freezeReference(update.change);
    pending.latestChangeKey = changeKey;
    if (conversationVisible) pending.needsConversation = true;
    if (!pending.requestId) pending.kind = pending.needsConversation ? "conversation" : "profile";
    touchIncoming(current.incoming, key, pending);
    return;
  }
  const created: IncomingRefresh = {
    account: freezeReference(update.account),
    conversation: freezeReference(update.conversation),
    latestChange: freezeReference(update.change),
    latestChangeKey: changeKey,
    sentChangeKey: null,
    kind: conversationVisible ? "conversation" : "profile",
    body: null,
    bodyKey: "",
    requestId: null,
    retries: 0,
    needsConversation: conversationVisible,
  };
  touchIncoming(current.incoming, key, created);
  while (current.incoming.size > MAX_INCOMING_REFRESHES) {
    const oldest = current.incoming.keys().next().value;
    if (oldest === undefined) break;
    current.incoming.delete(oldest);
  }
}

function touchIncoming(map: Map<string, IncomingRefresh>, key: string, value: IncomingRefresh): void {
  map.delete(key);
  map.set(key, value);
}

function incomingAction(session: StaffSession, current: ProfileFlowState, response: ObjectValue | null): Json | undefined {
  for (const [key, pending] of current.incoming) {
    if (pending.requestId && response && incomingResponseMatches(response, pending)) {
      return consumeIncomingResponse(session, current, key, pending, response);
    }
  }
  for (const pending of current.incoming.values()) {
    if (!pending.requestId) return issueIncomingRead(session, pending);
  }
  return undefined;
}

function incomingResponseMatches(response: ObjectValue, pending: IncomingRefresh): boolean {
  return stringValue(response.request_id) === pending.requestId && canonical(response.query) === pending.bodyKey;
}

function consumeIncomingResponse(
  session: StaffSession,
  current: ProfileFlowState,
  key: string,
  pending: IncomingRefresh,
  response: ObjectValue,
): Json | undefined {
  if (retryableReadError(response)) {
    if (pending.retries >= MAX_READ_RETRIES) {
      current.incoming.delete(key);
      return undefined;
    }
    pending.requestId = null;
    pending.retries += 1;
    return issueIncomingRead(session, pending);
  }
  const result = objectValue(response.result);
  const expected = pending.kind === "conversation"
    ? result?.kind === "conversation_page" && conversationResultMatches(result, pending.conversation, pending.account, session.roundId)
    : result?.kind === "profile" && profileResultMatches(result, pending.account, session.roundId);
  if (response.error || !expected) {
    current.incoming.delete(key);
    return undefined;
  }
  if (pending.latestChangeKey !== pending.sentChangeKey || (pending.kind === "profile" && pending.needsConversation)) {
    pending.kind = "conversation";
    pending.needsConversation = false;
    pending.requestId = null;
    pending.retries = 0;
    return issueIncomingRead(session, pending);
  }
  if (pending.kind === "conversation") {
    pending.kind = "profile";
    pending.needsConversation = false;
    pending.requestId = null;
    pending.retries = 0;
    return issueIncomingRead(session, pending);
  }
  current.incoming.delete(key);
  return undefined;
}

function issueIncomingRead(session: StaffSession, pending: IncomingRefresh): Json {
  const query = pending.kind === "conversation"
    ? conversationQuery(freezeReference(pending.conversation))
    : profileQuery(freezeReference(pending.account));
  const action = staffRequest(session, { kind: "query", query: String(query.query) });
  const raw = objectValue(action);
  const request = objectValue(raw?.request);
  const requestId = typeof request?.request_id === "string" ? request.request_id : null;
  pending.body = JSON.parse(String(query.query)) as ObjectValue;
  pending.bodyKey = canonical(pending.body);
  pending.requestId = requestId;
  pending.sentChangeKey = pending.latestChangeKey;
  return action;
}

function consumeResponse(session: StaffSession, current: ProfileFlowState, response: ObjectValue | null): void {
  const write = current.write;
  if (!write || !response) return;
  if (write.read) {
    consumeRead(session, current, write, response);
    return;
  }
  if (stringValue(response.request_id) !== write.requestId || canonical(response.query) !== write.bodyKey) return;
  const result = objectValue(response.result);
  if (!writeMatches(session, write, response.query)) return;
  if (response.error) {
    current.write = null;
    return;
  }
  if (write.op === "warning" || write.op === "profile_note") {
    if (result?.kind === "accepted") write.read = queuedRead("profile", profileQuery(write.account));
    else current.write = null;
    return;
  }
  if (write.op === "conversation") {
    const reference = readRef(result?.conversation, session.roundId);
    if (result?.kind === "conversation" && reference?.kind === "conversation") {
      write.conversation = reference;
      seedConversation(session, reference, write.account);
      write.read = queuedRead("conversation", conversationQuery(reference));
    } else current.write = null;
    return;
  }
  const message = readRef(result?.message, session.roundId);
  if (result?.kind === "message" && message?.kind === "message" && write.conversation) {
    write.read = queuedRead("conversation", conversationQuery(write.conversation));
  } else current.write = null;
}

function consumeRead(session: StaffSession, current: ProfileFlowState, write: PendingWrite, response: ObjectValue): void {
  const read = write.read;
  if (!read || !read.requestId || stringValue(response.request_id) !== read.requestId || canonical(response.query) !== read.bodyKey) return;
  if (retryableReadError(response)) {
    if (read.retries >= MAX_READ_RETRIES) {
      current.write = null;
      return;
    }
    read.requestId = null;
    read.retries += 1;
    return;
  }
  const result = objectValue(response.result);
  const expected = read.kind === "profile"
    ? result?.kind === "profile" && profileResultMatches(result, write.account, session.roundId)
    : result?.kind === "conversation_page" && conversationResultMatches(result, write.conversation, write.account, session.roundId);
  if (response.error || !expected) {
    current.write = null;
    return;
  }
  if (write.op === "message" && read.kind === "conversation") {
    write.read = queuedRead("profile", profileQuery(write.account));
    return;
  }
  current.write = null;
}

function issueRead(session: StaffSession, write: PendingWrite, read: PendingRead): Json {
  const action = staffRequest(session, { kind: "query", query: JSON.stringify(read.body) });
  read.requestId = requestIdOf(action);
  if (!read.requestId) write.read = null;
  return action;
}

function queuedRead(kind: ReadKind, action: Record<string, Json>): PendingRead {
  const body = JSON.parse(String(action.query)) as ObjectValue;
  return { kind, body, bodyKey: canonical(body), requestId: null, retries: 0 };
}

function validAccount(value: unknown, round: string): StaffRef | null {
  const account = readRef(value, round);
  return account?.kind === "account" && isProfileId(account.id) ? { round: "", kind: "account", id: account.id } : null;
}

function validConversation(value: unknown, round: string): StaffRef | null {
  const conversation = readRef(value, round);
  return conversation?.kind === "conversation" ? { round: conversation.round, kind: "conversation", id: conversation.id } : null;
}

function profileResultMatches(result: ObjectValue, account: StaffRef, round: string): boolean {
  const profile = objectValue(result.profile);
  const target = readRef(profile?.target, round);
  return !!target && sameRef(target, account);
}

function conversationResultMatches(result: ObjectValue, reference: StaffRef | undefined, account: StaffRef, round: string): boolean {
  if (!reference) return false;
  const record = objectValue(result.conversation);
  const actual = readRef(record?.reference, round);
  const owner = validAccount(record?.account, round);
  return !!actual && sameRef(actual, reference) && !!owner && sameRef(owner, account);
}

function writeMatches(session: StaffSession, write: PendingWrite, value: unknown): boolean {
  const body = objectValue(value);
  if (!body || body.op !== write.op) return false;
  if (write.op === "warning" || write.op === "profile_note") return !!validAccount(body.target, session.roundId) && sameRef(validAccount(body.target, session.roundId), write.account);
  if (write.op === "conversation") return !!validAccount(body.account, session.roundId) && sameRef(validAccount(body.account, session.roundId), write.account);
  return !!write.conversation && !!validConversation(body.conversation, session.roundId) && sameRef(validConversation(body.conversation, session.roundId), write.conversation);
}

function retryableReadError(response: ObjectValue): boolean {
  const result = objectValue(response.result);
  return [response.error, result?.error, result?.code, result?.reason, result?.kind].some((value) => {
    const error = stringValue(value).toLowerCase().replace(/[.\- ]/g, "_");
    return error === "bound" || error.endsWith("_bound") || error === "stale_revision" || error.endsWith("_stale_revision") || error === "revision_stale" || error.endsWith("_revision_stale");
  });
}

function requestIdOf(action: Json): string | null {
  const raw = objectValue(action);
  const request = objectValue(raw?.request);
  return typeof request?.request_id === "string" ? request.request_id : null;
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value as ObjectValue).sort().map((key) => `${JSON.stringify(key)}:${canonical((value as ObjectValue)[key])}`).join(",")}}`;
  return JSON.stringify(value) ?? "null";
}
