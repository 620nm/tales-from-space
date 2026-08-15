-- Drinking: a swig moves 0.05 mol from the can to the bloodstream, and
-- metabolism burns the sugar whose hook heals oxygen damage. (Port of
-- the observable half of the Rust m7 test; exact conservation across
-- the can stays native until t grows a container query.)
t.world([==[(
    name: "canteen floor",
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
    items: [(1, 1, "cola")],
)]==], 7)

local p = t.join()
t.tick()

-- A rough shift so far: some oxygen damage to heal.
t.set_health(p, { oxy = 30 })

t.click(p, 1, 1, t.target_at(1, 1, "cola")) -- pick up the can
t.tick()
assert(t.blood_moles(p) == 0, "nothing in the blood yet")

t.click(p, 1, 1) -- click your own tile: a swig
t.tick()
local swig = t.blood_moles(p)
assert(math.abs(swig - 0.05) < 1e-9, ("one 0.05 mol gulp, got %g"):format(swig))

-- Metabolism burns the sugar; sugar's on_mob_life heals oxy.
local before = t.health(p).oxy
t.run_ticks(400)
local after = t.health(p).oxy
assert(after < before, ("sugar healed oxy: %g -> %g"):format(before, after))
assert(t.blood_moles(p) < swig, "metabolism removed moles from the blood")
