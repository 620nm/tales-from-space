-- Building a temperature control unit the long way, which is the only
-- way there is.
--
-- Every other machine in the atmospherics kit is a FITTING: you drop
-- the part on a tile and wrench it (fittings_test.luau). This one is
-- not, and tg says so twice -- `circuit =
-- /obj/item/circuitboard/machine/thermomachine` (thermomachine.dm:18),
-- and zero hits in the RPD's dispenser list. It is a frame, a board and
-- four stock parts, in that order, with a refusal at every step that
-- names what is missing.
--
-- The whole chain a player walks, and then the same chain backwards.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

-- The bench: a run reaching in from the west, a bare tile to build on,
-- and every part of the machine lying at the builder's feet.
t.world([==[(
    name: "assembly bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(3, 2)],
    items: [
        (3, 2, "metal"),
        (3, 2, "cable_coil"),
        (3, 2, "thermomachine_board"),
        (3, 2, "matter_bin"),
        (3, 2, "matter_bin"),
        (3, 2, "micro_laser"),
        (3, 2, "micro_laser"),
        (3, 2, "glass"),
        (3, 2, "screwdriver"),
        (3, 2, "crowbar"),
    ],
    pipes: [(1, 1, 4), (2, 1, 4)],
)]==], 7)

local p = t.join()
t.tick()

-- Everything is picked up from the tile underfoot, one thing at a
-- time: two hands, and a spec that walks around proves nothing this
-- one does not.
local function take(id)
    t.click(p, 3, 2, t.target_at(3, 2, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

-- ---------------------------------------------------------------
-- THE FRAME. Five sheets, and the build menu has to name WHICH thing
-- five sheets make: a girder comes first in registry order, so a bare
-- click would raise one. tg's radial asks the same question.
-- ---------------------------------------------------------------
take("metal")
t.build(p, "metal", "machine_frame", 3, 1)
t.run_seconds(8.5)
local frame = t.structure_at(3, 1)
assert(frame ~= nil and frame.id == "machine_frame", "five sheets box up into a frame")
assert(frame.state == "empty", "and it opens bare")

-- A part held against a frame with no board in it is refused by the
-- STATE, because there is nothing yet to ask what it wants.
put_down()
take("matter_bin")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_ticks(2)
assert(
    said(p, "The machine frame must be boarded first."),
    "the frame names the state its parts row wants"
)
assert(t.hands(p).held == "matter_bin", "and swallows nothing")

-- ---------------------------------------------------------------
-- WIRED, THEN BOARDED.
-- ---------------------------------------------------------------
put_down()
take("cable_coil")
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1).state == "wired", "five lengths of cable wire it")

put_down()
take("thermomachine_board")
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "boarded", "the board clicks into place")
assert(t.count_items("thermomachine_board") == 0, "and is installed rather than dropped")

-- ---------------------------------------------------------------
-- THE PARTS, AND THE REFUSALS THAT NAME THEM.
--
-- tg's frame refuses the screwdriver while `req_components` still
-- lists anything (machine_frame.dm). Here the refusal reads the list
-- out, one line at a time, because an engineer only ever has to fetch
-- one thing at a time.
-- ---------------------------------------------------------------
take("screwdriver")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_seconds(4.5)
local heard = table.concat(t.messages(p), " | ")
-- The board's list is held in a fixed order, so which line comes first
-- is deterministic rather than whichever the engine happened to walk.
assert(
    heard:find("It still needs 1 x cable coil.", 1, true),
    "the screwdriver says what the board is short of, got: " .. heard
)
assert(t.structure_at(3, 1).id == "machine_frame", "and nothing was assembled")

-- Something the board never asked for is refused by NAME rather than
-- eaten: a frame is not a bin.
put_down()
take("metal")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_ticks(2)
assert(said(p, "The machine frame has no use for that."), "the assembly is not a rubbish bin")

-- ...and now the four things it does want. A stack gives up ONE unit
-- (tg's `req_components` counts sheets, not reels), so the coil and
-- the pane keep standing in the hand.
put_down()
for _, part in ipairs({ "cable_coil", "glass" }) do
    take(part)
    t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
    t.run_ticks(2)
    assert(t.hands(p).held == part, "a stack gives up a unit and stays in the hand")
    put_down()
end

-- Two down, and the refusal has moved on to the next thing rather than
-- repeating itself: the list is read out one line at a time.
take("screwdriver")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_seconds(4.5)
heard = table.concat(t.messages(p), " | ")
assert(
    heard:find("It still needs 2 x matter bin.", 1, true),
    "the refusal names what is missing NOW, got: " .. heard
)

put_down()
for _, part in ipairs({ "matter_bin", "matter_bin", "micro_laser", "micro_laser" }) do
    take(part)
    t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
    t.run_ticks(2)
    assert(t.hands(p).held == nil, "a loose part is spent whole")
end

-- ---------------------------------------------------------------
-- THE SCREWDRIVER, AND A MACHINE STANDING IN THE RUN.
-- ---------------------------------------------------------------
take("screwdriver")
t.click(p, 3, 1, t.target_at(3, 1, "machine_frame"))
t.run_seconds(4.5)
local unit = t.structure_at(3, 1)
assert(unit ~= nil and unit.id == "thermomachine", "the assembly becomes the machine its board named")
assert(unit.state == "off", "switched off, as anything fresh out of a frame is")
assert(
    t.ledger_has("StructureStep", "machine_frame", "finished"),
    "and the assembly is on the record"
)

-- It is PLUMBED IN: the board built a structure, so it went down the
-- same path a mapped one does and found the run beside it.
put_down()
t.click(p, 3, 1, t.target_at(3, 1, "thermomachine"))
t.tick()
local panel = t.ui(p)
assert(panel, "a temperature control unit wears a panel")
assert(panel.setpoints[1].field == "temperature", "with a thermostat on it")
assert(readout(panel, "pipe") ~= "no pipe", "and its mouth found the run: " .. tostring(readout(panel, "pipe")))
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- AND BACKWARDS. tg's crowbar deconstruction drops the board and every
-- component and leaves a frame standing (_machinery.dm:934-985).
-- ---------------------------------------------------------------
take("crowbar")
-- The leftovers of the build are still lying about, so the two stacks
-- are weighed as a DIFFERENCE; the parts that went in whole are
-- weighed outright, because none of those are left on the deck.
local glass_before = t.count_items("glass")
local coil_before = t.count_items("cable_coil")
t.click(p, 3, 1, t.target_at(3, 1, "thermomachine"))
t.run_seconds(4.5)
local left = t.structure_at(3, 1)
assert(left ~= nil and left.id == "machine_frame", "a frame is what is left standing")
for item, count in pairs({
    thermomachine_board = 1,
    matter_bin = 2,
    micro_laser = 2,
}) do
    assert(
        t.count_items(item) == count,
        item .. ": expected " .. count .. " back, got " .. t.count_items(item)
    )
end
assert(t.count_items("glass") == glass_before + 1, "the pane comes back as its own pile")
assert(t.count_items("cable_coil") == coil_before + 1, "and so does the cable")
