-- A micro-laser: the stock part that decides how HARD a machine works.
--
-- tg's `/obj/item/stock_parts/micro_laser` and its three better rungs
-- (research/stock_parts.dm:49-52, 86-92, 128-134, 171-177), icon states
-- on icons/obj/devices/stock_parts.dmi. Wherever tg reads a laser it is
-- reading a rate or a reach: the reaction chamber multiplies its
-- coefficient by one (chem_heater.dm:88-90) and a temperature control
-- unit sets both ends of its dial off the pair it holds
-- (thermomachine.dm:94-96).
--
-- One base item and three variants, because a rung of a ladder is a
-- preconfiguration of the part rather than a second kind of thing
-- (docs/CONTENT-SCHEMA.md §1.1a). The efficiencies come off
-- `lib/stock_parts.luau`, which is where this pack's ladder is argued.
return {
    id = "micro_laser",
    name = "micro-laser",
    sprite = "micro_laser",
    examine = { flavor = "A tiny laser used in certain devices." },
    component = { kind = "laser", tier = 1, efficiency = stock_parts.efficiency[1] },
    variants = {
        tier2 = {
            name = "high-power micro-laser",
            sprite = "high_micro_laser",
            component = stock_parts.rung(2),
        },
        tier3 = {
            name = "ultra-high-power micro-laser",
            sprite = "ultra_high_micro_laser",
            component = stock_parts.rung(3),
        },
        tier4 = {
            name = "quad-ultra micro-laser",
            sprite = "quadultra_micro_laser",
            component = stock_parts.rung(4),
        },
    },
}
