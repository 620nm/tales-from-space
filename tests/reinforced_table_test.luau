-- The reinforced table, and the cover that has to come off first.
--
-- Its own file rather than a fourth act in tables_test.luau, because
-- the claim is a different one: not "a table is a table" but "this one
-- refuses to be taken apart until somebody has weakened it". tg makes
-- that a bit on the object (`deconstruction_ready = FALSE`,
-- code/game/objects/structures/tables_racks.dm:748) and a welder that
-- toggles it in fifty deciseconds each way (:784-801); here it is two
-- states, one welder row per direction, and refusals the engine
-- composes out of the state names -- which is the whole reason a state
-- in this pack is spelled as an adjective.
--
-- The material is reinforced glass rather than plasteel because this
-- pack has no plasteel; tg's rglass stack builds a reinforced table too
-- (glass.dm:173), and structures/reinforced_table.luau says so.
t.world([==[(
    name: "glazier's corner",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [
        (2, 1, "rod"),
        (1, 2, "rglass"),
        (1, 1, "wrench"),
        (1, 1, "welder"),
    ],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "rod"))
t.run_ticks(2)
t.build(p, "rod", "table_frame", 2, 2)
t.run_seconds(1.5)
assert(t.structure_at(2, 2).id == "table_frame", "the same frame as any other table")

-- The sheet decides which table the frame becomes. Reinforced glass,
-- because this pack has no plasteel: tg's rglass stack builds a
-- reinforced table too (glass.dm:173).
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(1, 2, "rglass"))
t.run_ticks(2)
assert(t.hands(p).held == "rglass", "reinforced glass in hand")
t.click(p, 2, 2, t.target_at(2, 2, "table_frame"))
t.run_seconds(2.5)
local hard = t.structure_at(2, 2)
assert(hard ~= nil and hard.id == "reinforced_table",
    "the frame took the reinforced pane: " .. tostring(hard and hard.id))
assert(hard.state == "welded",
    "and arrives with its cover welded on: " .. tostring(hard.state))
assert(hard.sprite == "reinforced_table-0",
    "wearing its own family's isolated frame: " .. tostring(hard.sprite))

-- The ratchet declines, and says which state it wants. A silent no-op
-- would read as a dropped click.
t.swap_hands(p)
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
t.run_ticks(2)
local _ = t.messages(p)
t.click(p, 2, 2, t.target_at(2, 2, "reinforced_table"))
t.run_seconds(4.5)
assert(t.structure_at(2, 2) ~= nil, "the table is still standing")
local refused = false
for _, m in ipairs(t.messages(p)) do
    if m == "The reinforced table must be loosened first." then
        refused = true
    end
end
assert(refused, "the refusal named the state the job wants")

-- A torch weakens it, and then the same ratchet finishes the job.
t.swap_hands(p)
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1, t.target_at(1, 1, "welder"))
t.run_ticks(2)
assert(t.hands(p).held == "welder", "a torch in hand")
t.click(p, 2, 2, t.target_at(2, 2, "reinforced_table"))
t.run_seconds(5.5)
assert(t.structure_at(2, 2).state == "loosened",
    "five seconds of welding weakened the cover: "
        .. tostring(t.structure_at(2, 2).state))

t.swap_hands(p)
assert(t.hands(p).held == "wrench", "the ratchet is back in the active hand")
t.click(p, 2, 2, t.target_at(2, 2, "reinforced_table"))
t.run_seconds(4.5)
assert(t.structure_at(2, 2) == nil, "and now it comes apart")
assert(t.item_at(2, 2, "rglass") ~= nil, "the pane is back on the deck")
assert(t.item_at(2, 2, "rod") ~= nil, "and so are the legs")
