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
    name = "power storage unit",
    sprite = "smes",
    ui = { modules = { "battery", "throttles", "ports" } },
    fixture = "Smes",
    category = "power",
    dense = true,
    examine = {
        flavor = "A cabinet of superconducting coils, cold to the touch, "
            .. "with a charge meter down one side.",
    },
}
