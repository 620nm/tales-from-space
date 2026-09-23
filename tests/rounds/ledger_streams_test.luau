-- The round's audit stream keeps every row the engine announced
-- (content/ledger.luau), item lifecycle rows included, and nothing else
-- is declared.
t.world(
    [==[(
    name: "audit room",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn")],
)]==],
    7,
    "free_build"
)

local builder = t.join()
t.run_ticks(4)
assert(builder, "a builder stands in the room")

local all = t.ledger_rows()
local audit = t.ledger_stream_rows("audit")
assert(#all > 0, "the round announced something")
assert(#audit == #all, "audit keeps every row: " .. #audit .. " of " .. #all)
for i, row in ipairs(all) do
    assert(audit[i].seq == row.seq, "audit row " .. i .. " is the same row")
end
local spawned = 0
for _, row in ipairs(audit) do
    if row.event == "item_spawned" then
        spawned += 1
    end
end
assert(spawned > 0, "the issued outfit is on the audit record")

assert(not pcall(function()
    t.ledger_stream_rows("talk")
end), "only the declared stream exists")
