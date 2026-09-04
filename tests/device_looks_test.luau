-- The pictures a WORKED machine wears once it has settled.
--
-- atmos_anim_test.luau owns the moving half -- the wheel turning under
-- your hand, the running pump's loop -- and meter_test.luau owns the
-- needle. What is left, and what nothing asserted until now, is the
-- resting picture of a machine in each position it can be left in, and
-- the rule that decides WHICH one it wears.
--
-- That rule is one line of tg and it is not "the switch": a pump is
-- drawn by `on && is_operational` (pump.dm:55), the same condition it
-- opens `process_atmos` with, so a machine that has lost its APC goes
-- dark on the deck rather than lying about running. The engine asks it
-- once, in `PipeDevice::working`, with `position()` on top
-- (sim/atmos_machines/mod.rs) -- which is why the last scenario here
-- takes a machine's picture away without touching its switch.
--
-- And then a second question the engine asks for three of these
-- machines: NOT "is it switched on" but "did the last atmos pass see it
-- do anything". A mixer with a dry intake, a filter with both outlets
-- full and a scrubber whose waste main nobody plumbed are all switched
-- on, fed, and moving nothing -- and all three used to wear a running
-- body, one of them a four-frame loop. Every "it went dark without
-- anybody touching the switch" below is that rule, and every one of
-- them checks the panel afterwards to prove the switch really did not
-- move (docs/ATMOS.md SS6, SS8).
--
-- Timing note: the pass that judges a machine runs at the atmos cadence
-- rather than every tick, so a picture derived from WORK is asserted
-- after a full second and never after two ticks.
--
-- Every sprite name below comes from a TfS content file
-- (`structures/air_scrubber.luau`, `filter.luau`, `mixer.luau`)
-- and the engine has never heard of any of them.

local function readout(p, label)
    for _, r in ipairs(t.ui(p).readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

local function toggle(p, field)
    for _, sw in ipairs(t.ui(p).toggles) do
        if sw.field == field then
            return sw
        end
    end
    return nil
end

-- ---------------------------------------------------------------
-- A SCRUBBER HAS THREE PICTURES, AND THE THIRD ONE IS A WARNING.
--
-- Every other machine in the kit is drawn off or on. A scrubber running
-- the wrong way round is emptying the room you are standing in, and tg
-- draws that with art of its own (`scrub_purge`, vent_scrubber.dm:142)
-- rather than leave an engineer to open the panel and find out. The
-- waste main runs out under the west wall; a unary component's single
-- mouth points OPPOSITE its facing (an `Axis` link's `NODE_BACK`,
-- sim/atmos_machines/mod.rs), so one drawing from a west main wears the
-- east picture.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a scrubber to watch",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#....#",
        "#..ag#",
        "######",
    ],
    spawns: [(3, 2)],
    pipes: [(0, 1, 2), (1, 1, 2)],
    structures: [(2, 1, "air_scrubber")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

local off = t.structure_at(2, 1)
assert(off.id == "air_scrubber", "the map bolted one to the deck")
assert(off.state == "off", "and tg's ships off")
assert(off.sprite == "scrubber_off_e", "dark, and aimed: " .. tostring(off.sprite))

t.click(p, 2, 1, t.target_at(2, 1, "air_scrubber"))
t.tick()
assert(t.ui(p), "a scrubber wears a panel")

-- ---- the emergency dials do nothing to a machine that is off ----
--
-- The sharpest thing `position()` says: it asks `working()` FIRST, so a
-- scrubber set up to empty the room while switched off has no running
-- posture to show and stays exactly as dark as it was. Setting a
-- machine up before you start it must not paint a purge warning on an
-- occupied room.
t.ui_act(p, "toggle", '{"field":"roster"}')
t.run_ticks(2)
local armed = t.structure_at(2, 1)
assert(toggle(p, "roster").on == true, "the dial moved")
assert(armed.state == "off", "and the machine did not: " .. tostring(armed.state))
assert(armed.sprite == "scrubber_off_e", "nor its picture: " .. tostring(armed.sprite))

t.ui_act(p, "toggle", '{"field":"roster"}')
t.run_ticks(2)

-- ---- switched on: the everyday picture ----
--
-- The dials first, so the machine has a job that cannot finish while
-- this section runs: whole air, with no floor under it. A scrubber
-- ships at a floor of 100 kPa and set to carbon dioxide, which a room of
-- clean air at one atmosphere satisfies at once -- and a machine that
-- has ARRIVED is drawn idle now, which is the next scenario rather than
-- this one.
t.ui_act(p, "set", '{"field":"floor","value":0}')
t.ui_act(p, "toggle", '{"field":"roster"}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(1)
local running = t.structure_at(2, 1)
assert(running.state == "scrubbing", "the fan is turning")
assert(running.sprite == "scrubber_on_e", "wearing its working body: " .. running.sprite)

-- The one wire-truth check here: the picture is not merely right in the
-- sim, it reached the client that can see the tile -- and it arrives as
-- a STACK, which is the seam worth pinning. A bare length of pipe is
-- not an entity at all; the client is sent topology and shapes the run
-- itself (pipe_autojoin_test.luau). But a machine's mouth is not where
-- its tile is -- it depends on the facing, the flip, and which of the
-- five piping layers it bound to, none of which the pipe channel
-- carries -- so the sim reads it and sends the answer under the body,
-- on the layer stack already there (sim/atmos_machines/underlays.rs).
-- `intact` is tg's word for a mouth that FOUND its run; 8 is west.
local drawn = t.layers(p, t.target_at(2, 1, "air_scrubber"))
assert(#drawn == 2, "a stub under a body, and nothing else: " .. #drawn)
assert(drawn[1] == "pipe_intact_l2_8", "the mouth it bound, beneath it: " .. drawn[1])
assert(drawn[2] == "scrubber_on_e", "then the machine: " .. tostring(drawn[2]))

-- ---- the emergency posture over a room that is still fine ----
--
-- The panel says whole air with no floor -- the pair that empties a
-- room -- and the picture does NOT, and that is the contract: the
-- third position is a WARNING, and a warning that fires over a room at
-- one atmosphere is a warning nobody reads twice. A scrubber drawing
-- whole air out of a full room is being used as a fast bulk return,
-- and it looks like what it is being used as.
--
-- The pressure that decides is the machine's OWN TILE -- the air it is
-- actually taking, and the air anybody standing beside it is breathing,
-- which a wide-open fan draws down well below the rest of the room.
assert(t.room_pressure(2, 1) > 85.0, "the air at the grille is comfortable to start with")
local emptying = t.structure_at(2, 1)
assert(toggle(p, "roster").on == true, "the panel says whole air")
assert(
    emptying.sprite == "scrubber_on_e",
    "and the corridor is told nothing it does not need to know yet: "
        .. tostring(emptying.sprite)
)

-- ---- and then the room goes ----
--
-- Nobody touches a control from here. `safe_pressure_kpa` is content's
-- own number (content/tuning.luau, engine default 85) and the specs run
-- against the engine's, so this is the machine crossing a line rather
-- than anybody moving one.
local guard = 0
while t.structure_at(2, 1).state ~= "siphoning" and guard < 240 do
    t.run_seconds(1)
    guard = guard + 1
end
local purging = t.structure_at(2, 1)
assert(purging.state == "siphoning", "NOW it is an emergency")
assert(
    t.room_pressure(2, 1) < 85.0,
    "and it waited for the air at the grille to go under the line: "
        .. t.room_pressure(2, 1) .. " kPa"
)
assert(
    purging.sprite == "scrubber_purge_e",
    "and says so in art of its own, which is the whole reason the third"
        .. " position exists: " .. tostring(purging.sprite)
)
assert(
    purging.sprite ~= running.sprite,
    "a siphoning scrubber must never look like a scrubbing one"
)

-- ...and back, because a warning you cannot clear is not a warning:
-- narrow the roster to its named gases and the bulk draw -- the thing
-- the warning was about -- stops with it.
t.ui_act(p, "toggle", '{"field":"roster"}')
t.run_seconds(1)
local calm = t.structure_at(2, 1)
assert(
    calm.state ~= "siphoning" and calm.sprite ~= "scrubber_purge_e",
    "narrowed back, the warning clears: " .. tostring(calm.sprite)
)

-- ---------------------------------------------------------------
-- A FAN BOLTED OVER NOTHING IS DRAWN OFF.
--
-- The same machine, the same switch, and no waste main under its mouth
-- at all. It is switched on and the mains are behind it, and it can
-- move exactly nothing -- so the deck says so, and the panel is where
-- you go to find out that the switch is still thrown. tg would draw
-- this one running.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a scrubber joined to nothing",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#....#",
        "#..ag#",
        "######",
    ],
    spawns: [(3, 2)],
    structures: [(2, 1, "air_scrubber")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3),
    ],
)]==], 7)

local lone = t.join()
t.tick()
local unplumbed = t.target_at(2, 1, "air_scrubber")
t.click(lone, 2, 1, unplumbed)
t.tick()
assert(readout(lone, "supply") == "fed", "the mains are behind it")
t.ui_act(lone, "toggle", '{"field":"power"}')
t.run_seconds(1)
assert(toggle(lone, "power").on == true, "the switch is thrown")
local nothing = t.structure_at(2, 1)
assert(
    nothing.state == "off",
    "and a fan with nowhere to put the air is drawn off: " .. tostring(nothing.state)
)

-- ---------------------------------------------------------------
-- THE TRINARIES CHANGE PICTURE AT THEIR PANEL.
--
-- Neither a filter nor a mixer has a wheel: an empty hand on one opens
-- its window (tg's `ui_interact`, filter.dm:123-127) and the switch is
-- thrown there. Both are drawn from four pictures per position, because
-- a machine that reaches three ways is a different object from every
-- angle -- so this asserts the aimed name, not a generic "on".
--
-- The T: a main west to east with the machine standing in a gap in it
-- and a one-length stub dropping south for the third mouth. The engine
-- aims it at the only facing whose three mouths all have run to reach.
-- ---------------------------------------------------------------
local JUNCTION = [==[(
    name: "a trinary to watch",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#..a..g#",
        "########",
    ],
    spawns: [(3, 2)],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4), (3, 2, 4)],
    structures: [(3, 1, "%s")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

-- The dial each of the two needs before it has a job at all. A filter
-- passes its input port every pass whatever the pressures are, so it
-- needs nothing; a mixer stops dead at its setpoint, and every mapped
-- run on this bench opens at one atmosphere, which is exactly where its
-- dial ships. Opening that dial is the difference between "it has
-- arrived" and "it is working", and both are drawn.
local ARM = {
    filter = function() end,
    mixer = function(q)
        t.ui_act(q, "set", '{"field":"pressure","value":4500}')
    end,
}

for _, machine in ipairs({ "filter", "mixer" }) do
    t.world(JUNCTION:format(machine), 7)
    local q = t.join()
    t.tick()

    local cold = t.structure_at(3, 1)
    assert(cold.id == machine, machine .. " is where the map put it")
    assert(cold.state == "off", machine .. " ships off")
    assert(cold.sprite == machine .. "_off_e", machine .. " is dark, aimed east: " .. cold.sprite)

    t.click(q, 3, 1, t.target_at(3, 1, machine))
    t.tick()
    assert(t.ui(q), machine .. " answers an empty hand with a window")
    ARM[machine](q)
    t.ui_act(q, "toggle", '{"field":"power"}')
    t.run_seconds(1)

    local hot = t.structure_at(3, 1)
    assert(hot.state == "running", machine .. " is running")
    assert(hot.sprite == machine .. "_on_e",
        machine .. " swapped picture, not facing: " .. hot.sprite)
    -- The running bodies of both trinaries are four-frame loops
    -- (assets/sprites/20-atmos-inline-devices.ron). A loop is the
    -- client's own clock and costs the wire nothing, so the NAME is the
    -- whole of what the sim has to get right -- and it must not drift
    -- while the machine keeps working.
    t.run_seconds(3)
    assert(t.structure_at(3, 1).sprite == machine .. "_on_e",
        machine .. " keeps one name while it keeps working")

    -- ...and off again. A one-way picture change would pass every
    -- assertion above.
    t.ui_act(q, "toggle", '{"field":"power"}')
    t.run_seconds(1)
    local back = t.structure_at(3, 1).sprite
    assert(back == machine .. "_off_e", machine .. " goes dark again: " .. back)
end

-- ---------------------------------------------------------------
-- A MIXER SHORT OF AN INTAKE IS DRAWN OFF.
--
-- The same T with the SOUTH STUB REMOVED, so the machine's third mouth
-- opens onto bare deck. A mixer set to 50/50 reads both intakes and a
-- short side drags the other down with it (docs/ATMOS.md SS6), so this
-- one can never blend a mole -- and it is the failure an engineer is
-- meant to spot from the corridor, since the machine downstream of it
-- is a department's air supply.
--
-- Nothing about the panel changes: the switch is thrown throughout.
-- ---------------------------------------------------------------
t.world([==[(
    name: "one intake short",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#..a..g#",
        "########",
    ],
    spawns: [(3, 2)],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [(3, 1, "mixer")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local m = t.join()
t.tick()
t.click(m, 3, 1, t.target_at(3, 1, "mixer"))
t.tick()
t.ui_act(m, "set", '{"field":"pressure","value":4500}')
t.ui_act(m, "toggle", '{"field":"power"}')
t.run_seconds(1)
local starved = t.structure_at(3, 1)
assert(toggle(m, "power").on == true, "the switch is thrown and stays thrown")
assert(
    starved.state == "off",
    "a mixer that cannot reach one of its two supplies is drawn off: "
        .. tostring(starved.state)
)

-- ---------------------------------------------------------------
-- THE PICTURE IS CHOSEN BY THE MAINS, NOT BY THE SWITCH.
--
-- A generator on the backbone, an APC bridging it to a room circuit, and a
-- scrubber standing on the room circuit three tiles along. One snip between
-- them and the machine is on a dead circuit: it goes dark on the deck
-- while its own switch is still thrown, which is what an engineer
-- walking into an unpowered room should see.
--
-- Then the cable goes back down and the machine starts again by itself.
-- Nobody touches the panel between the two: a machine that needed
-- switching back on after a blackout would be a different machine.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a scrubber on the grid",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "########",
        "#G.....#",
        "#a.....#",
        "########",
    ],
    spawns: [(4, 1)],
    items: [(4, 1, "wirecutters"), (5, 1, "cable_coil")],
    cables: [
        (1, 1, 2), (1, 2, 2),
        (1, 2, 1), (2, 2, 1), (3, 2, 1), (4, 2, 1),
    ],
    pipes: [(5, 2, 2), (6, 2, 2)],
    structures: [(4, 2, "air_scrubber")],
)]==], 7)

local e = t.join()
t.tick()

-- The waste main is east this time, so the machine wears the other
-- picture: the facing is the run's doing and the switch must not
-- disturb it.
assert(t.structure_at(4, 2).sprite == "scrubber_off_w", "aimed by its own plumbing")

t.click(e, 4, 2, t.target_at(4, 2, "air_scrubber"))
t.tick()
assert(readout(e, "supply") == "fed", "the mains are behind it")
-- Whole air with the floor down to nothing, so this scrubber never
-- runs out of work while the section runs. What is under test here is
-- the SUPPLY, and a machine that has reached its floor is drawn idle
-- for a reason of its own -- which would make the last assertion in
-- the file ambiguous.
t.ui_act(e, "set", '{"field":"floor","value":0}')
t.ui_act(e, "toggle", '{"field":"roster"}')
t.ui_act(e, "toggle", '{"field":"power"}')
t.run_seconds(1)
assert(t.structure_at(4, 2).sprite == "scrubber_on_w", "and it runs")
t.ui_close(e)
t.tick()

-- ---- one snip, three tiles away ----
t.click(e, 4, 1, t.target_at(4, 1, "wirecutters"))
t.run_ticks(2)
t.click_subfloor(e, 3, 2, "cable", 1)
t.run_seconds(1.5)
assert(t.cable_at(3, 2) == 0, "the room circuit is parted")
assert(t.ledger_has("CableCut"), "and cutting it is attributable")

-- The grid is swept on tg's SSmachines cadence (every 40th tick), so
-- the machine notices on the next pass rather than in the same instant.
t.run_seconds(2.5)
local dark = t.structure_at(4, 2)
assert(dark.state == "off", "the machine is drawn dead: " .. tostring(dark.state))
assert(dark.sprite == "scrubber_off_w",
    "the picture it wore before anyone switched it on: " .. dark.sprite)

-- But NOT switched off. The two are different facts and the panel keeps
-- them apart: the switch is where the engineer left it, and the supply
-- line is what changed.
t.click(e, 4, 2, t.target_at(4, 2, "air_scrubber"))
t.tick()
assert(toggle(e, "power").on == true, "the switch is still thrown")
assert(readout(e, "supply") == "dead", "and the panel names what is actually wrong")
t.ui_close(e)
t.tick()

-- ---- put the cable back ----
t.drop(e)
t.run_ticks(2)
t.click(e, 5, 1, t.target_at(5, 1, "cable_coil"))
t.run_ticks(2)
-- A fresh coil arrives on yellow (tg's CABLE_LAYER_2 default), and this
-- department runs on red, so dial it twice: yellow -> blue -> red.
t.use_self(e)
t.run_ticks(2)
t.use_self(e)
t.run_ticks(2)
t.click(e, 3, 2)
t.run_seconds(1.5)
assert(t.cable_at(3, 2) == 1, "the coil lays the red line back")
assert(t.segment_at(4, 2).feed == 1, "and the machine is back on the panel")

t.run_seconds(2.5)
local revived = t.structure_at(4, 2)
assert(revived.state == "scrubbing", "it started again on its own: " .. revived.state)
assert(revived.sprite == "scrubber_on_w",
    "and the picture came back with the power: " .. revived.sprite)
