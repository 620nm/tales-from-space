-- Dice: the two moments a die is rolled, and the two sentences it says.
--
-- tg rolls a die on `attack_self` and again on `throw_impact`
-- (code/game/objects/items/dice.dm:68-75), which is exactly the pair
-- of hooks the prototypes carry. The second one is the point of the
-- whole exercise: a thrown die comes to rest by itself, and the engine
-- fires `on_throw_land` where it stopped.
--
-- SEED-PINNED. `t.world(..., 0)` fixes the shift RNG, so every roll
-- below is a fact rather than a range: the d6 lands on 6 in the hand
-- and on 1 where it stops, which is also (deliberately) the value that
-- earns tg's "Ouch, bad luck." remark. A change to how many numbers
-- the engine draws before these will move them, and the fix is to read
-- the new ones off a failing run rather than to loosen the assertion.
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
)]==], 0)

local p = t.join()
t.tick()

-- ---- in the hand (tg's attack_self) ------------------------------------
t.click(p, 2, 1, t.target_at(2, 1, "d6"))
t.tick()
assert(t.hands(p).held == "d6", "the die is in hand")

t.use_self(p)
t.tick()
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("You roll the d6. It lands on 6.", 1, true),
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
assert(msgs:find("The d6 rolls to a stop, landing on 1.", 1, true),
    "landing rolls it again: " .. msgs)
assert(msgs:find("Ouch, bad luck.", 1, true),
    "and a 1 on a six-sider earns tg's remark (MIN_SIDES_ALERT = 5)")

local threw = t.ledger_rows("Threw")
assert(#threw == 1 and threw[1].item == "d6",
    "the throw is on the record, once, naming what was thrown")

-- ---- twenty sides, and the one number anybody remembers ----------------
t.click(p, 2, 1, t.target_at(2, 1, "d20"))
t.tick()
assert(t.hands(p).held == "d20", "the good one is in hand")

-- Seed 0 puts the natural twenty on the 35th roll of this die and the
-- first natural one on the 47th, so sixty covers both with room for
-- the RNG to shift a little. tg comments on a 20 and on a 1 and on
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
