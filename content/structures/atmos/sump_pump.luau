-- A sump pump: the power user's way to dry a deck, film and all.
--
-- A scrubber that takes liquid and no gas (the engine's
-- docs/atmos/liquid-mouths.md). Where a floor drain stops at the film this
-- takes settled liquid to the last drop, over the reach on its panel: its
-- own tile, the cardinals, or the whole ring. Each tile takes the full dial,
-- so reach multiplies the bill. Beads float past it, and gas is not its
-- business. Its run must lead somewhere: at a full line it stops and shows
-- its fault lamp, and the panel says why.
--
-- It is plumbing and not room air, so it joins no air alarm.
--
-- tg has no sump pump; these numbers are this pack's.
--
-- TEN LITRES A SECOND out of the crate, twenty floor drains' worth, and
-- fifty at the top of the dial: the pair of tiles behind the alcove's door
-- hold 100 L, ten seconds at the stock setting.
--
-- `watts` 2000 is the bill at full dial on one tile. Lifting 50 kg/s through
-- three metres (one deck) at 9.81 m/s2 is 1471 W of water; at three quarters
-- efficiency that is 1960 W. The stock dial bills 400 W, under three vents.
-- The whole ring at full dial is 18 kW, billed for as long as the pump is on,
-- dry floor included. With no feed that flattens a 1 MJ panel in 55 s; against
-- a panel's 10 kW `charge_w` the net 8 kW takes about 125 s.
return {
    id = "sump_pump",
    visual_layer = "fixture",
    energy_network = "power",
    -- tg's AREA_USAGE_ENVIRON, atmosmachinery.dm:18 (docs/POWER.md).
    load_class = "environment",
    name_label = "lunatic/tfs:entity.sump_pump.name",
    name = "sump pump",
    sprite = "sump_pump_off_n",
    ui = { modules = { "scrubber" } },
    dense = false,
    examine = {
        flavor = "A squat pump with its intake on the deck. It leaves nothing behind.",
    },
    states = { "off", "pumping", "fault" },
    facing_sprites = {
        off = {
            north = "sump_pump_off_n",
            south = "sump_pump_off_s",
            east = "sump_pump_off_e",
            west = "sump_pump_off_w",
        },
        pumping = {
            north = "sump_pump_pumping_n",
            south = "sump_pump_pumping_s",
            east = "sump_pump_pumping_e",
            west = "sump_pump_pumping_w",
        },
        fault = {
            north = "sump_pump_fault_n",
            south = "sump_pump_fault_s",
            east = "sump_pump_fault_e",
            west = "sump_pump_fault_w",
        },
    },
    atmos = {
        channel = "l3",
        network = "pipe",
        device = "scrubber",
        mouth_cap = "vent",
        positions = { "off", "pumping", "fault" },
        phases = { "liquid" },
        whole_phase = true,
        rate_lps = 10.0,
        max_rate_lps = 50.0,
        service = 1,
        watts = 2000.0,
    },
    build = {
        sound = "smash",
        on = { "component:station_base" },
        from_item = "sump_pump_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "lunatic/tfs:entity.sump_pump.build.start",
        done = "lunatic/tfs:entity.sump_pump.build.done",
    },
    transitions = {
        {
            sound = "smash",
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { sump_pump_fitting = 1 },
            start = "lunatic/tfs:entity.sump_pump.remove.start",
            done = "lunatic/tfs:entity.sump_pump.remove.done",
        },
    },
}
