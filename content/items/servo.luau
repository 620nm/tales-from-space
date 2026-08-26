-- A micro-servo: the stock part that decides how FINE a machine's hand
-- is.
--
-- tg's `/obj/item/stock_parts/servo` and its three better rungs
-- (research/stock_parts.dm:42-47, 78-84, 120-126, 162-169), icon states
-- on icons/obj/devices/stock_parts.dmi. tg reads a servo where a
-- machine's precision or reach is at stake: past rung three a chem
-- dispenser unlocks a second half of its shelf
-- (chem_dispenser.dm:467-471).
--
-- The id and the socket word are `servo`, tg's own `base_name` for the
-- family (stock_parts.dm:47) — the name a frame uses when it wants ANY
-- servo rather than the micro one specifically. The item is still
-- called what tg calls it.
return {
    id = "servo",
    name = "micro-servo",
    sprite = "micro_servo",
    examine = {
        flavor = "A tiny little servo motor used in the construction of certain devices.",
    },
    component = { kind = "servo", tier = 1, efficiency = stock_parts.efficiency[1] },
    variants = {
        tier2 = {
            name = "nano-servo",
            sprite = "nano_servo",
            component = stock_parts.rung(2),
        },
        tier3 = {
            name = "pico-servo",
            sprite = "pico_servo",
            component = stock_parts.rung(3),
        },
        tier4 = {
            name = "femto-servo",
            sprite = "femto_servo",
            component = stock_parts.rung(4),
        },
    },
}
