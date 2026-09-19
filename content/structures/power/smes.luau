-- The superconducting bank: what a station charges when it has surplus
-- and drains when it does not.
--
-- A map may tell one what each cable layer is for, which is how a bank
-- standing on the backbone still FEEDS it rather than only drinking
-- from it:
--
--   (3, 22, "smes", { "l2": "bidirectional" })
--
-- ...and may mark one inexhaustible, which is tg's
-- /obj/machinery/power/smes/magical -- a bank that "generates power out
-- of thin air" (smes.dm). Disclosed in the window, so no engineer is
-- ever surprised by a meter that will not move.
return {
    id = "smes",
    visual_layer = "fixture",
    energy_network = "power",
    default_props = { l1 = "output", l2 = "input", l3 = "output" },
    name_label = "lunatic/tfs:entity.smes.name",
    name = "power storage unit",
    sprite = "smes",
    ui = { modules = { "store", "throttles", "ports" } },
    -- FIVE STANDARD BATTERIES, 1 MJ each (tg machine_circuitboards.dm:374,
    -- power.dm:32), in and out at tg's 200 kW caps (smes.dm:26, :37).
    -- The breakers start at those caps rather than tg's 50 kW
    -- (smes.dm:24, :35): the engine sets a throttle's level at its
    -- store's own cap (the engine's docs/power/panels.md).
    store = { capacity_j = 5000000, charge_w = 200000, discharge_w = 200000 },
    bridge = { throttles = true },
    -- tg's front panel (smes.dm:144-150): the output lamp, the input
    -- lamp, and a five-segment charge bar that shows nothing below a
    -- fifth and its last segment only when full (smes.dm:344-346).
    appearance = {
        states = {
            output_off = "smes_out0",
            output_on = "smes_out1",
            input_off = "smes_in0",
            input_on = "smes_in1",
            level_1 = "smes_chg1",
            level_2 = "smes_chg2",
            level_3 = "smes_chg3",
            level_4 = "smes_chg4",
            level_5 = "smes_chg5",
        },
    },
    category = "power",
    dense = true,
    examine = {
        flavor = "A cabinet of superconducting coils, cold to the touch, "
            .. "with a charge meter down one side.",
    },
}
