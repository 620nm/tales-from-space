-- Where the station's air comes from.
--
-- The chain is canister -> distribution run -> vent -> room, and it is
-- the ONLY chain: nothing on a station makes air. A canister is 2000 L
-- of premixed 21/79 at 45 atm (tg's canister.dm: `maximum_pressure`
-- 90 atm x `filled` 0.5), it charges the run it stands on up to one
-- atmosphere, and the vents on that run release into their rooms until
-- the rooms read one atmosphere too. Every mole a room gains came out
-- of the canister, so a canister that has been spent is spent, and a
-- long breach is expensive in a way you can read off a gauge.
--
-- Layer masks in the maps below are tg's five piping layers; 4 is
-- layer 3, the distribution run.

-- Moles in a volume at a pressure, at room temperature -- the ideal gas
-- law, so the spec can check the books rather than trust a direction.
local function moles(kpa, volume_m3)
    return kpa * 1000.0 * volume_m3 / (8.314 * 293.15)
end

local function heard(p, want)
    for _, s in ipairs(t.sounds(p)) do
        if s == want then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------
-- One sealed room, one vent, one canister, and the run between
-- them. Breach it, weld it shut, and watch the room come back --
-- out of the canister and nowhere else.
-- ---------------------------------------------------------------
t.world([==[(
    name: "air supply",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating, fixture: Some(Canister)),
    },
    rows: [
        "#####",
        "#...#",
        "#..c#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "welder")],
    pipes: [(2, 2, 4)],
    // The vent, and the socket under the canister. Without the socket
    // the bottle is furniture.
    structures: [(1, 2, "vent"), (3, 2, "connector_port")],
)]==], 7)

local p = t.join()
t.tick()

-- The room is nine tiles of 1 m³; one raw length joins the vent's
-- 200 L mouth to the connector's zero-volume socket.
local ROOM_M3 = 9.0
local CAN_M3 = 2.0

-- A full canister reads about 45 atm. That is the whole supply.
local full = t.canister_pressure(3, 2)
assert(full ~= nil, "the canister is where the map put it")
assert(full > 4000.0, "a fresh canister is at 45 atm: " .. full)
assert(t.pipe_pressure(2, 2) > 90.0, "and it has charged the run to one atmosphere")
assert(t.room_pressure(2, 2) > 90.0, "so the room is breathable from the start")

-- A room that is ALREADY at one atmosphere costs nothing. The release
-- valve is a setpoint, not a tap left running.
t.run_seconds(10)
assert(
    math.abs(t.canister_pressure(3, 2) - full) < 1.0,
    "a settled station does not drain its canister: " .. t.canister_pressure(3, 2)
)

-- Take the welder off the deck FIRST: loose things do not survive a
-- decompression, and a welder dragged into space is a welder lost.
t.click(p, 2, 2, t.target_at(2, 2, "welder"))
t.run_ticks(2)

-- Open the hull. The room empties, and the vent fights the hole and
-- loses -- which is correct, and which is what makes breaches cost
-- something other than time.
t.fault(2, 1, t.now() + 4)
t.run_seconds(10)
assert(t.is_breached(2, 1), "the fault opened the room")
local emptied = t.room_pressure(2, 3)
-- It does not reach hard vacuum: the vent is feeding it the whole
-- time, and what the canister sends up the line goes straight out the
-- hole. That standoff is exactly the cost of leaving a breach open.
assert(emptied < 60.0, "the room emptied: " .. emptied)

-- Weld it shut. Now it is a sealed vacuum with a live vent over a
-- charged run.
t.click(p, 2, 1)
t.run_seconds(4.5)
assert(not t.is_breached(2, 1), "welded shut")

local room_before = t.room_pressure(2, 3)
local can_before = t.canister_pressure(3, 2)
t.run_seconds(60)
local room_after = t.room_pressure(2, 3)
local can_after = t.canister_pressure(3, 2)

assert(room_after > 90.0, "the vent brought the room back up: " .. room_after)
assert(can_after < can_before, "and the canister is what paid: " .. can_after)

-- The books balance: what the room gained, the canister lost. (Not to
-- the mole -- the run itself holds some of it, and the room is sampled
-- at one tile -- but to the same order, which is the difference between
-- plumbing and a magic trick.)
local gained = moles(room_after - room_before, ROOM_M3)
local spent = moles(can_before - can_after, CAN_M3)
assert(gained > 100.0, "the room gained a real amount: " .. gained)
assert(
    spent > gained * 0.7 and spent < gained * 1.5,
    "the room's gain came out of the canister: gained "
        .. gained
        .. " mol, canister spent "
        .. spent
        .. " mol"
)

-- And you can hear it. A canister that starts feeding hisses once.
assert(heard(p, "hiss"), "the room heard the valve open")

-- The gauge has moved off full, which is the point of a gauge.
assert(can_after < full, "the reading dropped: " .. full .. " -> " .. can_after)

-- ---------------------------------------------------------------
-- Air is finite, and this is what that means.
--
-- A sealed room with a vent, and a scrap of deck hanging in open
-- space at the other end of the same distribution run, carrying the
-- station's only canister and a second vent. That vent releases into
-- vacuum forever, so the canister empties into space -- nobody
-- notices until somebody needs air.
-- ---------------------------------------------------------------
t.world([==[(
    name: "spent",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating, fixture: Some(Canister)),
    },
    rows: [
        "#####                   ",
        "#...#                   ",
        "#...#.................c ",
        "#...#                   ",
        "#####                   ",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "welder")],
    pipes: [
        (2, 2, 4), (3, 2, 4), (4, 2, 4), (5, 2, 4), (6, 2, 4),
        (7, 2, 4), (8, 2, 4), (9, 2, 4), (10, 2, 4), (11, 2, 4), (12, 2, 4),
        (13, 2, 4), (14, 2, 4), (15, 2, 4), (16, 2, 4), (17, 2, 4),
        (18, 2, 4), (21, 2, 4),
    ],
    structures: [
        (1, 2, "vent"),
        (20, 2, "passive_vent"),
        (22, 2, "connector_port"),
    ],
)]==], 7)

local q = t.join()
t.tick()
assert(t.canister_pressure(22, 2) > 4000.0, "the second canister starts full too")
assert(t.room_pressure(2, 2) > 90.0, "and the crew room starts breathable")

-- Tear the deck open under the strip. (The station is handed over
-- SETTLED, so a hole has to actually happen for anything to move --
-- a mapper cannot author a room mid-decompression.) From here the
-- second vent is releasing into a vacuum that never fills, so the
-- canister empties itself into space one lungful per pass.
t.fault(10, 2, t.now() + 4)
t.run_seconds(300)
local left = t.canister_pressure(22, 2)
assert(left < 100.0, "the canister blew itself empty: " .. left)
assert(t.pipe_pressure(21, 2) < 10.0, "and the bottle's outlet run is dead with it")

-- The crew room never noticed: it was already at one atmosphere, so
-- its vent had no reason to run.
assert(t.room_pressure(2, 2) > 80.0, "the sealed room is still fine")

-- Until it isn't. Breach it, weld it shut, and give the vent every
-- chance: it is a fan over a dead line, and a fan moves no air it was
-- not handed.
t.click(q, 2, 2, t.target_at(2, 2, "welder"))
t.run_ticks(2)
t.fault(2, 1, t.now() + 4)
t.run_seconds(8)
assert(t.is_breached(2, 1), "the crew room opened")
t.click(q, 2, 1)
t.run_seconds(4.5)
assert(not t.is_breached(2, 1), "and was welded shut again")

local sealed = t.room_pressure(2, 3)
assert(sealed < 45.0, "sealed at a fraction of an atmosphere: " .. sealed)
t.run_seconds(60)
local later = t.room_pressure(2, 3)
assert(
    later < sealed + 5.0,
    "an empty canister repressurises nothing: " .. sealed .. " -> " .. later
)

-- ---------------------------------------------------------------
-- A canister is PORTABLE, and the PORT is the plumbing.
--
-- tg's portable atmos devices (portable/portable_atmospherics.dm)
-- start unanchored and fasten to a `portables_connector` -- a pipe
-- fitting that must itself be wrenched onto a run before it will host
-- anything. So there are two things here, not one: laying the socket
-- is slow work with a progress bar, and putting a bottle on the socket
-- takes no time at all (tg's `wrench_act` has no do_after in it).
--
-- A canister on a bare distribution main is standing on plumbing with
-- no way into it. That is the whole correction: pipe is not a port.
--
-- The room below is sealed and already at one atmosphere, which makes
-- the reading unambiguous: a canister that is feeding anything is
-- feeding the RUN, because the room has no demand. The run's far end
-- is a vent over open space, so as long as the canister is on a port
-- it is pouring its air into the void and the gauge falls.
-- ---------------------------------------------------------------
t.world([==[(
    name: "portable",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '_': (turf: Plating),
        'c': (turf: Floor, fixture: Some(Canister)),
    },
    rows: [
        "######### ",
        "#.c.....#_",
        "#.......# ",
        "######### ",
    ],
    spawns: [(1, 1)],
    items: [(1, 2, "wrench")],
    // The run reaches the vent by going AROUND (3, 1): that tile is
    // bare deck with nothing under it, so the canister can be stood
    // somewhere unplumbed without the net being cut in two.
    pipes: [
        (1, 2, 4), (2, 2, 4), (3, 2, 4), (4, 2, 4),
        (5, 2, 4), (6, 2, 4),
        (4, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4),
    ],
    // Three sockets beside the run, plus the vent on the scrap of deck
    // outside. (4, 1) is deliberately NOT a socket: it is charged main
    // with nowhere to plug in.
    structures: [
        (1, 1, "connector_port"),
        (2, 1, "connector_port"),
        (5, 1, "connector_port"),
        (9, 1, "vent"),
    ],
)]==], 7)

local w = t.join()
t.tick()
t.click(w, 1, 2, t.target_at(1, 2, "wrench")) -- the wrench
t.run_ticks(2)

-- Fastened to the port it was mapped on: it is feeding the leak, and
-- you can watch it happen on the gauge.
local before = t.canister_pressure(2, 1)
assert(before ~= nil, "the canister is where the map put it")
t.run_seconds(10)
local fastened = t.canister_pressure(2, 1)
assert(fastened < before - 100.0,
    "a fastened canister feeds the run: " .. before .. " -> " .. fastened)

-- Laying plumbing is slow. The player is standing on a port of their
-- own at (1, 1); a wrench takes two seconds to break it out of the run
-- and hand it back as a fitting, which is the contrast the next step is
-- about. (The round trip itself is fittings_test.luau's business.)
t.click(w, 1, 1, t.target_at(1, 1, "connector_port"))
t.run_ticks(1)
assert(not t.ledger_has("StructureStep", "connector_port", "gone"),
    "one tick in, the port is still bolted down")
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "connector_port", "gone"),
    "and two seconds in, it is up")
assert(#t.items_at(1, 1) == 1, "and it is lying on the deck as a fitting")

-- Unfastening a canister takes NO time. One tick, one ratchet, off.
t.click(w, 2, 1, t.target_at(2, 1))
t.run_ticks(1)
assert(t.ledger_has("StructureStep", "canister", "displaced"),
    "the canister comes off the port instantly")

-- Read the gauge the moment it is off.
local off = t.canister_pressure(2, 1)
t.run_seconds(10)
local loose = t.canister_pressure(2, 1)
assert(math.abs(loose - off) < 1.0,
    "off the port, it feeds nothing: " .. off .. " -> " .. loose)
assert(t.pipe_pressure(2, 2) < 20.0,
    "and the adjacent run it left is emptying into space: " .. t.pipe_pressure(2, 2))

-- Loose means loose. Walk into it and it gives way (see
-- movement.rs::shove -- tg would have you PULL it), and the tile it
-- lands on has nothing under the floor.
t.move(w, "east")
t.run_ticks(3)
assert(t.canister_pressure(2, 1) == nil, "it is not where it was")
assert(t.canister_pressure(3, 1) ~= nil, "it is one tile east")
assert(t.ledger_has("StructureStep", "canister", "pushed"),
    "and the shove is on the record")

-- No pipe, no port, nothing to fasten to. tg says "Nothing happens.";
-- we say which rule stopped it, because a dropped click is worse than
-- a refusal.
local function refused_with(line)
    for _, m in ipairs(t.messages(w)) do
        if m == line then
            return true
        end
    end
    return false
end

local _ = t.messages(w)
t.click(w, 3, 1, t.target_at(3, 1))
t.run_ticks(2)
assert(refused_with("There is nothing here to fasten it to."),
    "the refusal named the rule on bare deck")
assert(not t.ledger_has("StructureStep", "canister", "anchored"),
    "nothing was fastened to bare deck")

-- And the correction itself: one tile further east is charged
-- distribution main, and it is still not a port. The pipe is right
-- there under the canister and the wrench does nothing.
t.move(w, "east")
t.run_ticks(3)
assert(t.canister_pressure(4, 1) ~= nil, "it is over the run now")
assert(t.pipe_pressure(4, 1) ~= nil, "on live pipe, at that")
local _ = t.messages(w)
t.click(w, 4, 1, t.target_at(4, 1))
t.run_ticks(2)
assert(refused_with("There is nothing here to fasten it to."),
    "a bare run is not a socket")
assert(not t.ledger_has("StructureStep", "canister", "anchored"),
    "and nothing was fastened to it")

-- Shove it one further, onto a real port, and the wrench takes --
-- instantly, again.
t.move(w, "east")
t.run_ticks(3)
assert(t.canister_pressure(5, 1) ~= nil, "it is on the second port")
local moved = t.canister_pressure(5, 1)
t.click(w, 5, 1, t.target_at(5, 1))
t.run_ticks(1)
assert(t.ledger_has("StructureStep", "canister", "anchored"),
    "fastened to the port it was shoved onto")

t.run_seconds(10)
local rejoined = t.canister_pressure(5, 1)
assert(rejoined < moved - 100.0,
    "and it is feeding the loop from its new tile: "
        .. moved .. " -> " .. rejoined)

-- ---------------------------------------------------------------
-- A bottle is pushed ACROSS the atmospherics kit, not around it.
--
-- Josh's ruling (2026-08-16). An injector, a scrubber, a vent, a meter
-- and a connector all lie flat in the deck plates: nothing about them
-- is dense, and a crewman walks over one without breaking stride. So
-- one cannot be what stops the bottle that crewman is pushing. The
-- shove's landing rule is density plus "never onto a mob"
-- (movement.rs::shove_blocked), which is the same test the walker
-- himself passed one tile earlier.
--
-- The situation below is the one that was reported: two sockets with an
-- injector standing between them, and a canister that has to get from
-- the first to the second.
-- ---------------------------------------------------------------
t.world([==[(
    name: "across the kit",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'v': (turf: Plating),
        'c': (turf: Floor, fixture: Some(Canister)),
    },
    rows: [
        "######### ",
        "#.c.....#v",
        "#.......# ",
        "######### ",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "wrench")],
    // One run along the second row, out under the east wall to the
    // vent hanging over open space -- so anything in the line goes
    // straight off the station and the gauge is a proof.
    pipes: [
        (2, 2, 4), (3, 2, 4), (4, 2, 4), (5, 2, 4), (6, 2, 4),
        (6, 1, 4), (7, 1, 4), (8, 1, 4),
    ],
    // Two sockets, the injector standing between them, and the vent
    // (a structure since the constructible-vents cutover) hanging
    // over open space at the end of the line.
    structures: [
        (2, 1, "connector_port"),
        (4, 1, "connector_port"),
        (3, 1, "air_injector"),
        (9, 1, "vent"),
    ],
)]==], 7)

local v = t.join()
t.tick()
t.click(v, 1, 1, t.target_at(1, 1, "wrench"))
t.run_ticks(2)
assert(t.hands(v).held == "wrench", "wrench in hand")

assert(t.target_at(3, 1, "air_injector") ~= nil, "the injector stands between the two sockets")
local supply = t.canister_pressure(2, 1)
t.run_seconds(10)
assert(t.canister_pressure(2, 1) < supply - 100.0,
    "the bottle opens the shift plumbed into the first socket: " .. t.canister_pressure(2, 1))

-- Off the socket, instantly, and now nothing holds it down.
t.click(v, 2, 1, t.target_at(2, 1, "canister"))
t.run_ticks(1)
assert(t.ledger_has("StructureStep", "canister", "displaced"), "unfastened")

-- THE SHOVE THAT WAS REFUSED. The injector's tile is a legal landing:
-- it is not dense, and nobody is standing on it.
t.move(v, "east")
t.run_ticks(5)
assert(t.canister_pressure(3, 1) ~= nil,
    "the bottle went onto the injector's own tile")
assert(t.canister_pressure(2, 1) == nil, "and left the one it was on")
assert(t.target_at(3, 1, "air_injector") ~= nil,
    "with the injector still there underneath it, untouched")

-- And straight on across, onto the second socket.
t.move(v, "east")
t.run_ticks(5)
assert(t.canister_pressure(4, 1) ~= nil, "one more shove puts it on the far socket")
assert(#t.ledger_rows("structure_step") > 0, "and both shoves are on the record")

t.click(v, 4, 1, t.target_at(4, 1, "canister"))
t.run_ticks(1)
assert(t.ledger_has("StructureStep", "canister", "anchored"),
    "fastened to the socket on the far side")

local landed = t.canister_pressure(4, 1)
t.run_seconds(10)
assert(t.canister_pressure(4, 1) < landed - 100.0,
    "and feeding the run again from there: "
        .. landed .. " -> " .. t.canister_pressure(4, 1))
