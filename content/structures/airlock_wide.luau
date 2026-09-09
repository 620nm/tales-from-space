-- THE TWO-TILE AIRLOCK. One leaf, two tiles, one doorway.
--
-- tg's /obj/machinery/door/airlock/multi_tile
-- (code/game/machinery/doors/airlock.dm:2581-2607): one door object
-- hung off its west tile with an invisible filler standing on the tile
-- next door (`set_filler`, code/game/machinery/doors/door.dm:198-208),
-- so both tiles block, both tiles seal, and one swing moves them
-- together. Here that is a `footprint` rather than a second object --
-- the anchor is the west tile a map names, the second cell is one step
-- east, and the engine's door mechanism answers for both from the one
-- leaf (docs/FOOTPRINTS.md, docs/construction/doors.md).
--
-- WHY IT IS ITS OWN FILE and not a variant of `airlock`: a footprint is
-- a fact about the entry, not about a placement. `airlock` stands in one
-- doorway and this stands in two, and nothing a map could write turns
-- one into the other.
--
-- GLAZED BY CONSTRUCTION. tg ships no solid multi-tile leaf: the sheet
-- has no `fill_` family at all, only the frame and the glass overlay
-- that fills it (multi_tile/public/glass.dmi beside its overlays.dmi),
-- and the object sets `glass = TRUE`, `opacity = FALSE` at :2586-2587.
-- So the livery below declares its glazed pictures and no solid ones,
-- which is the schema's way of saying this door has a window in it and
-- there was never a version that did not. It never blocks sight, shut
-- or open or halfway through either swing, from EITHER of its tiles.
--
-- No `paints` beyond the one: a wide door is a hallway door, and tg
-- draws no department stripes on this sheet.
return {
    id = "airlock_wide",
    name_label = "lunatic/tfs:entity.airlock_wide.name",
    name = "wide airlock",
    sprite = "door_wide_l",
    fixture = "Door",
    category = "power",
    -- West tile then east tile, which is the order every per-cell
    -- picture in the livery below is written in.
    footprint = {
        { at = { 0, 0 } },
        { at = { 1, 0 }, sprite = "door_wide_r" },
    },
    paints = {
        {
            id = "interior",
            glass = {
                closed = { "door_wide_l", "door_wide_r" },
                open = { "door_wide_open_l", "door_wide_open_r" },
                opening = { "door_wide_opening_l", "door_wide_opening_r" },
                closing = { "door_wide_closing_l", "door_wide_closing_r" },
            },
        },
    },
    examine = {
        flavor = "A doorway two men wide, glazed the whole way across. "
            .. "Both leaves run off the one motor.",
    },
}
