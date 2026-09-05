-- BREATHING IS A PUMP, and the pump is an organ you can take out.
--
-- The lungs are a driven vessel (content/items/organ_lungs.luau): six
-- litres of shell, a stroke that sweeps 1.99 of them -- tg's
-- BREATH_VOLUME, atmos_mob_interaction.dm:10 -- and one conversion, all
-- of the oxygen the stroke drew in for the same number of moles of
-- carbon dioxide, which is tg's `breathe_gas_volume(breath, oxygen,
-- carbon_dioxide)` with no volume argument (_lungs.dm:255,712-718).
--
-- What that buys, and what this spec weighs:
--
--   * a sealed room with a crewman in it GOES BAD. Oxygen falls,
--     carbon dioxide rises, and the two move together because one
--     became the other;
--   * the waste is EXHALED A STROKE LATE, because the shell is bigger
--     than the stroke. The residual is where it waits, and it is
--     readable: lungs are a vessel like any other, so `t.vessel` shows
--     what is in them;
--   * a corpse does none of it. The heart is this pack's boolean life
--     state (heart_life_test.luau) and the breath pass never starts on
--     a body that is not animate -- so a dead crewman neither takes
--     air out of a room nor puts anything back;
--   * VACUUM cycles nothing: expansion draws the share of the tile the
--     stroke swept, and a share of nothing is nothing;
--   * NO LUNGS is suffocation with a beating heart. Take them out on
--     the table and the patient stays alive -- the heart is what life
--     is -- and starts drowning where they lie.
--
-- The room is one tile and sealed, so nothing that leaves a pair of
-- lungs can wander off before it is weighed.

local ARENA = [==[(
    name: "closet",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "###", "#.#", "###" ],
    spawns: [(1, 1)],
)]==]

local BREATH = 160 -- one breath cycle, 8 s at 20 Hz

local function gas(key)
    local held = t.room_gas(1, 1)
    return (held and held[key]) or 0.0
end

-- What is standing inside somebody, which for a pair of lungs is a real
-- reading and not a figure of speech.
local function inside(who, key)
    local seated = t.sockets(who).lungs.seated
    if not seated then
        return 0.0
    end
    local held = t.vessel(seated)
    local rows = held and held.contents[key]
    return (rows and rows.gas) or 0.0
end

-- =====================================================================
-- A SEALED ROOM WITH SOMEBODY IN IT GOES BAD.
-- =====================================================================
t.world(ARENA, 0)
local crew = t.join()
t.run_ticks(3)

assert(t.sockets(crew).lungs.ok, "the crewman arrives with lungs")
assert(t.body(crew).animate, "and a beating heart")
local o2_0, co2_0 = gas("o2"), gas("co2")
assert(o2_0 > 0.0, "the closet is commissioned with air in it")

-- One stroke. It fills the lungs and exhales the residual they arrived
-- with, which is nothing: the room has lost oxygen and gained no waste.
t.run_ticks(BREATH + 4)
assert(gas("o2") < o2_0, "the first stroke took air out of the room")
assert(gas("co2") - co2_0 < 1e-9,
    "and put none back yet: the waste is still inside")
assert(inside(crew, "co2") > 0.0,
    "...which is exactly where it is: " .. inside(crew, "co2") .. " mol in the lungs")
assert(inside(crew, "o2") < 1e-9,
    "and the oxygen the stroke drew is gone, every mole of it converted")

-- Ten more. Now the room is visibly worse: the crewman is a slow leak
-- of carbon dioxide and a slow drain of oxygen, and the two are the
-- same transaction.
t.run_ticks(BREATH * 10)
local burned = o2_0 - gas("o2")
local made = gas("co2") - co2_0
assert(made > 0.0, "the room is filling with waste: " .. made .. " mol")
assert(burned > made,
    "and losing more air than it gained, because a lungful is still held: "
        .. burned .. " vs " .. made)
assert(burned - made < 0.30,
    "the gap is one crewman's worth of lungs and no more: " .. (burned - made))

-- ONE TRANSACTION, weighed. Every mole of oxygen that left the room is
-- either standing in a pair of lungs or has become a mole of carbon
-- dioxide -- there is no third place for it to be.
local waste = made + inside(crew, "co2")
local air = inside(crew, "o2")
assert(math.abs((waste + air) - burned) < 1e-6,
    "the books close: " .. (waste + air) .. " vs " .. burned)

-- =====================================================================
-- A CORPSE NEITHER BREATHES NOR CONVERTS.
-- =====================================================================
t.set_health(crew, { brute = 200 })
t.run_ticks(3)
assert(t.body(crew).animate == false, "200 brute is past the dead line")
assert(t.sockets(crew).heart.failing, "and it stopped the heart")

local o2_dead, co2_dead = gas("o2"), gas("co2")
t.run_ticks(BREATH * 4)
assert(math.abs(gas("o2") - o2_dead) < 1e-9,
    "a corpse takes nothing out of the room: " .. gas("o2") .. " vs " .. o2_dead)
assert(math.abs(gas("co2") - co2_dead) < 1e-9,
    "and puts nothing back into it: " .. gas("co2") .. " vs " .. co2_dead)
assert(inside(crew, "co2") > 0.0,
    "the last breath is still in there, unexhaled and unconverted")

-- =====================================================================
-- VACUUM CYCLES NOTHING.
-- =====================================================================
local VOID = [==[(
    name: "the void",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "###", "#. ", "###" ],
    spawns: [(1, 1)],
)]==]
t.world(VOID, 0)
local spacer = t.join()
t.run_ticks(3)
-- The tile is open to space; give it time to finish emptying.
t.run_seconds(20)
assert(gas("o2") < 1e-6, "the tile is vacuum: " .. gas("o2") .. " mol of air")

-- Every stroke sheds the swept share into the vacuum and draws nothing
-- in behind it, so the lungs empty and stay empty.
t.run_ticks(BREATH * 12)
assert(inside(spacer, "o2") < 1e-9 and inside(spacer, "co2") < 1e-9,
    "a pair of lungs cycling vacuum is empty")
assert(t.health(spacer).oxy > 0, "and the crewman is suffocating in it")

-- =====================================================================
-- NO LUNGS, BEATING HEART: alive, and drowning.
-- =====================================================================
local THEATRE = [==[(
    name: "theatre",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    structures: [(2, 1, "optable")],
    items: [
        (1, 1, "scalpel"), (1, 1, "retractor"), (1, 1, "hemostat"),
        (1, 1, "circular_saw"), (1, 1, "cautery"),
    ],
)]==]

t.world(THEATRE, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)
t.rest(patient, true)
t.unequip(patient, "uniform")
t.run_ticks(2)

local PX, PY = 2, 1
local pid = t.body_id(patient)

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

local function step(tool, secs, state)
    hold(tool)
    t.click(surgeon, PX, PY, pid)
    t.run_ticks(math.ceil(secs * 20) + 3)
    assert(t.parts(patient).chest.states[state] == true, "the chest is " .. state)
end

step("scalpel", 1.6, "skin_cut")
step("retractor", 2.4, "skin_open")
step("hemostat", 2.4, "vessels_clamped")
step("circular_saw", 5.4, "bone_sawed")
step("scalpel", 2.4, "organs_cut")

hold("hemostat")
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
local win = t.ui(surgeon)
local pick
for _, toggle in ipairs(win.toggles) do
    if face(toggle.label):find("lungs", 1, true) then pick = toggle.option end
end
assert(pick, "the window offers the lungs")
t.ui_act(surgeon, "toggle", string.format('{"field":"operation","option":"%s"}', pick))
t.run_ticks(23)

assert(t.sockets(patient).lungs.seated == false, "the lungs are out")
assert(t.body(patient).animate == true,
    "and the patient is ALIVE, because in this pack life is the heart")
assert(t.capacity(patient, "breathing") == 0, "but breathes nothing at all")

-- The room is perfectly good air; the only thing wrong is the hole.
local hurt_0 = t.health(patient).oxy
t.run_ticks(BREATH * 3)
assert(t.health(patient).oxy > hurt_0,
    "a body with no lungs drowns in breathable air: "
        .. hurt_0 .. " -> " .. t.health(patient).oxy)
assert(t.body(patient).animate == true, "still alive while it happens")
