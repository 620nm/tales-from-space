-- The network a station gets for free, and the one gesture that
-- overrides it.
--
-- Every other device network in this pack is built by hand: somebody
-- unlocks a box, reads its candidates and presses a row
-- (tests/network_test.luau). This one is built by the WIRE. A panel
-- that carries a card is a hub, and the electrical pass sews every
-- device that panel feeds underneath it -- the fittings on its
-- lighting circuit, the fans on its cable, and anything on a cord into
-- a port it stands behind (../lunatic/docs/devices/joining.md). A
-- room's plant is on a network because a room's plant is plugged in.
--
-- Which makes two rules worth pinning, because they are what stop that
-- from being a network nobody can work with:
--
--   * A HARDWIRED EDGE IS NOT THE PANEL'S TO CUT. It says which panel
--     feeds the device, and the way off it is to join the device
--     somewhere else -- so the panel draws the member as a readout
--     with no drop beside it, and a client that asks anyway is
--     refused on the record.
--
--   * A HARDWIRED CHILD IS STILL JOINABLE. An engineer pairing a fan
--     to a console severs the wire's edge and takes it; releasing it
--     later hands it straight back to the panel, because the wire
--     never stopped feeding it.
--
-- The fitting is the exception both ways: it is `hardwired_only`
-- (content/structures/light.luau), so it hangs off its panel and
-- appears on nobody's candidate list at all.

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function rows(ui, field)
    local out = {}
    for _, row in ipairs(ui.toggles or {}) do
        if row.field == field then
            out[#out + 1] = row
        end
    end
    return out
end

local function row_for(ui, field, option)
    for _, row in ipairs(rows(ui, field)) do
        if row.option == option then
            return row
        end
    end
    return nil
end

-- Every address the panel draws as WIRED IN: a readout rather than a
-- toggle, which is the whole difference this file is about.
local function hardwired(ui)
    local out = {}
    for _, r in ipairs(ui.readouts or {}) do
        if word(r.label) == "link.member.hardwired" then
            out[#out + 1] = r.label.args.address
        end
    end
    table.sort(out)
    return out
end

local function holds(list, mac)
    for _, held in ipairs(list) do
        if held == mac then
            return true
        end
    end
    return false
end

-- The bench: a panel on the backbone opening one room circuit, a port
-- on it, and four things drawing through the panel by four different
-- routes -- a fitting on a cord, a fan on a cord, a fan standing on
-- the cable itself, and an air alarm with a card of its own. Nobody
-- joins anything; the wire does all of it.
t.world([==[(
    name: "hardwire",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'o': (turf: Plating, fixture: Some(Outlet)),
        'l': (turf: Plating, fixture: Some(Light)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "############",
        "#.o.......g#",
        "#l.........#",
        "############",
    ],
    spawns: [(9, 2)],
    structures: [
        (3, 2, "vent"),
        (5, 1, "vent"),
        (7, 1, "air_alarm", { "network_1": "network_card" }),
        (9, 1, "apc"),
    ],
    cables: [
        (10, 1, 2), (9, 1, 2),
        (9, 1, 1), (8, 1, 1), (7, 1, 1), (6, 1, 1), (5, 1, 1),
        (4, 1, 1), (3, 1, 1), (2, 1, 1),
    ],
    labels: [(9, 1, "Engineering")],
)]==], 0)

local p = t.join()
t.tick()
t.run_seconds(3)
t.run_ticks(60)

-- ---------------------------------------------------------------
-- 1. THE PANEL HOLDS THE ROOM, and nobody put it there. The fitting
--    on a cord, the fan on a cord, the fan on bare cable and the
--    alarm with its own card are all under it, each drawn as wired
--    in rather than as something to let go of.
-- ---------------------------------------------------------------
t.click(p, 9, 1, t.target_at(9, 1))
t.tick()
local panel = t.ui(p)
assert(panel ~= nil, "the panel opens")
-- Placed with no `access` word: a lock with no key opens for whoever
-- is standing at it (tests/network_test.luau, the router's case).
t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(p)

local members = hardwired(panel)
assert(#members == 4, "the whole room hangs off the panel: " .. #members)
assert(#rows(panel, "link_drop") == 0,
    "and not one of them is the panel's to let go of")

-- ---------------------------------------------------------------
-- 2. AND WILL NOT LET GO. There is no row to press, so a client that
--    wants one has to name an address the window never offered --
--    which is the hostile case, and the one the panel contract
--    already answers: what a client may name is exactly what the
--    document published (docs/TGUI.md). The press moves nothing and
--    files nothing, because there was no gesture to refuse.
-- ---------------------------------------------------------------
local victim = members[1]
t.ui_act(p, "toggle", string.format('{"field":"link_drop","option":"%s"}', victim))
t.tick()
t.run_seconds(3)
t.run_ticks(40)
assert(holds(hardwired(t.ui(p)), victim), "the edge is still there")
assert(#t.ledger_rows("link_released") == 0, "and nothing was cut")
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- 3. A CONSOLE MAY STILL TAKE ONE. The alarm is a hub two tiles from
--    the fan on the cable, and that fan is on its candidate list
--    despite already being bound: what the wire sewed is exactly what
--    an engineer is allowed to move (../lunatic/docs/devices/joining.md).
--    The FITTING is not, and never will be.
-- ---------------------------------------------------------------
t.move(p, "west")
t.run_ticks(5)
t.move(p, "west")
t.run_ticks(5)
t.click(p, 7, 1, t.target_at(7, 1))
t.tick()
local alarm = t.ui(p)
assert(alarm ~= nil, "the alarm opens too")
t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
alarm = t.ui(p)

local offers = rows(alarm, "link_join")
assert(#offers > 0, "the alarm has something to take")
local fitting = nil
for _, held in ipairs(members) do
    if row_for(alarm, "link_join", held) == nil then
        fitting = held
    end
end
assert(fitting ~= nil, "one member is on nobody's list")

local fan = offers[1].option
t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', fan))
t.tick()
alarm = t.ui(p)
assert(row_for(alarm, "link_drop", fan) ~= nil, "the alarm holds it now")
assert(row_for(alarm, "link_join", fan) == nil, "and no longer offers it")
t.ui_close(p)
t.tick()
t.run_seconds(3)
t.run_ticks(60)

-- The panel has lost it: an explicit join severs the wire's edge
-- rather than standing beside it, because a device has one parent.
t.move(p, "east")
t.run_ticks(5)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 9, 1, t.target_at(9, 1))
t.tick()
panel = t.ui(p)
assert(not holds(hardwired(panel), fan), "the panel let the fan go")
assert(#hardwired(panel) == 3, "and holds the other three: " .. #hardwired(panel))
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- 4. AND HANDS IT BACK. Release the fan at the console and the wire
--    takes it again on the next pass -- nobody re-wired anything, and
--    the panel never stopped feeding it. A device released from a
--    console falls to the panel behind it rather than off the network
--    altogether.
-- ---------------------------------------------------------------
t.move(p, "west")
t.run_ticks(5)
t.move(p, "west")
t.run_ticks(5)
t.click(p, 7, 1, t.target_at(7, 1))
t.tick()
t.ui_act(p, "toggle", string.format('{"field":"link_drop","option":"%s"}', fan))
t.tick()
assert(row_for(t.ui(p), "link_drop", fan) == nil, "the console let it go")
t.ui_close(p)
t.tick()
t.run_seconds(3)
t.run_ticks(60)

t.move(p, "east")
t.run_ticks(5)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 9, 1, t.target_at(9, 1))
t.tick()
panel = t.ui(p)
assert(holds(hardwired(panel), fan), "and the wire has it back")
assert(#hardwired(panel) == 4, "the room is whole again: " .. #hardwired(panel))
