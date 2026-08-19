-- The Captain's Aid: one dial, five positions, and a picture that
-- follows it all the way round and back to off.
--
-- The assertion worth making is not "clicking it changes something" --
-- it is that TWO pieces of per-instance state, the engine's anonymous
-- dial (`modes`/`ctx.set_mode`) and the appearance state
-- (`states`/`ctx.set_state`), stay in step over a full cycle and past
-- the wrap. They are separate mechanisms; a hook that advanced one and
-- not the other would leave a toy that is set to "aft" and drawn
-- pointing "fore", and only reading the SPRITE off the deck catches it.
--
-- tg does the same thing in one line by writing `icon_state` out of its
-- mode list (toys.dm:427), and does its own bounds check in the hook
-- (toys.dm:422-426). Here the clamp is native -- `ctx.set_mode` refuses
-- a position the prototype never declared -- so the last leg of this
-- spec is the interesting one: after the fifth click the dial is back
-- at off, having wrapped rather than run off the end.
t.world([==[(
    name: "bridge",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "captains_aid")],
)]==], 0)

local p = t.join()
t.tick()

-- ---- out of the machine, switched off ---------------------------------
local resting = t.item_at(2, 1, "captains_aid")
assert(resting ~= nil, "the Aid is on the deck")
assert(resting.state == "off", "a fresh one is off: " .. tostring(resting.state))
assert(resting.sprite == "captains_aid_off",
    "and wears the off picture: " .. tostring(resting.sprite))

t.click(p, 2, 1, t.target_at(2, 1, "captains_aid"))
t.tick()
assert(t.hands(p).held == "captains_aid", "it is in hand")

-- ---- one full cycle, and the wrap -------------------------------------
-- tg's own roster, in tg's own order (toys.dm:404-410). The fifth
-- click after "aft" is the one that must come back to "off" rather
-- than ask the engine for a sixth position that was never declared.
local CYCLE = { "port", "starboard", "fore", "aft", "off" }
for _, direction in ipairs(CYCLE) do
    t.use_self(p)
    t.tick()

    local said = t.messages(p)
    local last = said[#said]
    if direction == "off" then
        assert(last:find("You switch the Captain's Aid off.", 1, true),
            "the last click turns it off: " .. tostring(last))
    else
        assert(last:find("The Captain's Aid points " .. direction .. ".", 1, true),
            "it says which way it points: " .. tostring(last))
    end
    assert(table.concat(t.sounds(p), " "):find("switch_click", 1, true),
        "and the switch clicks (tg plays a screwdriver at it, toys.dm:421)")

    -- THE HAND, first: the panel showing what you are holding is where
    -- a player looks while they are fiddling with the thing, and it is
    -- a different code path from the world sprite. It read the
    -- PROTOTYPE once, so an Aid cycled through all five positions sat
    -- in the hand showing "off" the whole way round.
    local hud = t.hud(p)
    assert(hud[1] == "captains_aid_" .. direction,
        "the hand panel shows the position it was turned to: " .. tostring(hud[1]))

    -- ...and then the deck, which is the other half a player sees.
    -- Read it off the floor, not out of the message just asserted.
    t.drop(p)
    t.tick()
    local down = t.item_at(1, 1, "captains_aid")
    assert(down ~= nil, "it is at the holder's feet")
    assert(down.state == direction,
        "the state is the position it was turned to: " .. tostring(down.state))
    assert(down.sprite == "captains_aid_" .. direction,
        "and the sprite is that position's cell: " .. tostring(down.sprite))
    t.click(p, 1, 1, t.target_at(1, 1, "captains_aid"))
    t.tick()
end

-- ---- every turn is on the record --------------------------------------
-- Two rows per click, because two mechanisms moved: the dial that was
-- set and the face that was repainted. An Aid that had been fiddled
-- with is evidence of nothing at all, which is exactly why the ledger
-- must not have to know that.
local turns = t.ledger_rows("ModeSet")
assert(#turns == #CYCLE, "one ModeSet per click, got " .. #turns)
local repaints = t.ledger_rows("StateSet")
assert(#repaints == #CYCLE, "one StateSet per click, got " .. #repaints)
assert(repaints[#repaints].state == "off",
    "and the last one put it back to off: " .. tostring(repaints[#repaints].state))

-- ---- round again, from off --------------------------------------------
-- The wrap is only proved by what happens AFTER it: a dial that had
-- run off the end and been clamped would sit on "aft" forever, and
-- this click would be a no-op instead of the start of a second lap.
t.use_self(p)
t.tick()
t.drop(p)
t.tick()
local second_lap = t.item_at(1, 1, "captains_aid")
assert(second_lap.state == "port",
    "off + one is port again, not stuck at the end: " .. tostring(second_lap.state))
