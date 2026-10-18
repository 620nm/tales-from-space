local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

-- BLOOD HARMONY: the pack's half of a body's blood
-- (`content/lib/blood_harmony.luau`, docs/BIOLOGY.md).
--
-- The engine holds blood as moles of the `blood` substance in the chest's
-- bloodstream and only ever bleeds it. Topping it up, trimming it back
-- and charging air for the missing share are the plan's `mob.life`
-- handler. Blood is moved with real syringes, because a needle is how a
-- crewman takes blood out of a body or puts it back:
--
--   1. Under target: a draw leaves the donor short, and the short
--      blood grows back at tg's regeneration rate (0.25 u/s = 0.00625
--      mol/s at a full heart) without ever passing the plan's normal.
--   2. Over target: that blood pushed into the patient, who was
--      already full, is drawn back out to the normal, and a dose
--      riding in the same bloodstream is left alone.
--   3. A conscious body that bled pays oxygen only up to the share of
--      blood it is missing. The unconscious-at-50% branch of that rule
--      needs half a body of blood gone, which no spec lever reaches.
--   4. A stopped body hears no `mob.life`: nothing restores it.
local NORMAL = 13.75 -- 560 u x 0.025 mol/u, content/items/anatomy/human_chest.luau
local REGEN_PER_S = 0.25 * 0.025 -- BLOOD_REGEN_FACTOR, mobs.dm:28

t.world(
    [==[(
    name: "transfusion",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "########", "#......#", "########" ],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (3, 1, "player_spawn", { "jobs": "engineer" }),
            ],
            items: [
                (2, 1, "syringe"),
                (2, 1, "beaker.libital"),
            ],
        ),
    ],
)]==],
    0
)

local medic = t.join("medic")
local patient = t.join("assistant")
local donor = t.join("engineer")
t.run_ticks(3)

local function blood_of(p: number): number
    return ui_controls.number(assert(t.body(p)).blood)
end
local function near(got: number, want: number, slack: number, what: string)
    assert(math.abs(got - want) <= slack, ("%s: wanted %g, got %g"):format(what, want, got))
end
local function said(who: number, needle: string): boolean
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end
local function take(p: number, x: number, y: number, id: string)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.tick()
    end
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_ticks(2)
end

for _, who in ipairs({ medic, patient, donor }) do
    near(blood_of(who), NORMAL, 1e-9, "everyone starts at the plan normal")
end
assert(#t.script_errors() == 0, "the harmony handler runs clean")

-- ---------------------------------------------------------------
-- A DOSE FIRST, SO IT IS THERE WHEN THE BLOOD IS IN EXCESS.
-- The medic draws a stroke from the libital beaker and pushes it into
-- the patient's bloodstream.
-- ---------------------------------------------------------------
take(medic, 2, 1, "syringe")
assert(t.hands(medic).held == "syringe", "the syringe is in hand")
t.click(medic, 2, 1, assert(t.target_at(medic, 2, 1, "beaker.libital")))
t.run_ticks(2)
assert(said(medic, "You fill the syringe."), "the plunger comes back on the beaker")
t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to inject"), "turned round to inject")
t.click(medic, 1, 1, t.body_target(medic, patient))
t.run_ticks(clock.deadline_ticks(3) + 2)
local dosed = t.blood(patient).libital or 0
assert(dosed > 0, "the dose is in the patient's blood")
near(blood_of(patient), NORMAL, 1e-9, "and the blood beside it is untouched")

-- ---------------------------------------------------------------
-- UNDER TARGET. Draw from the donor (a needle on someone else is
-- three seconds of standing still), then watch the blood come back.
-- ---------------------------------------------------------------
t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to draw"), "turned back to draw")
t.click(medic, 3, 1, t.body_target(medic, donor))
t.run_ticks(clock.deadline_ticks(3) + 2)
local short = NORMAL - blood_of(donor)
assert(short > 0.01, ("the draw left the donor short, by %g"):format(short))

local circulation = assert(t.capacity(donor, "blood"))
local at_draw = blood_of(donor)
t.run_seconds(4)
local grown = blood_of(donor) - at_draw
assert(grown > 0, "short blood grows")
-- Two passes of two seconds each land in the window; a pass in flight
-- either side makes it one more or one fewer.
near(
    grown,
    REGEN_PER_S * circulation * 4,
    REGEN_PER_S * circulation * 2.1,
    "at tg's regeneration rate scaled by the heart"
)
-- ---------------------------------------------------------------
-- OVER TARGET. The donor's blood goes into the patient, who was full.
-- The excess is drawn back out to the normal, and only blood is: the
-- dose beside it is still there.
-- ---------------------------------------------------------------
t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to inject"), "turned round to inject")
t.click(medic, 1, 1, t.body_target(medic, patient))
-- Watch tick by tick: the pass that trims may run the tick after the
-- needle lands, and the excess has to be seen to have been there.
local peak = 0
for _ = 1, clock.deadline_ticks(3) + clock.deadline_ticks(3) do
    t.tick()
    peak = math.max(peak, blood_of(patient))
end
assert(peak > NORMAL + 1e-3, ("the transfusion put the patient over the line, peak %g"):format(peak))
near(blood_of(patient), NORMAL, 1e-9, "the excess blood is trimmed to the normal")
assert((t.blood(patient).libital or 0) > 0, "and the dose is still beside it, untouched by the trim")
assert(blood_of(patient) <= NORMAL + 1e-9, "never above the normal")

-- The donor, meanwhile, finishes growing back and stops on the line.
for _ = 1, 40 do
    t.run_seconds(1)
    assert(blood_of(donor) <= NORMAL + 1e-9, "regeneration never passes the normal")
end
near(blood_of(donor), NORMAL, 1e-9, "and it stops exactly on the normal")

-- ---------------------------------------------------------------
-- A STOPPED BODY HEARS NO `mob.life`. Kill the donor, draw from the
-- corpse, and the blood it is short stays short.
-- ---------------------------------------------------------------
assert(t.staff_kill(donor), "the donor dies")
t.run_ticks(4)
assert(not assert(t.body(donor)).animate, "and stops")
t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to draw"), "turned back to draw")
t.click(medic, 3, 1, t.body_target(medic, donor))
t.run_ticks(clock.deadline_ticks(3) + 2)
local stopped_at = blood_of(donor)
assert(stopped_at < NORMAL - 0.01, ("the corpse is short, at %g"):format(stopped_at))
t.run_seconds(30)
near(blood_of(donor), stopped_at, 1e-9, "and nothing restores it")

-- ---------------------------------------------------------------
-- THE MISSING-BLOOD OXYGEN COST (blood.dm:253-262). A swung toolbox
-- opens a bleeder, and the bleeder outpaces the regeneration for as
-- long as it stays open. A conscious body pays air only up to the share
-- of blood it is missing, so its oxygen damage follows the missing
-- percentage and never runs away from it.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "brawl",
    legend: { ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    levels: [
        (
            rows: [ "#####", "#...#", "#####" ],
            structures: [
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (2, 1, "player_spawn", { "jobs": "medic" }),
            ],
            items: [ (1, 1, "toolbox") ],
        ),
    ],
)]==],
    0
)
local attacker = t.join("assistant")
local victim = t.join("medic")
t.run_ticks(3)
t.click(attacker, 1, 1, t.target_at(attacker, 1, 1, "toolbox"))
t.run_ticks(2)
-- One swing a zone: every part wounded is a bleeder of its own, so six
-- of them lose blood faster than the heart makes it for a while.
for _, zone in ipairs({ "head", "chest", "l_arm", "r_arm", "l_leg", "r_leg" }) do
    assert(t.set_zone(attacker, zone), "the attacker aims at " .. zone)
    t.click(attacker, 2, 1, t.body_target(attacker, victim))
    t.run_seconds(1.5)
end
assert((assert(t.body(victim)).bleed_rate or 0) > 0, "the swings opened bleeders")
local oxy_at_start = ui_controls.number(t.health(victim).oxy)
local peak_missing = 0
local trace = {}
for _ = 1, 60 do
    t.run_seconds(1)
    local row = assert(t.body(victim))
    local share = (1 - assert(row.blood) / NORMAL) * 100
    peak_missing = math.max(peak_missing, share)
    trace[#trace + 1] = string.format("%.1f", share)
end
local oxy = ui_controls.number(t.health(victim).oxy)
assert(
    peak_missing > 1,
    ("the open wounds cost blood, peak missing %g%% (%s)"):format(peak_missing, table.concat(trace, " "))
)
assert(oxy > oxy_at_start, ("and the missing blood costs air: oxy %g"):format(oxy))
assert(
    oxy <= peak_missing + 0.75,
    ("but only up to the missing share: oxy %g, peak missing %g%%"):format(oxy, peak_missing)
)
assert(assert(t.body(victim)).conscious, "a body this healthy stays awake")
assert(#t.script_errors() == 0, "the harmony handler runs clean")
