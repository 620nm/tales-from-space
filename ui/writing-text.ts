import type { UiNode, UiInlineRun } from "@lunatic/ui";
import type { WritingFragment } from "./document-model";
import { text } from "./view";
import * as S from "./strings";

/** Native append and UI text limits, measured as UTF-8 bytes. */
export const TEXT_LIMIT = 4096;
export const BODY_LIMIT = 8192;
export const FRAGMENT_LIMIT = 64;
const NODE_LIMIT = 4096;
const RUN_LIMIT = 64;

export function utf8Length(value: string): number {
  let bytes = 0;
  for (const char of value) {
    const code = char.codePointAt(0)!;
    bytes += code <= 0x7f ? 1 : code <= 0x7ff ? 2 : code <= 0xffff ? 3 : 4;
  }
  return bytes;
}

/** Keep complete Unicode scalar values within a byte budget. */
export function sliceUtf8(value: string, limit: number): string {
  if (utf8Length(value) <= limit) return value;
  let out = "";
  let bytes = 0;
  for (const char of value) {
    const size = utf8Length(char);
    if (bytes + size > limit) break;
    out += char;
    bytes += size;
  }
  return out;
}

/** Parse one Markdown fragment into inert runs. Each fragment is parsed once. */
export function markdownRuns(source: string): UiInlineRun[] {
  const runs: UiInlineRun[] = [];
  const input = sliceUtf8(source, BODY_LIMIT);
  const push = (run: UiInlineRun): void => {
    for (let offset = 0; offset < run.text.length; ) {
      const value = sliceUtf8(run.text.slice(offset), TEXT_LIMIT);
      if (!value) break;
      runs.push({ ...run, text: value });
      offset += value.length;
    }
  };
  const pattern = /(\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`)/g;
  let cursor = 0;
  for (const match of input.matchAll(pattern)) {
    const start = match.index ?? 0;
    if (start > cursor) push({ text: input.slice(cursor, start) });
    const value = match[2] ?? match[3] ?? match[4] ?? match[0];
    push({
      text: value,
      ...(match[2] ? { fontWeight: 700 } : {}),
      ...(match[3] ? { fontStyle: "italic" } : {}),
      ...(match[4] ? { fontFamily: "mono" } : {}),
    } as UiInlineRun);
    cursor = start + match[0].length;
  }
  if (cursor < input.length || !runs.length) push({ text: input.slice(cursor) || " " });
  if (runs.length <= FRAGMENT_LIMIT) return runs;
  // Keep all source text when syntax creates more runs than the wire allows.
  // The tail loses marks only after the bounded prefix; it never disappears.
  const prefix = runs.slice(0, FRAGMENT_LIMIT - 2);
  const tail = runs.slice(FRAGMENT_LIMIT - 2).map((run) => run.text).join("");
  for (let offset = 0; offset < tail.length; ) {
    const value = sliceUtf8(tail.slice(offset), TEXT_LIMIT);
    if (!value) break;
    prefix.push({ text: value });
    offset += value.length;
  }
  return prefix.slice(0, FRAGMENT_LIMIT);
}

export function fragmentText(fragment: WritingFragment): string {
  return typeof fragment.text === "string" ? fragment.text : "";
}

function fragmentRuns(fragment: WritingFragment): UiInlineRun[] {
  const style = fragment.style;
  if (!style) return markdownRuns(fragmentText(fragment));
  // Native committed text is Markdown. Parse each fragment independently,
  // then apply its frozen defaults; marks never cross an append boundary.
  const source = fragmentText(fragment);
  const base = {
    ...(style.color ? { color: style.color } : {}),
    ...(style.font_family ? { fontFamily: style.font_family } : {}),
    ...(style.weight ? { fontWeight: style.weight } : {}),
  };
  return markdownRuns(source).map((run) => ({ ...base, ...run,
    color: run.color ?? base.color, fontFamily: run.fontFamily ?? base.fontFamily,
    fontWeight: run.fontWeight ?? base.fontWeight,
  }));
}

function clipFragment(fragment: WritingFragment, limit: number): WritingFragment | undefined {
  if (limit <= 0) return undefined;
  const value = sliceUtf8(fragment.text, limit);
  return value ? { ...fragment, text: value } : undefined;
}

/** Normalize committed fragments without discarding an over-budget prefix. */
export function fragmentList(raw: unknown): WritingFragment[] {
  if (!Array.isArray(raw)) return [];
  const out: WritingFragment[] = [];
  let bytes = 0;
  for (const value of raw.slice(0, FRAGMENT_LIMIT)) {
    if (!value || typeof value !== "object" || Array.isArray(value)) continue;
    const fragment = value as WritingFragment;
    const length = utf8Length(fragmentText(fragment));
    if (!length) continue;
    const keep = Math.min(length, BODY_LIMIT - bytes);
    const clipped = keep === length ? fragment : clipFragment(fragment, keep);
    if (clipped) out.push(clipped);
    bytes += keep;
    if (bytes >= BODY_LIMIT) break;
  }
  return out;
}

export interface FlowingText {
  nodes: UiNode[];
  truncated: boolean;
}

/** Parse fragments independently, then flow their safe runs into bounded nodes. */
export function flowingText(id: string, fragments: WritingFragment[], classes: string[], nodeLimit = NODE_LIMIT): FlowingText {
  const runs = fragments.flatMap(fragmentRuns);
  const out: UiNode[] = [];
  let chunk: UiInlineRun[] = [];
  let bytes = 0;
  let truncated = false;
  const maxNodes = Math.max(1, Math.floor(nodeLimit));
  const flush = (): void => {
    if (!chunk.length) return;
    if (out.length >= maxNodes) {
      truncated = true;
      chunk = [];
      bytes = 0;
      return;
    }
    const plain = chunk.map((run) => run.text).join("");
    out.push(text(`${id}/part/${out.length}`, plain, classes, undefined, chunk));
    chunk = [];
    bytes = 0;
  };
  runsLoop: for (const run of runs) {
    if (out.length >= maxNodes) {
      truncated = true;
      break;
    }
    for (let offset = 0; offset < run.text.length; ) {
      const value = sliceUtf8(run.text.slice(offset), NODE_LIMIT);
      if (!value) break;
      const size = utf8Length(value);
      if (bytes + size > NODE_LIMIT || chunk.length >= RUN_LIMIT) {
        flush();
        if (out.length >= maxNodes) {
          truncated = true;
          break runsLoop;
        }
      }
      chunk.push({ ...run, text: value });
      bytes += size;
      offset += value.length;
      if (bytes >= NODE_LIMIT) flush();
    }
  }
  flush();
  return { nodes: out, truncated };
}

function flowingNodes(id: string, fragments: WritingFragment[], committed: boolean): UiNode[] {
  return flowingText(id, fragments, ["paper-line", ...(committed ? ["paper-committed"] : [])]).nodes;
}

export function writingPreview(id: string, fragments: WritingFragment[], cls: string[] = []): UiNode[] {
  const bounded = fragmentList(fragments);
  if (!bounded.length) return [text(`${id}/empty`, S.tfs("ui.writing.empty"), ["hint", ...cls])];
  const total = fragments.reduce((sum, fragment) => sum + utf8Length(fragmentText(fragment)), 0);
  return [
    ...flowingNodes(id, bounded, true),
    ...(bounded.length < fragments.length || total > BODY_LIMIT
      ? [text(`${id}/truncated`, S.tfs("ui.writing.truncated"), ["hint"])] : []),
  ];
}
