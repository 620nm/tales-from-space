-- The network router: the rack that tops a station's device network.
--
-- It is a ROOT (docs/DEVICES.md §2), and a root does exactly two
-- things. It accepts access points -- hubs only, never devices, because
-- a device belongs to the room it is in and not to the rack in the
-- server closet -- and it HEARS ITS WHOLE TREE. That second one is the
-- only asymmetry in the routing rule (§5): every other node hears its
-- own segment and one hop up, while whatever a root tops reaches the
-- root as well. A station with a router is a station where one machine
-- is listening to all of it, which is the reason to build one and the
-- reason to care who can open it.
--
-- Two roots are two networks, however close they stand. Nothing about
-- putting a second one in the same closet joins the two -- the shape of
-- the forest is the whole security model.
--
-- tg's nearest thing is the telecommunications relay, "a mighty piece
-- of hardware used to send massive amounts of data far away"
-- (code/game/machinery/telecomms/machines/relay.dm:9-11), whose board
-- asks for two servos, two lengths of cable and two subspace filters
-- (machine_circuitboards.dm:160-168). This pack models neither
-- subspace nor netspeed, so the servos and the filters have nothing to
-- be worth: the one socket that means something is the one the address
-- comes out of, and the cable is on the board.
--
-- WHERE ITS ADDRESS COMES FROM, and what its lock is keyed to, are the
-- access point's two answers exactly (structures/access_point.luau): a
-- card in the network socket, and the placement's own `access` word.
return {
    id = "network_router",
    name = "network router",
    sprite = "network_router",
    script = "network_router",
    ui = { modules = { "link", "parts" } },
    dense = true,
    corded = true,
    examine = {
        flavor = "A floor-standing rack with a row of dark sockets down "
            .. "one side. Everything joined to it reaches it, whether or "
            .. "not it reaches back.",
    },
    parts = { slots = { "network" } },
    link = { role = "root", socket = "network", locked = true },
    -- The two generic rungs every finished machine has: a screwdriver
    -- opens the panel, a crowbar pries it apart, and what is left
    -- standing is the frame it was screwed together from, holding the
    -- board and everything in the sockets (docs/CONSTRUCTION.md).
    teardown = {
        open = "screwdriver",
        remove = "crowbar",
        into = "machine_frame",
        state = "boarded",
    },
}
