-- THE AIRLOCK. One file, every door on the station.
--
-- tg has a subtype per department and per glazing:
-- /obj/machinery/door/airlock/engineering beside /glass beside
-- /glass/engineering, each one a copy of the same object with a
-- different sheet name and a different `req_access` (airlock.dm). That
-- ladder is what `paints`, `glass` and `access` exist to refuse. A door
-- is one noun; which livery it wears, whether somebody put a window in
-- it and who may walk through are facts about the leaf somebody bolted
-- into THAT doorway, and a map says them per placement:
--
--   (10, 3, "airlock", { "paint": "engineering", "glass": true,
--                        "access": "engineering" })
--
-- Four appearances per livery, not two: the two rests and the two
-- swings between them (tg's AIRLOCK_FRAME_OPENING/CLOSING appended by
-- `update_icon_state`, airlock.dm:556). A door that only knew "shut"
-- and "open" would teleport through half of every cycle.
--
-- NOT dense, and that is not a mistake. Whether a leaf fills its
-- doorway is what `open` says, and the engine reads that directly
-- (sim/movement.rs) -- a standing `dense` flag would say "always", and
-- an open door you cannot walk through is not a door.
--
-- No `transitions`: taking an airlock apart is a job nobody has
-- authored yet. tg pries one with a crowbar when it is unpowered and
-- cuts the frame out with a welder; both are construction steps waiting
-- on a door-assembly entry, and until then the leaf is furniture the
-- station came with.
return {
    id = "airlock",
    name_label = "lunatic/tfs:entity.airlock.name",
    name = "airlock",
    sprite = "door",
    fixture = "Door",
    script = "airlock",
    link = { network_interface = true, role = "endpoint", class = "atmos" },
    category = "power",
    paints = {
        -- The station's own, and the default: a placement that names no
        -- livery gets this one. tg's /obj/machinery/door/airlock
        -- (station/public.dmi).
        {
            id = "public",
            closed = "door",
            bolt_lights = "door_bolt_lights",
            open = "door_open",
            opening = "door_opening",
            closing = "door_closing",
            glass = {
                closed = "door_glass",
                bolt_lights = "door_bolt_lights",
                open = "door_glass_open",
                opening = "door_glass_opening",
                closing = "door_glass_closing",
            },
        },
        -- Engineering's stripes (station/engineering.dmi). The paint is
        -- a LIVERY and nothing else: what stops somebody walking
        -- through is `access`, said separately, because a striped door
        -- nobody locked is a thing a station has.
        {
            id = "engineering",
            closed = "door_eng",
            bolt_lights = "door_bolt_lights",
            open = "door_eng_open",
            opening = "door_eng_opening",
            closing = "door_eng_closing",
            glass = {
                closed = "door_eng_glass",
                bolt_lights = "door_bolt_lights",
                open = "door_eng_glass_open",
                opening = "door_eng_glass_opening",
                closing = "door_eng_glass_closing",
            },
        },
        -- The interior leaf, for a doorway inside the hull rather than
        -- one onto a maintenance shaft: two tall panes over the height
        -- of the door instead of the station livery's letterbox slot.
        -- tg's /obj/machinery/door/airlock/public
        -- (code/game/machinery/doors/airlock.dm:2274-2283), which is a
        -- whole sheet and not a recolour, so the glazed set below reads
        -- ITS overlays -- panes are only in the right place on the
        -- frame they were drawn for.
        {
            id = "interior",
            closed = "door_int",
            bolt_lights = "door_int_bolt_lights",
            open = "door_int_open",
            opening = "door_int_opening",
            closing = "door_int_closing",
            glass = {
                closed = "door_int_glass",
                bolt_lights = "door_int_bolt_lights",
                open = "door_int_glass_open",
                opening = "door_int_glass_opening",
                closing = "door_int_glass_closing",
            },
        },
    },
    examine = {
        flavor = "A powered leaf on a track. It opens for anyone it "
            .. "recognises and shuts itself behind them.",
    },
    -- The doors a mapper reaches for often enough to name. Each is the
    -- same three properties any placement may already write, said
    -- once: this is the subtype ladder collapsed rather than rebuilt,
    -- and a placement may still say otherwise -- `(x, y,
    -- "airlock.engineering_glass", { "glass": false })` is an
    -- engineering door somebody left solid.
    variants = {
        engineering = {
            name_label = "lunatic/tfs:entity.airlock.engineering.name",
            name = "engineering airlock",
            props = { paint = "engineering", access = "engineering" },
        },
        engineering_glass = {
            name_label = "lunatic/tfs:entity.airlock.engineering_glass.name",
            name = "engineering airlock",
            props = { paint = "engineering", access = "engineering", glass = true },
        },
        -- The windowed interior door, which is the one a hallway wants:
        -- the interior livery with the panes glazed, so a corridor can
        -- be shut off without being blinded. Unlocked, because a door
        -- across a public hallway is not a door anybody was meant to be
        -- stopped by.
        interior_glass = {
            name_label = "lunatic/tfs:entity.airlock.interior_glass.name",
            name = "glass airlock",
            props = { paint = "interior", glass = true },
        },
    },
}
