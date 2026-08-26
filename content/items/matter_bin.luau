-- A matter bin: the stock part that decides how MUCH a machine holds.
--
-- tg's `/obj/item/stock_parts/matter_bin` and its three better rungs
-- (research/stock_parts.dm:55-58, 94-99, 136-141, 179-184), icon states
-- on icons/obj/devices/stock_parts.dmi. Wherever tg reads a bin it is
-- reading a capacity: a temperature control unit's heat bath is its
-- bins squared (thermomachine.dm:87-90) and a chem dispenser's draw
-- falls a quarter of a kilowatt per rung of them
-- (chem_dispenser.dm:461-463).
--
-- The socket word is `bin` rather than `matter_bin`: the kind is what
-- a machine's `parts.slots` asks for by name, and a placement's key is
-- `bin_1`. It is the pack's word, and short is what a property sheet
-- wants (docs/MAP-PROPERTIES.md).
return {
    id = "matter_bin",
    name = "matter bin",
    sprite = "matter_bin",
    examine = {
        flavor = "A container designed to hold compressed matter awaiting reconstruction.",
    },
    component = { kind = "bin", tier = 1, efficiency = stock_parts.efficiency[1] },
    variants = {
        tier2 = {
            name = "advanced matter bin",
            sprite = "advanced_matter_bin",
            component = stock_parts.rung(2),
        },
        tier3 = {
            name = "super matter bin",
            sprite = "super_matter_bin",
            component = stock_parts.rung(3),
        },
        tier4 = {
            name = "bluespace matter bin",
            sprite = "bluespace_matter_bin",
            component = stock_parts.rung(4),
        },
    },
}
