-- Plasteel: iron and plasma alloyed into the sheet a station's hard
-- parts are made of (tg sheet_types.dm:309-312, "an alloy of iron and
-- plasma"). What it BUILDS is written where it is built, the same as
-- metal -- a reinforced girder knows one sheet reinforces it, a
-- reinforced girder knows one more plates it into hull.
--
-- Fifty to a stack, which is the sheet family's own maximum and not a
-- number chosen here (sheets.dm:10). The picture is tg's single-sheet
-- state rather than metal's three-high pile, because that is the
-- icon_state the plasteel entry names for itself (sheet_types.dm:313)
-- and a stack of plasteel is a rarer thing to be holding.
return {
    id = "plasteel",
    name = "plasteel sheets",
    sprite = "plasteel",
    inhand_sprite = { "held_plasteel_l", "held_plasteel_r" },
    -- The whole sheet family sounds like the metal it is
    -- (sheets.dm:18-19), plasteel included.
    pickup_sound = "metal_pickup",
    drop_sound = "metal_drop",
    stack = 50,
}
