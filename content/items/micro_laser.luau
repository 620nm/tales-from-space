-- A micro-laser: the other stock part a temperature control unit is
-- built out of.
--
-- tg's `/obj/item/stock_parts/micro_laser` (research/stock_parts.dm:49-52,
-- icon `micro_laser` on icons/obj/assemblies/stock_parts.dmi). In a
-- thermomachine the lasers are the RANGE -- two tier-1 ones give a unit
-- 73.15 K at the cold end and 573.15 K at the hot end
-- (thermomachine.dm:95-96) -- which is why a machine built with better
-- ones reaches further in tg, and why this pack's single tier is also
-- its single spec sheet.
return {
    id = "micro_laser",
    name = "micro-laser",
    sprite = "micro_laser",
}
