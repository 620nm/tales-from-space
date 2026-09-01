-- The access point: the box on the wall a segment of the station's
-- device network hangs off.
--
-- It is a HUB (docs/DEVICES.md §2), which is the middle of the three
-- roles and the only one that matters to somebody standing in a
-- corridor: devices join to it from within five tiles, and it may in
-- turn join a router. A hub with one device joined to it IS a network
-- -- nothing above it is required -- so a shift that has lost its
-- router still has as many small networks as it has access points.
--
-- FIVE TILES. Far enough to cover the room it is bolted in and the
-- doorway out of it, short enough that a second one is what covers the
-- next room. tg has no number to copy here: its telecomms machines
-- reach by z-level and its wall boxes reach by wire.
--
-- WHERE ITS ADDRESS COMES FROM. Nowhere, until somebody fits a card.
-- The `socket` says the address is whatever is in the network socket
-- (docs/DEVICES.md §5a), so an access point with an empty socket is on
-- no network at all, and pulling the card takes the whole segment off
-- the air without forgetting a single join.
--
-- WHAT ITS LOCK IS KEYED TO IS NOT WRITTEN HERE, and cannot be. A lock
-- names no claim in a file: it takes the placement's own `access` word,
-- the same row an airlock's placement carries, so one entry stands up a
-- rack of nodes keyed to different departments
-- (docs/CONTENT-SCHEMA.md §1.10c). One built by hand out of a wall
-- frame has no placement and therefore no key -- which is still a lock,
-- because it has to be worked by somebody standing at it, and the
-- engineer who screwed it together is exactly that somebody.
return {
    id = "access_point",
    name = "access point",
    sprite = "access_point",
    mount = true,
    corded = true,
    ui = { modules = { "link", "parts" } },
    -- One state, so one set of four faces answers for the whole entry.
    appearance = {
        mounted = {
            north = "access_point_n", south = "access_point_s",
            east = "access_point_e", west = "access_point_w",
        },
    },
    category = "power",
    parts = { slots = { "network" } },
    link = { role = "hub", radius = 5, socket = "network", locked = true },
    examine = {
        flavor = "A flat panel with one indicator on it. Whatever it is "
            .. "carrying, it carries quietly.",
    },
    transitions = {
        -- The crowbar, and the whole assembly with it. The frame stands
        -- back up in its FIRST state -- bare metal -- so the five coils
        -- the wiring cost come back in this pile, exactly as the
        -- temperature control unit's do
        -- (structures/thermomachine.luau).
        --
        -- THE SOCKET SAYS WHAT COMES OUT, so the network card is NOT
        -- written here: a `yields` list is written once and cannot know
        -- which card this one was built around, while the roster in
        -- front of it can (docs/CONTENT-SCHEMA.md §1.10b). Naming a
        -- component here is a load error for that reason, and it is the
        -- reason worth wanting -- the card that comes back out is the
        -- card that was in it, address and joins and all.
        {
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "wall_frame",
            yields = {
                ["machine_board.access_point"] = 1,
                cable_coil = 5,
            },
            start = "You start prying the access point apart.",
            done = "The access point comes apart, leaving its frame on the wall.",
        },
    },
}
