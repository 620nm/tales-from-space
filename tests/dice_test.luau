-- Dice: the two moments a die is rolled, the two sentences it says, and
-- the face it is left showing.
--
-- tg rolls a die on `attack_self` and again on `throw_impact`
-- (code/game/objects/items/dice.dm:68-75), which is exactly the pair
-- of hooks the prototypes carry. The second one is the point of the
-- whole exercise: a thrown die comes to rest by itself, and the engine
-- fires `throw.land.done` where it stopped.
--
-- And the PICTURE follows, which is what `t.item_at` is here to prove:
-- tg's rolled die wears the overlay `"[icon_state]-[result]"`
-- (dice.dm:114-116), and a die here is put into the declared appearance
-- state of the same name, so `sprite == "d6_" .. state` is the assertion
-- that the repaint and the bookkeeping have not drifted apart.
--
-- SEED-PINNED. `t.world(..., 2)` fixes the shift RNG, so every roll
-- below is a fact rather than a range: the d6 lands on 1 in the hand
-- and on 2 where it stops, and neither is the six it was minted on,
-- which is what makes the picture assertions below mean anything. A
-- change to how many numbers the engine draws before these will move
-- them, and the fix is to read the new ones off a failing run -- and
-- to keep the landing off six -- rather than to loosen the assertion.
t.world([==[(
    name: "rec room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "########",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "d6"), (2, 1, "d20")],
)]==], 2)

local p = t.join()
t.tick()

-- ---- the face it is lying on, before anybody touches it ----------------
-- A die out of the box is on the state its file mints it in, and the
-- picture agrees with the state. Asserted FIRST so the changes below are
-- changes from a known face rather than from whatever happened to be
-- there.
local resting = t.item_at(2, 1, "d6")
assert(resting ~= nil, "the die is lying on the deck")
assert(resting.state == "6", "a fresh d6 rests on six: " .. tostring(resting.state))
assert(resting.sprite == "d6_6", "and wears six's picture: " .. tostring(resting.sprite))

-- ---- in the hand (tg's attack_self) ------------------------------------
t.click(p, 2, 1, t.target_at(2, 1, "d6"))
t.tick()
assert(t.hands(p).held == "d6", "the die is in hand")

t.use_self(p)
t.tick()
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("You roll the d6. It lands on 1.", 1, true),
    "a roll in the hand reads out, seed-pinned: " .. msgs)
assert(table.concat(t.sounds(p), " "):find("dice_roll", 1, true),
    "and it is heard tumbling (tg plays the sound from diceroll itself)")

-- ---- and where it lands (tg's throw_impact) ----------------------------
t.throw(p, 5, 1)
t.tick()
assert(t.hands(p).held == nil, "it left the hand at once")

t.run_ticks(8)
assert(#t.items_at(5, 1) == 1, "it flew four tiles and stopped there")
msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("The d6 rolls to a stop, landing on 2.", 1, true),
    "landing rolls it again: " .. msgs)

local threw = t.ledger_rows("Threw")
assert(#threw == 1 and threw[1].item == "d6",
    "the throw is on the record, once, naming what was thrown")

-- ---- THE TRIPWIRE: the picture follows the roll ------------------------
-- tg's whole dice appearance is `"[icon_state]-[result]"`
-- (code/game/objects/items/dice.dm:114-116). This is that, arrived at by
-- a declared state instead of a pasted string: the die that landed on 1
-- is showing one pip to anybody who walks past, and it was minted on six
-- so the state really moved.
local landed = t.item_at(5, 1, "d6")
assert(landed ~= nil, "the die is where it stopped")
assert(landed.state == "2",
    "it is in the state it rolled, seed-pinned: " .. tostring(landed.state))
assert(landed.sprite == "d6_" .. landed.state,
    "and the sprite is that state's picture, not the resting one: " .. tostring(landed.sprite))
assert(landed.sprite ~= resting.sprite,
    "which is a different picture from the one it was minted wearing")

local set = t.ledger_rows("StateSet")
assert(#set >= 1 and set[#set].state == "2",
    "and the face it came to rest on is on the record")

-- ...and it REACHED the player. A repaint can be right in the world and
-- never reach the wire, and only `t.layers` would notice: this is what
-- the client was actually told to draw.
local drawn = t.layers(p, t.target_at(5, 1, "d6"))
assert(table.concat(drawn, " "):find("d6_2", 1, true),
    "the client was sent the rolled face: " .. table.concat(drawn, " "))

-- ---- twenty sides, and the one number anybody remembers ----------------
t.click(p, 2, 1, t.target_at(2, 1, "d20"))
t.tick()
assert(t.hands(p).held == "d20", "the good one is in hand")

-- Sixty rolls of a d20 contain a natural twenty and a natural one with
-- room to spare, so this survives the RNG shifting a little -- which it
-- does whenever the engine draws a number earlier in the shift. tg comments on a 20 and on a 1 and on
-- nothing else (dice.dm:90-93); this is both of them.
local nat20, unlucky = false, false
for _ = 1, 60 do
    t.use_self(p)
    t.tick()
    for _, m in ipairs(t.messages(p)) do
        nat20 = nat20 or m:find("It lands on 20. NAT 20!", 1, true) ~= nil
        unlucky = unlucky or m:find("It lands on 1. Ouch, bad luck.", 1, true) ~= nil
    end
end
assert(nat20, "sixty seeded rolls of a d20 contain a natural twenty")
assert(unlucky, "and a one, which says so")

-- ---- rolled in the hand, read off the floor ----------------------------
-- The other half of the tripwire, and the half tg's `attack_self` is:
-- rolling a die you are HOLDING sets its face too, so the number is
-- there when you put it down. Nobody but the roller heard the sentence;
-- the picture is what everyone else gets.
t.use_self(p)
t.tick()
local said = t.messages(p)
local rolled = said[#said]:match("It lands on (%d+)%.")
assert(rolled ~= nil, "the roll said a number: " .. tostring(said[#said]))

-- IN THE HAND, before it is put down. The panel showing what you are
-- holding is a different path from the world delta -- a carried item
-- has no tile to be repainted at -- and it used to read the PROTOTYPE,
-- so a die rolled in the hand went on showing the face it was minted
-- wearing until somebody dropped it.
assert(t.hud(p)[1] == "d20_" .. rolled,
    "the hand shows the face it just rolled: " .. tostring(t.hud(p)[1]))

t.drop(p)
t.tick()
assert(t.hands(p).held == nil, "it left the hand")

local down = t.item_at(1, 1, "d20")
assert(down ~= nil, "the good one is on the deck where its holder stood")
assert(down.state == rolled,
    "the face it is showing is the number it rolled in the hand: "
        .. tostring(down.state) .. " vs " .. rolled)
assert(down.sprite == "d20_" .. rolled,
    "and the picture is that face's cell: " .. tostring(down.sprite))
-- Seed-pinned like every other number in this file: the sixty-first roll
-- of this die is an 8, so the face on the floor is eight and the die
-- was minted on twenty — the state really moved, and it moved to the
-- number that was said. Read a new one off a failing run rather than
-- loosening the assertion.
assert(rolled == "8", "seed 2 puts the sixty-first roll on 8, got " .. rolled)
assert(down.state ~= "20", "and it is not still on the face it was minted wearing")
