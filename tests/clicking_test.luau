-- What a click acts on: the thing you pointed at.
--
-- tg's ClickOn hands the whole chain the atom BYOND's mouse-opacity
-- pass picked and never re-derives a target from the tile
-- (code/_onclick/click.dm:145-180); our per-pixel hit-test names the
-- same fact on the wire, so a spec spells it out with `t.target_at`.
-- Three player-visible consequences, all of them reported as bugs:
-- a crowbar aimed at a dropped thing pried the floor out from under
-- it, two piles of tiles would not become one, and a tile could not go
-- down where the pile already lay.

local function has(list, want)
    for _, v in ipairs(list) do
        if v == want then
            return true
        end
    end
    return false
end

t.world([==[(
    name: "workshop",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "####",
        "#..#",
        "#..#",
        "####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "crowbar"), (2, 2, "metal")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 1, 1, t.target_at(1, 1, "crowbar"))
t.tick()
assert(t.hands(p).held == "crowbar", "the crowbar is in the working hand")
t.messages(p)

-- Symptom 1: the sheets are what the click named, so the floor they
-- lie on is not the target and never comes up.
local sheets = t.target_at(2, 2, "metal")
assert(sheets ~= nil, "the sheets are clickable")
t.click(p, 2, 2, sheets)
t.tick()
assert(t.turf(2, 2) == "floor", "the tile under the sheets stayed down")
assert(not has(t.messages(p), "You pry up the floor tile."), "nothing was pried")

-- The same crowbar on the same tile, aimed at the deck itself: that IS
-- the target, and it comes up as it always did.
t.click(p, 2, 2)
t.tick()
assert(t.turf(2, 2) == "plating", "a click on the deck still pries it")
t.click(p, 2, 1)
t.tick()
assert(t.turf(2, 1) == "plating", "and so does the next one")

-- Two loose tiles, one in hand: put the crowbar down and gather them.
t.drop(p)
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "floor_tile"))
t.tick()
assert(t.hands(p).held == "floor_tile", "one pried tile in hand")

-- Symptom 2: pointing at the other pile merges it in. It must not lay
-- a tile: a gather is not a build, and the plating is the proof.
t.click(p, 2, 2, t.target_at(2, 2, "floor_tile"))
t.tick()
assert(not has(t.items_at(2, 2), "floor_tile"), "the pile went into the hand")
assert(t.turf(2, 2) == "plating", "and nothing was built doing it")

-- Two units in one hand, two tiles laid: the merge kept the count.
t.click(p, 2, 2)
t.run_seconds(1.0)
assert(t.turf(2, 2) == "floor", "the first unit went down")
t.click(p, 2, 1)
t.run_seconds(1.0)
assert(t.turf(2, 1) == "floor", "and the second")
assert(t.hands(p).held == nil, "which spent the stack exactly")
