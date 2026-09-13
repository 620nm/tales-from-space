import type { StaffRef } from "../model";

type PresentationPayload = Record<string, unknown> | null;

export interface HistoricalEventPresentation {
  time: string;
  target?: string;
  targetRef?: StaffRef;
}

const MS_PER_SECOND = 1_000;
const MS_PER_MINUTE = 60 * MS_PER_SECOND;
const MS_PER_HOUR = 60 * MS_PER_MINUTE;
const MS_PER_DAY = 24 * MS_PER_HOUR;
const MIN_UTC_MS = -8_640_000_000_000_000;
const MAX_UTC_MS = 8_640_000_000_000_000;

function padded(value: number, width: number): string {
  return String(value).padStart(width, "0");
}

function yearText(year: number): string {
  if (year >= 0 && year <= 9_999) return padded(year, 4);
  return `${year < 0 ? "-" : "+"}${padded(Math.abs(year), 6)}`;
}

/** Convert a bounded epoch millisecond value to a UTC calendar tuple. */
function utcCalendar(timestampMs: number): [number, number, number, number, number, number, number] {
  const days = Math.floor(timestampMs / MS_PER_DAY);
  const dayMs = timestampMs - days * MS_PER_DAY;
  const z = days + 719_468;
  const era = Math.floor(z / 146_097);
  const dayOfEra = z - era * 146_097;
  const yearOfEra = Math.floor((dayOfEra - Math.floor(dayOfEra / 1_460) + Math.floor(dayOfEra / 36_524) - Math.floor(dayOfEra / 146_096)) / 365);
  const yearBase = yearOfEra + era * 400;
  const dayOfYear = dayOfEra - (365 * yearOfEra + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100));
  const monthPart = Math.floor((5 * dayOfYear + 2) / 153);
  const day = dayOfYear - Math.floor((153 * monthPart + 2) / 5) + 1;
  const month = monthPart + (monthPart < 10 ? 3 : -9);
  const year = yearBase + (month <= 2 ? 1 : 0);
  const hour = Math.floor(dayMs / MS_PER_HOUR);
  const minuteMs = dayMs - hour * MS_PER_HOUR;
  const minute = Math.floor(minuteMs / MS_PER_MINUTE);
  const secondMs = minuteMs - minute * MS_PER_MINUTE;
  const second = Math.floor(secondMs / MS_PER_SECOND);
  const millisecond = secondMs - second * MS_PER_SECOND;
  return [year, month, day, hour, minute, second, millisecond];
}

/** Render a source timestamp without depending on the browser's locale. */
export function historicalEventTime(explicit: unknown, createdAtMs: unknown, fallback = "—"): string {
  if (typeof explicit === "string" || typeof explicit === "number") return String(explicit);
  if (typeof createdAtMs !== "number" || !Number.isSafeInteger(createdAtMs)
    || createdAtMs < MIN_UTC_MS || createdAtMs > MAX_UTC_MS) return fallback;
  const [year, month, day, hour, minute, second, millisecond] = utcCalendar(createdAtMs);
  return `${yearText(year)}-${padded(month, 2)}-${padded(day, 2)} ${padded(hour, 2)}:${padded(minute, 2)}:${padded(second, 2)}.${padded(millisecond, 3)} UTC`;
}

function identifier(value: unknown): string | undefined {
  if (typeof value === "string") return value.length ? value : undefined;
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? String(value) : undefined;
}

/** Resolve only an exact historical ref; unrelated refs never become targets. */
export function historicalEventPresentation(
  eventType: string,
  payload: PresentationPayload,
  refs: readonly StaffRef[],
  readRef: (value: unknown) => StaffRef | null,
  createdAtMs: unknown,
): HistoricalEventPresentation {
  const explicitTargetRef = readRef(payload?.target_ref);
  const payloadTarget = identifier(payload?.target);
  const eventName = typeof payload?.event === "string" ? payload.event : eventType;
  const itemTarget = eventName === "item_spawned" ? identifier(payload?.item_id) : undefined;
  const targetId = payloadTarget ?? itemTarget;
  const targetRef = explicitTargetRef
    ?? (targetId ? refs.find((ref) => ref.id === targetId) : undefined);
  const target = targetRef?.id ?? targetId;
  return {
    time: historicalEventTime(payload?.time, createdAtMs),
    ...(target === undefined ? {} : { target }),
    ...(targetRef ? { targetRef } : {}),
  };
}
