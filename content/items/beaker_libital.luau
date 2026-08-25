-- First aid in a glass: libital solution. A beaker like any other, so
-- it wears the same gestures as the empty one, out of the same
-- `lib/vessel.luau` -- your own tile is a swig, another vessel within
-- reach is a pour, the deck is a spill, and a gas line is refused. All
-- this file says is that the swig tastes of the infirmary.
local content = {
    id = "beaker_libital",
    name = "beaker (libital)",
    sprite = "beaker",
    inhand_sprite = { "held_beaker_l", "held_beaker_r" },
    contents = { water = 0.20, libital = 0.15 },
    -- A beaker like any other: tg's 50 mL (_cup.dm:6), the same shell
    -- beaker.luau declares.
    volume_ml = 50,
    -- The beaker fill ladder, exactly as beaker.luau's (_cup.dm:452).
    fill_sprites = {
        { 1, "beaker_fill_1" },
        { 20, "beaker_fill_20" },
        { 40, "beaker_fill_40" },
        { 60, "beaker_fill_60" },
        { 80, "beaker_fill_80" },
        { 100, "beaker_fill_100" },
    },
    acts_on_items = true,
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "beaker",
        phases = { "liquid", "solid" },
        pour = { units = 10 },
        sip = { units = 2, taste = "It tastes like a hospital." },
        spill = true,
    })
end

return content
