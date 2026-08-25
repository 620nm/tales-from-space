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

-- Metabolism burns the sugar; sugar's mob.life heals oxy.
local sugar = t.blood(p).sugar
assert(sugar ~= nil and sugar > 0, "the swig carried sugar into the blood")

local before = t.health(p).oxy
t.run_ticks(400)
local after = t.health(p).oxy
assert(after < before, ("sugar healed oxy: %g -> %g"):format(before, after))
assert(t.blood_moles(p) < swig, "metabolism removed moles from the blood")

-- THE HOOK IS HANDED A NUMBER.
--
-- `mob.life(ctx, self, user, moles)` takes four arguments and the
-- fourth is the moles this metabolism trip burned. A hook that names
-- three parameters binds the BODY to `moles`; arithmetic on a handle
-- throws, and a hook that throws loses its whole effect buffer -- so
-- the heal would silently never land at all. Sugar's heal is written
-- as `moles * 125`, which makes the arithmetic itself the proof.
--
-- Every heal is a ledger row, so the trips are readable one by one. A
-- trip that burns a full `metabolism_rate` is worth exactly 0.5 oxy
-- and no trip can be worth more; a trip that burns less pays less,
-- and a FLAT half-point a trip could not produce that second number
-- at all. The swig carries ~0.0083 mol of sugar and does not last
-- four trips, because the bloodstream is 310 K and fermentation is
-- happy there (reactions/fermentation.luau) -- the brewing takes its
-- cut of the same sugar, which is why the trips total less than the
-- swig was worth.
local full = 0.004 * 125.0 -- metabolism_rate x the per-mole heal
local function pool_amount(row, id)
    for _, entry in ipairs(row.pools or {}) do
        if entry[1] == id then
            return entry[2]
        end
    end
    return 0
end
local trips = {}
for _, row in ipairs(t.ledger_rows("Healed")) do
    trips[#trips + 1] = pool_amount(row, "oxy")
end
assert(#trips >= 2, "the swig was burned over several trips: " .. #trips)
local healed = 0
local tapered = false
for _, oxy in ipairs(trips) do
    assert(oxy > 0 and oxy <= full + 1e-6, ("a trip paid %g, over the %g a full one is worth"):format(oxy, full))
    tapered = tapered or oxy < full - 1e-6
    healed = healed + oxy
end
assert(math.abs(trips[1] - full) < 1e-6, ("a full trip pays %g, got %g"):format(full, trips[1]))
assert(tapered, "and the trip that burned the dregs paid proportionally less")
assert(healed <= sugar * 125.0 + 1e-6, "no trip healed sugar it had not burned")
assert(#t.ledger_rows("ScriptError") == 0, "and no metabolism hook threw")
