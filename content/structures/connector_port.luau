-- The connector port: the socket a portable atmospherics device is
-- fastened to, and the only place on the station one can be.
--
-- tg's `/obj/machinery/atmospherics/components/unary/portables_connector`
-- (components/unary_devices/portables_connector.dm). It is not a
-- machine: it draws no power, has no state to speak of, and its entire
-- job is that a device standing on it gets to breathe into the pipeline
-- it is assembled into (`return_airs_for_reconcilation`). It is a PIPE
-- FITTING, one per tile, and it hides under the floor.
--
-- `fitting = true` is that sentence to the engine, and it buys three
-- things at once: the port never gets in the way of anything on its
-- tile, a click reaches whatever is standing on it first, and while it
-- is bolted down it is what an `over = "fitting"` step fastens to.
--
-- The two states are the two halves of "assembled into the network".
-- Bolted, it has a stub running down into the run and it is a socket.
-- Unbolted, it is a length of pipe lying on the deck: joined to
-- nothing, hosting nothing, and light enough to shove around. Bolting
-- it needs pipe under the tile (`over = "pipe"`) — a socket wired to no
-- plumbing is the thing this whole design exists to make impossible.
--
-- Two seconds each way, which is tg's atmospherics wrench (its
-- `can_unwrench` path runs a do_after). The canister that fastens to
-- this is instant; laying the plumbing is not.
return {
    id = "connector_port",
    name = "connector port",
    sprite = "connector_port",
    fitting = true,
    -- Under the deck: you walk over a port, you do not walk around it.
    dense = false,
    states = { "anchored", "displaced" },
    loose = { "displaced" },
    state_sprites = {
        anchored = "connector_port",
        displaced = "connector_port_loose",
    },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            to = "displaced",
            start = "You start unbolting the connector port.",
            done = "The connector port comes up off the pipe.",
        },
        {
            at = "displaced",
            tool = "wrench",
            secs = 2.0,
            -- A port is a fitting ON a run. No run, no port.
            over = "pipe",
            to = "anchored",
            start = "You start bolting the connector port down.",
            done = "The connector port is seated on the pipe.",
        },
    },
}
