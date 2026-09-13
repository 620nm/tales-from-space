import type { StyleProps, UiNode } from "@lunatic/ui";
import { tfs } from "./strings";
import { panel, text } from "./view";
import { flowingText, markdownRuns, sliceUtf8, utf8Length } from "./writing-text";
import type { FileFragment } from "./document-model";

const BODY_LIMIT = 65536;
// Ceiling per reader; the caller passes what the tree has left
// (docs/pack-ui/components.md budgets).
export const READER_NODES = 384;
const TEXT_LIMIT = 4096;

/** Text-only readers; unsupported or invalid records use the editor. */
export function fileReader(id: string, ext: string, body: string, limit = READER_NODES, fragments?: FileFragment[]): UiNode[] | undefined {
  const NODE_LIMIT = Math.max(2, Math.min(READER_NODES, limit));
  if (ext === "atmo") return atmosphere(id, body);
  if (ext !== "md" && ext !== "pem") return undefined;
  if (ext === "md" && fragments?.length) return committedReader(id, fragments, NODE_LIMIT);
  const nodes: UiNode[] = [];
  if (ext === "pem")
    nodes.push(text(`${id}/access`, tfs("ui.files.reader.access"), undefined, { fontWeight: 700 }));
  let fenced = false;
  let consumed = 0;
  const lines = body.slice(0, BODY_LIMIT).split("\n");
  for (const line of lines) {
    if (nodes.length >= NODE_LIMIT - 1) break;
    consumed += line.length + 1;
    if (ext === "md" && /^\s*(```|~~~)/.test(line)) {
      fenced = !fenced;
      continue;
    }
    const heading = ext === "md" && !fenced ? /^(#{1,6})\s+(.*)$/.exec(line) : null;
    const quote = ext === "md" && !fenced && /^>\s?/.test(line);
    const value = heading ? heading[2]! : quote ? line.replace(/^>\s?/, "") : line;
    const cls = ["reader-line", ...(fenced || ext === "pem" ? ["mono"] : []), ...(heading ? ["reader-head"] : []), ...(quote ? ["reader-quote"] : [])];
    // theme-lint: allow — a heading's size follows its level.
    const style: StyleProps | undefined = heading ? { fontSize: Math.max(12, 22 - heading[1]!.length * 2) } : undefined;
    for (let offset = 0; offset < Math.max(1, value.length); offset += TEXT_LIMIT) {
      if (nodes.length >= NODE_LIMIT - 1) {
        consumed -= value.length - offset;
        break;
      }
      const chunk = value.slice(offset, offset + TEXT_LIMIT);
      const runs = ext === "md" && !fenced ? markdownRuns(chunk) : undefined;
      nodes.push(text(`${id}/line/${nodes.length}`, runs?.map((run) => run.text).join("") ?? chunk, cls, style, runs));
    }
  }
  if (body.length > BODY_LIMIT || consumed < body.length) {
    const rest = body.slice(Math.min(consumed, BODY_LIMIT));
    const lines = rest.split("\n").length - (rest.endsWith("\n") ? 1 : 0);
    nodes.push(text(`${id}/truncated`, tfs("ui.files.reader.truncated", { lines })));
  }
  return nodes;
}

function committedReader(id: string, fragments: FileFragment[], limit: number): UiNode[] {
  const bounded: { text: string; style?: FileFragment["style"] }[] = [];
  let bytes = 0;
  let omitted = fragments.length > 64;
  for (const fragment of fragments.slice(0, 64)) {
    if (!fragment || typeof fragment.text !== "string") continue;
    const remaining = BODY_LIMIT - bytes;
    if (remaining <= 0) { omitted = true; break; }
    const textValue = sliceUtf8(fragment.text, Math.min(TEXT_LIMIT, remaining));
    if (!textValue) continue;
    bytes += utf8Length(textValue);
    bounded.push({ text: textValue, style: fragment.style });
    if (textValue.length < fragment.text.length || utf8Length(textValue) < utf8Length(fragment.text)) {
      omitted = true;
      break;
    }
  }
  // The wrapper is one block in the reader column; its children remain
  // inline so a node-size boundary cannot introduce a visual line break.
  const flow = flowingText(id, bounded, ["reader-inline"], Math.max(1, limit - 2));
  const nodes = flow.nodes.length ? [panel(`${id}/flow`, flow.nodes, { cls: ["reader-flow"] })] : [];
  if (omitted || flow.truncated)
    nodes.push(text(`${id}/truncated`, tfs("ui.files.reader.truncated", { lines: 1 })));
  return nodes;
}

function record(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function nonnegative(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function atmosphere(id: string, body: string): UiNode[] | undefined {
  if (!body.trim() || body.length > BODY_LIMIT) return undefined;
  let data: unknown;
  try { data = JSON.parse(body); } catch { return undefined; }
  if (!record(data) || data.version !== 1 ||
      Object.keys(data).some((key) => !["version", "title", "temperature_k", "pressure_kpa", "gases"].includes(key)) ||
      (data.title !== undefined && (typeof data.title !== "string" || data.title.length > 160)) ||
      !nonnegative(data.temperature_k) || !nonnegative(data.pressure_kpa) ||
      !Array.isArray(data.gases) || data.gases.length > 32) return undefined;
  const gases: { id: string; moles: number }[] = [];
  const seen = new Set<string>();
  for (const gas of data.gases) {
    if (!record(gas) || Object.keys(gas).some((key) => !["id", "moles"].includes(key)) ||
        typeof gas.id !== "string" || !gas.id.trim() || gas.id.length > 80 ||
        !nonnegative(gas.moles) || seen.has(gas.id)) return undefined;
    seen.add(gas.id);
    gases.push({ id: gas.id, moles: gas.moles });
  }
  return [
    text(`${id}/title`, data.title || tfs("ui.files.reader.atmo"), undefined, { fontWeight: 700 }),
    text(`${id}/temperature`, tfs("ui.files.reader.temperature", { value: data.temperature_k })),
    text(`${id}/pressure`, tfs("ui.files.reader.pressure", { value: data.pressure_kpa })),
    ...gases.map((gas, index) => text(`${id}/gas/${index}`, tfs("ui.files.reader.gas", gas))),
  ];
}
