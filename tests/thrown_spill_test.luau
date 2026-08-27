-- An open vessel spills its real condensed contents when a throw comes
-- to rest. The wall is the obstacle; the salt lands on the standable
-- tile immediately before it and remains solid matter there.
t.world([==[(
    name: "impact spill room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###########",
        "#.........#",
        "###########",
    ],
    spawns: [(4, 1)],
    items: [(5, 1, "beaker.salt"), (5, 1, "bottle.iodine")],
)]==], 4)

local p = t.join()
t.tick()

local beaker = t.target_at(5, 1, "beaker.salt")
assert(beaker ~= nil, "the salt beaker is on the deck")
local before = t.matter_totals()
local contents = t.contents(beaker)
assert(contents ~= nil and math.abs((contents.salt or 0) - 0.80) < 1e-9,
    "the open beaker starts with solid salt")

t.click(p, 5, 1, beaker)
t.tick()
assert(t.hands(p).held == "beaker.salt", "the beaker is held")

-- Aim at the east wall. Native flight settles on the last standable
-- tile, then `throw.land.done` lets the vessel issue the spill there.
t.throw(p, 10, 1)
t.tick()
t.run_ticks(10)

local landed = t.item_at(9, 1, "beaker.salt")
assert(landed ~= nil, "the beaker stopped before the wall")
local left = t.contents(beaker)
assert(left ~= nil and math.abs(left.salt or 0) < 1e-9,
    ("the open beaker spilled all condensed salt (left=%s sealed=%s)"):format(
        tostring(left and left.salt), tostring(t.vessel(beaker).sealed)))

local spilled = t.ledger_rows("spilled")
assert(#spilled == 1, ("one impact spill, got %d"):format(#spilled))
assert(math.abs(spilled[1].moles - 0.80) < 1e-9, "the whole charge moved")
assert(spilled[1].at[1] == 9 and spilled[1].at[2] == 1,
    "the spill is on the landing tile before the wall")

local after = t.matter_totals()
assert(math.abs(after.moles - before.moles) < 1e-8,
    "throwing and spilling conserve station matter")
assert(math.abs(after.energy_j - before.energy_j) < 1e-5,
    "the salt carries its energy onto the tile")

-- A seal is the content-visible opt-out. The same vessel library owns
-- bottles, but their stopper keeps real matter inside through impact.
local bottle = t.target_at(5, 1, "bottle.iodine")
assert(bottle ~= nil, "the sealed control bottle is on the deck")
t.click(p, 5, 1, bottle)
t.tick()
assert(t.hands(p).held == "bottle.iodine", "the bottle is held")
t.throw(p, 0, 1)
t.tick()
t.run_ticks(10)

local sealed = t.vessel(bottle)
assert(sealed ~= nil and sealed.sealed and sealed.moles > 0.12,
    "a sealed vessel keeps its charge when thrown")
assert(#t.ledger_rows("spilled") == 1,
    "the sealed landing adds no spill to the ledger")
