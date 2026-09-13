import type { StaffCase, StaffEntity, StaffProfile, StaffRef, StaffSession } from "../model";
import { caseAccountIds, caseId, caseLabel, entitiesForRef, objectValue, readRef, recordResponse, responseProfileFor, sameRef, stringValue } from "../cases/records";
import { profileReference } from "../shared/records";
import { admitStaffReadResponse } from "./read-intents";
import { cachedConversation, cachedProfile, profilePage, rememberConversationResponse, rememberProfileResponse } from "./cache";

export { resetProfileCaches } from "./cache";

export { MAX_CONVERSATION_MESSAGES, MAX_PROFILE_ROWS } from "./cache";

export interface ProfileWarning {
  text: string;
  severity: string;
  time: string;
  author: StaffRef | null;
}

export interface ProfileRecordPage {
  warnings: ProfileWarning[];
  notes: object[];
  conversations: object[];
  next: string | null;
  error: string | null;
}

export interface ProfileView {
  profile: StaffProfile;
  account: StaffRef;
  bodies: StaffEntity[];
  cases: StaffCase[];
  warnings: ProfileWarning[];
  records: ProfileRecordPage;
}

export interface ProfileConversation {
  reference: StaffRef;
  account: StaffRef;
  record: object;
}

export function profileRef(session: StaffSession, id: string): StaffRef {
  void session;
  return profileReference(id);
}

function profileRecordPage(session: StaffSession, id: string): ProfileRecordPage {
  const warnings: ProfileWarning[] = [];
  const notes: object[] = [];
  const conversations: object[] = [];
  rememberProfileResponse(session);
  rememberConversationResponse(session);
  const page = profilePage(session, id);
  readWarningList(page.warnings, session.roundId, id, warnings);
  readObjectList(page.notes, notes);
  readObjectList(page.conversations, conversations);
  return {
    warnings: uniqueWarnings(warnings),
    notes,
    conversations,
    next: page.next,
    error: page.error,
  };
}

function readWarningList(value: unknown, round: string, targetId: string, output: ProfileWarning[]): void {
  if (!Array.isArray(value)) return;
  for (const item of value) {
    const raw = objectValue(item);
    if (!raw || typeof raw.text !== "string") continue;
    const target = readRef(raw.target, round);
    if (target?.kind !== "account" || target.id !== targetId) continue;
    const author = readRef(raw.author, round);
    if (author?.kind !== "account") continue;
    output.push({
      text: raw.text,
      severity: "",
      time: stringValue(raw.at),
      author,
    });
  }
}

function readObjectList(value: unknown, output: object[]): void {
  if (Array.isArray(value)) output.push(...value.filter((item): item is object => !!objectValue(item)));
}

function uniqueWarnings(values: ProfileWarning[]): ProfileWarning[] {
  return [...new Map(values.map((item) => [`${item.text}:${item.time}:${item.author?.id ?? ""}`, item])).values()];
}

/** Return the exact conversation address from a durable response or profile page. */
export function conversationFor(session: StaffSession, view: ProfileView): ProfileConversation | null {
  rememberProfileResponse(session);
  rememberConversationResponse(session);
  const cached = cachedConversation(session, view.account);
  if (cached) return cached;
  const response = recordResponse(session);
  const result = response?.error ? null : objectValue(response?.result);
  if (result?.kind === "conversation") {
    const reference = readRef(result.conversation, session.roundId);
    const query = objectValue(response?.query);
    const account = readRef(query?.account, session.roundId);
    if (reference?.kind === "conversation" && account?.kind === "account" && account.id === view.account.id) {
      return { reference, account: view.account, record: {} };
    }
  }
  if (result?.kind === "conversation_page" && admitStaffReadResponse(session.roundId, "conversation", response)) {
    const record = objectValue(result.conversation);
    const reference = readRef(record?.reference, session.roundId);
    const account = readRef(record?.account, session.roundId);
    const query = objectValue(response?.query);
    const queried = readRef(query?.conversation, session.roundId);
    if (record && reference?.kind === "conversation" && account?.kind === "account" && account.id === view.account.id && queried && sameRef(queried, reference)) {
      return { reference, account, record };
    }
  }
  const stored = view.records.conversations
    .map((item) => objectValue(item))
    .map((record) => {
      const reference = readRef(record?.reference, session.roundId);
      const account = readRef(record?.account, session.roundId);
      return record && reference?.kind === "conversation" && account?.kind === "account" && account.id === view.account.id
        ? { reference, account, record }
        : null;
    })
    .find((item): item is ProfileConversation => !!item);
  return stored ?? null;
}

/** A message response is useful only with the server-issued message address. */
export function messageResponse(session: StaffSession): StaffRef | null {
  const result = objectValue(recordResponse(session)?.result);
  if (!result || result.kind !== "message") return null;
  const message = readRef(result.message, session.roundId);
  return message?.kind === "message" ? message : null;
}

export function profileView(session: StaffSession, id: string): ProfileView | null {
  rememberProfileResponse(session);
  rememberConversationResponse(session);
  const ambient = (session.profiles ?? []).find((item) => item.id === id);
  const canonical = cachedProfile(session, id) ?? admittedResponseProfile(session, id);
  const profile = mergeProfile(canonical, ambient);
  if (!profile) return null;
  const account = profileRef(session, id);
  const records = profileRecordPage(session, id);
  // The compact live profile warning summary is not a record projection.
  // Canonical warning rows have already been target-validated above.
  records.warnings = uniqueWarnings(records.warnings);
  return {
    profile,
    account,
    bodies: entitiesForRef(session, account),
    cases: (session.cases ?? []).filter((item) => caseHasAccount(item, id)),
    warnings: records.warnings,
    records,
  };
}

function admittedResponseProfile(session: StaffSession, id: string): StaffProfile | null {
  const response = recordResponse(session);
  const query = objectValue(response?.query);
  if (query?.op === "profile" && !admitStaffReadResponse(session.roundId, "profile", response)) return null;
  return responseProfileFor(session, id);
}

function caseHasAccount(item: StaffCase, account: string): boolean {
  return caseAccountIds(item).some((id) => id === account);
}

export function warningCount(view: ProfileView): number {
  return Math.max(view.warnings.length, view.profile.warnings?.length ?? 0);
}

export function messageCount(view: ProfileView): number {
  const messages = view.records.conversations.reduce((count, conversation) => {
    const raw = objectValue(conversation);
    const total = validMessageCount(raw?.message_count);
    const loaded = Array.isArray(raw?.messages) ? raw.messages.length : 0;
    return count + (total === undefined ? loaded : total);
  }, 0);
  return Math.max(messages, view.profile.messageCount ?? 0);
}

function validMessageCount(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : undefined;
}

function mergeProfile(canonical: StaffProfile | null, ambient: StaffProfile | undefined): StaffProfile | null {
  const source = canonical ?? ambient;
  if (!source) return null;
  return {
    ...(ambient ?? {}),
    ...(canonical ?? {}),
    id: source.id,
    username: source.username,
    avatar: source.avatar,
    role: source.role,
    ...(ambient?.warnings === undefined ? {} : { warnings: ambient.warnings }),
    ...(ambient?.messageCount === undefined ? {} : { messageCount: ambient.messageCount }),
  };
}

export function bodyIdentity(entity: StaffEntity): string {
  const fallback = `${entity.kind} · ${entity.id}`;
  const identity = entity.name && entity.name !== fallback ? [entity.name, entity.kind, entity.id] : [fallback];
  return [...identity, entity.role]
    .filter(Boolean)
    .join(" · ");
}

export function caseIdentity(item: StaffCase): string {
  return [caseId(item), caseLabel(item)].filter(Boolean).join(" · ");
}
