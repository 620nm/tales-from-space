-- A door variant, and the placement that contradicts it.
--
-- `airlock.engineering_glass` is not a second airlock: it is the one
-- airlock file with three properties defaulted -- the livery, the access
-- claim, and the window -- every one of which a map could already have
-- written on the placement itself (docs/MAP-PROPERTIES.md, the property
-- sheet). So the spec asks the two questions that make a variant worth having:
-- does it arrive already dressed, and does a placement still win?
--
-- Both are read off the LEAF's picture, which is the whole story in one
-- string: `door_eng_glass` is engineering's stripes with a window in
-- them, `door_eng` is the same stripes solid. A door that lost its
-- variant's livery, or one that ignored a placement saying `glass:
-- false`, spells a different word here.
--
-- tg's ladder this replaces: /obj/machinery/door/airlock/engineering
-- beside /glass beside /glass/engineering (airlock.dm) -- three objects
-- for two facts about one doorway.
t.world([==[(
    name: "doorways",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#a...g#",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1)],
    structures: [
        (3, 1, "airlock.engineering_glass"),
        (3, 2, "airlock.engineering_glass", { "glass": false }),
        (5, 2, "airlock"),
    ],
    cables: [
        (1, 1, 1), (2, 1, 1), (3, 1, 1), (4, 1, 1), (5, 1, 1),
        (1, 1, 2), (1, 2, 1), (2, 2, 1), (3, 2, 1), (4, 2, 1), (5, 2, 1),
    ],
)]==], 7)

t.tick()

-- It is a real prototype with a dotted id, placed like any other.
local glazed = t.structure_at(3, 1)
assert(glazed ~= nil, "the map stood a leaf there")
assert(glazed.id == "airlock.engineering_glass", "by its own id")
assert(
    glazed.sprite == "door_eng_glass",
    "and it arrived striped and glazed, from the variant's defaults: " ..
        tostring(glazed.sprite)
)

-- ...and a placement outranks it. Same variant, one property said
-- otherwise, and only that property changes: the stripes stay.
local solid = t.structure_at(3, 2)
assert(solid.id == "airlock.engineering_glass", "the same variant")
assert(
    solid.sprite == "door_eng",
    "with the window taken out by the placement, and the livery kept: " ..
        tostring(solid.sprite)
)

-- The base is untouched by either of them: a variant defaults a
-- PLACEMENT, never the file it came from.
local plain = t.structure_at(5, 2)
assert(plain.id == "airlock", "the base is still the base")
assert(plain.sprite == "door", "in the station's own livery")
