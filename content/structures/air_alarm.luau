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
-- SEVENTEEN TILES, and the number is this pack's own rather than a
-- port, because the thing being replaced is an area. A Chebyshev
-- seventeen is a thirty-five by thirty-five square, and the shipped
-- map's hull is thirty-three by thirty-three -- x 4..36 by y 3..35 of a
-- forty by thirty-nine grid (maps/chillstation.ron) -- so an alarm
-- bolted anywhere near the middle of the station reaches every tile on
-- it, and one near an outer wall still reaches most of the far side.
--
-- That is deliberate, and it changes what the radius IS. At seven it
-- was a room measurement: the smallest circle that covered the largest
-- compartment (Atmospherics, thirteen by seven) from its long wall, and
-- an alarm could not adopt the plant next door. At seventeen it is a
-- ceiling and nothing more, and WHICH machines an alarm holds is
-- decided by the two things below it -- `accepts = { "atmos" }`, which
-- refuses everything that is not plumbing, and the join gesture itself,
-- which an engineer makes one machine at a time. A room's alarm is the
-- one somebody joined its vents to, not the one that happens to be
-- within reach of them.
--
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
-- WHAT DOES NOT WEAR IT, and why, since three machines in the kit have
-- a window and are still not on any alarm:
--
--   * the MANUAL VALVE has no window at all and is meant not to. It is
--     the one component nobody operates from a chair -- somebody walks
--     to it and puts a hand on the wheel -- and the digital valve
--     beside it exists precisely to be the remote one
--     (structures/manual_valve.luau, structures/digital_valve.luau).
--   * the CANISTER has a window, and it is a bottle on wheels: it is
--     unanchored until a wrench fastens it to a port, and a crewman
--     rolls it out of the room mid-shift. A radius join would bind a
--     moving target and suspend itself the moment it left, and tg's
--     alarm never drove a portable device either
--     (structures/canister.luau).
--   * the STATIONARY TANK has a window with nothing in it to turn. It
--     is a holder table -- what is inside and what it is rated to --
--     and its valves are its ports, worked with a wrench and a pipe
--     (sim/ui/settings/tank.rs). Proxying it would put a page of
--     readouts on the console and hand a crewman nothing to press.
--
-- The meters and the passive vent are the same argument as the tank:
-- gauges, and a hole in a wall.
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
    -- WHAT IT LOOKS LIKE IS WHAT IT IS DOING. tg draws this box shut
    -- (`alarmp`) with a teal lamp laid over it, and draws NO lamp at
    -- all while it is unpowered, broken or shorted
    -- (_air_alarm.dm:554-556, :522-525). The two states this engine can
    -- derive land on exactly those two pictures: a live box on a live
    -- segment shows the lamp, a dead cord or a box off the air shows
    -- the same panel dark. `offline` and `unpowered` are the same cell
    -- on purpose -- tg draws one picture for "not working" and so does
    -- this. The yellow and red faces are baked and named by nothing
    -- yet; they want a threshold pass over the room's mix
    -- (assets/sprites/73-network.ron).
    --
    -- No entry-wide `appearance.mounted`: every row here carries its
    -- own four faces, which is what a mount needs and what lets the
    -- picture change without losing the wall it hangs on
    -- (docs/content-schema/appearance.md).
    appearance = {
        device = {
            online = { sprite = "air_alarm_lit", mounted = {
                north = "air_alarm_lit_n", south = "air_alarm_lit_s",
                east = "air_alarm_lit_e", west = "air_alarm_lit_w",
            } },
            offline = { sprite = "air_alarm", mounted = {
                north = "air_alarm_n", south = "air_alarm_s",
                east = "air_alarm_e", west = "air_alarm_w",
            } },
            unpowered = { sprite = "air_alarm", mounted = {
                north = "air_alarm_n", south = "air_alarm_s",
                east = "air_alarm_e", west = "air_alarm_w",
            } },
        },
    },
    category = "atmospherics",
    parts = { slots = { "network" } },
    link = {
        role = "hub",
        radius = 17,
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
