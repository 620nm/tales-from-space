-- THE TWO-TILE AIRLOCK, north to south. The same leaf as
-- `airlock_wide_ew`, standing in a wall that runs the other way; that
-- file carries the whole story and the tg citations.
--
-- What differs is the two things that CANNOT be shared. The second cell
-- is one step NORTH -- tg's filler goes north of a leaf facing east or
-- west and east of one facing north or south (`n(dir)`,
-- code/game/machinery/doors/door.dm:198-208) -- and the pictures are the
-- sheet's east-facing direction rather than its south-facing one, which
-- is a different drawing and not the same drawing turned. Offsets are in
-- map frame, so north is -y: the anchor a map names is the SOUTH tile.
return {
    id = "airlock_wide_ns",
    name_label = "lunatic/tfs:entity.airlock_wide_ns.name",
    name = "wide airlock",
    sprite = "door_wide_s",
    fixture = "Door",
    category = "power",
    -- South tile then north tile, which is the order every per-cell
    -- picture in the livery below is written in.
    footprint = {
        { at = { 0, 0 } },
        { at = { 0, -1 }, sprite = "door_wide_n" },
    },
    paints = {
        {
            id = "interior",
            glass = {
                closed = { "door_wide_s", "door_wide_n" },
                open = { "door_wide_open_s", "door_wide_open_n" },
                opening = { "door_wide_opening_s", "door_wide_opening_n" },
                closing = { "door_wide_closing_s", "door_wide_closing_n" },
            },
        },
    },
    examine = {
        flavor = "A doorway two men wide, glazed the whole way across. "
            .. "Both leaves run off the one motor.",
    },
}
