import type { StyleProps, UiNode } from "@lunatic/ui";
import { tfs } from "./strings";
import { text } from "./view";

const BODY_LIMIT = 65536;
const NODE_LIMIT = 96;
const TEXT_LIMIT = 4096;

/** Text-only readers; unsupported or invalid records use the editor. */
export function fileReader(id: string, ext: string, body: string): UiNode[] | undefined {
  if (ext === "atmo") return atmosphere(id, body);
  if (ext !== "md" && ext !== "pem") return undefined;
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
    const style: StyleProps = { whiteSpace: "pre-wrap", flexShrink: 0 };
    if (fenced || ext === "pem") style.fontFamily = "mono";
    if (heading) {
      style.fontWeight = 700;
      style.fontSize = Math.max(12, 22 - heading[1]!.length * 2);
    }
    if (quote) style.paddingLeft = 12;
    for (let offset = 0; offset < Math.max(1, value.length); offset += TEXT_LIMIT) {
      if (nodes.length >= NODE_LIMIT - 1) {
        consumed -= value.length - offset;
        break;
      }
      nodes.push(text(`${id}/line/${nodes.length}`, value.slice(offset, offset + TEXT_LIMIT), undefined, style));
    }
  }
  if (body.length > BODY_LIMIT || consumed < body.length)
    nodes.push(text(`${id}/truncated`, tfs("ui.files.reader.truncated")));
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
