-- A scanning module: the stock part that decides how WELL a machine
-- sees.
--
-- tg's `/obj/item/stock_parts/scanning_module` and its three better
-- rungs (research/stock_parts.dm:36-40, 71-76, 113-118, 154-160), icon
-- states on icons/obj/devices/stock_parts.dmi.
--
-- NOTHING IN THIS PACK HAS A SCANNER SOCKET yet — the machines that
-- carry one in tg are the analysers, the cloner and the mech fabricator,
-- and none of those exists here. It is on the roster for the reason the
-- chem dispenser's shelf carries bromine and copper: the ladder is tg's,
-- a rung waiting for its consumer costs one file, and the day a machine
-- asks for `"scanner"` the part it wants is already on the vendor's
-- second shelf rather than being invented alongside it.
return {
    id = "scanning_module",
    name = "scanning module",
    sprite = "scan_module",
    examine = {
        flavor = "A compact, high resolution scanning module used in the construction "
            .. "of certain devices.",
    },
    component = { kind = "scanner", tier = 1, efficiency = stock_parts.efficiency[1] },
    variants = {
        tier2 = {
            name = "advanced scanning module",
            sprite = "adv_scan_module",
            component = stock_parts.rung(2),
        },
        tier3 = {
            name = "phasic scanning module",
            sprite = "super_scan_module",
            component = stock_parts.rung(3),
        },
        tier4 = {
            name = "triphasic scanning module",
            sprite = "triphasic_scan_module",
            component = stock_parts.rung(4),
        },
    },
}
