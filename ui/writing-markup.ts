export interface WritingMarkup {
  heading: string;
  caption: string;
  columns: string[];
  rows: string[][];
  paragraphs: string[];
}

const MAX_INPUT_BYTES = 8192;
const MAX_TOKENS = 1024;
const MAX_TEXT_BYTES = 512;
const MAX_TOTAL_TEXT_BYTES = 4096;
const MAX_ATTRIBUTE_BYTES = 128;
const MAX_ATTRIBUTES_PER_TAG = 16;
const MAX_TAG_BYTES = 512;
const MAX_ROWS = 12;
const MAX_COLUMNS = 12;
const MAX_CELLS = 144;
const MAX_PARAGRAPHS = 8;

type Token =
  | { kind: "text"; value: string }
  | { kind: "tag"; name: string; closing: boolean; selfClosing: boolean; attrs: Record<string, string> };

interface Cell {
  text: string;
  colspan: number;
  rowspan: number;
}

function utf8Length(value: string): number | undefined {
  if (value.length > MAX_INPUT_BYTES) return undefined;
  let bytes = 0;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    if (code <= 0x7f) bytes++;
    else if (code <= 0x7ff) bytes += 2;
    else if (code >= 0xd800 && code <= 0xdbff) {
      const next = value.charCodeAt(index + 1);
      if (!(next >= 0xdc00 && next <= 0xdfff)) return undefined;
      bytes += 4;
      index++;
    } else if (code >= 0xdc00 && code <= 0xdfff) return undefined;
    else bytes += 3;
    if (bytes > MAX_INPUT_BYTES) return undefined;
  }
  return bytes;
}

function isSpace(char: string): boolean {
  return char === " " || char === "\t" || char === "\n" || char === "\r";
}

function skipSpaces(source: string, start: number): number {
  let index = start;
  while (index < source.length) {
    const char = source[index];
    if (char === undefined || !isSpace(char)) break;
    index++;
  }
  return index;
}

function isControl(code: number): boolean {
  return code < 0x20 || (code >= 0x7f && code <= 0x9f);
}

function spanValue(value: string | undefined): number | undefined {
  if (value === undefined) return 1;
  if (value.length === 0 || value.length > 2) return undefined;
  let span = 0;
  for (const char of value) {
    if (char < "0" || char > "9") return undefined;
    span = span * 10 + char.charCodeAt(0) - 48;
  }
  return span >= 1 && span <= MAX_COLUMNS ? span : undefined;
}

function validAttributes(name: string, attrs: Record<string, string>): boolean {
  const names = Object.keys(attrs);
  if (name === "table") {
    return names.every((key) =>
      (key === "style" && attrs[key] === "text-align:center;")
      || (key === "border" && attrs[key] === "1")
      || (key === "width" && attrs[key] === "100%"));
  }
  if (name === "td") {
    return names.every((key) => {
      if (key === "style") {
        const value = attrs[key];
        if (value === undefined) return false;
        return [
          "background-color: red; color: white;",
          "background-color: blue; color: white;",
          "margin: 0; padding-left:6px; writing-mode: sideways-rl; background-color: blue; color: white;",
        ].includes(value);
      }
      if (key === "width") return attrs[key] === "25px";
      if (key === "height") return attrs[key] === "25px";
      if (key === "rowspan" || key === "colspan") return spanValue(attrs[key]) !== undefined;
      return false;
    });
  }
  return names.length === 0;
}

function parseTag(source: string, start: number): { token: Token; next: number } | undefined {
  let index = start + 1;
  let closing = false;
  if (source[index] === "/") {
    closing = true;
    index++;
  }

  const nameStart = index;
  while (index < source.length) {
    const char = source[index];
    if (char === undefined || !((char >= "a" && char <= "z") || (char >= "0" && char <= "9"))) break;
    index++;
  }
  if (index === nameStart) return undefined;
  const name = source.slice(nameStart, index);
  if (!["h2", "table", "tbody", "tr", "td", "br"].includes(name)) return undefined;

  const attrs: Record<string, string> = {};
  let selfClosing = false;
  let ended = false;
  let needsWhitespaceBeforeAttribute = false;
  while (index < source.length && index - start <= MAX_TAG_BYTES) {
    const char = source[index];
    if (char === undefined) return undefined;
    if (isSpace(char)) {
      index++;
      needsWhitespaceBeforeAttribute = false;
      continue;
    }
    if (char === ">") {
      index++;
      ended = true;
      break;
    }
    if (char === "/" && source[index + 1] === ">") {
      selfClosing = true;
      index += 2;
      ended = true;
      break;
    }
    if (closing || needsWhitespaceBeforeAttribute) return undefined;

    const attrStart = index;
    while (index < source.length) {
      const attrChar = source[index];
      if (attrChar === undefined || attrChar < "a" || attrChar > "z") break;
      index++;
    }
    if (index === attrStart) return undefined;
    const key = source.slice(attrStart, index);
    if (Object.prototype.hasOwnProperty.call(attrs, key) || Object.keys(attrs).length >= MAX_ATTRIBUTES_PER_TAG) {
      return undefined;
    }
    index = skipSpaces(source, index);
    if (source[index] !== "=") return undefined;
    index++;
    index = skipSpaces(source, index);
    if (source[index] !== '"') return undefined;
    index++;
    const valueStart = index;
    while (index < source.length && source[index] !== '"') {
      const valueChar = source[index];
      if (valueChar === undefined) return undefined;
      const code = source.charCodeAt(index);
      if (valueChar === "<" || valueChar === ">" || isControl(code)) return undefined;
      index++;
      if (index - valueStart > MAX_ATTRIBUTE_BYTES) return undefined;
    }
    if (index >= source.length) return undefined;
    const value = source.slice(valueStart, index);
    if (utf8Length(value) === undefined) return undefined;
    attrs[key] = value;
    index++;
    needsWhitespaceBeforeAttribute = true;
  }

  if (!ended || index - start > MAX_TAG_BYTES || (closing && (selfClosing || Object.keys(attrs).length > 0))) {
    return undefined;
  }
  if ((selfClosing && name !== "br") || (name === "br" && !selfClosing)) return undefined;
  if (!validAttributes(name, attrs)) return undefined;
  return { token: { kind: "tag", name, closing, selfClosing, attrs }, next: index };
}

function tokenize(source: string): Token[] | undefined {
  const inputBytes = utf8Length(source);
  if (inputBytes === undefined || inputBytes > MAX_INPUT_BYTES) return undefined;

  const tokens: Token[] = [];
  let totalTextBytes = 0;
  let index = 0;
  while (index < source.length) {
    if (source[index] === "<") {
      const parsed = parseTag(source, index);
      if (!parsed) return undefined;
      tokens.push(parsed.token);
      index = parsed.next;
    } else {
      const start = index;
      while (index < source.length) {
        const char = source[index];
        if (char === undefined || char === "<") break;
        const code = source.charCodeAt(index);
        if (isControl(code) && !isSpace(char)) return undefined;
        index++;
      }
      const value = source.slice(start, index);
      const bytes = utf8Length(value);
      if (bytes === undefined || bytes > MAX_TEXT_BYTES) return undefined;
      totalTextBytes += bytes;
      if (totalTextBytes > MAX_TOTAL_TEXT_BYTES) return undefined;
      tokens.push({ kind: "text", value });
    }
    if (tokens.length > MAX_TOKENS) return undefined;
  }
  return tokens;
}

function isTag(token: Token | undefined, name: string, closing = false): token is Extract<Token, { kind: "tag" }> {
  return token?.kind === "tag" && token.name === name && token.closing === closing;
}

function skipWhitespace(tokens: Token[], start: number): number {
  let index = start;
  while (index < tokens.length) {
    const token = tokens[index];
    if (token === undefined || token.kind !== "text") break;
    const value = token.value;
    let whitespace = true;
    for (const char of value) if (!isSpace(char)) whitespace = false;
    if (!whitespace) break;
    index++;
  }
  return index;
}

function readTextElement(
  tokens: Token[],
  start: number,
  name: string,
): { text: string; attrs: Record<string, string>; next: number } | undefined {
  const opening = tokens[start];
  if (!isTag(opening, name) || opening.selfClosing) return undefined;
  let value = "";
  for (let index = start + 1; index < tokens.length; index++) {
    const token = tokens[index];
    if (token === undefined) return undefined;
    if (token.kind === "text") {
      value += token.value;
      const bytes = utf8Length(value);
      if (bytes === undefined || bytes > MAX_TEXT_BYTES) return undefined;
    } else if (isTag(token, name, true)) {
      return { text: value.trim(), attrs: opening.attrs, next: index + 1 };
    } else {
      return undefined;
    }
  }
  return undefined;
}

function parseRows(
  tokens: Token[],
  start: number,
  endingTag: "table" | "tbody",
): { rows: Cell[][]; next: number } | undefined {
  const rows: Cell[][] = [];
  let totalCells = 0;
  let index = start;
  while (true) {
    index = skipWhitespace(tokens, index);
    if (isTag(tokens[index], endingTag, true)) return { rows, next: index };
    const rowOpening = tokens[index];
    if (!isTag(rowOpening, "tr") || rowOpening.selfClosing || Object.keys(rowOpening.attrs).length !== 0) {
      return undefined;
    }
    index++;
    const row: Cell[] = [];
    while (true) {
      index = skipWhitespace(tokens, index);
      if (isTag(tokens[index], "tr", true)) {
        index++;
        break;
      }
      const cell = readTextElement(tokens, index, "td");
      if (!cell) return undefined;
      const colspan = spanValue(cell.attrs.colspan);
      const rowspan = spanValue(cell.attrs.rowspan);
      if (colspan === undefined || rowspan === undefined) return undefined;
      row.push({ text: cell.text, colspan, rowspan });
      totalCells++;
      if (row.length > MAX_COLUMNS || totalCells > MAX_CELLS) return undefined;
      index = cell.next;
    }
    if (row.length === 0) return undefined;
    rows.push(row);
    if (rows.length > MAX_ROWS) return undefined;
  }
}

function normalizeRows(rows: Cell[][]): Pick<WritingMarkup, "caption" | "columns" | "rows"> | undefined {
  if (rows.length < 3 || rows.length > MAX_ROWS) return undefined;
  const top = rows[0];
  const header = rows[1];
  if (top === undefined || header === undefined) return undefined;
  const dataRows = rows.length - 2;
  if (top.length !== 3 || header.length < 3 || header.length > MAX_COLUMNS) return undefined;
  const topFirst = top[0];
  const topSecond = top[1];
  const captionCell = top[2];
  const headerFirst = header[0];
  const headerSecond = header[1];
  if (topFirst === undefined || topSecond === undefined || captionCell === undefined
    || headerFirst === undefined || headerSecond === undefined) return undefined;
  if (topFirst.text !== "" || topSecond.text !== "" || headerFirst.text !== "" || headerSecond.text !== "") {
    return undefined;
  }
  if (topFirst.colspan !== 1 || topFirst.rowspan !== 1 || topSecond.colspan !== 1 || topSecond.rowspan !== 1) {
    return undefined;
  }
  const labels = header.slice(2);
  if (labels.length < 1 || labels.length + 2 > MAX_COLUMNS) return undefined;
  if (captionCell.text.length === 0 || captionCell.colspan !== labels.length || captionCell.rowspan !== 1) {
    return undefined;
  }
  if (header.some((cell) => cell.colspan !== 1 || cell.rowspan !== 1)) return undefined;
  if (labels.some((cell) => cell.text.length === 0)) return undefined;

  const vertical = rows[2];
  if (vertical === undefined) return undefined;
  const verticalAxis = vertical[0];
  if (verticalAxis === undefined) return undefined;
  const columns = [verticalAxis.text, ...labels.map((cell) => cell.text)];
  if (vertical.length !== labels.length + 2 || verticalAxis.text.length === 0) return undefined;
  if (verticalAxis.colspan !== 1 || verticalAxis.rowspan !== dataRows) return undefined;
  const values: string[][] = [];
  for (let rowIndex = 0; rowIndex < dataRows; rowIndex++) {
    const row = rows[rowIndex + 2];
    if (row === undefined) return undefined;
    const offset = rowIndex === 0 ? 1 : 0;
    if (row.length !== labels.length + 1 + offset) return undefined;
    for (let cellIndex = offset; cellIndex < row.length; cellIndex++) {
      const cell = row[cellIndex];
      if (cell === undefined || cell.colspan !== 1 || cell.rowspan !== 1) return undefined;
    }
    const labelCell = row[rowIndex === 0 ? 1 : 0];
    if (labelCell === undefined) return undefined;
    const label = labelCell.text;
    const data = row.slice(rowIndex === 0 ? 2 : 1);
    if (label.length === 0 || data.length !== labels.length) return undefined;
    values.push([label, ...data.map((cell) => cell.text)]);
  }
  return { caption: captionCell.text, columns, rows: values };
}

function paragraphsAfterBreak(tokens: Token[], start: number): string[] | undefined {
  let source = "";
  for (let index = start; index < tokens.length; index++) {
    const token = tokens[index];
    if (token === undefined || token.kind !== "text") return undefined;
    source += token.value;
  }
  const paragraphs: string[] = [];
  let startOfLine = 0;
  for (let index = 0; index <= source.length; index++) {
    if (index < source.length && source[index] !== "\n" && source[index] !== "\r") continue;
    const paragraph = source.slice(startOfLine, index).trim();
    if (paragraph.length > 0) {
      const bytes = utf8Length(paragraph);
      if (bytes === undefined || bytes > MAX_TEXT_BYTES) return undefined;
      paragraphs.push(paragraph);
      if (paragraphs.length > MAX_PARAGRAPHS) return undefined;
    }
    if (source[index] === "\r" && source[index + 1] === "\n") index++;
    startOfLine = index + 1;
  }
  return paragraphs.length > 0 ? paragraphs : undefined;
}

export function parseWritingMarkup(source: string): WritingMarkup | undefined {
  const tokens = tokenize(source);
  if (!tokens) return undefined;

  let index = skipWhitespace(tokens, 0);
  const heading = readTextElement(tokens, index, "h2");
  if (!heading || heading.text.length === 0 || Object.keys(heading.attrs).length !== 0) return undefined;
  index = skipWhitespace(tokens, heading.next);

  const table = tokens[index];
  if (!isTag(table, "table") || table.selfClosing) return undefined;
  index = skipWhitespace(tokens, index + 1);
  const bodyOpening = tokens[index];
  let hasBody = false;
  if (isTag(bodyOpening, "tbody")) {
    if (bodyOpening.selfClosing || Object.keys(bodyOpening.attrs).length !== 0) return undefined;
    hasBody = true;
    index = skipWhitespace(tokens, index + 1);
  }

  const parsedRows = parseRows(tokens, index, hasBody ? "tbody" : "table");
  if (!parsedRows) return undefined;
  index = skipWhitespace(tokens, parsedRows.next);
  if (hasBody) {
    if (!isTag(tokens[index], "tbody", true)) return undefined;
    index = skipWhitespace(tokens, index + 1);
  }
  if (!isTag(tokens[index], "table", true)) return undefined;

  const normalized = normalizeRows(parsedRows.rows);
  if (!normalized) return undefined;
  index = skipWhitespace(tokens, index + 1);
  const lineBreak = tokens[index];
  if (!isTag(lineBreak, "br") || !lineBreak.selfClosing || Object.keys(lineBreak.attrs).length !== 0) {
    return undefined;
  }
  const paragraphs = paragraphsAfterBreak(tokens, index + 1);
  if (!paragraphs) return undefined;
  return { heading: heading.text, ...normalized, paragraphs };
}
