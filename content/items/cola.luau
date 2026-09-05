-- Dispensed by the vending machine; drinkable since M7. Clicking your
-- own tile with the can in hand takes a swig — the contents transfer
-- into your bloodstream mole by mole, and metabolism does the rest.
--
-- The ONE gesture, out of `lib/vessel.luau` like every other vessel's.
-- A can is not glassware: there is no pouring out of one and no tipping
-- it onto the deck, so it declares neither and a click at anything but
-- your own feet falls through to whatever it would otherwise have been.
local content = {
    id = "cola",
    name = "can of Space Cola",
    sprite = "cola",
    inhand_sprite = { "held_cola_l", "held_cola_r" },
    contents = { water = 0.30, sugar = 0.06 },
    -- tg's soda can holds 30 u (soda.dm:21), which is the DRINK; the
    -- can is a 330 mL can, which is the shell. Those were the same
    -- number here until capacity became geometry, and reading a dose
    -- as a shell left a can with a millilitre of headspace over its own
    -- syrup. The shell is the whole of what it holds, and 30 u of cola
    -- rattles around in one the way a real can does.
    volume_ml = 330,
    -- A can is shut. It does not trade its headspace with the room, it
    -- can strain against its own lid, and what ferments inside one has
    -- nowhere to go -- which is the whole of why a forgotten cola is
    -- interesting (docs/BENCH.md 2). Opening one for good is
    -- `sim.unseal`, and nothing here does it yet.
    sealed = true,
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "can",
        phases = { "liquid", "solid" },
        sip = { units = 2, message = "lunatic/tfs:items.cola.you_take_a_swig_of" },
    })
end

return content
