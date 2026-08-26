-- A bottle of iodine crystals: how iodine reaches the bench, since it
-- is not a dispenser button (docs/CHEMISTRY.md 7). The same glass as
-- items/bottle.luau with a charge in it, the way beaker_libital.luau is
-- a beaker with a charge in it.
--
-- Sealed, so what it holds over the crystals is their own vapour at the
-- sublimation line — a few pascals of violet at room temperature — and
-- nothing escapes until it is tipped out. Fifty units of tg's bottle
-- (reagent_containers/cups/bottle.dm:12) is 1.25 mol; a bottle of
-- crystals carries a tenth of that, 0.125 mol = 32 g = 6.4 mL of the
-- fifty.
local content = {
    id = "bottle_iodine",
    name = "bottle (iodine)",
    sprite = "bottle",
    examine = {
        flavor = "Glass with a neck on it. Grey-black crystals, and a "
            .. "violet haze over them that was not there a moment ago.",
    },
    contents = { iodine = 0.125 },
    volume_ml = 50,
    sealed = true,
    fill_sprites = {
        { 1, "bottle_fill_1" },
        { 20, "bottle_fill_20" },
        { 40, "bottle_fill_40" },
        { 60, "bottle_fill_60" },
        { 80, "bottle_fill_80" },
        { 100, "bottle_fill_100" },
    },
    acts_on_items = true,
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "bottle",
        phases = { "liquid", "solid" },
        pour = { units = 10 },
        sip = { units = 2, taste = "It tastes like a wound." },
        spill = true,
    })
end

return content
