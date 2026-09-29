import type { Json, UiNode } from "@lunatic/ui";
import { Card, LabeledList, Section, Stack } from "@lunatic/ui";
import { entry, press, select, text } from "../view";
import type { StaffRef, StaffSession } from "./model";
import { staffLocal } from "./actions";
import { canonical } from "./profile/read-intents";
import { recordResponse } from "./cases/records";
import { staffRequest } from "./shared/actions";
import * as S from "./strings";

type EconomySubjectKind = "item_uuid" | "lot" | "balance" | "entitlement" | "source_event" | "transaction" | "player_time";
type EconomySelectorValue = string | { player: string; from: string; to: string };
type ObjectValue = Record<string, unknown>;
type DefinitionMirrorState = "missing" | "incomplete" | "complete" | "conflict" | "unknown";

interface EconomyPage {
  query: ObjectValue;
  requestId: string;
  sourceDb: string;
  rows: ObjectValue[];
  next: string | null;
  completeness: ObjectValue | null;
  anomalies: ObjectValue[];
  anomaliesMore: boolean;
  error: string | null;
}

interface PendingEconomyRead {
  kind: "economy";
  round: string;
  requestId: string;
  queryKey: string;
  query: ObjectValue;
}

interface PendingDefinitionRead {
  kind: "economy_definition";
  round: string;
  requestId: string;
  queryKey: string;
  query: ObjectValue;
}

interface DefinitionPage {
  query: ObjectValue;
  requestId: string;
  sourceDb: string;
  digest: string;
  offset: string;
  nextOffset: string | null;
  totalBytes: string | null;
  owner: string;
  formatVersion: string;
  encoding: string;
  payload: string;
  state: DefinitionMirrorState;
  complete: boolean;
  available: boolean;
  error: string | null;
}

let pending: PendingEconomyRead | PendingDefinitionRead | null = null;
let page: EconomyPage | null = null;
let definition: DefinitionPage | null = null;
let pageRound = "";

/** The server-owned exact economy query envelope. Keep this helper stable for tests and callers. */
export function exactRecordQuery(
  sourceDb: string,
  selector: { kind: EconomySubjectKind; value: EconomySelectorValue },
  after: string | null = null,
): Record<string, Json> {
  return {
    kind: "query",
    query: JSON.stringify({
      op: "economy",
      source_db: sourceDb,
      selector,
      after,
      limit: 64,
    }),
  };
}

/** Economy responses use the same request/query correlation as profile reads. */
export function economyViewAction(session: StaffSession | null): Json | undefined {
  if (!session || !pending || pending.round !== session.roundId) return undefined;
  const response = recordResponse(session);
  if (!response || String(response.request_id ?? "") !== pending.requestId) return undefined;
  if (canonical(response.query) !== pending.queryKey) return undefined;
  const result = objectValue(response.result);
  const responseError = stringValue(response.error);
  const resultError = stringValue(result?.error);
  if (pending.kind === "economy_definition") {
    if ((!result || result.kind !== "economy_definition") && !responseError && !resultError) return undefined;
    const query = pending.query;
    const state = definitionMirrorState(result?.state);
    const payload = stringValue(result?.payload ?? result?.bytes ?? result?.data);
    definition = {
      query,
      requestId: pending.requestId,
      sourceDb: stringValue(result?.source_db, stringValue(query.source_db)),
      digest: stringValue(result?.digest, stringValue(query.digest)),
      offset: decimalString(result?.offset ?? query.offset) ?? "0",
      nextOffset: cursorValue(result?.next_offset),
      totalBytes: decimalString(result?.total_bytes),
      owner: stringValue(result?.owner),
      formatVersion: decimalString(result?.format_version) ?? "",
      encoding: stringValue(result?.encoding, "base64"),
      payload,
      state,
      complete: state === "complete" && result?.complete === true,
      available: result?.available === true && !responseError && !resultError,
      error: responseError || resultError || null,
    };
    pending = null;
    return undefined;
  }
  if ((!result || result.kind !== "economy") && !responseError && !resultError) return undefined;
  page = {
    query: pending.query,
    requestId: pending.requestId,
    sourceDb: stringValue(result?.source_db, stringValue(pending.query.source_db)),
    rows: rowsValue(result?.rows),
    next: cursorValue(result?.next),
    completeness: objectValue(result?.completeness),
    anomalies: objectRows(result?.anomalies),
    anomaliesMore: result?.anomalies_more === true,
    error: responseError || resultError || null,
  };
  pending = null;
  return undefined;
}

export function resetEconomyReads(): void {
  pending = null;
  page = null;
  definition = null;
  pageRound = "";
}

export function economyWorkspace(session: StaffSession): UiNode {
  ensureRound(session.roundId);
  return {
    id: "staff/economy/layout",
    type: "row",
    class: ["staff-cases-layout"],
    children: [economySelector(session), economyResults(session)],
  };
}

function economySelector(session: StaffSession): UiNode {
  const state = staffLocal(session);
  const draft = state.economy;
  const choices = [
    ["item_uuid", S.ECONOMY_ITEM],
    ["lot", S.ECONOMY_LOT],
    ["balance", S.ECONOMY_BALANCE],
    ["entitlement", S.ECONOMY_ENTITLEMENT],
    ["source_event", S.ECONOMY_SOURCE_EVENT],
    ["transaction", S.ECONOMY_TRANSACTION],
    ["player_time", S.ECONOMY_PLAYER_TIME],
  ] as Array<[EconomySubjectKind, string]>;
  const controls: UiNode[] = [
    text("staff/economy/selector/kicker", S.ECONOMY_TITLE, ["staff-eyebrow"]),
    text("staff/economy/selector/title", S.ECONOMY_SELECTOR, ["staff-title"]),
    entry("staff/economy/source-db", draft.sourceDb, (value) => { draft.sourceDb = value; invalidateEconomyPage(); draft.after = null; return undefined; }, { label: S.ECONOMY_SOURCE_DB, cls: ["staff-economy-field"] }),
    select("staff/economy/subject-kind", draft.subjectKind, choices.map(([value, label]) => ({ value, text: label })), (value) => {
      if (isSubjectKind(value)) draft.subjectKind = value;
      invalidateEconomyPage();
      draft.after = null;
      return undefined;
    }, { cls: ["staff-economy-field"] }),
    entry("staff/economy/subject", draft.subject, (value) => { draft.subject = value; invalidateEconomyPage(); draft.after = null; return undefined; }, { label: S.ECONOMY_VALUE, cls: ["staff-economy-field"] }),
  ];
  if (draft.subjectKind === "player_time") {
    controls.push(
      entry("staff/economy/player-from", draft.playerFrom, (value) => { draft.playerFrom = value; invalidateEconomyPage(); draft.after = null; return undefined; }, { label: S.ECONOMY_FROM, cls: ["staff-economy-field"] }),
      entry("staff/economy/player-to", draft.playerTo, (value) => { draft.playerTo = value; invalidateEconomyPage(); draft.after = null; return undefined; }, { label: S.ECONOMY_TO, cls: ["staff-economy-field"] }),
      text("staff/economy/player-hint", S.ECONOMY_PLAYER_TIME_HINT, ["staff-muted"]),
    );
  }
  controls.push(press("staff/economy/lookup", S.ECONOMY_LOOKUP, () => requestCurrent(session), { variant: "primary" }));
  if (pending?.round === session.roundId) controls.push(text("staff/economy/loading", S.ECONOMY_LOADING, ["staff-muted"]));
  return Card("staff/economy/selector", controls, { cls: ["staff-case-rail", "staff-economy-selector"] });
}

function economyResults(session: StaffSession): UiNode {
  ensureRound(session.roundId);
  const current = page;
  if (!current) return Card("staff/economy/results", [text("staff/economy/results/empty", S.ECONOMY_EMPTY, ["staff-muted"])], { cls: ["staff-case-timeline", "staff-economy-results"] });
  const status = completenessStatus(current.completeness);
  const rows = current.rows.map((row, index) => economyRow(session, row, index, current.sourceDb));
  const children = [
    Stack("staff/economy/results/head", [
      text("staff/economy/results/kicker", S.ECONOMY_EVIDENCE, ["staff-eyebrow"]),
      text("staff/economy/results/title", economyQueryTitle(current.query), ["staff-section-title"]),
      text("staff/economy/results/count", `${rows.length} · ${current.sourceDb || S.ECONOMY_UNKNOWN_VALUE}`, ["staff-mono"]),
    ], { cls: ["staff-timeline-heading"], gap: 6, align: "center" }),
    completenessCard(status, current.completeness),
    current.error ? text("staff/economy/results/error", S.ECONOMY_ERROR(current.error), ["staff-warning"]) : null,
    current.anomalies.length ? anomalyCard(session, current.anomalies, current.sourceDb, current.anomaliesMore) : text("staff/economy/results/no-anomalies", S.ECONOMY_NO_ANOMALIES, ["staff-muted"]),
    definitionCard(session),
    rows.length ? Stack("staff/economy/results/rows", rows, { gap: 7 }) : text("staff/economy/results/none", S.ECONOMY_EMPTY, ["staff-muted"]),
    current.next ? press("staff/economy/results/next", S.ECONOMY_NEXT, () => issueQuery(session, queryAction(current.query, current.next!)), { variant: "ghost" }) : null,
  ];
  return Card("staff/economy/results", children.filter(Boolean) as UiNode[], { cls: ["staff-case-timeline", "staff-economy-results"] });
}

function economyRow(session: StaffSession, row: ObjectValue, index: number, sourceDb: string): UiNode {
  const sequence = stringValue(row.sequence, String(index + 1));
  const receipt = row.receipt;
  const refs = refsValue(row.refs);
  const refCount = countValue(row.ref_count, refs.length);
  const refsMore = row.refs_more === true;
  const evidence = refCount > 0
    ? Stack(`staff/economy/row/${sequence}/refs`, [
      text(`staff/economy/row/${sequence}/refs/count`, `${S.ECONOMY_REFERENCES} · ${refs.length}/${refCount}`, ["staff-muted"]),
      refs.length ? Stack(`staff/economy/row/${sequence}/refs/list`, refs.map((ref, refIndex) => drillButton(session, `staff/economy/row/${sequence}/ref/${refIndex}`, ref, sourceDb)), { cls: ["staff-chain"], gap: 4, wrap: true }) : null,
      refsMore ? text(`staff/economy/row/${sequence}/refs/more`, S.ECONOMY_REFERENCES_MORE, ["staff-warning"]) : null,
    ].filter(Boolean) as UiNode[], { gap: 4 })
    : text(`staff/economy/row/${sequence}/refs/empty`, S.ECONOMY_UNKNOWN_VALUE, ["staff-muted"]);
  return Card(`staff/economy/row/${sequence}`, [
    Stack(`staff/economy/row/${sequence}/head`, [
      text(`staff/economy/row/${sequence}/sequence`, `${S.RECORDS} · ${sequence}`, ["staff-mono"]),
      text(`staff/economy/row/${sequence}/status`, receiptStatusText(receipt), ["staff-event-action"]),
    ], { cls: ["staff-timeline-heading"], gap: 6, align: "center" }),
    evidence,
    receiptEvidence(`staff/economy/row/${sequence}/receipt`, receipt, session, sourceDb),
  ], { cls: ["staff-economy-row"] });
}

function receiptEvidence(id: string, receipt: unknown, session: StaffSession, sourceDb: string): UiNode {
  const raw = objectValue(receipt);
  if (!raw) return text(`${id}/unknown`, S.ECONOMY_UNKNOWN_VALUE, ["staff-muted"]);
  const attempt = objectValue(raw.attempt);
  const status = receiptStatus(raw.status);
  const fields = [
    ["world", raw.world_id], ["account", raw.account_id], ["transaction", attempt?.transaction_id],
    ["semantic", raw.semantic_digest], ["inputs", raw.semantic_inputs], ["entitlement", raw.entitlement],
    ["mutations", raw.mutations], ["receipt", raw.receipt_digest],
  ].filter((row): row is [string, unknown] => row[1] !== undefined && row[1] !== null);
  const refs = nestedRefs(raw.semantic_inputs, raw.entitlement, raw.mutations);
  const definitions = definitionDigests(raw);
  const drilldowns = refs.length
    ? Stack(`${id}/drilldowns`, refs.map((ref, index) => drillButton(session, `${id}/drilldown/${index}`, ref, sourceDb)), { cls: ["staff-chain"], gap: 4, wrap: true })
    : text(`${id}/drilldowns/empty`, S.ECONOMY_UNKNOWN_VALUE, ["staff-muted"]);
  const definitionDrilldowns = definitions.length
    ? Stack(`${id}/definitions`, definitions.map((digest, index) => definitionButton(session, `${id}/definition/${index}`, sourceDb, digest)), { cls: ["staff-chain"], gap: 4, wrap: true })
    : text(`${id}/definitions/empty`, S.ECONOMY_UNKNOWN_VALUE, ["staff-muted"]);
  return Section(id, S.ECONOMY_RECEIPTS, [
    fields.length
      ? Stack(`${id}/values`, fields.map(([key, value]) => text(`${id}/${String(key)}`, `${String(key)} · ${compactValue(value)}`, ["staff-event-actor"])), { gap: 3 })
      : text(`${id}/empty`, S.ECONOMY_UNKNOWN_VALUE, ["staff-muted"]),
    text(`${id}/status`, `${status.label}${status.detail ? ` · ${status.detail}` : ""}`, [status.label === "Committed" ? "staff-good" : "staff-warning"]),
    text(`${id}/drilldowns/title`, `${S.ECONOMY_DRILL} · ${S.ECONOMY_CUSTODY} · ${S.ECONOMY_LOTS}`, ["staff-eyebrow"]),
    drilldowns,
    text(`${id}/definitions/title`, S.ECONOMY_DEFINITIONS, ["staff-eyebrow"]),
    definitionDrilldowns,
  ], { cls: ["staff-economy-evidence"] });
}

function completenessCard(status: ReturnType<typeof completenessStatus>, completeness: ObjectValue | null): UiNode {
  const statusText = status === "clean" ? S.ECONOMY_CLEAN : status === "incomplete" ? S.ECONOMY_INCOMPLETE : status === "unknown" ? S.ECONOMY_UNKNOWN : S.ECONOMY_INCOMPLETE;
  const lag = completeness ? projectionLag(completeness.source_highwater, completeness.cursor) : null;
  const fields: Array<[string, unknown]> = completeness ? [
    [S.ECONOMY_COMPLETENESS, status],
    [S.ECONOMY_LAG, lag ?? S.ECONOMY_UNKNOWN_VALUE],
    [S.TIME, decimalString(completeness.sampled_at_ms) ?? S.ECONOMY_UNKNOWN_VALUE],
  ] : [[S.ECONOMY_COMPLETENESS, S.ECONOMY_UNKNOWN]];
  const error = stringValue(completeness?.error);
  return Card("staff/economy/completeness", [
    text("staff/economy/completeness/title", `${S.ECONOMY_COMPLETENESS} · ${status}`, [status === "clean" ? "staff-good" : "staff-warning"]),
    text("staff/economy/completeness/status", statusText, ["staff-muted"]),
    error ? text("staff/economy/completeness/error", S.ECONOMY_ERROR(error), ["staff-warning"]) : null,
    LabeledList("staff/economy/completeness/values", fields.map(([label, value]) => ({ label, value: compactValue(value) }))),
  ].filter(Boolean) as UiNode[], { cls: ["staff-economy-status"] });
}

function anomalyCard(session: StaffSession, anomalies: ObjectValue[], sourceDb: string, more: boolean): UiNode {
  return Card("staff/economy/anomalies", [
    text("staff/economy/anomalies/title", `${S.ECONOMY_ANOMALIES} · ${anomalies.length}`, ["staff-warning"]),
    more ? text("staff/economy/anomalies/more", S.ECONOMY_ANOMALIES_MORE, ["staff-warning"]) : null,
    Stack("staff/economy/anomalies/list", anomalies.slice(0, 64).map((anomaly, index) => {
      const refs = refsValue(anomaly.evidence_refs);
      const refCount = countValue(anomaly.evidence_ref_count, refs.length);
      const refsMore = anomaly.evidence_refs_more === true;
      return Card(`staff/economy/anomaly/${index}`, [
        text(`staff/economy/anomaly/${index}/code`, stringValue(anomaly.code, S.ECONOMY_UNKNOWN_VALUE), ["staff-event-action"]),
        text(`staff/economy/anomaly/${index}/evidence`, compactValue(anomaly.evidence), ["staff-muted"]),
        refCount > 0 ? Stack(`staff/economy/anomaly/${index}/refs`, [
          text(`staff/economy/anomaly/${index}/refs/count`, `${S.ECONOMY_REFERENCES} · ${refs.length}/${refCount}`, ["staff-muted"]),
          refs.length ? Stack(`staff/economy/anomaly/${index}/refs/list`, refs.map((ref, refIndex) => drillButton(session, `staff/economy/anomaly/${index}/ref/${refIndex}`, ref, sourceDb)), { cls: ["staff-chain"], gap: 4, wrap: true }) : null,
          refsMore ? text(`staff/economy/anomaly/${index}/refs/more`, S.ECONOMY_REFERENCES_MORE, ["staff-warning"]) : null,
        ].filter(Boolean) as UiNode[], { gap: 4 }) : null,
      ].filter(Boolean) as UiNode[], { cls: ["staff-economy-anomaly"] });
    }), { gap: 4 }),
  ], { cls: ["staff-economy-anomaly-panel"] });
}

function drillButton(session: StaffSession, id: string, ref: StaffRef, sourceDb: string): UiNode {
  if (ref.kind === "economy_definition") return definitionButton(session, id, sourceDb, ref.id);
  if (!refSelector(ref)) return text(id, `${ref.kind} · ${ref.id}`, ["staff-muted"]);
  return press(id, `${ref.kind} · ${ref.id}`, () => requestRef(session, sourceDb, ref), { variant: "ghost", cls: ["staff-record-button"] });
}

function definitionButton(session: StaffSession, id: string, sourceDb: string, digest: string): UiNode {
  return press(id, `${S.ECONOMY_DEFINITION} · ${digest}`, () => requestDefinition(session, sourceDb, digest), { variant: "ghost", cls: ["staff-record-button"] });
}

function requestDefinition(session: StaffSession, sourceDb: string, digest: string, offset = "0"): Record<string, Json> | undefined {
  if (!validText(sourceDb) || !isDigest(digest) || !decimalString(offset)) return undefined;
  const action = exactDefinitionQuery(sourceDb, digest, offset);
  const request = staffRequest(session, action);
  const raw = objectValue(action);
  const query = raw?.query && typeof raw.query === "string" ? parseObject(raw.query) : null;
  const envelope = objectValue(request);
  const requestId = objectValue(envelope?.request)?.request_id;
  if (query && typeof requestId === "string") {
    pending = { kind: "economy_definition", round: session.roundId, requestId, queryKey: canonical(query), query };
    definition = null;
  }
  return request;
}

/** The read is served by the audit mirror; source databases are never contacted by this UI. */
export function exactDefinitionQuery(sourceDb: string, digest: string, offset = "0"): Record<string, Json> {
  return {
    kind: "query",
    query: JSON.stringify({
      op: "economy_definition",
      source_db: sourceDb,
      digest,
      offset,
      limit: 64 * 1024,
    }),
  };
}

function definitionCard(session: StaffSession): UiNode | null {
  const current = definition;
  if (!current) return null;
  const metadata = [
    [S.ECONOMY_DEFINITION_DIGEST, current.digest],
    [S.ECONOMY_DEFINITION_STATE, current.state],
    [S.ECONOMY_DEFINITION_OWNER, current.owner || S.ECONOMY_UNKNOWN_VALUE],
    [S.ECONOMY_DEFINITION_VERSION, current.formatVersion || S.ECONOMY_UNKNOWN_VALUE],
    [S.ECONOMY_DEFINITION_OFFSET, current.offset],
    [S.ECONOMY_DEFINITION_TOTAL, current.totalBytes ?? S.ECONOMY_UNKNOWN_VALUE],
    [S.ECONOMY_DEFINITION_ENCODING, current.encoding],
  ];
  const hasContinuation = current.available && current.payload.length > 0 && current.nextOffset !== null;
  const status = current.state === "incomplete"
    ? S.ECONOMY_DEFINITION_INCOMPLETE
    : current.error || !current.available
      ? S.ECONOMY_DEFINITION_UNAVAILABLE
      : current.complete
        ? S.ECONOMY_DEFINITION_COMPLETE
        : hasContinuation
          ? S.ECONOMY_DEFINITION_CONTINUATION
          : S.ECONOMY_DEFINITION_UNAVAILABLE;
  const continuation = hasContinuation
    ? press("staff/economy/definition/next", S.ECONOMY_NEXT, () => requestDefinition(session, current.sourceDb, current.digest, current.nextOffset!), { variant: "ghost" })
    : null;
  const statusClass = current.state === "complete" && current.complete && current.available ? ["staff-good"] : ["staff-warning"];
  return Card("staff/economy/definition", [
    text("staff/economy/definition/title", `${S.ECONOMY_DEFINITION} · ${current.digest}`, ["staff-section-title"]),
    text("staff/economy/definition/status", status, statusClass),
    current.error ? text("staff/economy/definition/error", S.ECONOMY_ERROR(current.error), ["staff-warning"]) : null,
    LabeledList("staff/economy/definition/metadata", metadata.map(([label, value]) => ({ label, value: String(value) }))),
    current.available ? text("staff/economy/definition/payload", current.payload || S.ECONOMY_UNKNOWN_VALUE, ["staff-mono", "staff-definition-payload"]) : null,
    continuation,
  ].filter(Boolean) as UiNode[], { cls: ["staff-economy-definition"] });
}

function requestCurrent(session: StaffSession): Record<string, Json> | undefined {
  const state = staffLocal(session).economy;
  if (!validText(state.sourceDb)) return undefined;
  const value = state.subjectKind === "player_time" ? playerTimeValue(state.subject, state.playerFrom, state.playerTo) : state.subject;
  if (value === null || (state.subjectKind !== "player_time" && !validText(state.subject))) return undefined;
  state.after = null;
  return issueQuery(session, exactRecordQuery(state.sourceDb, { kind: state.subjectKind, value }, null));
}

function requestRef(session: StaffSession, sourceDb: string, ref: StaffRef): Record<string, Json> | undefined {
  const kind = refSelector(ref);
  if (!kind || !validText(sourceDb) || !validText(ref.id)) return undefined;
  const state = staffLocal(session).economy;
  state.sourceDb = sourceDb;
  state.subjectKind = kind;
  state.subject = ref.id;
  state.after = null;
  return issueQuery(session, exactRecordQuery(sourceDb, { kind, value: ref.id }, null));
}

function queryAction(query: ObjectValue, after: string): Record<string, Json> {
  return { kind: "query", query: JSON.stringify({ ...query, after }) };
}

function issueQuery(session: StaffSession, action: Record<string, Json>): Record<string, Json> {
  const raw = objectValue(action);
  const query = raw?.query && typeof raw.query === "string" ? parseObject(raw.query) : null;
  const request = staffRequest(session, action);
  const envelope = objectValue(request);
  const requestId = objectValue(envelope?.request)?.request_id;
  if (query && typeof requestId === "string") {
    if (query.op === "economy") {
      staffLocal(session).economy.after = cursorValue(query.after);
      pending = { kind: "economy", round: session.roundId, requestId, queryKey: canonical(query), query };
    }
  }
  return request as Record<string, Json>;
}

function ensureRound(round: string): void {
  if (pageRound === round) return;
  pageRound = round;
  page = null;
  definition = null;
  pending = null;
}

function invalidateEconomyPage(): void {
  pending = null;
  page = null;
  definition = null;
}

function completenessStatus(value: ObjectValue | null): "clean" | "incomplete" | "unknown" | "hash_conflict" {
  const status = stringValue(value?.status);
  if (status === "clean" || status === "incomplete" || status === "unknown" || status === "hash_conflict") return status;
  return "unknown";
}

function receiptStatus(value: unknown): { label: string; detail: string | null } {
  const raw = objectValue(value);
  if (value === "Committed") return { label: "Committed", detail: null };
  const rejected = raw?.Rejected;
  if (rejected !== undefined) return { label: "Rejected", detail: rejectionDetail(rejected) };
  return { label: S.ECONOMY_UNKNOWN_VALUE, detail: null };
}

function receiptStatusText(value: unknown): string {
  const status = receiptStatus(value);
  return status.detail ? `${status.label} · ${status.detail}` : status.label;
}

function rejectionDetail(value: unknown): string | null {
  if (typeof value === "string") return value;
  const raw = objectValue(value);
  return raw ? stringValue(raw.code) || compactValue(raw) : null;
}

function refSelector(ref: StaffRef): EconomySubjectKind | null {
  switch (ref.kind) {
    case "economy_item": return "item_uuid";
    case "economy_mint_lot": return "lot";
    case "economy_balance": return "balance";
    case "economy_entitlement": return "entitlement";
    case "economy_source_event": return "source_event";
    case "economy_transaction": return "transaction";
    default: return null;
  }
}

function definitionDigests(receipt: ObjectValue): string[] {
  const found: string[] = [];
  const add = (value: unknown): void => {
    const digest = digestValue(value);
    if (digest && !found.includes(digest)) found.push(digest);
  };
  const inputs = objectValue(receipt.semantic_inputs);
  add(inputs?.content);
  if (Array.isArray(inputs?.definitions)) for (const value of inputs.definitions) add(value);
  const entitlement = objectValue(receipt.entitlement);
  const evidence = objectValue(entitlement?.evidence);
  const eligibility = objectValue(evidence?.eligibility);
  add(eligibility?.rule_definition);
  add(evidence?.rule_definition);
  add(evidence?.table_definition);
  add(evidence?.formula_definition);
  add(evidence?.rng_algorithm);
  if (Array.isArray(evidence?.modifiers)) for (const modifier of evidence.modifiers) add(objectValue(modifier)?.definition);
  const attempt = objectValue(receipt.attempt);
  if (Array.isArray(attempt?.mutations)) for (const mutation of attempt.mutations) add(objectValue(mutation)?.definition);
  for (const mutation of Array.isArray(receipt.mutations) ? receipt.mutations : []) add(objectValue(mutation)?.definition);
  return found.slice(0, 64);
}

function digestValue(value: unknown): string | null {
  if (typeof value === "string") return isDigest(value) ? value.toLowerCase() : null;
  if (!Array.isArray(value) || value.length !== 32 || value.some((byte) => typeof byte !== "number" || !Number.isInteger(byte) || byte < 0 || byte > 255)) return null;
  return value.map((byte) => (byte as number).toString(16).padStart(2, "0")).join("");
}

function isDigest(value: string): boolean {
  return /^[0-9a-fA-F]{64}$/.test(value);
}

function definitionMirrorState(value: unknown): DefinitionMirrorState {
  if (value === "missing" || value === "incomplete" || value === "complete" || value === "conflict") return value;
  return "unknown";
}

function playerTimeValue(player: string, from: string, to: string): EconomySelectorValue | null {
  if (!validText(player) || !decimalString(from) || !decimalString(to)) return null;
  if (compareDecimal(from, to) > 0) return null;
  return { player, from: decimalString(from)!, to: decimalString(to)! };
}

function economyQueryTitle(query: ObjectValue): string {
  const selector = objectValue(query.selector);
  const value = selector?.value;
  if (typeof value === "string" && value.length > 0) return value;
  const range = objectValue(value);
  return stringValue(range?.player, S.ECONOMY_UNKNOWN_VALUE);
}

function projectionLag(highwater: unknown, cursor: unknown): string | null {
  const high = decimalString(highwater);
  const current = decimalString(cursor);
  if (!high || !current || compareDecimal(high, current) < 0) return null;
  return subtractDecimal(high, current);
}

function validText(value: string): boolean {
  return value.length > 0 && value.length <= 512 && ![...value].some((character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127);
}

function refsValue(value: unknown): StaffRef[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 64).map((row) => {
    const raw = objectValue(row);
    if (!raw || typeof raw.kind !== "string" || typeof raw.id !== "string") return null;
    return { round: typeof raw.round === "string" ? raw.round : "", kind: raw.kind, id: raw.id };
  }).filter((ref): ref is StaffRef => !!ref && ref.id.length > 0);
}

function nestedRefs(...values: unknown[]): StaffRef[] {
  const found: StaffRef[] = [];
  const visit = (value: unknown, depth: number): void => {
    if (depth > 4 || found.length >= 64) return;
    const raw = objectValue(value);
    if (raw && typeof raw.kind === "string" && typeof raw.id === "string") {
      found.push({ round: typeof raw.round === "string" ? raw.round : "", kind: raw.kind, id: raw.id });
      return;
    }
    if (Array.isArray(value)) {
      for (const row of value.slice(0, 64)) visit(row, depth + 1);
    } else if (raw) {
      for (const row of Object.values(raw).slice(0, 64)) visit(row, depth + 1);
    }
  };
  for (const value of values) visit(value, 0);
  return [...new Map(found.map((ref) => [`${ref.round}:${ref.kind}:${ref.id}`, ref])).values()];
}

function rowsValue(value: unknown): ObjectValue[] {
  return Array.isArray(value) ? value.slice(0, 64).map(objectValue).filter((row): row is ObjectValue => !!row) : [];
}

function objectRows(value: unknown): ObjectValue[] {
  return Array.isArray(value) ? value.slice(0, 64).map(objectValue).filter((row): row is ObjectValue => !!row) : [];
}

function objectValue(value: unknown): ObjectValue | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as ObjectValue : null;
}

function parseObject(value: string): ObjectValue | null {
  try { return objectValue(JSON.parse(value)); } catch { return null; }
}

function stringValue(value: unknown, fallback = ""): string {
  return typeof value === "string" || typeof value === "number" ? String(value) : fallback;
}

function countValue(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : fallback;
}

function cursorValue(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  return decimalString(value);
}

function decimalString(value: unknown): string | null {
  if (typeof value === "number") return Number.isSafeInteger(value) && value >= 0 ? String(value) : null;
  if (typeof value !== "string" || !/^\d+$/.test(value)) return null;
  return value.replace(/^0+(?=\d)/, "");
}

function compareDecimal(left: string, right: string): number {
  const a = left.replace(/^0+(?=\d)/, "");
  const b = right.replace(/^0+(?=\d)/, "");
  return a.length !== b.length ? a.length - b.length : a < b ? -1 : a === b ? 0 : 1;
}

function subtractDecimal(left: string, right: string): string {
  const a = left.replace(/^0+(?=\d)/, "").split("").reverse().map(Number);
  const b = right.replace(/^0+(?=\d)/, "").split("").reverse().map(Number);
  const result: number[] = [];
  let borrow = 0;
  for (let index = 0; index < a.length; index += 1) {
    let digit = a[index] - borrow - (b[index] ?? 0);
    if (digit < 0) { digit += 10; borrow = 1; } else borrow = 0;
    result.push(digit);
  }
  return result.reverse().join("").replace(/^0+(?=\d)/, "") || "0";
}

function compactValue(value: unknown): string {
  if (value === null || value === undefined) return S.ECONOMY_UNKNOWN_VALUE;
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  try {
    const encoded = JSON.stringify(value);
    return encoded && encoded.length > 280 ? `${encoded.slice(0, 277)}…` : encoded ?? S.ECONOMY_UNKNOWN_VALUE;
  } catch {
    return S.ECONOMY_UNKNOWN_VALUE;
  }
}

function isSubjectKind(value: string): value is EconomySubjectKind {
  return ["item_uuid", "lot", "balance", "entitlement", "source_event", "transaction", "player_time"].includes(value);
}
