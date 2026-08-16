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
-- Its own tile is the component's centre and must not also carry a raw
-- pipe on the same layer. Turn the loose fitting with Alt+left/Alt+right
-- before wrenching it down when automatic alignment is not the shape
-- you want.
--
-- NO `over = "pipe"` (Josh's ruling, 2026-08-16). A port may be bolted
-- down anywhere the deck will take one, with no run anywhere near it.
-- Which is how a station is actually built: you put the socket where
-- the bottle has to stand and then run pipe out to it, and a refusal at
-- the door made that ordering illegal for no gain. Nothing is lost by
-- allowing it, because nothing is CACHED: an unplumbed port is a socket
-- wired to nothing until a run reaches its stub, and the moment one
-- does the engine notices by looking rather than by being told
-- (`refresh_pipe_topology` re-derives every binding from the live grid,
-- sim/atmos_machines/). A canister on an unplumbed port fills the room
-- it stands in, exactly as one standing loose does (sim/vents.rs), so
-- the mistake is visible on the gauge instead of being argued about at
-- the wrench. A port raised with no run in reach aims north, the
-- engine's deterministic fallback; turn the fitting first if you know
-- which way the pipe is coming from.
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
        -- No `over`. The deck is the whole requirement; see the note
        -- above. What the port ends up JOINED to is a question the gas
        -- loop asks the live grid, not one the wrench asks the builder.
        start = "You start bolting the connector port down.",
        done = "The connector port is bolted to the deck.",
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
            done = "The connector port comes up off the deck.",
        },
    },
}
