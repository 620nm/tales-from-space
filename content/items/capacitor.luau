-- A capacitor: the stock part that stores a charge.
--
-- tg's `/obj/item/stock_parts/capacitor` and its three better rungs
-- (research/stock_parts.dm:30-34, 63-69, 105-111, 146-152), icon states
-- on icons/obj/devices/stock_parts.dmi. tg reads it wherever a machine
-- has a CELL: the chem dispenser multiplies its recharge rate by one
-- (chem_dispenser.dm:464-466).
--
-- Nothing here reads it yet, and it is on the roster anyway, because
-- tg's chem dispenser board asks for one (machine_circuitboards.dm:757)
-- and a board's list is copied verbatim. Every corded appliance in this
-- pack draws flat off the mains, so there is no cell for a capacitor to
-- fill and no `scale` row naming it: it is a thing the machine is built
-- out of that the machine does not currently follow. The day a cell
-- economy exists it becomes a row rather than a file.
return {
    id = "capacitor",
    name = "capacitor",
    sprite = "capacitor",
    examine = {
        flavor = "A basic capacitor used in the construction of a variety of devices.",
    },
    component = { kind = "capacitor", tier = 1, efficiency = stock_parts.efficiency[1] },
    variants = {
        tier2 = {
            name = "advanced capacitor",
            sprite = "adv_capacitor",
            component = stock_parts.rung(2),
        },
        tier3 = {
            name = "super capacitor",
            sprite = "super_capacitor",
            component = stock_parts.rung(3),
        },
        tier4 = {
            name = "quadratic capacitor",
            sprite = "quadratic_capacitor",
            component = stock_parts.rung(4),
        },
    },
}
