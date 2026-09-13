import type { StaffCase, StaffEvent, StaffRef, StaffSession } from "../model";
import { accountRef, recordRef, refKey, staffRef } from "../model";

/** Event rows are addressed by durable SQLite cursor, never source sequence. */
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
  const ids = new Set(caseAddressedEvents(item).map((ref) => ref.id));
  return session.events.filter((event) => ids.has(event.reference.id) || event.caseId === item.id);
}

export function rowReference(round: string, cursor: string): StaffRef {
  return recordRef(round, cursor);
}
