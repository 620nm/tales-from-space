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
-- Three of tg's four are here; a category with nothing in it is not a
-- tab, it is an omission, so **Heat Exchange** is absent until the heat
-- exchanging family exists. What else tg lists and this pack does not
-- have yet: the layer, colour, bridge and multi-deck adapters under
-- Pipes, the temperature gate and temperature pump under Binary, and
-- the injector, scrubber, unary vent and passive vent under Devices.
-- Every one of them is one line here on the day it becomes a thing —
-- which is exactly what the gas analyzer cost the tool vendor.
--
-- WHAT TG HAS THAT THIS SHELF CANNOT SAY: tg's window carries a piping
-- layer, a paint colour and a per-recipe direction, because tg's
-- dispenser hands you a fitting already set. Ours hands you the fitting
-- and the RPD is where the settings live (items/rpd.luau). tg's own
-- flip toggle is likewise absent — a flipped trinary is a second
-- fitting here (docs/construction.md, "the trinaries"), which is why
-- both mirror images are on the shelf.
--
-- The tab ORDER is alphabetical rather than tg's, because the engine
-- sorts `categories` so the window is stable between rounds.
return {
    id = "pipe_dispenser",
    name = "pipe dispenser",
    sprite = "pipe_dispenser",
    dense = true,
    -- Its own file, not the vendor's: a dispenser also takes fittings
    -- BACK, and a softdrinks machine must never learn how to swallow
    -- a gas pump.
    script = "pipe_dispenser",
    corded = true,
    -- tg's `wait = world.time + 1 SECONDS` (pipe_dispenser.dm:213).
    vend_secs = 1.0,
    -- tg's own `desc`, which is the whole personality of the thing.
    ad = "Dispenses countless types of pipes. Very useful if you need pipes.",
    categories = {
        Pipes = "grip-lines",
        Binary = "arrows-alt-h",
        Devices = "microchip",
    },
    -- tg's dispenser has no stock at all — it conjures. The shelf count
    -- is display only, so it says the largest number the schema takes
    -- and means "as many as you like".
    vends = {
        { item = "pipe", name = "Pipe", category = "Pipes", amount = 999 },

        { item = "manual_valve_fitting", name = "Manual Valve", category = "Binary", amount = 999 },
        { item = "digital_valve_fitting", name = "Digital Valve", category = "Binary", amount = 999 },
        { item = "gas_pump_fitting", name = "Gas Pump", category = "Binary", amount = 999 },
        { item = "volume_pump_fitting", name = "Volume Pump", category = "Binary", amount = 999 },
        { item = "passive_gate_fitting", name = "Passive Gate", category = "Binary", amount = 999 },
        { item = "pressure_valve_fitting", name = "Pressure Valve", category = "Binary", amount = 999 },

        { item = "gas_filter_fitting", name = "Gas Filter", category = "Devices", amount = 999 },
        { item = "gas_filter_flipped_fitting", name = "Gas Filter (flipped)", category = "Devices", amount = 999 },
        { item = "gas_mixer_fitting", name = "Gas Mixer", category = "Devices", amount = 999 },
        { item = "gas_mixer_flipped_fitting", name = "Gas Mixer (flipped)", category = "Devices", amount = 999 },
        { item = "connector_port_fitting", name = "Connector", category = "Devices", amount = 999 },
        { item = "pipe_meter", name = "Meter", category = "Devices", amount = 999 },
    },
}
