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

-- What a candidate button says. An operation ON AN ORGAN is the
-- `procedure.on_organ` id carrying the two words as arguments; a plain
-- one is content's own word (docs/tgui/labels.md).
local function face(label)
    if type(label) ~= "table" then return tostring(label) end
    if label.args and label.args.organ then
        return tostring(label.args.operation) .. " " .. tostring(label.args.organ)
    end
    return tostring(label.text or label.id)
end

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
    if face(toggle.label):find("heart", 1, true) then pick = toggle.option end
end
assert(pick, "the window lists the heart among the organs to remove")

-- Take the heart out, and the patient dies on the table -- because in
-- this pack the heart IS the boolean life state
-- (content/items/organ_heart.luau: `vital = true`), and the engine's
-- `viability` port reads 0 for a vital organ that is missing exactly as
-- it does for one that has failed.
--
-- A DIVERGENCE from tg worth naming: tg gives a heartless patient a
-- cardiac-arrest grace period to work in, and this does not. The
-- surgeon has no clock -- they have a dead patient who comes back when
-- the new heart seats, which is the next thing this spec does. The two
-- are the same procedure with the tension moved: nothing decays while
-- `animate` is false, so an interrupted swap leaves a corpse that keeps
-- indefinitely rather than one that spoils.
t.ui_act(surgeon, "toggle", string.format('{"field":"operation","option":"%s"}', pick))
t.run_ticks(23) -- the 1 s removal
assert(t.organ_damage(patient, "heart") == nil, "the heart socket is empty")
assert(not t.body(patient).conscious, "the heart is out and the patient is under")
assert(not t.body(patient).animate, "and dead of the missing heart, not of any wound")
-- The wound did NOT stop the heart there is no heart to stop: the latch
-- fires on the `dead` HEALTH line (content/bodies/human.luau), and this
-- patient's health never moved. So the donor heart will take.
local past = {}
for _, id in ipairs(t.body(patient).thresholds) do past[id] = true end
assert(past.undone and not past.dead, "dead of viability alone")
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
assert(t.body(patient).animate and t.body(patient).controllable,
    "ALIVE AGAIN: a living heart in the socket clears the viability line")

-- Close up. The bone states and the incision clear, and 40 of the saw's
-- 50 brute is mended on the way out.
step("cautery", 2.4, function()
    local s = t.parts(patient).chest.states
    return not has(s, "skin_open") and not has(s, "skin_cut")
end, "closed")
assert(t.body(patient).bleed_rate == 0, "and no longer bleeding")

print("heart: swapped on the table with 0 failures; dead between hearts, alive after")
