-- What a crewman looks like, and who is told (docs/LOOKS.md).
--
-- Three claims, none of which the engine can make on its own: the roll
-- is a function of the shift seed and the rosters this pack wrote, the
-- stack that reaches a viewer is the layers `content/bodies/human.luau`
-- names in the colours the roll landed on, and posture crosses the wire
-- as a fact about a body rather than as a second picture.

local WARD = [==[(
    name: "looks ward",
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
    spawns: [(1, 1), (2, 1), (3, 1)],
)]==]

-- ---------------------------------------------------------------
-- The roll is the seed's.
-- ---------------------------------------------------------------
t.world(WARD, 0)
local p = t.join()
t.tick()

local look = t.look(p)
assert(look ~= nil, "a plan that declares `looks` mints one on every body")
assert(look.physique == "m" or look.physique == "f", "a physique this file named: " .. tostring(look.physique))
assert(look.skin_tone ~= nil and #look.skin_tone > 0, "a skin tone this file named")
assert(look.hair ~= nil, "a hairstyle, `bald` included")
assert(look.facial_hair ~= nil, "and a beard, `shaved` included")
assert(look.hair_color:match("^#%x%x%x%x%x%x$") ~= nil, "colours are hexes: " .. look.hair_color)
assert(look.facial_hair_color == look.hair_color,
    "the beard takes the hair's colour, as tg's randomiser does")
assert(look.eye_color == look.eye_color_right, "and one roll colours both eyes")
-- A body that is not `m` can only be shaved: every beard in the roster
-- names `gender = "m"` because tg's base facial datum is MALE.
if look.physique ~= "m" then
    assert(look.facial_hair == "shaved", "no beard is eligible for a body that is not `m`")
end

-- The SAME seed replays the same face...
t.world(WARD, 0)
local again = t.join()
t.tick()
local twice = t.look(again)
assert(twice.physique == look.physique and twice.skin_tone == look.skin_tone
    and twice.hair == look.hair and twice.hair_color == look.hair_color,
    "the same seed rolls the same crewman")

-- ...and a different one does not. Comparing the whole face rather
-- than one field: any single roster can land on the same row twice.
t.world(WARD, 99)
local other = t.join()
t.tick()
local elsewhere = t.look(other)
local same = elsewhere.physique == look.physique and elsewhere.skin_tone == look.skin_tone
    and elsewhere.hair == look.hair and elsewhere.facial_hair == look.facial_hair
    and elsewhere.hair_color == look.hair_color and elsewhere.eye_color == look.eye_color
assert(not same, "another seed rolls another crewman")

-- ---------------------------------------------------------------
-- What a SECOND player is told, which is the only honest place to
-- assert a picture: the world can compose it correctly and the wire
-- can still never carry it.
-- ---------------------------------------------------------------
t.world(WARD, 0)
local subject = t.join()
local watcher = t.join()
t.tick()
t.run_ticks(2)

local mine = t.look(subject)
local seen = t.seen(watcher, subject)
assert(seen.posture == "standing", "the crewman is on his feet")

-- Six bodyparts, two eyes, a beard and a hairstyle — then the three
-- pictures the job's kit puts on top of all of it, which is the old
-- worn-layer path drawing over the new body one.
local names = {}
for index, layer in ipairs(seen.layers) do
    names[index] = layer.sprite
end
assert(#names == 13, "ten body layers under three worn ones: " .. table.concat(names, " "))

assert(names[1] == "body_chest_" .. mine.physique,
    "the chest is the bottom layer, because the plan declares that slot first: " .. names[1])
assert(names[2] == "body_head_" .. mine.physique, "then the head")
assert(names[3] == "body_l_arm" and names[4] == "body_r_arm", "then the arms, which are not dimorphic")
assert(names[5] == "body_l_leg" and names[6] == "body_r_leg", "then the legs")
for index = 1, 6 do
    assert(seen.layers[index].color == seen.layers[1].color,
        "and every one of them takes the single skin tone")
end

assert(names[7] == "eye_l" and names[8] == "eye_r", "the two eyes sit over the body")
assert(seen.layers[7].color == mine.eye_color, "left eye in the colour that was rolled")
assert(seen.layers[8].color == mine.eye_color_right, "and the right in its own")

assert(names[9] == "facial_" .. mine.facial_hair, "the beard over the eyes")
assert(names[10] == "hair_" .. mine.hair, "and the hair on top of the body")
assert(seen.layers[9].color == mine.facial_hair_color, "both in the rolled hair colour")
assert(seen.layers[10].color == mine.hair_color)

-- A roster's "none" row names no cell, so `bald` and `shaved` cost the
-- wire a layer rather than an empty picture. Seed 0 rolls neither, and
-- the count above is what would say so if that ever changed.
assert(mine.hair ~= "bald" and mine.facial_hair ~= "shaved",
    "seed 0 rolls a crewman with hair on both ends")

-- ---------------------------------------------------------------
-- Posture is public, and it moves.
-- ---------------------------------------------------------------
t.rest(subject, true)
t.run_ticks(2)
assert(t.body(subject).posture == "lying", "the body went down")
assert(t.seen(watcher, subject).posture == "lying",
    "and the man standing next to him was told")
assert(#t.seen(watcher, subject).layers == 13,
    "without one layer changing: a crewman lying down is the same picture, turned")

t.rest(subject, false)
t.run_ticks(2)
assert(t.seen(watcher, subject).posture == "standing", "and back up again")

-- ---------------------------------------------------------------
-- The face rides the head. NOT ASSERTED here: nothing in this pack
-- takes a head off a living body — `content/operations/` has no
-- amputation — so the "lose the head, lose the hair" half of the rule
-- is proved in the engine, against a fixture plan whose parts can be
-- detached (`crates/lunatic-server/src/sim/tests/looks.rs`).
assert(t.parts(subject).head ~= nil, "the plan carries the part the face rides on")
