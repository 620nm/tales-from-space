-- The bag of dice, and the four solids that arrived with it.
--
-- `dice_test.luau` is the one that proves a die ROLLS -- two hooks, the
-- picture following the roll, the ledger row. This one proves the SET:
-- that a container declared with `holds` ships stocked with exactly the
-- roster its file names, that every new die is lying on the face its
-- file mints it wearing, and that the d00 -- the only die in the bag
-- whose face and whose READING are different numbers -- keeps the two
-- in step.
--
-- Deliberately NOT seed-pinned, where `dice_test.luau` is. That file
-- pins because the interesting thing is a particular number arriving in
-- a particular sentence. The interesting thing here is a RELATION that
-- must hold for every roll -- reading == (face - 1) * 10 -- and a
-- relation asserted over sixty rolls is a stronger statement than one
-- roll asserted exactly. Seed 0 still fixes the sequence, so a failure
-- here is reproducible; it is the assertion that is general, not the run.
t.world([==[(
    name: "rec room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "dice_bag")],
)]==], 0)

local p = t.join()
t.tick()

-- ---- the roster, in the order the file declares it ---------------------
t.click(p, 2, 1, t.target_at(2, 1, "dice_bag"))
t.tick()
assert(t.hands(p).held == "dice_bag", "the bag is in hand")

-- tg's `/datum/storage/dice` inherits `max_slots = 7` and its
-- `PopulateContents` fills every one (dice.dm:14-31). Ours is the
-- polyhedral set plus the d00 in tg's random-oddity slot, and seven
-- slots holding seven dice means a full bag has no room for an
-- eighth -- which is the whole of what `storage = 7` buys.
local ROSTER = { "d4", "d6", "d8", "d10", "d12", "d20", "d00" }
local emptied = {}
for i = 1, #ROSTER do
    -- Always slot 0: the bag closes up behind each die, so taking the
    -- first one seven times walks the whole roster in storage order.
    -- This is the client's own storage-panel command, not a spec
    -- shortcut -- a spec opens a bag the way a player does.
    t.take_held(p, 0)
    t.tick()
    t.swap_hands(p)
    local die = t.hands(p).held
    assert(die ~= nil, "slot " .. i .. " held a die")
    emptied[#emptied + 1] = die
    -- Out of the bag and onto the deck at the player's feet, so the
    -- resting face can be read off the floor below.
    t.drop(p)
    t.tick()
    t.swap_hands(p)
end
assert(table.concat(emptied, ",") == table.concat(ROSTER, ","),
    "the bag ships with its declared roster, in order: " .. table.concat(emptied, ","))

t.take_held(p, 0)
t.tick()
t.swap_hands(p)
assert(t.hands(p).held == nil, "an eighth take finds an empty bag")
t.swap_hands(p)
-- The empty bag goes down too, so every click below reaches a die
-- rather than being the bag being USED on the tile.
t.drop(p)
t.tick()

-- ---- every die is on the face its file mints it wearing ----------------
-- One picture per declared state, checked at load; this is the other
-- half -- that the state a fresh die is MINTED in is the one whose
-- picture the prototype's own `sprite` field was baked from, so a die
-- straight out of the bag looks like a die and not like a blank body.
local MINTED = { d4 = "4", d6 = "6", d8 = "8", d10 = "10", d12 = "12", d20 = "20", d00 = "10" }
for id, face in pairs(MINTED) do
    local lying = t.item_at(1, 1, id)
    assert(lying ~= nil, id .. " is on the deck where the bag was emptied")
    assert(lying.state == face,
        id .. " rests on " .. face .. ", got " .. tostring(lying.state))
    assert(lying.sprite == id .. "_" .. face,
        id .. " wears that face's cell, got " .. tostring(lying.sprite))
end

-- ---- the d00: the face and the reading are different numbers -----------
-- tg rolls 1..10, paints the overlay from the RAW result and only then
-- runs it through `manipulate_result` -> `(original - 1) * 10`
-- (dice.dm:114-116, 222-223). So the CELL is 1..10 and the SENTENCE is
-- 0..90, and the port's whole risk is those two drifting apart.
t.click(p, 1, 1, t.target_at(1, 1, "d00"))
t.tick()
assert(t.hands(p).held == "d00", "the percentile die is in hand")

local seen_zero = false
local readings = {}
for _ = 1, 60 do
    t.use_self(p)
    t.tick()
    local said = t.messages(p)
    local last = said[#said]
    local reading = last:match("It lands on (%d+)%.")
    assert(reading ~= nil, "the roll said a number: " .. tostring(last))
    reading = tonumber(reading)
    assert(reading % 10 == 0 and reading >= 0 and reading <= 90,
        "a d00 reads out in tens, 0 through 90, got " .. reading)
    readings[reading] = true
    -- The tripwire. Put the die down, read the cell it is showing off
    -- the floor, and check it against the number that was SAID.
    t.drop(p)
    t.tick()
    local down = t.item_at(1, 1, "d00")
    assert(down ~= nil, "the die is at the roller's feet")
    assert(tonumber(down.state) == reading / 10 + 1,
        "cell " .. tostring(down.state) .. " is the one that reads " .. reading)
    assert(down.sprite == "d00_" .. down.state,
        "and it wears that cell's picture: " .. tostring(down.sprite))
    if reading == 0 then
        assert(last:find("It lands on 0. Ouch, bad luck.", 1, true),
            "the bottom face reads 0 and still earns tg's remark: " .. last)
        seen_zero = true
    end
    t.click(p, 1, 1, t.target_at(1, 1, "d00"))
    t.tick()
end
assert(seen_zero, "sixty rolls of a ten-sider turn up its bottom face")
local distinct = 0
for _ in pairs(readings) do
    distinct += 1
end
assert(distinct >= 8, "and they are not all the same face: " .. distinct .. " of ten")

t.drop(p)
t.tick()

-- ---- the d4 says nothing, and that absence is the port -----------------
-- tg only comments on a roll when `sides > MIN_SIDES_ALERT` (5,
-- dice.dm:1-3, 90-91). Four is under it, so a d4 landing on 1 is
-- silent where a d6 landing on 1 is not -- the same branch, two
-- answers, and the only way to see it is to roll the small one a lot.
t.click(p, 1, 1, t.target_at(1, 1, "d4"))
t.tick()
assert(t.hands(p).held == "d4", "the caltrop is in hand")

local ones = 0
for _ = 1, 40 do
    t.use_self(p)
    t.tick()
    local said = t.messages(p)
    local last = said[#said]
    local face = tonumber(last:match("It lands on (%d+)%."))
    assert(face ~= nil and face >= 1 and face <= 4,
        "a d4 rolls 1 through 4, got " .. tostring(last))
    assert(not last:find("bad luck", 1, true),
        "and never earns the remark, whatever it rolls: " .. last)
    if face == 1 then
        ones += 1
    end
end
assert(ones > 0, "forty rolls of a four-sider include a 1 to be silent about")

-- ...where the d6 beside it, on the same branch, does say so.
t.drop(p)
t.tick()
t.click(p, 1, 1, t.target_at(1, 1, "d6"))
t.tick()
assert(t.hands(p).held == "d6", "the six-sider is in hand")
local remarked = false
for _ = 1, 60 do
    t.use_self(p)
    t.tick()
    for _, m in ipairs(t.messages(p)) do
        remarked = remarked or m:find("It lands on 1. Ouch, bad luck.", 1, true) ~= nil
    end
end
assert(remarked, "six sides is over MIN_SIDES_ALERT, so a 1 there is remarked on")
