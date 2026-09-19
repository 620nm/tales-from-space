-- A real CO2 parcel suppresses a supported fire by carrying matter and
-- cold into its tile. A separated control fire keeps fuel and heat,
-- proving this is suppression rather than natural burnout.
local ui_controls = require("@helpers/ui_controls")

local function gas(x: number, y: number, key: string): number
    local room = assert(t.room_gas(x, y))
    return room[key] or 0.0
end

t.world(
    [==[ (
    name: "extinguisher fire bench",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#########",
        "#...#...#",
        "#########",
    ],
    blends: {
        "burning_mix": (
            rows: [("plasma", 1.0), ("o2", 1.4)],
            temperature_k: 1200.0,
            amount: per_tile,
        ),
    },
    structures: [
        (3, 1, "player_spawn"),
        (2, 1, "canister"),
        (6, 1, "canister"),
    ],
    items: [(3, 1, "fire_extinguisher")],
    painted: [(2, 1, "burning_mix"), (6, 1, "burning_mix")],
)]==],
    0,
    "free_build"
)

-- Inhalation injury is outside this fire-suppression fixture.
t.set_breathing(false)
local p = t.join()
t.tick()
t.run_seconds(2)
assert(#t.ledger_rows("IgnitionAt") >= 2, "both supported fires ignite")

local control_plasma = gas(6, 1, "plasma")
local control_o2 = gas(6, 1, "o2")
local control_temperature = assert(t.room_temperature(6, 1))
assert(control_plasma > 0.01 and control_o2 > 0.01, "the control fire has fuel")
assert(control_temperature > 373.15, "the control fire is hot")

local extinguisher = assert(t.target_at(p, 3, 1, "fire_extinguisher"))
t.click(p, 3, 1, extinguisher)
t.tick()
assert(t.hands(p).held == "fire_extinguisher", "the player holds the extinguisher")
t.use_self(p)
t.tick()
t.run_ticks(16)
t.set_health(p, { brute = 0, burn = 0, oxy = 0, tox = 0 })

assert(#t.ledger_rows("ExtinguishedAt") == 0, "neither fire has extinguished before spraying")

-- Aim at the adjacent dense canister so the native parcel starts on the
-- burning tile. The canister is only a target; the parcel is real room gas.
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 1, "CO2 discharge is recorded")
local before_temperature = assert(t.room_temperature(2, 1))
for _ = 1, 9 do
    t.run_ticks(24)
    t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "canister")))
    t.tick()
end
assert(#t.ledger_rows("MatterSprayed") == 10, "the full charge supplies ten finite bursts")
t.run_seconds(2)
local target_extinguished = false
local control_extinguished = false
for _, row in ipairs(t.ledger_rows("ExtinguishedAt")) do
    local at = ui_controls.array(row.at)
    if at[1] == 2 and at[2] == 1 then
        target_extinguished = true
    elseif at[1] == 6 and at[2] == 1 then
        control_extinguished = true
    end
end
assert(target_extinguished, "the CO2 parcel extinguishes the target fire")
assert(not control_extinguished, "the control fire does not extinguish")
assert((assert(t.room_gas(2, 1)).co2 or 0.0) > 0.1, "real CO2 reaches the target tile")
assert(assert(t.room_temperature(2, 1)) < before_temperature, "the discharge cools the target tile")

-- The control remains supplied and hot enough that its fire did not
-- simply time out while the first room was being suppressed.
assert(gas(2, 1, "plasma") > 0.01 and gas(2, 1, "o2") > 0.01, "target fuel remains")
assert(gas(6, 1, "plasma") > 0.01 and gas(6, 1, "o2") > 0.01, "control fuel remains")
assert(assert(t.room_temperature(6, 1)) > 373.15, "control fire remains hot")
assert(control_plasma > 0.01 and control_o2 > 0.01, "the control baseline was fuelled")
assert(control_temperature > 373.15, "the control baseline was hot")
