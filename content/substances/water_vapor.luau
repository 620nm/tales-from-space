-- Steam, for its LOOK only. The twin of plasma.luau, and the same
-- mechanism: a builtin's physics stay in the engine registry (I9,
-- docs/reagents.md) and its colour comes from here.
--
-- `water_vapor` is the humidity gas a plasma fire makes -- distinct
-- from the gas phase of `water`, which is what a boiled beaker gives
-- off. The builtin roster gives this one a visibility threshold and
-- water none, so a burning room fogs and a kettle does not; the day
-- water's gas earns a threshold, this soft grey-white is already the
-- colour it will wear.
--
-- Almost white with the faintest blue in it (0.90/0.93/0.97 in the old
-- renderer, unchanged): fog reads as a thinning of the room rather than
-- a colour laid over it, which is the only way a hazard overlay can sit
-- on top of a corridor without hiding what is in it.
return {
    id = "water_vapor",
    visible = { tint = "#E6EDF7" },
}
