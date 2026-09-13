/** The minimal wire-reference shape needed to build a collision-proof key. */
export interface RefKeyValue {
  round: string;
  kind: string;
  id: string;
}

/**
 * The one collision-proof ref key for the staff and contact packages. A
 * colon join folds distinct refs together: the wire charset lets ':'
 * occur inside `kind` and `id` (lunatic-core's `validate_identifier`),
 * so a colon landing in one field can shift where the next field's
 * boundary appears to be. `staff/model.ts`, `staff/cases/records.ts`,
 * and `contact/model.ts` all share this rather than defining their own.
 */
export const refKey = (value: RefKeyValue | null | undefined): string =>
  value ? JSON.stringify([value.round, value.kind, value.id]) : "";
