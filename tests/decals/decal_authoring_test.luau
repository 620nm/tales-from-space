local ui_controls = require("@helpers/ui_controls")

-- Who may name a colour, and what an uncoloured decal carries.
--
-- The pack declares `decal_colors.free = { map = true, play = false }`
-- (content/compositions.luau), which is one ruling in two halves: a
-- MAPPER may reach outside the palette, a crewman with a spray gun may
-- not. This spec holds both halves of it -- the map's freedom, and the
-- painter's want of a control to be unfree with.

local word = ui_controls.word

-- ---------------------------------------------------------------
-- One plated strip, authored with the three kinds of colour a decal
-- row can carry: a palette paint, a raw #RRGGBB, and none at all.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "authored decals",
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "######",
        "#oooo#",
        "######",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "decal_painter")],
    decals: [
        (x: 1, y: 1, decal: "trim", paint: Some("blue")),
        (x: 2, y: 1, decal: "trim", color: Some("#AABBCC")),
        (x: 3, y: 1, decal: "hazard_line"),
        (x: 4, y: 1, decal: "mark_arrow", facing: Some(4)),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

-- ---- a palette paint is named, not spelled ----
local palette = t.decals_at(1, 1)[1]
assert(palette.paint == "blue" and palette.color == nil, "a paint id stays an id")

-- ---- and a map may spell one out ----
--
-- `free.map = true` is the whole reason this row loads at all. The
-- record keeps it as the raw colour it was authored as, with no paint
-- id to pretend it came off the shelf.
local free = t.decals_at(2, 1)[1]
assert(free.color == "#AABBCC", "the map named a colour of its own: " .. tostring(free.color))
assert(free.paint == nil, "and it is not a palette entry")

-- Two colours are two decals, never one run, so neither tile borrows
-- the other's seam: both draw their own box.
assert(table.concat(palette.sprites, "+") == "decal_trim_box", "the blue tile stands alone")
assert(table.concat(free.sprites, "+") == "decal_trim_box", "and so does the hand-mixed one")

-- ---- an uncoloured decal carries no colour at all ----
--
-- tg's warning stripes are painted art: yellow on black in their own
-- pixels (`decal_colors` never reaches them), so the roster declares
-- them `colored = false` and a placement carries neither key.
local stripes = t.decals_at(3, 1)[1]
assert(stripes.decal == "hazard_line", "the stripes loaded")
assert(stripes.paint == nil and stripes.color == nil, "and carry tg's own colours instead")

-- A mark is aimed rather than shaped: the map's cardinal bit comes back
-- as the letter the scripting surface speaks.
local arrow = t.decals_at(4, 1)[1]
assert(arrow.facing == "e", "the authored bit is the facing: " .. arrow.facing)
assert(table.concat(arrow.sprites, "+") == "decal_mark_arrow_e", "and picks the art")

-- ---- the other half: a crewman has no such freedom ----
--
-- `free.play = false`, so a raw colour reaching `sim.place_decal` is
-- refused where the placement compiles. Nothing in this pack can put
-- one there: the painter's Paint dial is the palette and only the
-- palette, with no custom entry and no colour wheel beside it, which is
-- tg's `set_painting_tool_color` (decal_painter.dm:135-138) deliberately
-- not ported. The engine's own refusal is covered by the engine's
-- `crates/lunatic-server/src/sim/decal_mutation/tests.rs` and
-- `sim/tests/script_v1_decals.rs`; what a spec here can hold is that
-- the pack offers no way to ask.
t.click(p, 1, 1, t.target_at(p, 1, 1, "decal_painter"))
t.run_ticks(2)
t.use_self(p)
t.tick()
local swatches: { string } = {}
for _, tog in ipairs(ui_controls.rows(ui_controls.state(p).toggles)) do
    if ui_controls.text(tog.field) == "dial1" and tog.option ~= nil then
        table.insert(swatches, word(tog.label))
    end
end
assert(#swatches == 12, "twelve buttons on the paint dial: " .. #swatches)
for _, name in ipairs(swatches) do
    assert(name:sub(1, 1) ~= "#", "every one of them is a palette id, not a colour: " .. name)
end
