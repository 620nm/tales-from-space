-- What the station sounds like being handled: a thing picked up, put
-- down, and coming to rest after a throw.
--
-- tg gives every item three optional sound vars and no defaults at all
-- (`pickup_sound`, `drop_sound`, `throw_drop_sound` --
-- code/game/objects/items.dm:88,90,92), so a noisy item is one whose
-- own file said so and a quiet one is quiet on purpose. TfS ports that
-- shape literally: the wrench names tg's wrench pair (wrench.dm:20-21),
-- and the headset names nothing, because tg's headset sounds are not
-- part of this bake.
--
-- The landing is the interesting one. Almost nothing in tg names a
-- separate `throw_drop_sound`, so a thrown thing lands on its ordinary
-- drop sound through `throw_drop_sound_chain` (items.dm:661-666) -- and
-- the LAUNCH is silent, because a throw takes the item out of the hand
-- with `silent = TRUE` (items.dm:1340).
t.world([==[(
    name: "workshop",
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
    items: [(2, 1, "wrench"), (2, 1, "headset")],
)]==], 7)

local function heard(p)
    return " " .. table.concat(t.sounds(p), " ") .. " "
end

local p = t.join()
t.tick()

-- ---- into a hand -------------------------------------------------------
t.click(p, 2, 1, t.target_at(2, 1, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "the wrench is in hand")
assert(heard(p):find(" wrench_pickup ", 1, true),
    "picking it up is the wrench's own noise, not a generic one")

-- ---- and back onto the deck --------------------------------------------
t.drop(p)
t.run_ticks(1)
assert(t.hands(p).held == nil, "the hand is empty again")
assert(heard(p):find(" wrench_drop ", 1, true),
    "and putting it down is a different noise from picking it up")

-- ---- thrown: nothing leaving the hand, something where it stops --------
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
t.run_ticks(2)
heard(p) -- discard the pickup we just caused

t.throw(p, 5, 1)
t.tick()
assert(t.hands(p).held == nil, "it left the hand at once")
assert(heard(p) == "  ", "the launch itself says nothing")

t.run_ticks(8)
assert(#t.items_at(5, 1) == 1, "it flew and came to rest")
assert(heard(p):find(" wrench_drop ", 1, true),
    "the wrench names no throw sound, so tg's chain lands on its drop sound")

-- ---- and the thing that named nothing ----------------------------------
-- The negative that keeps the boundary honest. Silence here is content's
-- decision, not a missing engine default: if the engine ever invents a
-- fallback name, it invents a game word, and this line fails.
t.click(p, 2, 1, t.target_at(2, 1, "headset"))
t.run_ticks(2)
assert(t.hands(p).held == "headset", "the headset is in hand")
assert(heard(p) == "  ", "an item that names no sound is picked up in silence")

t.drop(p)
t.run_ticks(1)
assert(heard(p) == "  ", "and put down in silence too")
