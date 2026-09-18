# Interaction cards

The overlay renders `state.hover.actions`, the server's resolved action
descriptors for the current actor and exact visible target. Every row has
its own stable id; two rows may share a gesture. The overlay adds no
interaction verbs. Server descriptors also supply Face towards and Examine.

Available actions precede unavailable actions, followed by the opted-in
Other interactions suggestions. Within each section, authored `order`
takes priority over gesture order. `presentation_group` names a catalog key
for a noninteractive group heading. The style tokens in
`ui/overlay/actions.ts` map to safe classes in `ui/theme-overlay.ts`.

Each action owns its implement sprite, accessible name, requirements and
unavailable reason. A row without an implement stays key-only, even when
another row on the same mouse button uses the held tool. Suggested tools
are representative sprites; available rows use the actual held sprite.
Requirement labels name the item, including a required condition such as
lit, and carry an explicit quantity. The overlay adds the Requires sentence
once; the server does not include that sentence inside the item label.

The empty machine frame opts into wiring and dismantling previews on its
real transitions. The wiring requirement derives five cable-coil units;
dismantling derives the welder tool requirement. Only transitions from the
current state participate, and holding the matching implement promotes the
same action instead of adding a duplicate suggestion.

Self-use keycaps come from the host's effective `use_self` binding.
Rows with gesture `other` (on the active-hand item's card, naming what the
use-on-other-hand key does with the other hand's item) take their keycaps
from `use_other` and carry the second line "In other hand" in their
`detail`. The server sorts rows by group, then declared `order`, then
gesture, so an `other` row sits right after self-use rows only where both
share a group and an `order`.
Pointer modifiers and action words use the selected catalog. The card uses
one intrinsic grid column for every input combination and wraps labels and
long chords. It contains no interactive folds.

`tools/test-hover-actions.mjs` checks descriptor rendering, ordering, mixed
same-button rows, long bindings, semantic presentation and partial-catalog
fallback. The engine's browser regression runs the actual guest renderer.

## Equipment action bar

Possession-scoped action documents supply equipment groups and actions.
Their qualified catalog IDs resolve directly; bare native document IDs
resolve under `module.`. Explicitly tagged nested labels follow the same
rule. Captions and accessibility labels use the same resolved text.

The welder uses distinct lit world and in-hand sprites and plays the
activation or deactivation sound when its self, secondary, or HUD action
toggles it. Ignition requires its declared fuel; an empty tank emits no
activation sound. Its visible state follows the engine's fuel activity state.
Art and sound selection follow tgstation's
`code/game/objects/items/tools/engineering/weldingtool.dm:49-50,77-92,250-267`.
