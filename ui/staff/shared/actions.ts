import type { Json, UiNode } from "@lunatic/ui";
import { Button } from "@lunatic/ui";
import { bind, press } from "../../view";
import type { StaffRef, StaffSession } from "../model";
import { rememberStaffRead, resetReadIntents } from "../profile/read-intents";

export type StaffAction = Record<string, Json>;

let counter = 0;
let namespaceEpoch = 0;
let prefix = newPrefix();

/** A page/session namespace prevents a retry from colliding with an old tab. */
function newPrefix(): string {
  try {
    const cryptoApi = (globalThis as typeof globalThis & { crypto?: Crypto }).crypto;
    const uuid = cryptoApi && typeof cryptoApi.randomUUID === "function" ? cryptoApi.randomUUID() : undefined;
    if (uuid) return uuid.replace(/[^a-zA-Z0-9-]/g, "").slice(0, 64);
    if (cryptoApi && typeof cryptoApi.getRandomValues === "function") {
      const bytes = cryptoApi.getRandomValues(new Uint8Array(12));
      return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
    }
  } catch {
    // The native browser wrapper supplies a second random namespace at send time.
  }
  namespaceEpoch += 1;
  // The trusted host adds its cryptographic page namespace before transport.
  // Keep the pack-side fallback monotonic so a reset never reuses a prefix.
  return `session-${namespaceEpoch.toString(36)}`;
}

/** Begin a new request namespace on a round/session boundary. */
export function resetActionScope(): void {
  counter = 0;
  prefix = newPrefix();
  resetReadIntents();
}

/** Encode one pack action into the exact native StaffRequest envelope. */
export function staffRequest(session: StaffSession, action: StaffAction): Json {
  counter += 1;
  const requestId = `${prefix}-${counter}`;
  rememberStaffRead(session.roundId, requestId, action);
  return {
    kind: "staff",
    request: {
      request_id: requestId,
      round_id: session.roundId,
      revision: session.revision,
      action: encodeAction(action),
    },
  };
}

/** Records requests stay JSON text because the engine owns their schema. */
export function recordsRequest(op: string, fields: Record<string, Json> = {}): StaffAction {
  return { kind: "records", request: JSON.stringify({ op, ...fields }) };
}

/** A native staff press allocates its id only when the user activates it. */
export function nativePress(
  id: string,
  caption: unknown,
  session: StaffSession,
  action: StaffAction,
  opts: Parameters<typeof press>[3] = {},
): UiNode {
  return press(id, caption, () => staffRequest(session, action), opts);
}

/** A local button still goes through the package event table. */
export function localButton(id: string, caption: unknown, action: () => void, opts: Parameters<typeof Button>[2] = {}): UiNode {
  bind(id, () => { action(); return undefined; });
  return Button(id, caption, { ...opts, event: id });
}

function encodeAction(action: StaffAction): Record<string, Json> {
  const kind = typeof action.kind === "string" ? action.kind : "";
  switch (kind) {
    case "enter": return { Enter: null };
    case "exit": return { Exit: null };
    case "ghost": return { Ghost: null };
    case "reenter": return { Reenter: null };
    case "release": return { Release: null };
    case "camera": return { Camera: { pos: action.pos ?? {} } };
    case "inspect": return { Inspect: { target: action.target ?? {} } };
    case "query": return { Query: { query: String(action.query ?? "{}") } };
    case "freeze": return { Freeze: { target: String(action.target ?? "0"), on: action.on === true } };
    case "drive": return { Drive: { target: String(action.target ?? "0") } };
    case "records": return { Records: { request: String(action.request ?? "{}") } };
    case "round_control": return { RoundControl: { action: action.action ?? "" } };
    case "edit": return { Edit: { edit: encodeEdit((action.edit ?? {}) as StaffAction) } };
    default: return {};
  }
}

function encodeEdit(edit: StaffAction): Record<string, Json> {
  const kind = typeof edit.kind === "string" ? edit.kind : "";
  const body = { ...edit };
  delete body.kind;
  if (kind === "move") return { Move: body };
  if (kind === "delete") return { Delete: body };
  if (kind === "restore") return { Restore: body };
  if (kind === "kill") return { Kill: body };
  if (kind === "gib") return { Gib: body };
  if (kind === "duplicate") return { Duplicate: body };
  if (kind === "spawn") {
    const spawn = { ...body, kind: body.spawnKind ?? "entity", properties: body.properties ?? "{}" };
    delete spawn.spawnKind;
    return { Spawn: spawn };
  }
  if (kind === "property") return { Property: body };
  if (kind === "turf") return { Turf: body };
  return {};
}

/** Return an immutable copy for pending reviews and exact target actions. */
export function freezeReference(reference: StaffRef): StaffRef {
  // StaffRef is the wire's exact three-field type; labels stay local UI data.
  return { round: reference.round, kind: reference.kind, id: reference.id };
}
