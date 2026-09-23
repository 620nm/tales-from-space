import type { StaffCase, StaffEvent, StaffRef, StaffSession } from "../model";
import { accountRef, recordRef, refKey, staffRef } from "../model";

/** A ledger row is addressed by its round and `seq` together; `seq` alone repeats across rounds. */
export function eventReference(event: StaffEvent): StaffRef {
  return { round: event.reference.round, kind: "event", id: event.reference.id };
}

export function caseReference(item: StaffCase): StaffRef {
  return { round: item.reference.round, kind: "case", id: item.reference.id };
}

export function entityReference(session: StaffSession, id: string, label?: string): StaffRef | null {
  const entity = session.entities.find((candidate) => candidate.id === id);
  return entity ? { ...entity.ref, ...(label ? { label } : {}) } : null;
}

export function profileReference(id: string, label?: string): StaffRef {
  return accountRef(id, label);
}

export function sourceSequence(event: StaffEvent): string | null {
  return event.sourceSeq ?? null;
}

/** Canonical event references for the case evidence rail, deduplicated in order. */
export function caseEventReferences(item: StaffCase): StaffRef[] {
  const values = [...item.anchorHistory, ...item.addressedEvents, ...item.attachments];
  return [...new Map(values.map((value) => [refKey(value), value])).values()];
}

export function caseAddressedEvents(item: StaffCase): StaffRef[] {
  return item.addressedEvents.filter((value) => value.kind === "event");
}

export function eventsForCase(session: StaffSession, item: StaffCase | null): StaffEvent[] {
  if (!item) return [];
  const keys = new Set(caseAddressedEvents(item).map(refKey));
  return session.events.filter((event) => keys.has(refKey(event.reference)) || event.caseId === item.id);
}

export function rowReference(round: string, seq: string): StaffRef {
  return recordRef(round, seq);
}

/** Decimal id text in numeric order: shorter is smaller, then digit by digit. */
export function compareDecimalIds(left: string, right: string): number {
  return left.length - right.length || (left < right ? -1 : left > right ? 1 : 0);
}

/** Rows in ledger order: by round, then by `seq`, both numeric. */
export function compareEventOrder(left: StaffEvent, right: StaffEvent): number {
  return compareDecimalIds(left.reference.round, right.reference.round)
    || compareDecimalIds(left.reference.id, right.reference.id);
}
