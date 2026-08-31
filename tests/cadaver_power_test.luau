-- What a cadaver chamber does about ELECTRICITY, which is the whole of
-- this station's divergence from tg: `morgue.dm` declares a plain
-- `/obj/structure` with no `use_power` and no controller in the story,
-- so a tg morgue cools, lights and beeps whatever Engineering is doing.
-- Here it is a corded appliance, and a chamber somebody has unplugged
-- is a chamber that has stopped doing all three.
--
-- Four claims, in the order a crewman would meet them: an unwired
-- chamber is dark; a wired one with somebody alive in it shows the
-- `morgue4` lamp and beeps; a corpse shows `morgue2` and the beeping
-- stops; and a corpse shut in a live one does not go off, while the
-- same corpse on the open slab does.
--
-- `cadaver_chamber_test.luau` is the mechanism (the tray, the
-- concealment, the push from inside); this file is only the power.

local function has(rows, wanted)
    for _, row in ipairs(rows) do
        if row == wanted then return true end
    end
    return false
end

-- ---- 1. NOTHING FEEDING THE CORD ------------------------------------
-- No plant, no controller, no socket. The chamber is identical in every
-- other respect, which is what makes the difference a fact about power.
t.world([==[(
    name: "dark cadaver bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1), (3, 1)],
    items: [],
    structures: [(2, 1, "cadaver_chamber", { "dir": "east" })],
)]==], 7)

local dark_attendant = t.join()
local dark_patient = t.join()
t.tick()

local dark = t.target_at(2, 1, "cadaver_chamber")
assert(#t.structure_at(2, 1).overlays == 0,
    "an unwired chamber shows no lamp at all")

-- ...and it goes on showing nothing with somebody shut inside it. The
-- sheet ships no dark state (morgue0..morgue4 are all lit), so the
-- unpowered face is the shut face with nothing over it and no art is
-- invented for it.
t.click(dark_attendant, 2, 1, dark)
t.tick()
t.rest(dark_patient)
t.click(dark_attendant, 2, 1, dark)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "it shuts on them")
assert(#t.structure_at(2, 1).overlays == 0,
    "a dead readout reports nothing rather than reporting wrongly")
assert(not has(t.sounds(dark_attendant), "cadaver_alert"),
    "and an unpowered chamber has nothing to beep with")

-- ---- 2. WIRED: THE LIVING LAMP AND THE BEEP -------------------------
-- The plant, the controller and the socket behind the rank, two cells
-- of cord from the chamber (docs/POWER.md, "Outlets and cords").
t.world([==[(
    name: "wired cadaver bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######",
        "#.....#",
        "#Gao..#",
        "#######",
    ],
    spawns: [(1, 1), (3, 1)],
    items: [],
    structures: [(2, 1, "cadaver_chamber", { "dir": "east" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 7)

local attendant = t.join()
local patient = t.join()
t.tick()

local chamber = t.target_at(2, 1, "cadaver_chamber")
assert(#t.structure_at(2, 1).overlays == 0,
    "an empty chamber names no lamp of its own, wired or not")

-- Somebody alive on the slab, and the door shut on them.
t.click(attendant, 2, 1, chamber)
t.tick()
t.rest(patient)
_ = t.sounds(attendant)
t.click(attendant, 2, 1, chamber)
t.tick()
assert(t.structure_at(2, 1).overlays[1] == "morgue4_e",
    "somebody who has not stopped lights tg's revivable lamp")
assert(has(t.sounds(attendant), "cadaver_alert"),
    "and the chamber says so out loud (morgue.dm:274-276)")

-- The one thing that stops it: they do. Four hundred brute is past the
-- plan's dead line (content/bodies/human.luau), and the plan's own
-- threshold hook is what decides that -- the engine only applies the
-- number and repaints the drawer around the body.
t.set_health(patient, { brute = 400 })
t.tick()
assert(not t.body(patient).animate, "the plan stopped them")
assert(t.structure_at(2, 1).overlays[1] == "morgue2_e",
    "a corpse drops the chamber back to the plain body lamp")
_ = t.sounds(attendant)
t.run_seconds(90)
assert(not has(t.sounds(attendant), "cadaver_alert"),
    "a corpse is not an emergency, so the beeping stops")

-- ---- 3. PRESERVATION ------------------------------------------------
-- tg keeps an internal gas mixture and cools it toward T0C-60 at 4°/s
-- while the tray is in, equalizing with the room while it is out
-- (morgue.dm:249-291). The chamber declares `preserves = 0.0` instead,
-- so the modelled thing is the preservation and not the temperature --
-- but tg's open/shut half is kept exactly.
local held = t.organ_damage(patient, "heart")
assert(held ~= nil, "the corpse still has its heart in it")
t.run_seconds(600)
assert(t.organ_damage(patient, "heart") == held,
    "nothing shut in a live chamber goes off at all")

-- Roll the slab out and the same corpse is in the room again.
t.click(attendant, 2, 1, chamber)
t.tick()
t.run_seconds(600)
local out = t.organ_damage(patient, "heart")
assert(out > held, "a corpse on an open slab goes off like any other")

-- ...and shutting it stops it again, where it stopped.
t.click(attendant, 2, 1, chamber)
t.tick()
t.run_seconds(600)
assert(t.organ_damage(patient, "heart") == out,
    "and shutting it holds the corpse exactly where it was")
