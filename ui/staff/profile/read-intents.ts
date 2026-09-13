import { readRef, refKey } from "../cases/records";

type ObjectValue = Record<string, unknown>;
export type StaffReadKind = "profile" | "conversation";

/** Keep one latest read for each profile/conversation in the current round. */
export const MAX_READ_INTENTS = 128;

interface ReadIntent {
  requestId: string;
  queryKey: string;
}

let intentRound = "";
const intents = new Map<string, ReadIntent>();

export function resetReadIntents(): void {
  intents.clear();
  intentRound = "";
}

/** Register before a query action is returned to the native bridge. */
export function rememberStaffRead(round: string, requestId: string, action: unknown): void {
  const query = queryFromAction(action);
  if (!query) return;
  const kind = query.op === "profile" || query.op === "conversation" ? query.op : null;
  if (!kind) return;
  const identity = readIdentity(kind, query, round);
  if (!identity) return;
  ensureRound(round);
  const key = `${kind}\u0000${identity}`;
  intents.delete(key);
  intents.set(key, { requestId, queryKey: canonical(query) });
  while (intents.size > MAX_READ_INTENTS) {
    const oldest = intents.keys().next().value;
    if (oldest === undefined) break;
    intents.delete(oldest);
  }
}

/** Admit only the newest exact request/query once local intent exists. */
export function admitStaffReadResponse(round: string, kind: StaffReadKind, response: unknown): boolean {
  ensureRound(round);
  const raw = objectValue(response);
  const query = objectValue(raw?.query);
  if (!raw || !query || query.op !== kind) return false;
  const identity = readIdentity(kind, query, round);
  if (!identity) return false;
  const intent = intents.get(`${kind}\u0000${identity}`);
  // A reconnect or fixture may carry an authorized response from before this
  // page issued a local read. Preserve that initial ambient snapshot.
  if (!intent) return true;
  return typeof raw.request_id === "string"
    && raw.request_id === intent.requestId
    && canonical(query) === intent.queryKey;
}

function ensureRound(round: string): void {
  if (intentRound === round) return;
  intents.clear();
  intentRound = round;
}

function queryFromAction(action: unknown): ObjectValue | null {
  const raw = objectValue(action);
  if (raw?.kind !== "query" || typeof raw.query !== "string") return null;
  try {
    return objectValue(JSON.parse(raw.query));
  } catch {
    return null;
  }
}

function readIdentity(kind: StaffReadKind, query: ObjectValue, round: string): string | null {
  const field = kind === "profile" ? query.target : query.conversation;
  const reference = readRef(field, round);
  if (!reference || reference.kind !== (kind === "profile" ? "account" : "conversation")) return null;
  return refKey(reference);
}

function objectValue(value: unknown): ObjectValue | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as ObjectValue : null;
}

export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value as ObjectValue).sort().map((key) => `${JSON.stringify(key)}:${canonical((value as ObjectValue)[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
