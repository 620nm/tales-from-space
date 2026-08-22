-- Plasma, for its LOOK only -- water.luau's shape, applied to a gas.
--
-- Plasma is a BUILTIN substance: its mass, its specific heat and its
-- visibility threshold live in the engine's matter registry because
-- atmos needs them long before content does. The registry skips a
-- content substance whose key it already knows (invariant I9,
-- docs/CHEMISTRY.md), so this file registers no physics and could not
-- override any if it tried. What it contributes is the METADATA half,
-- which the registry does not own -- and a colour is exactly that: not
-- a property of matter, a decision about how to draw it.
--
-- Before this file the purple lived in a `match` in the entity stream
-- (sim/stream), keyed on the string "plasma". That was a vocabulary
-- word in engine code, and the day a second content gas wanted to be
-- seen it would have had to be a third arm of the same match. Now the
-- stream asks the registry which gases are visible and asks the
-- metadata what colour each one is, and a visible gas with no colour
-- is simply not drawn.
--
-- The purple is the one the client has always drawn plasma in
-- (0.75/0.35/0.95 in the old renderer), so nothing on screen changes.
-- `moles` and `factor` are absent on purpose: those are the builtin's
-- and the registry keeps them.
return {
    id = "plasma",
    visible = { tint = "#BF59F2" },
}
