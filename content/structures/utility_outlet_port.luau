-- The utility outlet port: the branch circuit's public face, what a
-- corded appliance plugs into, and the one place on the deck where you
-- can read what the cables under it are doing.
--
-- ELECTRICAL, not atmospheric. It has nothing to do with air -- the fan
-- that blows a room full of it is `vent.luau`, an ordinary machine in
-- the plumbing.
--
-- IT STANDS ON THE FLOOR rather than hanging on a wall, which is the
-- one thing about it that is a decision. A socket at knee height is a
-- picture of a house; a squat bollard bolted to the deck beside the
-- cable run is a picture of a ship, and it can sit in the middle of a
-- room where a wall socket cannot. Nothing about the cord rule changes
-- with it: an appliance still reaches the NEAREST port within
-- `cord_range` (content/tuning.luau), and never through a wall or a
-- shut door.
--
-- THREE LAMPS, one per cable layer beneath it. The engine picks each
-- one independently from what that layer's segment is actually doing
-- (../lunatic/docs/content-schema/fixture-states.md), so a port on a
-- live backbone and a dead room circuit shows both facts at once:
--
--   dark    -- no cable of that layer under the port at all
--   dim     -- cable, but nothing on its run that could supply it
--   red     -- something could supply it and the run is not carrying
--   yellow  -- carrying, but only off a panel's reserve
--   green   -- carrying
--
-- WHICH ONE IT DRAWS FROM is not one of the lamps: it is the first
-- live layer in the station's own order, L2 before L1 before L3
-- (../lunatic/docs/power/topology.md). Green on more than one lamp
-- therefore means a choice was made, not that two things are being
-- drawn from -- read the order to know which.
--
-- No transitions. Nothing on this station builds one, and there is no
-- board, no vendor row and no dispenser entry that names it: ports are
-- part of the deck, laid with the cable.
return {
    id = "utility_outlet_port",
    name = "utility outlet port",
    -- The housing on its own. The three lamps are overlays the engine
    -- lays over it, one per layer, and a port with no cable under it at
    -- all still draws the box.
    sprite = "utility_outlet_port",
    fixture = "Outlet",
    appearance = {
        states = {
            wire_1_disconnected = "uop_wire_1_disconnected",
            wire_1_inactive = "uop_wire_1_inactive",
            wire_1_starved = "uop_wire_1_starved",
            wire_1_emergency = "uop_wire_1_emergency",
            wire_1_nominal = "uop_wire_1_nominal",
            wire_2_disconnected = "uop_wire_2_disconnected",
            wire_2_inactive = "uop_wire_2_inactive",
            wire_2_starved = "uop_wire_2_starved",
            wire_2_emergency = "uop_wire_2_emergency",
            wire_2_nominal = "uop_wire_2_nominal",
            wire_3_disconnected = "uop_wire_3_disconnected",
            wire_3_inactive = "uop_wire_3_inactive",
            wire_3_starved = "uop_wire_3_starved",
            wire_3_emergency = "uop_wire_3_emergency",
            wire_3_nominal = "uop_wire_3_nominal",
        },
    },
    category = "power",
    examine = {
        flavor = "A squat grey box bolted to the deck, two round sockets "
            .. "on its face and three small lamps along the bottom. One "
            .. "lamp per cable layer under the floor; a green one is a "
            .. "layer this port could draw from.",
    },
}
