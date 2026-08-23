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
-- Every sprite name below comes from a TfS content file
-- (`structures/air_scrubber.luau`, `gas_filter.luau`, `gas_mixer.luau`)
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

-- ---- the direction dial does nothing to a machine that is off ----
--
-- The sharpest thing `position()` says: it asks `working()` FIRST, so a
-- scrubber turned round while switched off has no running direction to
-- show and stays exactly as dark as it was. Setting a machine up before
-- you start it must not paint a siphon warning on an occupied room.
t.ui_act(p, "toggle", '{"field":"direction"}')
t.run_ticks(2)
local armed = t.structure_at(2, 1)
assert(toggle(p, "direction").on == true, "the dial moved")
assert(armed.state == "off", "and the machine did not: " .. tostring(armed.state))
assert(armed.sprite == "scrubber_off_e", "nor its picture: " .. tostring(armed.sprite))

t.ui_act(p, "toggle", '{"field":"direction"}')
t.run_ticks(2)

-- ---- switched on: the everyday picture ----
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
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

-- ---- turned round: the third picture ----
t.ui_act(p, "toggle", '{"field":"direction"}')
t.run_ticks(2)
local purging = t.structure_at(2, 1)
assert(purging.state == "siphoning", "it is emptying the room now")
assert(
    purging.sprite == "scrubber_purge_e",
    "and says so in art of its own, which is the whole reason the third"
        .. " position exists: " .. tostring(purging.sprite)
)
assert(
    purging.sprite ~= running.sprite,
    "a siphoning scrubber must never look like a scrubbing one"
)

-- ...and back, because a warning you cannot clear is not a warning.
t.ui_act(p, "toggle", '{"field":"direction"}')
t.run_ticks(2)
local calm = t.structure_at(2, 1).sprite
assert(calm == "scrubber_on_e", "turned back, an ordinary scrubber again: " .. calm)

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

for _, machine in ipairs({ "gas_filter", "gas_mixer" }) do
    local short = string.sub(machine, 5, -1) -- "filter" / "mixer", content's own art prefix
    t.world(JUNCTION:format(machine), 7)
    local q = t.join()
    t.tick()

    local cold = t.structure_at(3, 1)
    assert(cold.id == machine, machine .. " is where the map put it")
    assert(cold.state == "off", machine .. " ships off")
    assert(cold.sprite == short .. "_off_e", machine .. " is dark, aimed east: " .. cold.sprite)

    t.click(q, 3, 1, t.target_at(3, 1, machine))
    t.tick()
    assert(t.ui(q), machine .. " answers an empty hand with a window")
    t.ui_act(q, "toggle", '{"field":"power"}')
    t.run_ticks(2)

    local hot = t.structure_at(3, 1)
    assert(hot.state == "running", machine .. " is running")
    assert(hot.sprite == short .. "_on_e",
        machine .. " swapped picture, not facing: " .. hot.sprite)

    -- ...and off again. A one-way picture change would pass every
    -- assertion above.
    t.ui_act(q, "toggle", '{"field":"power"}')
    t.run_ticks(2)
    local back = t.structure_at(3, 1).sprite
    assert(back == short .. "_off_e", machine .. " goes dark again: " .. back)
end

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
t.ui_act(e, "toggle", '{"field":"power"}')
t.run_ticks(2)
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
