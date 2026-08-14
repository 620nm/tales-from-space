-- Windows, as a player builds them: rods make a grille, glass fills
-- it, and reinforced glass fills it in a way that takes real work to
-- undo. Every step here is a click a person could make, from a tile
-- they could stand on -- REACH is 1, so the walk matters.
local MAP = [==[(
    name: "glazing",
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
    items: [
        (3, 1, "rod"),
        (3, 2, "glass"),
        (1, 1, "crowbar"),
        (1, 2, "screwdriver"),
    ],
)]==]

t.world(MAP, 7)
local p = t.join()
t.tick()
t.move(p, "east") -- (2, 1): everything below is within arm's reach
t.run_ticks(6)

-- Two rods weave a grille on the tile below.
t.click(p, 3, 1)
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(1.5)
assert(t.ledger_has("StructureStep", "grille", "built"), "the grille stands")
-- A built grille arrives fastened down, as tg's does; glazing an
-- unfastened one is refused, which is why the state is named for it. The grille is still there underneath: the step moves
-- it to a state, it does not replace the thing.
--
-- Note the drop: a click while holding a material BUILDS rather than
-- picks up, because construction outranks pickup. You have to put the
-- rods down before you can pick anything else off the floor.
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2)
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "grille", "glazed"), "the pane went in")

-- A crowbar takes the pane back out and hands the sheets over, leaving
-- the grille standing.
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1)
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "grille", "bolted"), "the pane came out")
assert(t.count_items("glass") > 0, "the sheets came back")

-- An unfastened grille takes no glass: tg refuses with "needs to be
-- fastened to the floor first", and so does this. The screwdriver
-- toggle is what makes the state worth having -- and while it is
-- loose, it is also a thing you can shove.
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 2) -- the screwdriver
t.run_ticks(2)
t.click(p, 2, 2) -- unfasten
t.run_ticks(4)
assert(t.ledger_has("StructureStep", "grille", "unbolted"), "it came loose")

t.drop(p)
t.run_ticks(2)
t.click(p, 2, 2) -- the sheets the crowbar just handed back, on that tile
t.run_ticks(2)
local _ = t.messages(p)
t.click(p, 2, 2)
t.run_ticks(4)
local gated = false
for _, m in ipairs(t.messages(p)) do
    if m == "The grille must be bolted first." then
        gated = true
    end
end
assert(gated, "glass refuses an unfastened grille, and says so")

-- Scenario 2: reinforced glass is bolted in, and a crowbar alone will
-- not shift it. That refusal is the whole reason to spend the sheets.
t.world([==[(
    name: "reinforced",
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
    items: [
        (3, 1, "rod"),
        (3, 2, "rglass"),
        (1, 1, "crowbar"),
        (1, 2, "screwdriver"),
    ],
)]==], 7)

p = t.join()
t.tick()
t.move(p, "east")
t.run_ticks(6)
t.click(p, 3, 1)
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(1.5)
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2) -- the reinforced sheets
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "grille", "reinforced"), "bolted in")

-- The crowbar finds nothing to do: the bolts are still down, and it is
-- told which state it wants rather than failing in silence.
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1)
t.run_ticks(2)
local _ = t.messages(p)
t.click(p, 2, 2)
t.run_ticks(4)
-- And it names EVERY state that would have worked, not the first one
-- the file happens to list: a crowbar takes a glazed pane out directly
-- and a reinforced one only once unscrewed, so it must say both or it
-- sends you to undo work you never did.
local refused = false
for _, m in ipairs(t.messages(p)) do
    if m == "The grille must be glazed or loosened first." then
        refused = true
    end
end
assert(refused, "the crowbar says which states it could have worked in")

-- Unscrew, then pry: two tools, in order.
t.drop(p) -- a crowbar in hand pries the floor instead of picking up
t.run_ticks(2)
t.click(p, 1, 2) -- the screwdriver
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "grille", "loosened"), "the bolts backed out")

t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1) -- back to the crowbar
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(4.5)
assert(t.count_items("rglass") > 0, "the reinforced sheets came back")
