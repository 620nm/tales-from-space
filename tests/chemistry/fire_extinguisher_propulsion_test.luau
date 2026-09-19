-- Orthogonal bursts add recoil without erasing existing vacuum drift.
t.world([==[(
    name: "extinguisher vacuum steering",
    tags: ["space"],
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        's': (composition: (substrate: Some("space"))),
        'f': (composition: (substrate: Some("space"), components: [(component: "station_base")])),
    },
    rows: [
        "sssssssssssssss", "sssssssssssssss", "sssssssssssssss",
        "sssssssssssssss", "sssssssssssssss", "sssssssssssssss",
        "sssssssssssssss", "sssssssfsssssss", "sssssssssssssss",
        "sssssssssssssss", "sssssssssssssss", "sssssssssssssss",
        "sssssssssssssss", "sssssssssssssss", "sssssssssssssss",
    ],
    items: [(7, 7, "fire_extinguisher")],
    structures: [(7, 7, "player_spawn"), (11, 7, "canister"), (6, 3, "canister")],
)]==], 0, "free_build")

local p = t.join()
t.tick()
local extinguisher = assert(t.target_at(p, 7, 7, "fire_extinguisher"))
t.click(p, 7, 7, extinguisher)
t.tick()
t.use_self(p)
t.tick()
t.run_seconds(5)
assert(t.hands(p).held == "fire_extinguisher")
assert(assert(t.vessel(extinguisher)).pressure_kpa > 1.0)
assert(t.set_composition(7, 7, "bare"))
local initial_moles = assert(t.vessel(extinguisher)).moles

-- The body starts at rest without a handhold. Eastward emission pushes west.
t.click(p, 11, 7, assert(t.target_at(p, 11, 7, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 1, "the vacuum discharge is accepted")
assert(assert(t.vessel(extinguisher)).moles < initial_moles, "recoil spends actual CO2")
t.run_ticks(8)
t.click(p, 11, 7, assert(t.target_at(p, 11, 7, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 1, "cooldown refuses a second burst")
t.run_ticks(50)
local west_x, west_y = t.pos(p)
assert(west_x == 6 and west_y == 7, "eastward emission starts westward coast")

-- Northward emission adds southward velocity while retaining westward drift.
t.click(p, 6, 3, assert(t.target_at(p, 6, 3, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 2, "the steering burst is accepted")
t.run_ticks(80)
local diagonal_x, diagonal_y = t.pos(p)
assert(diagonal_x < west_x and diagonal_y > west_y, "recoil adds an orthogonal velocity")
t.run_ticks(80)
local coast_x, coast_y = t.pos(p)
assert(coast_x < diagonal_x and coast_y > diagonal_y, "both velocity components persist after firing")
