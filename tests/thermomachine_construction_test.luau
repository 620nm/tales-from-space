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

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if word(r.label) == label then
            return word(r.value)
        end
    end
    return nil
end

-- The bench: a run reaching in from the west, a bare tile to build on,
-- and the machine's parts laid out on the nearby floor.
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
        "#......#",
        "########",
    ],
    structures: [(3, 2, "player_spawn")],
    items: [
        (1, 3, "metal"),
        (2, 3, "cable_coil"),
        (3, 3, "machine_board.thermomachine"),
        (4, 3, "matter_bin"),
        (3, 2, "matter_bin"),
        (5, 3, "micro_laser"),
        (3, 2, "micro_laser"),
        (6, 3, "glass"),
        (1, 2, "screwdriver"),
        (5, 2, "crowbar"),
    ],
    pipes: [(1, 1, 4), (2, 1, 4)],
)]==], 7)

local p = t.join()
t.tick()

-- Supplies lie apart so each has a visible pixel. Fetch one at a
-- time and return to the workbench before using it.
local function take(id)
    local x, y = 3, 2
    local places = {["metal"] = {1, 3},["cable_coil"] = {2, 3},["machine_board.thermomachine"] = {3, 3},["matter_bin"] = {4, 3},["micro_laser"] = {5, 3},["glass"] = {6, 3},["screwdriver"] = {1, 2},["crowbar"] = {5, 2}}
    local at = if t.target_at(p, x, y, id) then {x, y} else places[id]
    local home_x, home_y = t.pos(p)
    local px, py = home_x, home_y
    for _ = 1, 16 do
        if math.abs(px - at[1]) <= 1 and math.abs(py - at[2]) <= 1 then break end
        local dir = if math.abs(py - at[2]) > 1 then (if py < at[2] then "south" else "north") else (if px < at[1] then "east" else "west")
        t.move(p, dir)
        t.run_ticks(3)
        px, py = t.pos(p)
    end
    assert(math.abs(px - at[1]) <= 1 and math.abs(py - at[2]) <= 1, "the supply is reachable")
    t.click(p, at[1], at[2], t.target_at(p, at[1], at[2], id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
    for _ = 1, 16 do
        if px == home_x and py == home_y then break end
        t.move(p, if px ~= home_x then (if px < home_x then "east" else "west") else (if py < home_y then "south" else "north"))
        t.run_ticks(3)
        px, py = t.pos(p)
    end
    assert(px == home_x and py == home_y, "returned to the workbench")
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
ui_controls.build(p, "metal", "machine_frame", 3, 1)
t.run_seconds(8.5)
local frame = t.structure_at(3, 1)
assert(frame ~= nil and frame.id == "machine_frame", "five sheets box up into a frame")
assert(frame.state == "empty", "and it opens bare")

-- A part held against a frame with no board in it is refused by the
-- STATE, because there is nothing yet to ask what it wants.
put_down()
take("matter_bin")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
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
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1).state == "wired", "five lengths of cable wire it")

put_down()
take("machine_board.thermomachine")
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "boarded", "the board clicks into place")
assert(t.count_items("machine_board.thermomachine") == 0, "and is installed rather than dropped")

-- ---------------------------------------------------------------
-- THE PARTS, AND THE REFUSALS THAT NAME THEM.
--
-- tg's frame refuses the screwdriver while `req_components` still
-- lists anything (machine_frame.dm). Here the refusal reads the list
-- out, one line at a time, because an engineer only ever has to fetch
-- one thing at a time.
--
-- WHAT THE LIST IS, in order: the SOCKETS the product declares
-- (structures/thermomachine.luau's `parts.slots`), then the stack
-- materials the board itself names. Both halves are held in a fixed
-- order, so which line comes first is deterministic rather than
-- whichever the engine happened to walk, and the sockets come first
-- because they are what the thing being built is made OF.
--
-- A socket names the LOWEST rung that fills it: any tier of matter bin
-- does, and the plain one is the one there is a crate of
-- (items/matter_bin.luau ships four).
-- ---------------------------------------------------------------
take("screwdriver")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
t.run_seconds(4.5)
local heard = table.concat(t.messages(p), " | ")
assert(
    heard:find("It still needs 2 x matter bin.", 1, true),
    "the screwdriver says what the board is short of, got: " .. heard
)
assert(t.structure_at(3, 1).id == "machine_frame", "and nothing was assembled")

-- Something the board never asked for is refused by NAME rather than
-- eaten: a frame is not a bin.
put_down()
take("metal")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
t.run_ticks(2)
assert(said(p, "The machine frame has no use for that."), "the assembly is not a rubbish bin")

-- ...and now the four sockets. A loose part is spent whole.
put_down()
for _, part in ipairs({ "matter_bin", "matter_bin", "micro_laser", "micro_laser" }) do
    take(part)
    t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
    t.run_ticks(2)
    assert(t.hands(p).held == nil, "a loose part is spent whole")
end

-- Four down, and the refusal has moved on to the next thing rather than
-- repeating itself: the list is read out one line at a time, and the
-- sockets being full is what lets the board's own rows be heard.
take("screwdriver")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
t.run_seconds(4.5)
heard = table.concat(t.messages(p), " | ")
assert(
    heard:find("It still needs 1 x cable coil.", 1, true),
    "the refusal names what is missing NOW, got: " .. heard
)

-- A stack gives up ONE unit (tg's `req_components` counts sheets rather
-- than whole coils), so the cable and the pane keep standing in the
-- hand.
put_down()
for _, part in ipairs({ "cable_coil", "glass" }) do
    take(part)
    t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
    t.run_ticks(2)
    assert(t.hands(p).held == part, "a stack gives up a unit and stays in the hand")
    put_down()
end

-- ---------------------------------------------------------------
-- THE SCREWDRIVER, AND A MACHINE STANDING IN THE RUN.
-- ---------------------------------------------------------------
take("screwdriver")
t.click(p, 3, 1, t.target_at(p, 3, 1, "machine_frame"))
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
t.click(p, 3, 1, t.target_at(p, 3, 1, "thermomachine"))
t.tick()
local panel = t.ui(p)
assert(panel, "a temperature control unit wears a panel")
assert(panel.setpoints[1].field == "temperature", "with a thermostat on it")
assert(readout(panel, "thermo.pipe") ~= "thermo.pipe.none",
    "and its mouth found the run: " .. tostring(readout(panel, "thermo.pipe")))
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
t.click(p, 3, 1, t.target_at(p, 3, 1, "thermomachine"))
t.run_seconds(4.5)
local left = t.structure_at(3, 1)
assert(left ~= nil and left.id == "machine_frame", "a frame is what is left standing")
for item, count in pairs({
    ["machine_board.thermomachine"] = 1,
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
