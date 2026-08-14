-- Metal sheets: the two-stage wall, and the sanity check that runs
-- twice. Scenario 1 walks the chain (girder, then wall). Scenario 2 is
-- the point of the second check: a build the tile cannot take is
-- refused BEFORE the do_after, so nobody spends four seconds on it.
t.world([==[(
    name: "site",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "metal")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 1) -- pick up the sheets
t.run_ticks(2)

t.click(p, 2, 2) -- raise a girder on the neighbouring floor
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "built"), "the girder rose")

t.click(p, 2, 2) -- plate the standing girder into a wall
t.run_seconds(4.5)
assert(t.turf(2, 2) == "wall", "the wall closed, got " .. tostring(t.turf(2, 2)))

-- Scenario 2: the precheck. You are standing on this tile, so no
-- girder can rise here — and the refusal comes at once, not after a
-- four-second do_after that quietly produces nothing.
local _ = t.messages(p)
t.click(p, 1, 1)
t.run_ticks(2)
local said = t.messages(p)
local refused = false
for _, m in ipairs(said) do
    if m == "Something is in the way." then
        refused = true
    end
    assert(m ~= "You start assembling a girder.",
        "the work never started")
end
assert(refused, "the precheck said why")
