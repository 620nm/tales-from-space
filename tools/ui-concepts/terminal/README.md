# Terminal frameset concept

Open `index.html` directly in a desktop browser. This preserved approved study
uses mock stores, sample telemetry, a simulated compiler and fictional PEM data.
It does not connect to a game server or implement authentication. Production
workspace code lives in `ui/`; this study is a visual reference only.

The full-width information frame sits above A:, a flexible reader/editor, and
optional B:. Ejecting B: expands the center. Drag the title bar or frame dividers,
resize, maximize/restore, edit files, and exercise the local dirty confirmation.
The study's geometry predates the production screen-aspect contract.

`baselines/` preserves the approved captures, including native-size sprites,
source with/without B:, Markdown, ATMO, PEM, and dirty confirmation at standard
and compact sizes. These captures are concept baselines, not in-game evidence.
`world.html` is the self-contained station backdrop from the approved HUD study.
`sprites.html` provides the sprite comparison gallery.

Regenerate concept screenshots and run its browser interaction checks:

```sh
node tools/ui-concepts/terminal/capture.mjs /tmp/tfs-terminal-captures
```

Requires Node 22+ and sandboxed `google-chrome-stable`. Omitting the output
argument creates a new temporary directory. Captures do not overwrite the
preserved baselines. The tool owns its temporary browser profile.

File sprites here are exact snapshots of the production PNGs. The computer
snapshot is the existing programming terminal; production titles use the actual
owner. [Art reference](../../../docs/art-reference/README.md) owns fonts,
palettes, provenance and the repeatable sprite recipe. Mock contents and
compiler failures stay within this concept tooling.
