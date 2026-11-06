-- What a cadaver chamber does about ELECTRICITY, which is the whole of
-- this station's divergence from tg: `morgue.dm` declares a plain
-- `/obj/structure` with no `use_power` and no controller in the story,
-- so a tg morgue cools, lights and beeps whatever Engineering is doing.
-- Here it is a corded appliance, and a chamber somebody has unplugged
-- is a chamber that has stopped doing all three.
--
-- Four claims, in the order a crewman would meet them: an unwired
-- chamber is dark; a wired one with somebody alive in it beeps; a corpse
-- shows `morgue2` and the beeping stops; and a corpse shut in a live one
-- does not go off, while the same corpse in the open one does. The last
-- section is what a watch must give back: a revived body, the living beside
-- a corpse, and everything when the power goes.
--
-- `cadaver_chamber_test.luau` is the mechanism (the concealment, the push
-- from inside); this file is only the power.
local clock = require("@helpers/clock")

local function has(rows, wanted)
    for _, row in ipairs(rows) do
        if row == wanted then
            return true
        end
    end
    return false
end

-- Whether a chamber's hold is on this body, read on its brain.
local function preserved(body): boolean
    return has(assert(assert(t.sockets(body)).brain.conditions), "preserved")
end

-- Opens the chamber, walks `body` onto it, lies it down and shuts it.
local function shut_in(closer, body, chamber)
    t.click(closer, 2, 1, chamber)
    t.tick()
    t.move(body, "west")
    t.run_ticks(4)
    t.rest(body)
    t.run_ticks(2)
    t.click(closer, 2, 1, chamber)
    t.tick()
    assert(assert(t.structure_at(2, 1)).state == "closed", "it shuts on them")
end

-- ---- 1. NOTHING FEEDING THE CORD ------------------------------------
-- No plant, no controller, no socket. The chamber is identical in every
-- other respect, which is what makes the difference a fact about power.
t.world(
    [==[(
    name: "dark cadaver bench",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#######",
            ],
            items: [],
            structures: [(1, 1, "player_spawn", { "jobs": "medic" }), (3, 1, "player_spawn", { "jobs": "assistant" }), (2, 1, "cadaver_chamber")],
        ),
    ],
)]==],
    7
)

local WATCH_TICKS = clock.deadline_ticks(1.0) + 2

local dark_attendant = t.join("medic")
local dark_patient = t.join("assistant")
t.tick()

local dark = t.target_at(dark_attendant, 2, 1, "cadaver_chamber")
assert(assert(t.structure_at(2, 1)).sprite == "morgue1_s", "an unwired chamber wears its shut face")

-- ...and it goes on showing nothing with somebody shut inside it, even once
-- they stop. The sheet ships no dark state (morgue0..morgue3 are all lit), so
-- the unpowered face is the shut face and no art is invented for it.
t.sounds(dark_attendant)
shut_in(dark_attendant, dark_patient, dark)
t.run_ticks(WATCH_TICKS)
assert(
    not has(t.sounds(dark_attendant), "cadaver_alert"),
    "an unpowered chamber has nothing to beep with"
)
t.set_health(dark_patient, { brute = 400 })
t.run_ticks(WATCH_TICKS)
local dark_shut = assert(t.structure_at(2, 1))
assert(
    dark_shut.state == "closed" and dark_shut.sprite == "morgue1_s",
    "a dead readout reports nothing rather than reporting wrongly"
)
local dark_brain = assert(t.organ_damage(dark_patient, "brain"))
t.run_seconds(600)
assert(
    assert(t.organ_damage(dark_patient, "brain")) > dark_brain,
    "and an unpowered chamber preserves nothing"
)

-- ---- 2. WIRED: THE BODY LAMP AND THE BEEP ---------------------------
-- The plant, the controller and the socket behind the rank, two cells
-- of cord from the chamber (docs/POWER.md, "Outlets and cords").
t.world(
    [==[(
    name: "wired cadaver bench",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#Gao..#",
                "#######",
            ],
            items: [],
            structures: [(1, 1, "player_spawn", { "jobs": "medic" }), (3, 1, "player_spawn", { "jobs": "assistant" }), (4, 1, "player_spawn", { "jobs": "engineer" }), (2, 1, "cadaver_chamber"), (2, 2, "apc")],
            networks: [
                (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    7
)

local attendant = t.join("medic")
local patient = t.join("assistant")
local second = t.join("engineer")
t.tick()

local chamber = t.target_at(attendant, 2, 1, "cadaver_chamber")
assert(assert(t.structure_at(2, 1)).sprite == "morgue1_s", "an empty chamber shows no lamp, wired or not")

-- Somebody alive on the slab, and the door shut on them.
t.sounds(attendant)
shut_in(attendant, patient, chamber)
t.run_ticks(WATCH_TICKS)
assert(
    has(t.sounds(attendant), "cadaver_alert"),
    "the chamber says somebody has not stopped (morgue.dm:281-283)"
)

-- The minute survives the door, so a cycled door beeps no faster.
t.sounds(attendant)
t.click(attendant, 2, 1, chamber)
t.run_ticks(2)
assert(assert(t.structure_at(2, 1)).state == "open", "the door opens on them")
t.click(attendant, 2, 1, chamber)
t.run_ticks(WATCH_TICKS)
assert(assert(t.structure_at(2, 1)).state == "closed", "and shuts on them again")
assert(not has(t.sounds(attendant), "cadaver_alert"), "without restarting the minute")
t.run_seconds(60)
assert(has(t.sounds(attendant), "cadaver_alert"), "which still runs out")

-- The one thing that stops it: they do. Four hundred brute is past the
-- plan's dead line (content/bodies/human.luau), and the plan's own
-- threshold handler is what decides that; the next pass reads the corpse.
t.set_health(patient, { brute = 400 })
t.tick()
assert(not assert(t.body(patient)).animate, "the plan stopped them")
t.run_ticks(WATCH_TICKS)
local lit = assert(t.structure_at(2, 1))
assert(
    lit.state == "closed_bodies" and lit.sprite == "morgue2_s",
    "a corpse lights the plain body lamp"
)
t.sounds(attendant)
t.run_seconds(90)
assert(
    not has(t.sounds(attendant), "cadaver_alert"),
    "a corpse is not an emergency, so the beeping stops"
)

-- ---- 3. PRESERVATION ------------------------------------------------
-- tg keeps an internal gas mixture and cools it toward T0C-60 at 4°/s
-- while the tray is in, equalizing with the room while it is out
-- (morgue.dm:278-298). The pack holds a `heals = false` organ condition
-- instead (lib/closets/chamber_watch.luau), so the modeled thing is the
-- preservation and not the temperature, and tg's open/shut half is kept.
-- Measured on the BRAIN and not the heart: dying stops the heart by driving
-- it to `max_health` (content/bodies/human.luau), so a corpse's heart has no
-- room left to decay. The brain is the organ still on a clock, and a
-- defibrillator refuses one decayed to failure (content/items/surgery/
-- defib.luau), so this chamber preserves the window to bring its occupant back.
local held = t.organ_damage(patient, "brain")
assert(held ~= nil, "the corpse still has its brain in it")
t.run_seconds(600)
assert(t.organ_damage(patient, "brain") == held, "nothing shut in a live chamber goes off at all")

-- Open it and the same corpse is in the room again, slid out onto the tray's
-- tile. A click on a lit chamber steps the lamp back first.
t.click(attendant, 2, 1, chamber)
t.run_ticks(2)
assert(assert(t.structure_at(2, 1)).state == "open", "the lit chamber opens to a click")
local corpse_name = assert(t.bodies_at(2, 2)[1]).name
t.run_seconds(600)
local out = t.organ_damage(patient, "brain")
assert(assert(out) > held, "a corpse in an open chamber goes off like any other")

-- ...and shutting it stops it again, where it stopped.
t.click(attendant, 2, 1, chamber)
t.run_ticks(WATCH_TICKS)
assert(assert(t.structure_at(2, 1)).state == "closed_bodies", "it shuts on the corpse")
assert(#t.bodies_at(2, 1) == 0, "a lit chamber hides the corpse")
assert(t.target_at(attendant, 2, 1, "name:" .. corpse_name) == nil, "and leaves nothing to click")
local reshut = t.organ_damage(patient, "brain")
t.run_seconds(600)
assert(
    t.organ_damage(patient, "brain") == reshut,
    "and shutting it holds the corpse exactly where it was"
)

-- ---- 4. WHAT A WATCH MUST GIVE BACK ---------------------------------
-- A door cycled inside one pass hands the chamber to a new task. Two tasks
-- would share one record and act alike, so what a spec can see is that the
-- lamp and the hold still work.
t.click(attendant, 2, 1, chamber)
t.run_ticks(2)
assert(assert(t.structure_at(2, 1)).state == "open", "the door cycles")
t.click(attendant, 2, 1, chamber)
t.run_ticks(WATCH_TICKS)
assert(assert(t.structure_at(2, 1)).state == "closed_bodies", "the new watch lights the lamp")
assert(preserved(patient), "and holds the corpse")

-- A corpse revived inside: the next pass reads somebody alive, so the lamp
-- gives the exact `closed` back, the hold lets go and the alarm starts again.
t.sounds(attendant)
t.set_health(patient, { brute = 0, burn = 0, oxy = 0, tox = 0 })
t.set_organ_damage(patient, "heart", 0)
t.run_seconds(3)
assert(assert(t.body(patient)).animate, "the patient is back, inside the chamber")
local revived = assert(t.structure_at(2, 1))
assert(revived.state == "closed" and revived.sprite == "morgue1_s", "the lamp goes out for them")
assert(not preserved(patient), "the hold lets go of them")
assert(has(t.sounds(attendant), "cadaver_alert"), "and the alarm is back")

-- Somebody alive shut in WITH a corpse: the living keep the exact `closed`
-- their push and air need, and only the corpse is held.
t.click(attendant, 2, 1, chamber)
t.run_ticks(2)
t.rest(patient)
t.run_ticks(2)
for _ = 1, 2 do
    t.move(second, "west")
    t.run_ticks(8)
end
assert(t.pos(second) == 2, "the second body stands on the slab: " .. t.pos(second))
t.set_health(second, { burn = 200 })
t.run_ticks(2)
assert(not assert(t.body(second)).animate, "and dies there")
t.click(attendant, 2, 1, chamber)
t.run_ticks(WATCH_TICKS)
local shared = assert(t.structure_at(2, 1))
assert(shared.state == "closed" and shared.sprite == "morgue1_s", "the living keep it exactly shut")
assert(preserved(second), "the corpse beside them is held")
assert(not preserved(patient), "and they are not")

-- A power cut under a lit, holding chamber drops the lamp and the hold.
t.set_health(patient, { burn = 200 })
t.run_ticks(WATCH_TICKS)
assert(assert(t.structure_at(2, 1)).state == "closed_bodies", "two corpses light it")
assert(preserved(patient) and preserved(second), "and both are held")
t.outage()
t.run_seconds(4)
local unlit = assert(t.structure_at(2, 1))
assert(unlit.state == "closed" and unlit.sprite == "morgue1_s", "the cut drops the lamp")
assert(not preserved(patient) and not preserved(second), "and lets go of both")
local cut = assert(t.organ_damage(second, "brain"))
t.run_seconds(600)
assert(assert(t.organ_damage(second, "brain")) > cut, "so they go off again")
assert(#t.script_errors() == 0, "the watch runs cleanly")
