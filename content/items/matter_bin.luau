-- A matter bin: one of the two stock parts every framed machine is
-- fed before it will take a screwdriver.
--
-- tg's `/obj/item/stock_parts/matter_bin` (research/stock_parts.dm:55-58,
-- icon `matter_bin` on icons/obj/assemblies/stock_parts.dmi). What a bin
-- DOES depends entirely on the machine it ends up in; in a temperature
-- control unit it is the heat capacity, so two of them are 5000 J/K of
-- thermostat (thermomachine.dm:88-90).
--
-- tg has four tiers of these and a whole upgrade economy behind them.
-- This pack has one, deliberately: tiers need a protolathe, a research
-- tree and a deconstruction bench, none of which exist here, and a
-- machine whose spec sheet is a constant is a machine whose numbers can
-- live in its own file.
return {
    id = "matter_bin",
    name = "matter bin",
    sprite = "matter_bin",
}
