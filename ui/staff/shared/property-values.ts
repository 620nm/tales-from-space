import { t } from "@lunatic/ui";

export type PropertyPrimitive = null | string | number | boolean;
export type PropertyOption = PropertyPrimitive | { value: PropertyPrimitive; label: string };
export type PropertyType = "string" | "integer" | "number" | "boolean" | "enum" | "text" | "json" | "reference";

export interface PropertyChoice {
  value: string;
  text: string;
}

export function propertyOptionValue(option: PropertyOption): PropertyPrimitive {
  return isOptionObject(option) ? option.value : option;
}

export function propertyOptionLabel(option: PropertyOption): string {
  return isOptionObject(option) ? option.label : option === null ? t("engine.editor.compass.unset") : String(option);
}

/** Give each option a stable DOM value for its exact primitive identity. */
export function propertyOptionToken(option: PropertyOption): string {
  return `staff-option:${JSON.stringify(propertyOptionValue(option))}`;
}

export function propertyOptionChoices(options: readonly PropertyOption[]): PropertyChoice[] {
  return options.map((option) => ({ value: propertyOptionToken(option), text: propertyOptionLabel(option) }));
}

/** Normalize a nullable enum's clear value into the same option path as its values. */
export function nullablePropertyOptions(
  nullable: boolean | undefined,
  options: readonly PropertyOption[] | undefined,
): PropertyOption[] | undefined {
  if (options === undefined || !nullable || options.some((option) => Object.is(propertyOptionValue(option), null))) {
    return options === undefined ? undefined : [...options];
  }
  return [{ value: null, label: propertyOptionLabel(null) }, ...options];
}

/** Parse one disclosed option, preserving null while rejecting malformed objects. */
export function parsePropertyOption(value: unknown): PropertyOption | undefined {
  if (value === null || typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : undefined;
  const raw = value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
  if (!raw || !Object.hasOwn(raw, "label") || typeof raw.label !== "string" || !Object.hasOwn(raw, "value")) return undefined;
  const selected = raw.value;
  if (selected === null || typeof selected === "string" || typeof selected === "boolean") {
    return { value: selected, label: raw.label };
  }
  return typeof selected === "number" && Number.isFinite(selected)
    ? { value: selected, label: raw.label }
    : undefined;
}

/** Return the DOM token for the exact current primitive, if it is an option. */
export function propertyOptionDraft(
  value: PropertyPrimitive | null | undefined,
  options?: readonly PropertyOption[],
): string {
  if (value === undefined || !options?.length) return value === null || value === undefined ? "" : String(value);
  const option = options.find((candidate) => Object.is(propertyOptionValue(candidate), value));
  return option === undefined ? "" : propertyOptionToken(option);
}

/** Encode a live draft according to its disclosed descriptor, never by JSON guessing. */
export function propertyDraftJson(
  type: PropertyType | undefined,
  draft: string,
  options?: readonly PropertyOption[],
): string | undefined {
  const value = propertyDraftValue(type, draft, options);
  if (value === undefined) return undefined;
  const encoded = JSON.stringify(value);
  return typeof encoded === "string" ? encoded : undefined;
}

export function propertyDraftValue(
  type: PropertyType | undefined,
  draft: string,
  options?: readonly PropertyOption[],
): PropertyPrimitive | undefined {
  if (type === "boolean") {
    if (draft === "true") return true;
    if (draft === "false") return false;
    return undefined;
  }
  if (type === "integer") {
    if (!/^[+-]?\d+$/.test(draft.trim())) return undefined;
    const value = Number(draft);
    return Number.isSafeInteger(value) ? value : undefined;
  }
  if (type === "number") {
    if (!draft.trim()) return undefined;
    const value = Number(draft);
    return Number.isFinite(value) ? value : undefined;
  }
  if (type === "enum" || (type === "json" && options?.length)) {
    const option = options?.find((candidate) => propertyOptionToken(candidate) === draft);
    return option === undefined ? undefined : propertyOptionValue(option);
  }
  return draft;
}

function isOptionObject(value: PropertyOption): value is { value: PropertyPrimitive; label: string } {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
