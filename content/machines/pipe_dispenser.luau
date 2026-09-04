-- The pipe dispenser: where an atmospherics technician's day starts.
--
-- tg's `/obj/machinery/pipedispenser` (code/game/machinery/pipe/
-- pipe_dispenser.dm). It hands out fittings, free, one per second, onto
-- its own tile — and takes them back if you have finished with them.
-- Everything it stocks is a NOUN this pack already has a file for, so
-- the dispenser is a shelf list and nothing else: the machine that
-- dispenses is the same engine machine the softdrinks vendor is.
--
-- THE SHELVES are tg's own recipe categories, in tg's own words
-- (`GLOB.atmos_pipe_recipes`, code/_globalvars/lists/pipe_recipes.dm).
-- All four of tg's categories are here. What else tg lists and this
-- pack does not have yet: the bridge and multi-deck adapters under
-- Pipes. Every one of them is one line here on the day it becomes a
-- thing — which is exactly what the analyzer cost the tool vendor,
-- and exactly what the scrubber, the injector and the two vents cost
-- this shelf.
--
-- WHAT TG HAS THAT THIS SHELF CANNOT SAY: tg's window carries a piping
-- layer, a paint colour and a per-recipe direction, because tg's
-- dispenser hands you a fitting already set. Ours hands you the fitting
-- and the RPD is where the settings live (items/rpd.luau). tg's own
-- flip toggle is likewise absent — a flipped trinary is a second
-- fitting here (docs/CONSTRUCTION.md, "Fittings, portables, and the round trip"), which is why
-- both mirror images are on the shelf.
--
-- The group order below is the window's stable order between rounds.
return {
    id = "pipe_dispenser",
    name = "pipe dispenser",
    sprite = "pipe_dispenser",
    ui = { modules = { "shelf" }, opens_on_click = false },
    dense = true,
    -- Its own file, not the vendor's: a dispenser also takes fittings
    -- BACK, and a softdrinks machine must never learn how to swallow
    -- a pump.
    script = "pipe_dispenser",
    corded = true,
    infinite_stock = true,
    -- tg's `wait = world.time + 1 SECONDS` (pipe_dispenser.dm:213).
    vend_secs = 1.0,
    -- tg's own `desc`, which is the whole personality of the thing.
    ad = "Dispenses countless types of pipes. Very useful if you need pipes.",
    categories = { "Pipes", "Binary", "Devices", "Heat Exchange" },
    -- tg's dispenser has no stock at all — it conjures. `infinite_stock`
    -- makes the shelf count display-only in every mode.
    vends = {
        { item = "pipe", name = "Pipe", category = "Pipes", amount = 999 },
        { item = "layer_adapter_fitting", name = "Layer Adapter", category = "Pipes", amount = 999 },
        { item = "color_adapter_fitting", name = "Color Adapter", category = "Pipes", amount = 999 },

        { item = "manual_valve_fitting", name = "Manual Valve", category = "Binary", amount = 999 },
        { item = "digital_valve_fitting", name = "Digital Valve", category = "Binary", amount = 999 },
        { item = "pump_fitting", name = "Pump", category = "Binary", amount = 999 },
        { item = "volume_pump_fitting", name = "Volume Pump", category = "Binary", amount = 999 },
        { item = "passive_gate_fitting", name = "Passive Gate", category = "Binary", amount = 999 },
        { item = "pressure_valve_fitting", name = "Pressure Valve", category = "Binary", amount = 999 },
        { item = "temperature_gate_fitting", name = "Temperature Gate", category = "Binary", amount = 999 },
        { item = "temperature_pump_fitting", name = "Temperature Pump", category = "Binary", amount = 999 },

        { item = "filter_fitting", name = "Filter", category = "Devices", amount = 999 },
        { item = "filter_flipped_fitting", name = "Filter (flipped)", category = "Devices", amount = 999 },
        { item = "mixer_fitting", name = "Mixer", category = "Devices", amount = 999 },
        { item = "mixer_flipped_fitting", name = "Mixer (flipped)", category = "Devices", amount = 999 },
        { item = "connector_port_fitting", name = "Connector", category = "Devices", amount = 999 },
        { item = "pipe_meter", name = "Meter", category = "Devices", amount = 999 },
        -- The two ends of the air loop: some take a room's air away,
        -- the rest hand it back. Everything else on this shelf moves
        -- gas between two PIPES.
        --
        -- The vent is the one an engineer reaches for most and the one
        -- a station has most of: a scrubber and an injector are
        -- department kit, and a vent is what every room with people in
        -- it needs one of.
        { item = "air_scrubber_fitting", name = "Air Scrubber", category = "Devices", amount = 999 },
        { item = "air_injector_fitting", name = "Air Injector", category = "Devices", amount = 999 },
        { item = "vent_fitting", name = "Air Vent", category = "Devices", amount = 999 },
        { item = "passive_vent_fitting", name = "Passive Vent", category = "Devices", amount = 999 },

        -- tg's own Heat Exchange shelf (`GLOB.atmos_pipe_recipes`,
        -- _globalvars/lists/pipe_recipes.dm:29-34). tg stocks "Pipe",
        -- "Manifold" and "4-Way Manifold" as three objects; a length's
        -- shape is derived from what it joins here, so all three are the
        -- one entry and a manifold is what a fourth length makes.
        { item = "he_pipe", name = "Pipe", category = "Heat Exchange", amount = 999 },
        { item = "he_junction_fitting", name = "Junction", category = "Heat Exchange", amount = 999 },
        { item = "heat_exchanger_fitting", name = "Heat Exchanger", category = "Heat Exchange", amount = 999 },
    },
}
