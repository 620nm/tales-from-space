-- THE TWO-TILE AIRLOCK, east to west. One leaf, two tiles, one doorway.
--
-- tg's /obj/machinery/door/airlock/multi_tile
-- (code/game/machinery/doors/airlock.dm:2581-2607): one door object hung
-- off a single tile with an invisible filler standing on the tile beside
-- it (`set_filler`, code/game/machinery/doors/door.dm:198-208), so both
-- tiles block, both tiles seal, and one swing moves them together. Here
-- that is a `footprint`: the anchor is the tile a map names, the second
-- cell is one step east -- exactly where tg puts the filler for a leaf
-- facing north or south -- and the engine's door mechanism answers for
-- both from the one leaf (docs/FOOTPRINTS.md,
-- docs/construction/doors.md).
--
-- TWO ENTRIES, NOT ONE WITH A DIRECTION. A footprint does not rotate
-- (docs/FOOTPRINTS.md), and the two orientations are not one picture
-- turned: tg draws each in its own direction of the 64x64 cell, the
-- south-facing leaf across the bottom and the east-facing leaf down the
-- left. So a doorway running north to south is `airlock_wide_ns`, the
-- same door said the other way round, and a mapper picks the one that
-- fits the wall they cut.
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
-- open or halfway through either swing, from EITHER of its tiles.
--
-- No `paints` beyond the one: a wide door is a hallway door, and tg
-- draws no department stripes on this sheet.
return {
    id = "airlock_wide_ew",
    name_label = "lunatic/tfs:entity.airlock_wide_ew.name",
    name = "wide airlock",
    sprite = "door_wide_w",
    fixture = "Door",
    category = "power",
    -- West tile then east tile, which is the order every per-cell
    -- picture in the livery below is written in.
    footprint = {
        { at = { 0, 0 } },
        { at = { 1, 0 }, sprite = "door_wide_e" },
    },
    paints = {
        {
            id = "interior",
            glass = {
                closed = { "door_wide_w", "door_wide_e" },
                open = { "door_wide_open_w", "door_wide_open_e" },
                opening = { "door_wide_opening_w", "door_wide_opening_e" },
                closing = { "door_wide_closing_w", "door_wide_closing_e" },
            },
        },
    },
    examine = {
        flavor = "A doorway two men wide, glazed the whole way across. "
            .. "Both leaves run off the one motor.",
    },
}
