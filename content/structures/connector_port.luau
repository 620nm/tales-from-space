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
-- THE ROUND TRIP. A port is never PLACED and never DISPLACED -- it is
-- built out of a fitting item and it yields that fitting back. That is
-- tg's universal atmospherics construction, not a quirk of this one
-- device: `/obj/item/pipe/wrench_act` deletes the fitting and spawns
-- the machine (construction.dm:268-312), and `on_deconstruction` mints
-- the machine's `construction_type` back onto the tile
-- (atmosmachinery.dm:511-520). So there is exactly one state here.
-- Everything a "displaced port" used to be is now an item in somebody's
-- hands (items/connector_port.luau), which is the whole point: you can
-- pick it up, carry it across the station, and put it down somewhere
-- better.
--
-- Two seconds each way, which is tg's atmospherics wrench (its
-- `can_unwrench` path runs `use_tool(..., 2 SECONDS)`,
-- atmosmachinery.dm:456). The canister that fastens to this is instant;
-- laying the plumbing is not.
--
-- The stub is the whole of the port's connection to the run. Josh's
-- rule: it joins the pipe network THROUGH its visible pipe stub, not
-- through its four sides. tg says the same thing in one line -- a unary
-- atmospherics component's `initialize_directions` IS its dir
-- (components/unary_devices/unary_devices.dm:14) -- so a port aimed at
-- bare deck feeds nothing, whatever is laid on its other three sides.
-- A port raised from a fitting aims itself at the run it is being
-- bolted onto, which is the same tile the `over = "pipe"` refusal just
-- checked. (tg lets you turn the fitting in hand first,
-- `/obj/item/pipe/attack_self`, construction.dm:256-257; that wants a
-- rotate command this protocol has not grown yet.)
return {
    id = "connector_port",
    name = "connector port",
    sprite = "connector_port_s",
    fitting = true,
    stub = true,
    facing_sprites = {
        anchored = {
            north = "connector_port_n",
            south = "connector_port_s",
            east = "connector_port_e",
            west = "connector_port_w",
        },
    },
    -- Under the deck: you walk over a port, you do not walk around it.
    dense = false,
    -- One state, and it is the only state a port in the world is ever
    -- in. Bolted down is what a port IS; the alternative is not a port
    -- lying on the floor, it is a fitting in your hands.
    states = { "anchored" },
    build = {
        on = { "floor", "plating" },
        from_item = "connector_port_fitting",
        tool = "wrench",
        secs = 2.0,
        -- A port is a fitting ON a run. No run, no port.
        over = "pipe",
        start = "You start bolting the connector port down.",
        done = "The connector port is seated on the pipe.",
    },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            -- tg's `can_unwrench`: "You cannot unwrench [src], detach
            -- [connected_device] first!" (portables_connector.dm:54-58).
            -- You do not pull the socket out from under a bottle that
            -- is plumbed into it.
            bare = true,
            gone = true,
            yields = { connector_port_fitting = 1 },
            start = "You start unbolting the connector port.",
            done = "The connector port comes up off the pipe.",
        },
    },
}
