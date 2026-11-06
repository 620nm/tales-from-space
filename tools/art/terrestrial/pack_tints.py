r"""
Reads tint colors out of the pack's Luau content so plates and the workbench draw what
the pack declares. A tolerant reader for data tables: string, number and table values,
`local` string constants; anything else (expressions, calls) reads as absent.
Fails closed: a missing file, entry or key raises `PackTintError`.
"""
from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
import re
from typing import Any

_TOKEN = re.compile(
    r'\s+|--\[(=*)\[.*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
    r'|\[(=*)\[.*?\]\2\]|[A-Za-z_][A-Za-z0-9_]*|\d[\d.eExX+-]*|\.\.\.|==|~=|<=|>=|\.\.|::|.',
    re.S,
)
_OPERATORS = {"..", "+", "-", "*", "/", "//", "%", "^", "(", "[", ".", ":", "==", "~=", "<", ">", "<=", ">=", "and", "or"}
_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


class PackTintError(RuntimeError):
    pass


@dataclass(frozen=True)
class PackTint:
    r"""A tint read from pack data: `substance` (by id) or `terrain` (a profile by key) and a dotted path."""

    source: str
    entry: str
    path: str

    def address(self) -> str:
        return f"{self.source}:{self.entry}.{self.path}"


def _tokens(text: str) -> list[str]:
    out: list[str] = []
    for m in _TOKEN.finditer(text):
        tok = m.group(0)
        if tok.isspace() or tok.startswith("--"):
            continue
        out.append(tok)
    return out


class _Reader:
    def __init__(self, toks: list[str]) -> None:
        self.toks, self.i, self.locals = toks, 0, {}  # type: ignore[var-annotated]

    def peek(self, k: int = 0) -> str | None:
        j = self.i + k
        return self.toks[j] if j < len(self.toks) else None

    def skip_expr(self) -> None:
        depth = 0
        while (tok := self.peek()) is not None:
            if depth == 0 and tok in (",", ";", "}"):
                return
            if tok in ("{", "(", "["):
                depth += 1
            elif tok in ("}", ")", "]"):
                depth -= 1
            self.i += 1

    def value(self) -> Any:
        tok = self.peek()
        if tok == "{":
            return self.table()
        nxt = self.peek(1)
        simple = nxt not in _OPERATORS
        if tok is not None and tok[0] in "\"'" and simple:
            self.i += 1
            return tok[1:-1]
        if tok is not None and re.match(r"^[A-Za-z_]\w*$", tok) and simple:
            self.i += 1
            return {"true": True, "false": False}.get(tok, self.locals.get(tok))
        if tok is not None and re.match(r"^\d", tok) and simple:
            self.i += 1
            try:
                return float(tok)
            except ValueError:
                return None
        self.skip_expr()
        return None

    def table(self) -> dict[Any, Any]:
        self.i += 1
        out: dict[Any, Any] = {}
        pos = 1
        while (tok := self.peek()) is not None and tok != "}":
            if re.match(r"^[A-Za-z_]\w*$", tok) and self.peek(1) == "=":
                self.i += 2
                out[tok] = self.value()
            elif tok == "[":
                self.skip_expr()
            else:
                out[pos] = self.value()
                pos += 1
            if self.peek() in (",", ";"):
                self.i += 1
        self.i += 1
        return out

    def chunk(self) -> Any:
        r"""The top-level `return` value; `local` constants and tables at top level only."""
        block = 0
        while (tok := self.peek()) is not None:
            if block == 0 and tok == "local" and re.match(r"^[A-Za-z_]\w*$", self.peek(1) or "") \
                    and self.peek(2) == "=" and (self.peek(3) or " ")[0] in "{\"'":
                name = self.toks[self.i + 1]
                self.i += 3
                self.locals[name] = self.value()
            elif block == 0 and tok == "return":
                self.i += 1
                return self.value()
            else:
                if tok in ("function", "do", "if", "repeat"):
                    block += 1
                elif tok in ("end", "until"):
                    block -= 1
                self.i += 1
        return None


@lru_cache(maxsize=None)
def read_luau_table(path: Path) -> Any:
    r"""The table a Luau content file returns, as nested dicts (list entries keyed 1..n)."""
    return _Reader(_tokens(path.read_text(encoding="utf-8"))).chunk()


def _substance_file(content: Path, entry: str) -> Path:
    hits = sorted((content / "substances").rglob(f"{entry}.luau"))
    if len(hits) != 1:
        raise PackTintError(f"substance {entry!r}: {len(hits)} files under {content / 'substances'}")
    return hits[0]


def _entry_table(content: Path, tint: PackTint) -> dict[Any, Any]:
    if tint.source == "substance":
        table = read_luau_table(_substance_file(content, tint.entry))
        if not isinstance(table, dict) or table.get("id") != tint.entry:
            raise PackTintError(f"{tint.address()}: file does not return substance {tint.entry!r}")
        return table
    if tint.source == "terrain":
        table = read_luau_table(content / "terrain.luau")
        profiles = table.get("profiles", {}) if isinstance(table, dict) else {}
        for prof in profiles.values():
            if isinstance(prof, dict) and prof.get("key") == tint.entry:
                return prof
        raise PackTintError(f"{tint.address()}: no terrain profile {tint.entry!r}")
    raise PackTintError(f"{tint.address()}: unknown source {tint.source!r}")


def resolve_tint(content: Path, tint: PackTint) -> str:
    r"""The `#RRGGBB` at `tint`'s address, upper-cased."""
    node: Any = _entry_table(content, tint)
    for key in tint.path.split("."):
        if not isinstance(node, dict) or key not in node:
            raise PackTintError(f"{tint.address()}: no {key!r}")
        node = node[key]
    if not isinstance(node, str) or not _HEX.match(node):
        raise PackTintError(f"{tint.address()}: {node!r} is not #RRGGBB")
    return node.upper()


def resolve_presets(content: Path, sources: dict[str, dict[str, str | PackTint]]) -> dict[str, dict[str, str]]:
    r"""Each preset with every `PackTint` replaced by the color the pack declares."""
    return {
        name: {role: resolve_tint(content, v) if isinstance(v, PackTint) else v for role, v in roles.items()}
        for name, roles in sources.items()
    }
