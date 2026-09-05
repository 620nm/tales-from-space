# Words

Every player-visible sentence this pack writes, and where it lives. This
is the pack's own contract; every other `docs/…` path this repository
cites is the ENGINE's, in the lunatic checkout.

No player-visible sentence is spelled in this repository's code. `ui/*.ts`
holds catalog KEYS and `content/**/*.luau` emits them; the words live in
`locale/<tag>.json`, one flat `{key: template}` object per language whose
stem is its normalized tag (lunatic's `docs/localization/catalogs.md`).

## A key

A key is `lunatic/tfs:<area>.<name>` — `ui.tray.drop` for the interface,
`ui.binding.<id>` for a key binding's label, `module.<label id>` for a word
the server names on a settings panel (lunatic's `docs/tgui/labels.md`), and
`<dir>.<file>.<slug>` for a line some Luau file sends. A pack may also
render an `engine.*` key the engine already emits, which is how this
station words a refusal the engine states plainly; it may not invent one.

A sentence two files both say is neither file's: it is `lib.<area>.<name>`,
hoisted once and named by both, the way `lib.vessel.*` is the wording of a
gesture `content/lib/vessel.luau` shares out. One sentence is one key —
two keys holding the same English are two translations to keep in step and
one of them will drift.

## Adding a line

Write it in `locale/en.json` and emit
`sim.msg("lunatic/tfs:<key>", { … })`, whose argument names must be exactly
the `{placeholders}` the template asks for. One key is one FINISHED
sentence — never a clause another site frames, a fragment joined with `..`,
or a list glued together (lunatic's `docs/LOCALIZATION.md` §5). A
per-outcome variant is a key of its own, which is why a die has `roll` and
`roll_bad`.

## Adding a language

Copy the keys you want out of `locale/en.json` into `locale/<tag>.json`,
keep every `{placeholder}` the English uses, and give it
`lunatic/tfs:locale.name` — its own name, in itself, for the picker to
read. A key you leave out reads in English; nothing else has to change.
`locale/fr.json` is a worked partial example.

## The gate

`mod.toml` declares `[localization] require_keys = true`, so the promise
above is the engine's to keep: it scans the whole content tree at load
and refuses the round at `file:line` for a `message = "…"` sentence —
prototype `failure` lines the script loader never evaluates included —
and `sim.message.send`, `broadcast` and `notify` refuse a bare string at
the send, which is where a sentence assembled at runtime out of pieces
turns up. A line a helper RETURNS is under the same rule: return the
`sim.msg` and let the caller send it.

What the engine does not see is content it draws itself — a transition's
`start`/`done`, a body's looks, an examine line. Those are still spelled
in `content/`, and keying them is work this rule has not reached.

`node tools/keyed-messages.mjs` moves any `message = "…"` a send carries
into the catalog and rewrites the call; a sentence the catalog already
holds is pointed at the key it already has rather than minted a second
time. `--check` writes nothing and fails on the first literal that comes
back. Run the check before committing content.
