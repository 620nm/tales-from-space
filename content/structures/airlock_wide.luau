-- THE TWO-TILE AIRLOCK. One leaf, two tiles, one doorway, either way
-- the wall runs.
--
-- tg's /obj/machinery/door/airlock/multi_tile
-- (code/game/machinery/doors/airlock.dm:2581-2607): one door object hung
-- off a single tile with an invisible filler standing on the tile beside
-- it -- east of a leaf facing north or south, north of one facing east
-- or west (`set_filler` and `n(dir)`,
-- code/game/machinery/doors/door.dm:198-208) -- so both tiles block,
-- both tiles seal, and one swing moves them together.
--
-- Here that is a `footprint` and a `facings` list. The footprint is the
-- SOUTH shape: the anchor a map names, and the second cell one step
-- east. Placed `dir = "east"` the engine turns it a quarter at a time
-- and the second cell lands one step NORTH instead, which is exactly
-- where tg's filler goes for that facing (docs/content-schema/facings.md,
-- docs/FOOTPRINTS.md). One entry, two doorways.
--
-- THE PICTURES ARE NOT ONE DRAWING TURNED, which is why they are said
-- per facing. tg authors the leaf in a 64x64 cell and draws each
-- direction separately -- the south-facing door across the bottom
-- 64x32, the east-facing one down the left 32x64 -- so a turn moves the
-- cells and the file says what each cell wears once it gets there.
--
-- WHY IT IS NOT A VARIANT of `airlock`: a footprint is a fact about the
-- entry, not about a placement. `airlock` stands in one doorway and this
-- stands in two, and nothing a map could write turns one into the other.
--
-- GLAZED BY CONSTRUCTION. tg ships no solid multi-tile leaf: the sheet
-- has no `fill_` family at all, only the frame and the glass overlay
-- that fills it (multi_tile/public/glass.dmi beside its overlays.dmi),
-- and the object sets `glass = TRUE`, `opacity = FALSE` at :2586-2587.
-- So the livery below declares its glazed pictures and no solid ones,
-- which is the schema's way of saying this door has a window in it and
-- there was never a version that did not. It never blocks sight, shut or
-- open or halfway through either swing, from EITHER of its tiles, in
-- EITHER facing.
--
-- No `paints` beyond the one: a wide door is a hallway door, and tg
-- draws no department stripes on this sheet.
return {
    id = "airlock_wide",
    name_label = "lunatic/tfs:entity.airlock_wide.name",
    name = "wide airlock",
    sprite = "door_wide_w",
    fixture = "Door",
    category = "power",
    facings = { "south", "east" },
    -- The south shape: the anchor, then the tile east of it. That order
    -- is the order every per-cell row below is written in, and it
    -- survives a turn -- so the second name is the second cell wherever
    -- the turn puts it.
    footprint = {
        { at = { 0, 0 } },
        { at = { 1, 0 }, sprite = "door_wide_e" },
    },
    paints = {
        {
            id = "interior",
            glass = {
                closed = {
                    south = { "door_wide_w", "door_wide_e" },
                    east = { "door_wide_s", "door_wide_n" },
                },
                open = {
                    south = { "door_wide_open_w", "door_wide_open_e" },
                    east = { "door_wide_open_s", "door_wide_open_n" },
                },
                opening = {
                    south = { "door_wide_opening_w", "door_wide_opening_e" },
                    east = { "door_wide_opening_s", "door_wide_opening_n" },
                },
                closing = {
                    south = { "door_wide_closing_w", "door_wide_closing_e" },
                    east = { "door_wide_closing_s", "door_wide_closing_n" },
                },
            },
        },
    },
    examine = {
        flavor = "A doorway two men wide, glazed the whole way across. "
            .. "Both leaves run off the one motor.",
    },
}
