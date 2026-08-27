-- TAKING IT APART AGAIN, and getting back what was actually inside.
--
-- Two claims, and both used to be false.
--
-- ONE: a machine that was screwed together out of a frame can be taken
-- apart again. tg gives every machine the same two rungs generically —
-- a screwdriver opens the maintenance panel
-- (`default_deconstruction_screwdriver`, _machinery.dm:1049) and a
-- crowbar pries it apart behind the open panel (:912) — and here they
-- are the machine's own `teardown` block. What stands there afterwards
-- is the assembly, holding the board and its parts, so the one gesture
-- that hands them back is the frame's own crowbar.
--
-- TWO: what comes back is what is IN it. A `yields` list is content
-- written once and cannot know which rungs a particular unit was
-- assembled from; the roster in front of it can, and the engine mints
-- that alongside the file's own rows whenever a step takes the thing
-- out of the world. An upgraded unit prised apart hands back its
-- upgrade, which is tg's `component_parts` (_machinery.dm:925-968).

local function count(list, id)
    local n = 0
    for _, item in ipairs(list) do
        if item == id then
            n = n + 1
        end
    end
    return n
end

-- The bench: a build site at the west end, an upgraded temperature
-- control unit standing at the east, and every part of a reaction
-- chamber lying at the builder's feet.
t.world([==[(
    name: "deconstruction bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#########",
        "#.......#",
        "#.......#",
        "#########",
    ],
    spawns: [(2, 2)],
    structures: [
        (7, 1, "thermomachine.fullupgrade", "off"),
    ],
    items: [
        (2, 2, "metal"),
        (2, 2, "cable_coil"),
        (2, 2, "chem_heater_board"),
        (2, 2, "glass"),
        (2, 2, "micro_laser.tier3"),
        (2, 2, "screwdriver"),
        (2, 2, "crowbar"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local function take(id)
    t.click(p, 2, 2, t.target_at(2, 2, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

local function walk(dir, steps)
    for _ = 1, steps do
        t.move(p, dir)
        t.run_ticks(5)
    end
end

-- ---------------------------------------------------------------
-- ONE: A CHAMBER BUILT AROUND A RUNG-THREE LASER.
--
-- The long way, because the point is that the socket remembers which
-- laser went in (parts_test.luau walks the same chain for what the
-- socket is WORTH; this one is about getting it back out).
-- ---------------------------------------------------------------
take("metal")
t.build(p, "metal", "machine_frame", 2, 1)
t.run_seconds(8.5)
assert(t.structure_at(2, 1).id == "machine_frame", "five sheets box up into a frame")

put_down()
take("cable_coil")
t.click(p, 2, 1, t.target_at(2, 1, "machine_frame"))
t.run_seconds(2.5)
assert(t.structure_at(2, 1).state == "wired", "five lengths of cable wire it")

put_down()
take("chem_heater_board")
t.click(p, 2, 1, t.target_at(2, 1, "machine_frame"))
t.run_ticks(2)
assert(t.structure_at(2, 1).state == "boarded", "the board clicks into place")

put_down()
take("glass")
t.click(p, 2, 1, t.target_at(2, 1, "machine_frame"))
t.run_ticks(2)

put_down()
take("micro_laser.tier3")
t.click(p, 2, 1, t.target_at(2, 1, "machine_frame"))
t.run_ticks(2)
assert(t.hands(p).held == nil, "a rung three laser fills the socket like any other")

take("screwdriver")
t.click(p, 2, 1, t.target_at(2, 1, "machine_frame"))
t.run_seconds(4.5)
local chamber = t.target_at(2, 1)
assert(chamber ~= nil, "the assembly becomes the machine its board named")
assert(t.structure_at(2, 1) == nil, "and the frame is spent into it")

-- ---------------------------------------------------------------
-- ...AND BACK APART. The panel first: a crowbar against a shut panel
-- is refused rather than silent, which is tg's `can_crowbar_deconstruct`
-- (_machinery.dm:899).
-- ---------------------------------------------------------------
put_down()
take("crowbar")
local _ = t.messages(p)
t.click(p, 2, 1, chamber)
t.run_ticks(2)
local heard = table.concat(t.messages(p), " | ")
assert(heard:find("panel", 1, true), "the refusal says which rung is missing: " .. heard)
assert(t.target_at(2, 1) ~= nil, "and the chamber is still standing")

put_down()
take("screwdriver")
t.click(p, 2, 1, chamber)
t.run_ticks(2)
assert(t.target_at(2, 1) ~= nil, "the driver opens the panel and does nothing else")

put_down()
take("crowbar")
t.click(p, 2, 1, chamber)
t.run_ticks(2)
local frame = t.structure_at(2, 1)
assert(frame ~= nil and frame.id == "machine_frame", "the assembly is what is left standing")
assert(frame.state == "boarded", "holding its board and its parts")
assert(
    t.ledger_has("StructureStep", "chem_heater", "machine_frame"),
    "and the teardown is on the record"
)

-- The frame's own crowbar is the ONE path a board and its parts come
-- back out by — the same row that has always undone a board.
t.click(p, 2, 1, t.target_at(2, 1, "machine_frame"))
t.run_ticks(2)
local left = t.items_at(2, 1)
assert(count(left, "micro_laser.tier3") == 1,
    "the laser that went in is the laser that comes out, not a tier one: "
        .. table.concat(left, ", "))
assert(count(left, "micro_laser") == 0, "and no plain rung was invented")
assert(count(left, "glass") == 1, "with the pane the board asked for")
-- The board goes to the free hand rather than the deck, exactly as it
-- has always done when an assembly is pried open.
local hands = t.hands(p)
assert(hands[1] == "chem_heater_board" or hands[2] == "chem_heater_board",
    "and the board is back in a hand: " .. tostring(hands[1]) .. ", " .. tostring(hands[2]))

-- ---------------------------------------------------------------
-- TWO: AN UPGRADED UNIT PRISED APART HANDS BACK ITS UPGRADE.
--
-- A temperature control unit is a STRUCTURE — it stands in a pipe run —
-- so it comes apart by its own crowbar row rather than by a teardown
-- block. Same rule underneath: the sockets say what comes out, and its
-- `yields` spells only what no socket holds.
-- ---------------------------------------------------------------
put_down()
take("crowbar")
walk("east", 4)
t.click(p, 7, 1, t.target_at(7, 1, "thermomachine.fullupgrade"))
t.run_seconds(4.5)
assert(t.structure_at(7, 1).id == "machine_frame", "a frame is what is left standing")

local apart = t.items_at(7, 1)
assert(count(apart, "matter_bin.tier4") == 2,
    "both bins come back at the rung they were: " .. table.concat(apart, ", "))
assert(count(apart, "micro_laser.tier4") == 2, "and both lasers")
assert(count(apart, "matter_bin") == 0 and count(apart, "micro_laser") == 0,
    "with no plain rung anywhere in the pile")
assert(count(apart, "thermomachine_board") == 1, "the board its file still spells")
assert(count(apart, "glass") == 1, "and the pane")
