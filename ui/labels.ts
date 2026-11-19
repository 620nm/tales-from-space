import type { Json, LabelResolveContext, UiLabel } from "@lunatic/ui";
import { resolveLabel } from "@lunatic/ui";

const LABEL_CONTEXT: LabelResolveContext = {
  // Keyed refs are public. Actor-private wording arrives as Plain and is
  // returned verbatim without consulting the public catalog.
  visibility: "public",
  structuralKey: (id) => `lunatic/tfs:module.${id}`,
};

export function renderLabel(label: UiLabel | null | undefined): string {
  if (label == null) return "";
  return resolveLabel(label, LABEL_CONTEXT);
}

/** Structural references retain identity separately from their translation. */
export function structuralLabelId(label: UiLabel | null | undefined): string | undefined {
  if (!label || !("keyed" in label)) return undefined;
  const reference = label.keyed.reference;
  return "structural" in reference ? reference.structural : undefined;
}

/** Readouts remain arbitrary JSON; only an explicit typed-label tag resolves. */
export function readoutText(value: Json | undefined): string {
  if (value == null) return "";
  if (typeof value !== "object") return String(value);
  if (!Array.isArray(value) && Object.keys(value).length === 1) {
    const record = value as Record<string, Json>;
    if ("plain" in record || "keyed" in record) return renderLabel(value as UiLabel);
  }
  return JSON.stringify(value);
}
