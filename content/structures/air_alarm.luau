-- The air alarm: the box on the wall that a room's plumbing answers to.
--
-- tg's `/obj/machinery/airalarm` is the console every vent and scrubber
-- on a station is actually set from: a vent pump carries a direction, a
-- pressure check and two bounds, and an area's alarm writes all four
-- (`vent_pump.dm:24-30`). It finds the machines it drives by AREA and by
-- nothing else -- `my_area.air_vents` and `my_area.air_scrubbers`
-- (code/modules/atmospherics/machinery/air_alarm/_air_alarm.dm:119,
-- 315, 332) -- so there is no distance in tg to copy here.
--
-- This engine has no areas. What it has is a device forest, so an alarm
-- is a HUB: the vents and scrubbers of the room JOIN it, and the `reach`
-- module draws the settings of everything it holds (docs/TGUI.md). A
-- machine paired to one goes read-only at its own casing, which is the
-- same fact tg states by giving a vent no window of its own at all.
--
-- SEVEN TILES, and the number is this pack's own rather than a port,
-- because the thing being replaced is an area. It is the smallest
-- Chebyshev radius that covers the largest compartment on the shipped
-- map -- Atmospherics, thirteen tiles across (maps/chillstation.ron) --
-- from any wall the box can hang on, and short enough that it stops in
-- the corridor rather than reaching through into the next department.
-- The access point's five is a different claim and stays five: a comms
-- box covers the room it is in and the doorway out, where an alarm has
-- to reach a whole room's plant.
--
-- WHAT IT WILL TAKE, and the word it takes it by. `accepts` is the one
-- thing that makes this box different from an access point standing in
-- the same bracket: it holds atmospherics and refuses everything else,
-- so an alarm bolted up next to a transceiver never adopts it and never
-- lists it. "atmos" is this pack's word and the engine knows nothing
-- about it -- it compares opaque strings, which is what keeps a class
-- from becoming a permission (docs/content-schema/link.md).
--
-- It is SPELLED OUT here and in every endpoint that wears it, which is
-- the one place this pack repeats itself on purpose. `content/lib/` is
-- published into the item sandbox and not into the structure
-- registry's, so a structure reading a shared table reads nil at
-- prototype time (crates/lunatic-server/src/structures/registry.rs).
--
-- WHERE ITS ADDRESS COMES FROM, and what its lock is keyed to, are the
-- access point's answers exactly (structures/access_point.luau): a card
-- in the network socket, and the placement's own `access` word. Neither
-- is written here and neither can be.
return {
    id = "air_alarm",
    name = "air alarm",
    sprite = "air_alarm",
    mount = true,
    corded = true,
    -- The sentence a crewman gets for touching it, which is the only
    -- part of this box that is not mechanism (fixtures/air_alarm.luau).
    script = "air_alarm",
    -- `link` is the network half -- the address, the lock, the roster,
    -- what it could take. `reach` is the atmospherics half: one section
    -- per machine joined to it, drawn from that machine's own module.
    -- `parts` is the socket the card sits in.
    ui = { modules = { "link", "reach", "parts" } },
    -- One state, so one set of four faces answers for the whole entry,
    -- as the access point's does.
    appearance = {
        mounted = {
            north = "air_alarm_n", south = "air_alarm_s",
            east = "air_alarm_e", west = "air_alarm_w",
        },
    },
    category = "atmospherics",
    parts = { slots = { "network" } },
    link = {
        role = "hub",
        radius = 7,
        socket = "network",
        locked = true,
        accepts = { "atmos" },
    },
    examine = {
        flavor = "A flat panel with a lamp on it, wired into the room's "
            .. "plumbing. Every fan in here is set from this box.",
    },
    transitions = {
        -- The crowbar, and the assembly with it: the board's one length
        -- of cable plus the wall frame's five, which is the access
        -- point's arithmetic and for the same reason
        -- (structures/access_point.luau).
        --
        -- The network card is NOT listed. A `yields` list cannot know
        -- which card this box was built around, and the roster in front
        -- of it can (docs/CONTENT-SCHEMA.md §1.10b), so the card that
        -- comes back out is the card that went in -- address, joins and
        -- every vent in the room still bound to it.
        {
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "wall_frame",
            yields = {
                ["machine_board.air_alarm"] = 1,
                cable_coil = 6,
            },
            start = "You start prying the air alarm apart.",
            done = "The air alarm comes apart, leaving its frame on the wall.",
        },
    },
}
