# Station editor declarations

`editor/manifest.json` configures both station modes using the engine's
`docs/mapping/manifest.md` declarative schema. Prototype `previews` are ordered
rules: the first matching `when` selects a bottom-to-top `layers` stack.
Conditions read placement properties over the roster's defaults, including
variant defaults. Editing a placement overrides those defaults directly.

Airlock previews cover public, engineering and interior paint, glass, open
position and bolts. Open rules precede bolted rules: an open leaf has no bolt
lamp. Closed bolted rules place the paint's bolt lamp over the selected leaf.
These are authored editor appearances; live power and motion are simulation
state. `content/structures/airlock.luau` owns the corresponding runtime art.
The same rules are declared for each airlock variant in both modes.

To add a preview for another structure, add its `kind` and `id` to each
relevant mode's `prototypes`, then write specific property combinations before
broader fallback rules. A rule needs only conditions and atlas layers:

```json
{"when": {"paint": "engineering", "glass": true, "open": true}, "layers": ["door_eng_glass_open"]}
```

Use `state` for a prototype's named state and `direction` for facing when
needed. No callback or new engine behavior is needed for these combinations.
Keep the sprite names aligned with the runtime prototype and run
`node tools/test-editor-previews.mjs`; the matrix checks defaults and explicit
overrides across the shipped paints and variants.
