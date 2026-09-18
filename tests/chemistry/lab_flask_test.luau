-- The pressure flask keeps its charge behind the seal, while opening it
-- restores the ordinary vessel pour. Gas remains in the headspace: pours
-- move condensed matter, and charging still owns the gas path.
t.world(
    [==[(
    name: "lab flask closure",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    blends: {
        "flask_charge": (
            rows: [("water:liquid", 0.20), ("n2:gas", 0.10)],
            temperature_k: 293.15,
            amount: total,
        ),
    },
    structures: [(2, 1, "player_spawn")],
    items: [
        (2, 1, "lab_flask", { "blend": "flask_charge" }),
        (3, 1, "beaker"),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local flask = assert(t.target_at(p, 2, 1, "lab_flask"), "the charged flask is present")
local beaker = assert(t.target_at(p, 3, 1, "beaker"), "the receiving beaker is present")

local function phase(item: SpecObservedTarget, substance: string, state: "liquid" | "gas"): number
    local row = assert(t.vessel(item)).contents[substance]
    if row == nil then
        return 0.0
    end
    return if state == "liquid" then (row.liquid or 0.0) else (row.gas or 0.0)
end

assert(assert(t.vessel(flask)).sealed, "the lab flask starts sealed")
assert(
    math.abs(phase(flask, "water", "liquid") - 0.20) < 1e-9,
    "the flask starts with liquid water"
)
assert(math.abs(phase(flask, "n2", "gas") - 0.10) < 1e-9, "the flask starts with nitrogen gas")
assert(next(assert(t.contents(beaker))) == nil, "the receiving beaker starts empty")

-- Holding the sealed flask against ordinary glass is refused by the flask;
-- no condensed matter moves and no pour is recorded.
t.click(p, 2, 1, flask)
t.tick()
assert(t.hands(p).held == "lab_flask", "the player picks up the flask")
t.click(p, 3, 1, beaker)
t.tick()
assert(math.abs(phase(flask, "water", "liquid") - 0.20) < 1e-9, "a sealed flask keeps its water")
assert(math.abs(phase(flask, "n2", "gas") - 0.10) < 1e-9, "a sealed flask keeps its nitrogen")
assert(next(assert(t.contents(beaker))) == nil, "a sealed flask pours nothing")
assert(
    string.find(table.concat(t.messages(p), " "), "Open the vessel before pouring.", 1, true) ~= nil,
    "a sealed pour explains how to open the flask"
)
assert(#t.ledger_rows("Poured") == 0, "a refused pour is absent from the ledger")

-- The flask's self action opens the valve. Its next pour moves the liquid
-- into the adjacent beaker while the gas charge remains in the headspace.
t.use_self(p)
t.tick()
assert(not assert(t.vessel(flask)).sealed, "self-use opens the flask")
t.click(p, 3, 1, beaker)
t.tick()
assert(phase(beaker, "water", "liquid") > 0.19, "the open flask pours its water")
assert(phase(flask, "water", "liquid") < 1e-9, "the poured water leaves the flask")
assert(math.abs(phase(flask, "n2", "gas") - 0.10) < 1e-9, "pouring preserves the gas charge")
assert(#t.ledger_rows("Poured") == 1, "the accepted pour is on the ledger")

t.use_self(p)
t.tick()
assert(assert(t.vessel(flask)).sealed, "self-use closes the flask again")
