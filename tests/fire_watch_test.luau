-- The station's own count of the fires it had, driven entirely by the
-- matter kernel's edges. Nothing in `main.luau` decides that a fire
-- starts or stops: the authored plasma rules and the physics do, and
-- `matter.ignition.done` / `matter.extinguished.done` are how content
-- hears about it after the fact.
t.world([==[(
    name: "fire watch bench",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "atmos_resin_projector")],
    air_presets: {
        "burning_mix": (
            gases: [("plasma", 10.0), ("o2", 14.0)],
            temperature_k: 700.0,
        ),
    },
    air: [(1, 1, "burning_mix")],
)]==], 0)

local p = t.join()
t.tick()

local function tallies(key)
    local rows = {}
    for _, row in t.ledger_rows("VarSet") do
        if row.key == "lunatic/tfs:" .. key then
            table.insert(rows, row)
        end
    end
    return rows
end

assert(#tallies("fires_lit") == 0, "nothing has burned yet")

-- Two atmos passes are enough for the hot, fuelled mixture to catch.
t.run_seconds(1)
assert(#t.ledger_rows("IgnitionAt") == 1, "the room caught fire once")
local lit = tallies("fires_lit")
assert(#lit == 1, ("the shift record counted one fire, got %d"):format(#lit))
assert(lit[1].value == "1", "the first fire is the first: " .. tostring(lit[1].value))
assert(lit[1].actor.kind == "script", "the content file owns the count")

-- A fire that keeps burning is not a second fire: the anchor is an
-- edge, and the count follows the anchor.
t.run_seconds(3)
assert(#tallies("fires_lit") == 1, "a fire still burning is still one fire")
assert(#tallies("fires_out") == 0, "and it has not gone out")

-- Put it out with the pack's own suppressant, and the other edge lands.
local projector = t.target_at(1, 1, "atmos_resin_projector")
t.click(p, 1, 1, projector)
t.tick()
t.click(p, 1, 1)
t.tick()
t.run_seconds(1)
assert(#t.ledger_rows("ExtinguishedAt") == 1, "the spray put it out")
local out = tallies("fires_out")
assert(#out == 1, ("one fire went out on the record, got %d"):format(#out))
assert(out[1].value == "1", "and it is the first: " .. tostring(out[1].value))
