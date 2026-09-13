import type { Json } from "@lunatic/ui";
import type { GameplayView } from "../model";

export interface StaffRef {
  round: string;
  kind: string;
  id: string;
}

export interface ContactMessage {
  ref: StaffRef;
  from: "staff" | "player";
  sender: string;
  body: string;
  second?: number;
  delivered: boolean;
  unread: boolean;
  fresh: boolean;
}

export interface ContactConversation {
  ref: StaffRef;
  label: string;
  staffName: string;
  messages: ContactMessage[];
  cursor: string | null;
  unread: number;
}

export interface StaffContactState {
  revision: string;
  available: boolean;
  conversations: ContactConversation[];
  selected: string | null;
  unread: number;
  cursor: string | null;
  denial: string | null;
}

export interface ContactLocalState {
  open: boolean;
  selected: string | null;
  drafts: Record<string, string>;
  round: number | string;
  cache: Map<string, ContactConversation>;
  delivered?: { conversation: string; message: string };
}

type ObjectValue = Record<string, unknown>;

const object = (value: unknown): ObjectValue | null =>
  value && typeof value === "object" && !Array.isArray(value)
    ? value as ObjectValue
    : null;

const stringValue = (value: unknown): string => typeof value === "string" ? value : "";

const MAX_REF_ROUND_BYTES = 128;
const MAX_REF_KIND_BYTES = 96;
const MAX_REF_ID_BYTES = 128;
const MAX_CURSOR_BYTES = 128;
export const MAX_CONTACT_BODY_BYTES = 4096;
const identifier = (value: unknown, max: number): string | null => {
  if (typeof value !== "string" || !value || value.length > max) return null;
  return /^[A-Za-z0-9_.:/-]+$/.test(value) ? value : null;
};

const pageCursor = (value: unknown): string | null | undefined =>
  value === null ? null : identifier(value, MAX_CURSOR_BYTES);

const reference = (value: unknown, expectedKind?: string): StaffRef | null => {
  const raw = object(value);
  if (!raw) return null;
  const round = identifier(raw.round, MAX_REF_ROUND_BYTES);
  const kind = identifier(raw.kind, MAX_REF_KIND_BYTES);
  const id = identifier(raw.id, MAX_REF_ID_BYTES);
  return round && kind && id && (!expectedKind || kind === expectedKind)
    ? { round, kind, id }
    : null;
};

/** JSON keeps round, kind and id distinct even when an id contains `:`. */
export const refKey = (ref: StaffRef): string => JSON.stringify([ref.round, ref.kind, ref.id]);

const bodyBytes = (body: string): number => {
  let bytes = 0;
  for (const character of body) {
    const code = character.codePointAt(0) ?? 0;
    bytes += code <= 0x7f ? 1 : code <= 0x7ff ? 2 : code <= 0xffff ? 3 : 4;
  }
  return bytes;
};

/** Keep the native body contract in bytes, without splitting a code point. */
export const bodyLimit = (value: string): string => {
  let bytes = 0;
  let result = "";
  for (const character of value) {
    const code = character.codePointAt(0) ?? 0;
    const size = code <= 0x7f ? 1 : code <= 0x7ff ? 2 : code <= 0xffff ? 3 : 4;
    if (bytes + size > MAX_CONTACT_BODY_BYTES) break;
    result += character;
    bytes += size;
  }
  return result;
};

function message(value: unknown): ContactMessage | null {
  const raw = object(value);
  if (!raw) return null;
  const ref = reference(raw.ref, "message");
  const from = raw.from === "staff" || raw.from === "player" ? raw.from : null;
  const body = stringValue(raw.body);
  if (!ref || ref.kind !== "message" || !body || bodyBytes(body) > MAX_CONTACT_BODY_BYTES) return null;
  if (!from || typeof raw.delivered !== "boolean" || typeof raw.unread !== "boolean") return null;
  return {
    ref,
    from,
    sender: from === "staff" ? stringValue(raw.sender) : "",
    body,
    ...(typeof raw.second === "number" ? { second: raw.second } : {}),
    delivered: raw.delivered,
    unread: raw.unread,
    fresh: raw.fresh === true,
  };
}

function conversation(value: unknown): ContactConversation | null {
  const raw = object(value);
  if (!raw) return null;
  const ref = reference(raw.ref, "conversation");
  if (!ref) return null;
  if (!Array.isArray(raw.messages)) return null;
  const messages = raw.messages
    .map((item) => message(item))
    .filter((item): item is ContactMessage => !!item);
  if (typeof raw.unread !== "number" || !Number.isSafeInteger(raw.unread) || raw.unread < 0) return null;
  const cursor = pageCursor(raw.cursor);
  if (cursor === undefined) return null;
  return {
    ref,
    label: "",
    staffName: "",
    messages,
    cursor,
    unread: raw.unread,
  };
}

/** Read the one ordinary bridge projection; account records are absent here. */
export function readContact(view: GameplayView): StaffContactState | null {
  const raw = object(view.state.staff_contact);
  if (!raw) return null;
  if (!Array.isArray(raw.conversations) || typeof raw.available !== "boolean") return null;
  if (typeof raw.revision !== "string" || !raw.revision) return null;
  const conversations = raw.conversations
    .map((thread) => conversation(thread))
    .filter((item): item is ContactConversation => !!item);
  if (!(raw.denial === null || typeof raw.denial === "string")) return null;
  const cursor = pageCursor(raw.cursor);
  if (cursor === undefined) return null;
  if (typeof raw.unread !== "number" || !Number.isSafeInteger(raw.unread) || raw.unread < 0) return null;
  const denial = raw.denial;
  const selected = conversations[0] ? refKey(conversations[0].ref) : null;
  return {
    revision: raw.revision,
    available: raw.available,
    conversations,
    selected,
    unread: raw.unread,
    cursor,
    denial,
  };
}

export function selectedConversation(state: StaffContactState, local: ContactLocalState): ContactConversation | null {
  const key = local.selected ?? state.selected;
  if (!key) return state.conversations[0] ?? null;
  return state.conversations.find((item) => refKey(item.ref) === key)
    ?? local.cache.get(key)
    ?? null;
}

export function unreadMessages(conversation: ContactConversation | null): ContactMessage[] {
  return conversation?.messages.filter((item) => item.from === "staff" && item.unread) ?? [];
}

export type ContactAction =
  | { Inbox: { after: string | null } }
  | { Reply: { conversation: StaffRef; body: string } }
  | { Delivered: { conversation: StaffRef; message: StaffRef } };

let requestCounter = 0;
let requestPrefix = "contact";
let prefixEpoch = 0;

function newPrefix(): string {
  try {
    const cryptoApi = (globalThis as typeof globalThis & { crypto?: Crypto }).crypto;
    const uuid = cryptoApi?.randomUUID?.();
    if (uuid) return uuid.replace(/[^a-zA-Z0-9-]/g, "").slice(0, 64);
  } catch {
    // The monotonic fallback still satisfies the native identifier contract.
  }
  prefixEpoch += 1;
  return `contact-${prefixEpoch.toString(36)}`;
}

export function resetContactRequests(): void {
  requestCounter = 0;
  requestPrefix = newPrefix();
}

/** Encode only the StaffContactRequest DTO consumed by the native bridge. */
export function contactAction(action: ContactAction): Json {
  requestCounter += 1;
  return {
    kind: "staff_contact",
    request: {
      request_id: `${requestPrefix}-${requestCounter}`,
      action,
    },
  };
}
