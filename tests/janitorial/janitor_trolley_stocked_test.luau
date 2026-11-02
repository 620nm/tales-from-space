-- The stocked cart (docs/janitorial/trolley.md): placed on a map it holds its
-- stock and a brimming tub and draws them, and the plain cart beside it holds
-- nothing.
t.world(
    [==[(
    name: "closet",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(2, 1, "player_spawn")],
            items: [
                (1, 1, "janitor_trolley.stocked"),
                (3, 1, "janitor_trolley"),
                (2, 1, "spray_bottle.cleaner"),
            ],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()
local stocked = assert(t.target_at(p, 1, 1, "janitor_trolley.stocked"))
local plain = assert(t.target_at(p, 3, 1, "janitor_trolley"))

-- Stock and water, drawn.
assert((assert(t.contents(stocked)).water or 0) > 229, "the tub brims")
assert(assert(t.vessel(stocked)).headspace_l < 0.05, "to its 4167 mL")
assert(table.find(t.overlays(stocked), "janitor_trolley_water") ~= nil, "it wears its water")
for _, sprite in ipairs({ "janitor_trolley_mop", "janitor_trolley_spray", "janitor_trolley_replacer" }) do
    assert(t.target_at(p, 1, 1, "sprite:" .. sprite) == stocked, sprite .. " draws")
end

-- The rack's bottle arrives charged as tg's: 100 u of cleaner.
local cleaner = assert(t.target_at(p, 2, 1, "spray_bottle.cleaner"))
assert(math.abs((assert(t.contents(cleaner)).space_cleaner or 0) - 0.91) < 0.01, "a charged bottle")

-- The plain cart stays empty.
assert(next(assert(t.contents(plain))) == nil, "no water")
assert(table.find(t.overlays(plain), "janitor_trolley_water") == nil, "and draws none")
assert(t.target_at(p, 3, 1, "sprite:janitor_trolley_mop") == nil, "nor a mop")
