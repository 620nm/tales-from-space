-- Harness smoke: a world boots, a player joins, walks, and is heard.
t.world([==[(
    name: "smoke cell",
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
)]==])

local p = t.join()
t.tick()

t.say(p, "hello shift")
t.tick()
local heard = table.concat(t.messages(p), "\n")
assert(heard:find("hello shift", 1, true), "speaker hears themself: " .. heard)

t.move(p, "east")
t.run_ticks(5)
local x, y = t.pos(p)
assert(x == 2 and y == 1, ("moved east to (%d, %d)"):format(x, y))
