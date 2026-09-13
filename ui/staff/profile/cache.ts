import type { StaffProfile, StaffRef, StaffSession } from "../model";
import { isDecimalId, isProfileId } from "../model";
import { objectValue, readRef, refKey, sameRef, stringValue } from "../cases/records";
import { admitStaffReadResponse, resetReadIntents } from "./read-intents";

type ObjectValue = Record<string, unknown>;

export const MAX_PROFILE_ENTRIES = 64;
export const MAX_PROFILE_ROWS = 1024;
export const MAX_PROFILE_CONVERSATIONS = 64;
export const MAX_CONVERSATION_ENTRIES = 64;
export const MAX_CONVERSATION_MESSAGES = 1000;
export const MAX_CONVERSATION_PAGES = 16;

export interface CachedProfilePage {
  target: StaffRef;
  identity: StaffProfile | null;
  warnings: ObjectValue[];
  notes: ObjectValue[];
  conversations: ObjectValue[];
  next: string | null;
  error: string | null;
}

export interface CachedConversation {
  reference: StaffRef;
  account: StaffRef;
  record: ObjectValue;
}

interface ProfileEntry extends CachedProfilePage {
  freshWarnings: Set<string>;
  freshNotes: Set<string>;
  freshConversations: Set<string>;
  warningRows: Map<string, ObjectValue>;
  noteRows: Map<string, ObjectValue>;
  conversationRows: Map<string, ObjectValue>;
  conversationCounts: Map<string, number>;
}

interface ConversationEntry extends CachedConversation {
  messages: Map<string, ObjectValue>;
  receipts: Map<string, ObjectValue>;
  freshMessages: Set<string>;
  freshReceipts: Set<string>;
  messageCount?: number;
  pages: number;
  next: string | null;
  error: string | null;
}

const profiles = new Map<string, ProfileEntry>();
const conversations = new Map<string, ConversationEntry>();
let cacheRound = "";
let rememberedResponse = "";

export function resetProfileCaches(): void {
  profiles.clear();
  conversations.clear();
  cacheRound = "";
  rememberedResponse = "";
  resetReadIntents();
}

function ensureRound(round: string): void {
  if (cacheRound === round) return;
  profiles.clear();
  conversations.clear();
  cacheRound = round;
  rememberedResponse = "";
}

function lruGet<K, V>(cache: Map<K, V>, key: K): V | undefined {
  const value = cache.get(key);
  if (value === undefined) return undefined;
  cache.delete(key);
  cache.set(key, value);
  return value;
}

function lruSet<K, V>(cache: Map<K, V>, key: K, value: V, limit: number): void {
  cache.delete(key);
  cache.set(key, value);
  while (cache.size > limit) {
    const oldest = cache.keys().next().value as K | undefined;
    if (oldest === undefined) break;
    cache.delete(oldest);
  }
}

function profileEntry(target: StaffRef): ProfileEntry {
  const existing = lruGet(profiles, target.id);
  if (existing) return existing;
  const created: ProfileEntry = {
    target: { round: "", kind: "account", id: target.id }, identity: null,
    warnings: [], notes: [], conversations: [], next: null, error: null,
    freshWarnings: new Set(), freshNotes: new Set(), freshConversations: new Set(),
    warningRows: new Map(), noteRows: new Map(), conversationRows: new Map(), conversationCounts: new Map(),
  };
  lruSet(profiles, target.id, created, MAX_PROFILE_ENTRIES);
  return created;
}

function conversationEntry(reference: StaffRef, account: StaffRef): ConversationEntry {
  const key = refKey(reference);
  const existing = lruGet(conversations, key);
  if (existing) {
    if (sameRef(existing.account, account)) return existing;
    conversations.delete(key);
  }
  const created: ConversationEntry = {
    reference: { round: reference.round, kind: "conversation", id: reference.id }, account,
    record: { reference, account },
    messages: new Map(), receipts: new Map(), freshMessages: new Set(), freshReceipts: new Set(),
    messageCount: undefined,
    pages: 0, next: null, error: null,
  };
  lruSet(conversations, key, created, MAX_CONVERSATION_ENTRIES);
  return created;
}

function rowKey(value: ObjectValue, kind: "warning" | "note"): string {
  const target = readRef(value.target, cacheRound);
  const author = readRef(value.author, cacheRound);
  return `${kind}:${target?.id ?? ""}:${author?.id ?? ""}:${stringValue(value.at)}:${stringValue(value.text)}`;
}

function validAccount(value: unknown, expected?: StaffRef): StaffRef | null {
  const account = readRef(value, cacheRound);
  if (!account || account.kind !== "account" || !isProfileId(account.id)) return null;
  return expected && !sameRef(account, expected) ? null : account;
}

function validProfile(value: unknown, target: StaffRef): StaffProfile | null {
  const raw = objectValue(value);
  if (!raw || !isProfileId(raw.id) || raw.id !== target.id
      || typeof raw.username !== "string" || typeof raw.avatar !== "string" || typeof raw.role !== "string") return null;
  const avatar = raw.avatar === "portrait-01" || raw.avatar === "portrait-02" || raw.avatar === "portrait-03" || raw.avatar === "portrait-04" || raw.avatar === "unknown"
    ? raw.avatar : "unknown";
  return { id: raw.id, username: raw.username, avatar, role: raw.role };
}

function validWarning(value: unknown, target: StaffRef): ObjectValue | null {
  const raw = objectValue(value);
  return raw && typeof raw.text === "string" && validAccount(raw.target, target) && validAccount(raw.author) ? raw : null;
}

function validNote(value: unknown, target: StaffRef): ObjectValue | null {
  const raw = objectValue(value);
  return raw && typeof raw.text === "string" && validAccount(raw.target, target) && validAccount(raw.author) ? raw : null;
}

function validConversation(value: unknown, target?: StaffRef): ObjectValue | null {
  const raw = objectValue(value);
  const reference = readRef(raw?.reference, cacheRound);
  const account = validAccount(raw?.account, target);
  return raw && reference?.kind === "conversation" && account ? raw : null;
}

function validMessageCount(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : undefined;
}

function validMessage(value: unknown, reference: StaffRef): ObjectValue | null {
  const raw = objectValue(value);
  const message = readRef(raw?.reference, cacheRound);
  return raw && message?.kind === "message" && typeof raw.body === "string" && reference.kind === "conversation" ? raw : null;
}

function validReceipt(value: unknown, account: StaffRef): ObjectValue | null {
  const raw = objectValue(value);
  return raw && readRef(raw.message, cacheRound)?.kind === "message" && validAccount(raw.account, account) ? raw : null;
}

function cursor(value: unknown): string | null {
  return typeof value === "string" || typeof value === "number" ? String(value) : null;
}

function responseKey(response: ObjectValue): string {
  return `${stringValue(response.request_id)}\u0000${canonical(response.query)}\u0000${canonical(response.result)}\u0000${stringValue(response.error)}`.slice(0, 8192);
}

/** Save a profile page before the native bridge replaces its response. */
export function rememberProfileResponse(session: StaffSession): void {
  ensureRound(session.roundId);
  const response = objectValue(session.records?.response);
  if (!response || response.error || responseKey(response) === rememberedResponse) return;
  if (!admitStaffReadResponse(session.roundId, "profile", response)) return;
  const query = objectValue(response.query);
  const target = validAccount(query?.target);
  const result = objectValue(response.result);
  const payload = objectValue(result?.profile);
  const payloadTarget = validAccount(payload?.target);
  if (query?.op !== "profile" || !target || !payload || (payloadTarget && !sameRef(target, payloadTarget)) || result?.kind !== "profile") return;
  rememberedResponse = responseKey(response);
  const entry = profileEntry(target);
  const completePage = !!payloadTarget;
  const firstPage = query.after === undefined || query.after === null || query.after === "";
  const warnings = Array.isArray(payload.warnings) ? payload.warnings.map((row) => validWarning(row, target)).filter((row): row is ObjectValue => !!row).slice(0, MAX_PROFILE_ROWS) : [];
  const notes = Array.isArray(payload.notes) ? payload.notes.map((row) => validNote(row, target)).filter((row): row is ObjectValue => !!row).slice(0, MAX_PROFILE_ROWS) : [];
  const conversationRows = Array.isArray(payload.conversations) ? payload.conversations.map((row) => validConversation(row, target)).filter((row): row is ObjectValue => !!row).slice(0, MAX_PROFILE_CONVERSATIONS) : [];
  if (completePage) {
    mergeRows(entry.warningRows, entry.freshWarnings, warnings, row => rowKey(row, "warning"), firstPage);
    mergeRows(entry.noteRows, entry.freshNotes, notes, row => rowKey(row, "note"), firstPage);
    mergeConversationProfileRows(entry, conversationRows, firstPage);
  }
  entry.identity = validProfile(payload.identity, target) ?? entry.identity;
  if (completePage) {
    entry.next = cursor(payload.next);
    entry.error = stringValue(response.error) || null;
  }
  entry.warnings = [...entry.warningRows.values()].slice(0, MAX_PROFILE_ROWS);
  entry.notes = [...entry.noteRows.values()].slice(0, MAX_PROFILE_ROWS);
  entry.conversations = [...entry.conversationRows.values()].slice(0, MAX_PROFILE_CONVERSATIONS);
  if (completePage) for (const row of conversationRows) {
    const reference = readRef(row.reference, cacheRound);
    const account = validAccount(row.account, target);
    if (reference && account) saveConversationRecord(reference, account, row, false);
  }
}

function mergeConversationProfileRows(entry: ProfileEntry, incoming: ObjectValue[], replaceFresh: boolean): void {
  const keyOf = (row: ObjectValue) => refKey(readRef(row.reference, cacheRound)!);
  const nextFresh = new Set(incoming.map(keyOf));
  if (replaceFresh) {
    for (const key of entry.freshConversations) if (!nextFresh.has(key)) entry.conversationRows.delete(key);
    entry.freshConversations.clear();
    for (const key of nextFresh) entry.freshConversations.add(key);
  }
  for (const row of incoming) {
    const key = keyOf(row);
    const incomingCount = validMessageCount(row.message_count);
    const knownCount = entry.conversationCounts.get(key);
    const count = incomingCount === undefined ? knownCount : Math.max(knownCount ?? 0, incomingCount);
    if (count === undefined) {
      entry.conversationRows.delete(key);
      entry.conversationRows.set(key, row);
    } else {
      entry.conversationRows.delete(key);
      entry.conversationRows.set(key, { ...row, message_count: count });
      entry.conversationCounts.set(key, count);
    }
  }
  while (entry.conversationRows.size > MAX_PROFILE_CONVERSATIONS) entry.conversationRows.delete(entry.conversationRows.keys().next().value as string);
}

function mergeRows(
  rows: Map<string, ObjectValue>, fresh: Set<string>, incoming: ObjectValue[], keyOf: (row: ObjectValue) => string, replaceFresh: boolean,
): void {
  const nextFresh = new Set(incoming.map(keyOf));
  if (replaceFresh) for (const key of fresh) if (!nextFresh.has(key)) rows.delete(key);
  if (replaceFresh) {
    fresh.clear();
    for (const key of nextFresh) fresh.add(key);
  }
  for (const row of incoming) {
    const key = keyOf(row);
    rows.delete(key);
    rows.set(key, row);
  }
  while (rows.size > MAX_PROFILE_ROWS) rows.delete(rows.keys().next().value as string);
}

function saveConversationRecord(reference: StaffRef, account: StaffRef, record: ObjectValue, replaceFresh: boolean): void {
  const entry = conversationEntry(reference, account);
  mergeConversation(entry, record, replaceFresh);
}

function mergeConversation(entry: ConversationEntry, record: ObjectValue, replaceFresh: boolean): void {
  const incomingMessages = Array.isArray(record.messages) ? record.messages.map((row) => validMessage(row, entry.reference)).filter((row): row is ObjectValue => !!row).slice(0, MAX_CONVERSATION_MESSAGES) : [];
  const incomingReceipts = Array.isArray(record.delivery_receipts) ? record.delivery_receipts.map((row) => validReceipt(row, entry.account)).filter((row): row is ObjectValue => !!row).slice(0, MAX_CONVERSATION_MESSAGES) : [];
  const keyOf = (row: ObjectValue, field: string) => refKey(readRef(row[field], cacheRound)!);
  mergeConversationRows(entry.messages, entry.freshMessages, incomingMessages, row => keyOf(row, "reference"), replaceFresh, "reference");
  mergeConversationRows(entry.receipts, entry.freshReceipts, incomingReceipts, row => keyOf(row, "message"), replaceFresh, "message");
  const incomingCount = validMessageCount(record.message_count);
  if (incomingCount !== undefined) entry.messageCount = Math.max(entry.messageCount ?? 0, incomingCount);
  entry.pages = Math.min(MAX_CONVERSATION_PAGES, entry.pages + 1);
  entry.next = cursor(record.next);
  entry.error = null;
  entry.record = {
    ...entry.record, ...record, reference: entry.reference, account: entry.account,
    messages: [...entry.messages.values()].slice(0, MAX_CONVERSATION_MESSAGES),
    delivery_receipts: [...entry.receipts.values()].slice(0, MAX_CONVERSATION_MESSAGES),
    ...(entry.messageCount === undefined ? {} : { message_count: entry.messageCount }),
    ...(entry.next ? { next: entry.next } : { next: null }),
  };
}

function mergeConversationRows(
  rows: Map<string, ObjectValue>, fresh: Set<string>, incoming: ObjectValue[], keyOf: (row: ObjectValue) => string, replaceFresh: boolean,
  referenceField: "reference" | "message",
): void {
  const nextFresh = new Set(incoming.map(keyOf));
  if (replaceFresh) {
    // Newest pages shift as messages arrive; missing head rows remain valid history.
    fresh.clear();
    for (const key of nextFresh) fresh.add(key);
  }
  for (const row of incoming) {
    const key = keyOf(row);
    rows.delete(key);
    rows.set(key, row);
  }
  const ordered = [...rows.entries()].sort(([, left], [, right]) => conversationRowOrder(left, right, referenceField));
  rows.clear();
  for (const [key, row] of ordered) rows.set(key, row);
  while (rows.size > MAX_CONVERSATION_MESSAGES) rows.delete(rows.keys().next().value as string);
}

function conversationRowOrder(left: ObjectValue, right: ObjectValue, referenceField: "reference" | "message"): number {
  const leftRef = readRef(left[referenceField], cacheRound);
  const rightRef = readRef(right[referenceField], cacheRound);
  const leftId = leftRef?.kind === "message" && isDecimalId(leftRef.id) ? leftRef.id : null;
  const rightId = rightRef?.kind === "message" && isDecimalId(rightRef.id) ? rightRef.id : null;
  if (leftId !== null && rightId !== null) {
    if (leftId.length !== rightId.length) return leftId.length - rightId.length;
    if (leftId !== rightId) return leftId < rightId ? -1 : 1;
  }
  const leftAt = rowTime(left);
  const rightAt = rowTime(right);
  if (leftAt !== rightAt) {
    if (leftAt === null) return 1;
    if (rightAt === null) return -1;
    return leftAt < rightAt ? -1 : 1;
  }
  return referenceOrder(leftRef, rightRef);
}

function rowTime(row: ObjectValue): number | null {
  const value = row.at;
  const number = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  return Number.isFinite(number) ? number : null;
}

function referenceOrder(left: StaffRef | null, right: StaffRef | null): number {
  if (!left || !right) return (left ? 1 : 0) - (right ? 1 : 0);
  const leftKey = refKey(left);
  const rightKey = refKey(right);
  if (left.round !== right.round) return left.round.localeCompare(right.round);
  if (left.kind !== right.kind) return left.kind.localeCompare(right.kind);
  if (/^\d+$/.test(left.id) && /^\d+$/.test(right.id)) {
    const leftId = left.id.replace(/^0+(?=\d)/, "");
    const rightId = right.id.replace(/^0+(?=\d)/, "");
    if (leftId.length !== rightId.length) return leftId.length - rightId.length;
    if (leftId !== rightId) return leftId.localeCompare(rightId);
  }
  return leftKey.localeCompare(rightKey);
}

/** Save an exact conversation page response. */
export function rememberConversationResponse(session: StaffSession): void {
  ensureRound(session.roundId);
  const response = objectValue(session.records?.response);
  if (!response || response.error || responseKey(response) === rememberedResponse) return;
  if (!admitStaffReadResponse(session.roundId, "conversation", response)) return;
  const query = objectValue(response.query);
  const wanted = readRef(query?.conversation, session.roundId);
  const result = objectValue(response.result);
  const record = objectValue(result?.conversation);
  const reference = readRef(record?.reference, session.roundId);
  const account = validAccount(record?.account);
  if (query?.op !== "conversation" || result?.kind !== "conversation_page" || !wanted || wanted.kind !== "conversation" || !record || !reference || !sameRef(wanted, reference) || !account) return;
  rememberedResponse = responseKey(response);
  const firstPage = query.after === undefined || query.after === null || query.after === "";
  const entry = conversationEntry(reference, account);
  mergeConversation(entry, record, firstPage);
  entry.error = stringValue(response.error) || null;
}

export function seedConversation(session: StaffSession, reference: StaffRef, account: StaffRef): void {
  ensureRound(session.roundId);
  if (reference.kind !== "conversation" || !validAccount(account, account)) return;
  conversationEntry(reference, account);
}

export function cachedProfile(session: StaffSession, id: string): StaffProfile | null {
  ensureRound(session.roundId);
  return lruGet(profiles, id)?.identity ?? null;
}

export function profilePage(session: StaffSession, id: string): CachedProfilePage {
  ensureRound(session.roundId);
  const entry = lruGet(profiles, id);
  return entry ? {
    target: entry.target, identity: entry.identity, warnings: [...entry.warnings], notes: [...entry.notes], conversations: overlayConversationCounts(entry), next: entry.next, error: entry.error,
  } : { target: { round: "", kind: "account", id }, identity: null, warnings: [], notes: [], conversations: [], next: null, error: null };
}

function overlayConversationCounts(entry: ProfileEntry): ObjectValue[] {
  return entry.conversations.map((row) => {
    const reference = readRef(row.reference, cacheRound);
    if (!reference) return row;
    const key = refKey(reference);
    const cached = conversations.get(key);
    if (!cached || !sameRef(cached.account, entry.target)) return row;
    const cachedCount = cached.messageCount;
    const profileCount = entry.conversationCounts.get(key);
    const count = cachedCount === undefined ? profileCount : Math.max(profileCount ?? 0, cachedCount);
    if (count === undefined) return row;
    entry.conversationCounts.set(key, count);
    return { ...row, message_count: count };
  });
}

export function cachedConversation(session: StaffSession, account: StaffRef, reference?: StaffRef | null): CachedConversation | null {
  ensureRound(session.roundId);
  if (reference) {
    const found = lruGet(conversations, refKey(reference));
    return found && sameRef(found.account, account) ? publicConversation(found) : null;
  }
  for (const entry of [...conversations.values()].reverse()) if (sameRef(entry.account, account)) return publicConversation(entry);
  return null;
}

function publicConversation(entry: ConversationEntry): CachedConversation {
  return { reference: entry.reference, account: entry.account, record: entry.record };
}

export function conversationPage(session: StaffSession, reference: StaffRef): { record: ObjectValue | null; next: string | null; error: string | null } {
  ensureRound(session.roundId);
  const entry = lruGet(conversations, refKey(reference));
  return entry ? { record: entry.record, next: entry.next, error: entry.error } : { record: null, next: null, error: null };
}

export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value as ObjectValue).sort().map((key) => `${JSON.stringify(key)}:${canonical((value as ObjectValue)[key])}`).join(",")}}`;
  return JSON.stringify(value) ?? "null";
}
