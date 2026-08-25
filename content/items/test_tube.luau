-- The test tube: thirty units, and the vessel you keep a batch in once
-- the beaker is needed for the next one. A rack of these is what a
-- chemist's bench looks like.
--
-- The shell is tg's `volume = 30`, and the shell is the whole of what
-- it holds. The picture is tg's `test_tube`
-- and the fill ladder is its `fill_icon_state = "tube"`, which is why
-- the two names differ: the glass comes off the chemistry sheet and
-- the level off the fillings sheet (_cup.dm:797-806; `volume = 30`
-- at :805).
--
-- The gestures are the vessel's rather than this file's
-- (`lib/vessel.luau`): your own tile is a swig, another vessel within
-- reach is a pour, the deck is a spill, and an open tube held to a gas
-- line is refused.
local content = {
    id = "test_tube",
    name = "test tube",
    sprite = "test_tube",
    examine = {
        flavor = "A narrow tube of glass. Where a finished batch waits "
            .. "while the beaker gets on with the next one.",
    },
    -- tg's test tube: `volume = 30` (cups/_cup.dm:805). Narrow enough
    -- that a tube of something warm saturates its own headspace in one
    -- pass and then sits there.
    volume_ml = 30,
    fill_sprites = {
        { 1, "tube_fill_1" },
        { 20, "tube_fill_20" },
        { 40, "tube_fill_40" },
        { 60, "tube_fill_60" },
        { 80, "tube_fill_80" },
        { 100, "tube_fill_100" },
    },
    acts_on_items = true,
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        -- What the sentences call it. Short of the prototype's own name
        -- on purpose: "you pour from the test tube" is not how anybody
        -- at a bench says it.
        noun = "tube",
        phases = { "liquid", "solid" },
        -- tg's cup default `amount_per_transfer_from_this = 10`
        -- (_cup.dm:4), which is also the beaker's gesture: a pour is a
        -- pour whatever it comes out of.
        pour = { units = 10 },
        sip = { units = 2 },
        spill = true,
    })
end

return content
