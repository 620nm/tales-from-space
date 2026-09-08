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
Requirements use catalog templates and explicit quantities.

The empty machine frame opts into wiring and dismantling previews on its
real transitions. The wiring requirement derives five cable-coil units;
dismantling derives the welder tool requirement. Only transitions from the
current state participate, and holding the matching implement promotes the
same action instead of adding a duplicate suggestion.

Self-use keycaps come from the host's effective `use_self` binding.
Pointer modifiers and action words use the selected catalog. The card uses
one intrinsic grid column for every input combination and wraps labels and
long chords. It contains no interactive folds.

`tools/test-hover-actions.mjs` checks descriptor rendering, ordering, mixed
same-button rows, long bindings, semantic presentation and partial-catalog
fallback. The engine's browser regression runs the actual guest renderer.
