-- The heart swap the charter promises on a proper table (docs/SURGERY.md
-- §6.3, tg's replace-a-failing-heart workflow). On an operating table the
-- modifier is 1.0 and nothing can fail, so this is the OTHER half of the
-- shaft test: the full sequence down to the organ, the choice window, and
-- the cardiac-arrest clock that starts the moment the heart comes out and
-- stops when a new one seats.

local ARENA = [==[(
    name: "theatre",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    structures: [(2, 1, "optable")],
    items: [
        (1, 1, "scalpel"), (1, 1, "retractor"), (1, 1, "hemostat"),
        (1, 1, "circular_saw"), (1, 1, "cautery"), (1, 1, "organ_heart"),
    ],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)
t.rest(patient, true)
t.unequip(patient, "uniform") -- bare the chest (Strip is B3)
t.run_ticks(2)
assert(t.body(patient).posture == "lying" and t.body(patient).conscious,
    "the patient is on the table, awake for now")
assert(t.worn(patient).uniform == nil, "the chest is bared")

local PX, PY = 2, 1
local pid = t.body_id(patient)

local function has(states, name) return states[name] == true end

local function hold(id)
    if t.hands(surgeon).held ~= nil then t.drop(surgeon); t.tick() end
    t.click(surgeon, 1, 1, t.target_at(1, 1, id))
    t.run_ticks(2)
    assert(t.hands(surgeon).held == id, "the surgeon holds the " .. id)
end

-- A single-attempt operation on the table: click once, wait it out, and
-- assert it landed (0 % failure, so no loop).
local function step(tool, secs, done, why)
    hold(tool)
    t.click(surgeon, PX, PY, pid)
    t.run_ticks(math.ceil(secs * 20) + 3)
    assert(done(), why)
end

-- The open-up sequence, each step nothing can fail on the table.
step("scalpel", 1.6, function() return has(t.parts(patient).chest.states, "skin_cut") end, "incised")
step("retractor", 2.4, function() return has(t.parts(patient).chest.states, "skin_open") end, "retracted")
step("hemostat", 2.4, function() return has(t.parts(patient).chest.states, "vessels_clamped") end, "clamped")
step("circular_saw", 5.4, function() return has(t.parts(patient).chest.states, "bone_sawed") end, "sawed")
step("scalpel", 2.4, function() return has(t.parts(patient).chest.states, "organs_cut") end, "organs cut")

-- The heart is whole and beating, so the socket is reachable and the
-- removal is offered — but so are the other chest organs, so a hemostat
-- here opens the CHOICE WINDOW rather than performing one thing.
hold("hemostat")
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
local win = t.ui(surgeon)
assert(win ~= nil and win.document == "modules" and win.presentation == "choices",
    "several organs to reach: the choice document opened")
local pick
for _, toggle in ipairs(win.toggles) do
    if toggle.label:find("heart", 1, true) then pick = toggle.option end
end
assert(pick, "the window lists the heart among the organs to remove")

-- Take the heart out. The socket empties, it lands on the patient's tile,
-- and cardiac arrest begins at once: the blood capacity is 0, and its
-- `when_zero` holds the body under (docs/BIOLOGY.md §8).
t.ui_act(surgeon, "toggle", string.format('{"field":"operation","option":"%s"}', pick))
t.run_ticks(23) -- the 1 s removal
assert(t.organ_damage(patient, "heart") == nil, "the heart socket is empty")
assert(not t.body(patient).conscious, "arrest: the heart is out and the patient is under")
assert(t.body(patient).state ~= "dead", "but not yet dead -- the clock has only just started")
assert(t.count_items("organ_heart") >= 2, "the old heart is on the deck beside the donor")

-- Seat the donor heart. The socket fills, the blood capacity returns, and
-- the body comes back to the state its numbers say.
hold("organ_heart")
t.click(surgeon, PX, PY, pid)
t.run_ticks(23) -- the 1 s insertion
-- Seated (the donor picked up a little decay lying on the deck, which is
-- why a spare organ is kept cold in tg); what matters is that it beats.
assert(t.organ_damage(patient, "heart") ~= nil, "a heart is seated in the socket")
assert(t.organ_damage(patient, "heart") < 40, "and it is in good order")
assert(t.body(patient).conscious, "the heart beats again and the patient comes to")
assert(t.body(patient).state == "alive", "alive, off the arrest clock")

-- Close up. The bone states and the incision clear, and 40 of the saw's
-- 50 brute is mended on the way out.
step("cautery", 2.4, function()
    local s = t.parts(patient).chest.states
    return not has(s, "skin_open") and not has(s, "skin_cut")
end, "closed")
assert(t.body(patient).bleed_rate == 0, "and no longer bleeding")

print("heart: swapped on the table with 0 failures; arrest survived")
