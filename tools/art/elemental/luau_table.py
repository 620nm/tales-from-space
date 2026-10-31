"""A reader for the data subset of Luau: `return { ... }` of tables, strings, numbers,
booleans and nil, with `--` comments. The pack's data files that the gallery previews
(`content/matter_appearances.luau`) stay inside it. Anything else (a `local`, a call, an
operator other than a leading minus) raises `LuauTableError` naming the line, so a pack file
that grows past the subset fails loudly instead of previewing the wrong numbers.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

_TOKEN = re.compile(
    r"""
    (?P<space>\s+|--[^\n]*)
  | (?P<number>-?(?:0[xX][0-9A-Fa-f]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?))
  | (?P<string>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')
  | (?P<name>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<punct>[{}\[\]=,;])
    """,
    re.VERBOSE,
)


class LuauTableError(ValueError):
    pass


def _tokens(source: str) -> list[tuple[str, str, int]]:
    out: list[tuple[str, str, int]] = []
    pos, line = 0, 1
    while pos < len(source):
        m = _TOKEN.match(source, pos)
        if m is None:
            raise LuauTableError(f"line {line}: unsupported Luau near {source[pos:pos + 20]!r}")
        kind = m.lastgroup or ""
        text = m.group()
        if kind != "space":
            out.append((kind, text, line))
        line += text.count("\n")
        pos = m.end()
    return out


class _Parser:
    def __init__(self, tokens: list[tuple[str, str, int]]) -> None:
        self.tokens = tokens
        self.at = 0

    def peek(self) -> tuple[str, str, int] | None:
        return self.tokens[self.at] if self.at < len(self.tokens) else None

    def take(self) -> tuple[str, str, int]:
        tok = self.peek()
        if tok is None:
            raise LuauTableError("unexpected end of file")
        self.at += 1
        return tok

    def expect(self, text: str) -> None:
        kind, got, line = self.take()
        if got != text:
            raise LuauTableError(f"line {line}: expected {text!r}, found {got!r}")

    def value(self) -> Any:
        kind, text, line = self.take()
        if kind == "number":
            return int(text, 16) if text.lower().lstrip("-").startswith("0x") else float(text) if any(c in text for c in ".eE") else int(text)
        if kind == "string":
            return bytes(text[1:-1], "utf-8").decode("unicode_escape")
        if kind == "name" and text in ("true", "false"):
            return text == "true"
        if kind == "name" and text == "nil":
            return None
        if text == "{":
            return self.table()
        raise LuauTableError(f"line {line}: {text!r} is outside the data subset")

    def table(self) -> Any:
        keyed: dict[Any, Any] = {}
        listed: list[Any] = []
        while True:
            tok = self.peek()
            if tok is None:
                raise LuauTableError("unclosed table")
            kind, text, line = tok
            if text == "}":
                self.take()
                break
            if text in (",", ";"):
                self.take()
                continue
            nxt = self.tokens[self.at + 1] if self.at + 1 < len(self.tokens) else None
            if kind == "name" and nxt is not None and nxt[1] == "=":
                self.take()
                self.take()
                keyed[text] = self.value()
            elif text == "[":
                self.take()
                key = self.value()
                self.expect("]")
                self.expect("=")
                keyed[key] = self.value()
            else:
                listed.append(self.value())
        if keyed:
            keyed.update({i + 1: v for i, v in enumerate(listed)})
            return keyed
        return listed


def parse_luau_table(source: str) -> Any:
    """The table a data file returns."""
    parser = _Parser(_tokens(source))
    kind, text, line = parser.take()
    if text != "return":
        raise LuauTableError(f"line {line}: a data file starts with `return`, found {text!r}")
    result = parser.value()
    if parser.peek() is not None:
        raise LuauTableError(f"line {parser.peek()[2]}: text after the returned table")  # type: ignore[index]
    return result


def read_luau_table(path: Path) -> Any:
    try:
        return parse_luau_table(path.read_text(encoding="utf-8"))
    except LuauTableError as err:
        raise LuauTableError(f"{path}: {err}") from None
