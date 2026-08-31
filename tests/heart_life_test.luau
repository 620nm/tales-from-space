-- LIFE IS THE HEART.
--
-- This pack's answer to "is this body alive" is one organ: the heart is
-- `vital` (content/items/organ_heart.luau), so the engine's `viability`
-- port reads 0 while it is missing or FAILING, the plan's `undone`
-- threshold reads that port, and the plan's hook turns `undone` into
-- `animate = false` (content/bodies/human.luau).
--
-- The latch is the other half: crossing the plan's `dead` line calls
-- `sim.fail_organ` on the heart. That is what makes death stick. Before
-- it, death was a line the numbers sat on one side of, and a hemostat
-- to a corpse's bruises walked it back over and stood it up.
--
-- So this spec is four assertions in one sentence: a corpse's heart is
-- stopped, healing its PARTS does not restart it, and the two things
-- that do are a new heart and a defibrillator.
--
-- tg reaches the same place with two mechanisms this pack does not
-- need: a latched `stat` and a 0.2 dead-healing multiplier
-- (operation_healing.dm:190). Neither is ported, because neither has
-- anything to do once life is an organ rather than a sum of damage.

-- The chamber is here for one assertion at the very bottom -- a patient
-- shut in a drawer mid-charge -- and it is unpowered on purpose: what
-- this spec needs is a drawer that opens and shuts, not a lamp.
local ARENA = [==[(
    name: "theatre",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "######", "#....#", "#....#", "######" ],
    spawns: [(1, 1), (2, 1), (3, 1)],
    items: [ (1, 1, "hemostat"), (1, 1, "defib") ],
    structures: [(2, 2, "cadaver_chamber", { "dir": "north" })],
)]==]

local function said(who, needle)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end

-- =====================================================================
-- Dying stops the heart, and healing the parts does not restart it.
-- =====================================================================
t.world(ARENA, 0)
local medic = t.join()
local patient = t.join()
local attendant = t.join()   -- somebody with a free hand for the drawer
t.run_ticks(3)
local pid = t.body_id(patient)

assert(t.body(patient).animate == true, "they start out alive")
assert(t.organ_damage(patient, "heart") == 0, "with an undamaged heart")

-- 200 brute is what the cadaver chamber's own stock row deals
-- (content/structures/cadaver_chamber.luau), i.e. how this game makes a
-- corpse.
t.set_health(patient, { brute = 200 })
t.run_ticks(2)
assert(t.body(patient).animate == false, "200 brute is past the dead line")
assert(t.body(patient).label == "Dead", "and the plan says the word")
assert(t.organ_damage(patient, "heart") == 100,
    "...and the crossing STOPPED THE HEART: " .. t.organ_damage(patient, "heart"))
assert(t.capacity(patient, "blood") == 0, "a failing heart circulates nothing")

-- Now heal every part back to nothing. Under the old model this alone
-- brought them back; now it clears one line and leaves the other.
t.set_health(patient, { brute = 0, burn = 0, oxy = 0, tox = 0 })
t.run_ticks(2)
assert(t.parts(patient).chest.brute == 0, "the parts are whole again")
assert(t.body(patient).animate == false,
    "PARTS HEALED, STILL DEAD: the dead line cleared and the heart did not")
assert(t.organ_damage(patient, "heart") == 100, "the heart is where the death left it")

-- =====================================================================
-- REVIVAL A: a defibrillator restarts the heart.
-- =====================================================================
t.click(medic, 1, 1, t.target_at(1, 1, "defib"))
t.run_ticks(2)
assert(t.hands(medic).held == "defib", "the defibrillator is in hand")

t.click(medic, 2, 1, pid)
t.run_ticks(2)
assert(said(medic, "charge the defibrillator"), "it charges")
-- tg's five seconds end to end (defib.dm:564-568), and the shock lands
-- at the end of it and not before.
assert(t.body(patient).animate == false, "still dead half way through")
t.run_ticks(110)
assert(said(medic, "heart restarts"), "the shock landed")
assert(t.organ_damage(patient, "heart") < 100, "the heart is out of failure")
assert(t.body(patient).animate == true, "AND THE BODY IS ALIVE AGAIN")
assert(t.capacity(patient, "blood") > 0, "circulating")

-- =====================================================================
-- The refusals, which are tg's `can_defib` in this pack's words
-- (code/modules/mob/living/carbon/carbon.dm:784-835).
-- =====================================================================
-- The living: tg refuses them outright.
t.click(medic, 2, 1, pid)
t.run_ticks(3)
assert(said(medic, "heart is beating"), "you do not shock the living")

-- Too hurt to shock through: tg compares brute and burn against
-- MAX_REVIVE_BRUTE_DAMAGE 180 (code/__DEFINES/mobs.dm:554-555); here the
-- plan's own `dead` line is the same claim, and it is still crossed.
t.set_health(patient, { brute = 200 })
t.run_ticks(2)
assert(t.body(patient).animate == false, "dead again")
t.click(medic, 2, 1, pid)
t.run_ticks(3)
assert(said(medic, "too severe"), "treat them before you shock them")
assert(t.organ_damage(patient, "heart") == 100, "and nothing was restarted")

-- A brain too far gone: DEFIB_FAIL_FAILING_BRAIN (carbon.dm:830-831).
-- This is the revival WINDOW, and it is a clock the map sets — a brain
-- in a corpse decays (content/items/organ_brain.luau), and a drawer's
-- `preserves` multiplies that decay, so a body in the cadaver chamber
-- has no clock running at all. Half an hour of decay is not something a
-- spec can wait out, so `t.set_organ_damage` puts the brain where the
-- decay would have.
t.set_health(patient, { brute = 0, burn = 0, oxy = 0, tox = 0 })
t.run_ticks(2)
t.set_organ_damage(patient, "brain", 200)
t.run_ticks(2)
assert(t.organ_damage(patient, "brain") == 200, "the brain has decayed to failure")
t.click(medic, 2, 1, pid)
t.run_ticks(3)
assert(said(medic, "too far gone"), "there is nothing to shock back")
assert(t.body(patient).animate == false, "and they stay dead")

-- =====================================================================
-- The charge is a TWO-PARTY wait. A body effect is applied without a
-- reach test, so without `options.subject` on the do_after
-- (content/items/defib.luau) a medic could start the charge, have the
-- patient dragged into the next room or shut in a drawer, and still
-- land the shock at the end of it.
-- =====================================================================
t.set_organ_damage(patient, "brain", 0)
t.run_ticks(2)
assert(t.body(patient).animate == false, "a fresh corpse to work on")
_ = t.messages(medic)

-- ---- the medic walks off mid-charge ----------------------------------
-- The USER half, which the ordinary single-party guard already watched.
-- Here for the contrast with the half below it: a corpse cannot walk
-- away by itself, so the patient half needs a guard of its own or it has
-- no way of ending at all.
t.click(medic, 2, 1, pid)
t.run_ticks(3)
assert(said(medic, "charge the defibrillator"), "the charge started")
for _ = 1, 3 do
    t.move(medic, "east")
    t.run_ticks(10)
end
assert(t.pos(medic) == 4, "two tiles clear of the patient: " .. t.pos(medic))
t.run_ticks(120)
assert(not said(medic, "heart restarts"), "a medic who walked off shocked nobody")
assert(t.body(patient).animate == false, "still dead")
for _ = 1, 3 do
    t.move(medic, "west")
    t.run_ticks(10)
end
assert(t.pos(medic) == 1, "back beside the patient")

-- ---- the patient is taken away mid-charge ----------------------------
-- A body with no tile is a body that is NOWHERE, and the guard ends the
-- wait on the same clause that catches one carried off. The drawer's
-- slab comes out onto the patient's own tile, so shutting it takes them
-- with it (`sim/drawers.rs`: bodies are not dense and are exactly what a
-- close is for).
local chamber = t.target_at(2, 2, "cadaver_chamber")
t.click(attendant, 2, 2, chamber)
t.run_ticks(2)
assert(t.structure_at(2, 1) ~= nil, "the slab is out, under the patient")
_ = t.messages(medic)
t.click(medic, 2, 1, pid)
t.run_ticks(3)
assert(said(medic, "charge the defibrillator"), "the charge started again")
t.click(attendant, 2, 2, chamber)
t.run_ticks(2)
assert(t.structure_at(2, 1) == nil, "the slab went back in")
t.run_ticks(140)
assert(not said(medic, "heart restarts"), "a stowed patient is not shocked")
assert(t.body(patient).animate == false, "still dead in the drawer")

print("heart life: dying stops the heart, healing does not restart it, a defibrillator does")
