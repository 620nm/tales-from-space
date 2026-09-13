local ui_controls = require("@helpers/ui_controls")

-- Staff body actions use the human plan's declared restoration and
-- disassembly recipe. The harness exposes the authenticated staff seam
-- without requiring gateway persistence.

local ARENA = [==[(
    name: "staff body bench",
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
    structures: [(1, 1, "player_spawn")],
)]==]

t.world(ARENA, 0)
local patient = t.join()
t.run_ticks(3)

-- The pack's death handler stops the heart when the dead line is crossed.
t.set_health(patient, { brute = 200, burn = 0, oxy = 0, tox = 0 })
t.run_ticks(2)
assert(not assert(t.body(patient)).animate, "the damaged human is a corpse")
assert(t.organ_damage(patient, "heart") == 100, "death stopped the heart")

-- Restore repairs the body resources and clears the pack's failed-heart
-- latch, while keeping the same session and body handle.
assert(t.staff_restore(patient), "the human plan permits restoration")
local restored = assert(t.body(patient))
assert(restored.animate and restored.controllable and restored.conscious,
    "a fully restored human runs again")
assert(math.abs(restored.health - 100) < 0.01, "all body pools are clear")
assert(math.abs(assert(restored.blood) - 560) < 0.01, "blood returns to the plan normal")
assert(t.organ_damage(patient, "heart") == 0, "the failed heart is repaired")
for _, zone in ipairs({ "head", "chest", "pelvis", "l_arm", "r_arm", "l_leg", "r_leg" }) do
    local part = assert(t.parts(patient))[zone]
    assert(part and part.present, "restore keeps every human part: " .. zone)
    assert(part.brute == 0 and part.burn == 0, "restore clears harm: " .. zone)
end
assert(t.ledger_has("Revived", "Operator"), "restoration is audited")

-- Kill follows the human plan's vital organ rule and keeps the body in the
-- world, so staff can inspect the resulting corpse before gibbing it.
assert(t.staff_kill(patient), "the human plan permits a staff kill")
assert(not assert(t.body(patient)).animate, "staff kill leaves a stopped corpse")
assert(t.organ_damage(patient, "heart") == 100, "staff kill fails the vital heart")
assert(t.staff_restore(patient), "the same body can be restored again")

-- The declared gib recipe mints each remain through item initialization,
-- then destroys the body and its stowed anatomy. The Mind/session survives
-- without a body, and the pile is visible at the body's former tile.
assert(t.staff_gib(patient), "the human plan permits gibbing")
assert(t.bodies_at(1, 1)[1] == nil, "the body is gone")
local pile = t.items_at(1, 1)
local declared: {[string]: boolean} = {
    human_head = true, human_chest = true, human_pelvis = true,
    human_l_arm = true, human_r_arm = true, human_l_leg = true,
    human_r_leg = true, organ_brain = true, organ_eyes = true,
    organ_ears = true, organ_tongue = true, organ_heart = true,
    organ_lungs = true, organ_liver = true, organ_stomach = true,
    organ_appendix = true, staff_remains = true,
}
local expected: {[string]: boolean?} = {}
for id in pairs(declared) do expected[id] = true end
for _, id in ipairs(pile) do expected[id] = nil end
for id in pairs(expected) do
    error("gib left no declared remain: " .. id)
end
local spawned = t.ledger_rows("ItemSpawned")
local audited: {[string]: number} = {}
for _, row in ipairs(spawned) do
    local proto = ui_controls.text(row.proto)
    if declared[proto] then
        audited[proto] = (audited[proto] or 0) + 1
    end
end
for id in pairs(declared) do
    assert(audited[id] == 1,
        "every declared remain was initialized and audited: " .. id)
end
assert(t.ledger_has("ItemSpawned", "Operator"),
    "gib material is attributed to staff")
