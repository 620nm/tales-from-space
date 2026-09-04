-- THE AIR ALARM: one wall box that a room's plumbing answers to.
--
-- tg gives a vent pump no window at all. Its direction, its pressure
-- check and its two bounds are written by the AREA's air alarm
-- (`vent_pump.dm:24-30`), and the alarm finds what it drives by area
-- and nothing else (`my_area.air_vents`, `my_area.air_scrubbers`,
-- code/modules/atmospherics/machinery/air_alarm/_air_alarm.dm:315,332).
--
-- This engine has no areas, so the alarm is a HUB on the device forest
-- and the room's machines JOIN it. What that buys is asserted here and
-- nowhere else:
--
--   * an alarm holding nothing proxies nothing;
--   * a joined machine's whole settings pane appears under the alarm,
--     in a section named for the machine and its address;
--   * a dial turned on the ALARM is the machine's dial;
--   * the machine's own casing goes read-only and says who has it;
--   * a lock over the alarm takes every one of those away again;
--   * and the class word keeps the comms boxes out of all of it.
--
-- What a vent DOES with a setpoint is vent_panel_test.luau's; who may
-- join what is network_test.luau's. This file is the seam between them.

local ONE_ATM = 101.325
local TUNED = 150.0

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts or {}) do
        if r.label == label then
            return r.value
        end
    end
    return nil
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

local function dial(ui, field)
    for _, row in ipairs(ui.setpoints or {}) do
        if row.field == field then
            return row
        end
    end
    return nil
end

-- Every section heading the document draws, in the order the rows
-- carry them. The `link` module's two are static words ("members",
-- "joinable"); the `reach` module's are one per proxied machine, named
-- for the machine and its address, which is how a reader tells two
-- vents in one room apart.
local function sections(ui)
    local seen, out = {}, {}
    local lists = { ui.readouts or {}, ui.toggles or {}, ui.setpoints or {}, ui.labels or {} }
    for _, list in ipairs(lists) do
        for _, row in ipairs(list) do
            local label = row.section
            if label ~= nil and not seen[label] then
                seen[label] = true
                out[#out + 1] = label
            end
        end
    end
    return out
end

-- The section a named machine was drawn under, and the address in it.
local function proxied(ui, name)
    for _, label in ipairs(sections(ui)) do
        if label:sub(1, #name + 1) == name .. " " then
            return label, label:sub(#name + 2)
        end
    end
    return nil, nil
end

-- Every row on this document that belongs to some OTHER machine. Its
-- key is "<address>/<that machine's own field>", which is the one shape
-- no local module ever produces -- the alarm invents no vocabulary, it
-- scopes what the machine already had.
local function scoped(ui)
    local out = {}
    for _, list in ipairs({ ui.toggles or {}, ui.setpoints or {}, ui.offers or {} }) do
        for _, row in ipairs(list) do
            if type(row.field) == "string" and row.field:find("/", 1, true) then
                out[#out + 1] = row
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------
-- THE BENCH. A plated room with the plumbing on show: a vent fed by a
-- pump off a canister, a scrubber on a waste main, and along the same
-- wall the two boxes that are NOT atmospherics -- an access point and
-- a transceiver, both live, both unjoined, both well inside the
-- alarm's reach. They are the class test, and they are here
-- rather than in a second bench because "in range and refused anyway"
-- is the only thing worth asserting about them.
-- ---------------------------------------------------------------
t.world([==[(
    name: "air alarm bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    // One socket in the middle of the room, because three of the five
    // devices here hang on a CORD rather than on the cable under them
    // and a mount out of cord range is a mount with no address
    // (docs/POWER.md).
    rows: [
        "################",
        "#..............#",
        "#.......o......#",
        "#............ag#",
        "################",
    ],
    spawns: [(7, 2)],
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    items: [(7, 2, "id_engineering")],
    // The waste main runs out under the west wall, so the scrubber has
    // somewhere to put what it takes (tests/room_devices_test.luau).
    pipes: [(0, 2, 2), (1, 2, 2)],
    structures: [
        (2, 1, "vent"),
        (3, 1, "pump", "running", { "dir": "west", "target_kpa": 900.0 }),
        (4, 1, "connector_port", { "dir": "west" }),
        (4, 1, "canister", { "blend": "canister_air" }),
        (2, 2, "air_scrubber"),
        // The card is spelled out rather than left to the socket's
        // default, because this box is nothing at all without one and a
        // bench should say so (docs/map-properties/placements.md,
        // "Sockets").
        (6, 1, "air_alarm", { "access": "engineering", "network_1": "network_card" }),
        (9, 1, "access_point"),
    ],
    mounts: [(6, 1, North), (9, 1, North)],
    machines: [(11, 1, "transceiver")],
    cables: [
        (13, 3, 3), (14, 3, 2),
        (1, 1, 1), (2, 1, 1), (3, 1, 1), (4, 1, 1), (5, 1, 1), (6, 1, 1),
        (7, 1, 1), (8, 1, 1), (9, 1, 1), (10, 1, 1), (11, 1, 1), (12, 1, 1),
        (1, 2, 1), (2, 2, 1), (3, 2, 1), (4, 2, 1), (5, 2, 1), (6, 2, 1),
        (7, 2, 1), (8, 2, 1), (9, 2, 1), (10, 2, 1), (11, 2, 1), (12, 2, 1),
        (12, 3, 1), (13, 3, 1),
    ],
)]==], 7)

t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local p = t.join()
t.run_ticks(20)

-- Every machine on this bench stands on the north row and every walk
-- is along the south one, so the crewman is always a step away from
-- whatever they are about to touch. Reach is real here: a panel is
-- something you open by standing at the box.
local function walk_to(x)
    for _ = 1, 24 do
        local at = t.pos(p)
        if at == x then
            return
        end
        t.move(p, at < x and "east" or "west")
        t.run_ticks(4)
    end
    error("could not walk to x=" .. x .. ", stuck at " .. t.pos(p))
end

local function open(x, y, id)
    t.ui_close(p)
    t.tick()
    walk_to(x)
    t.click(p, x, y, t.target_at(x, y, id))
    t.tick()
    local panel = t.ui(p)
    assert(panel ~= nil, tostring(id or "the machine") .. " at " .. x .. "," .. y .. " wears a panel")
    return panel
end

-- ---------------------------------------------------------------
-- 1. THE TWO BOXES THAT ARE NOT ATMOSPHERICS, first, because their
--    addresses are what the rest of the file needs to prove a
--    NEGATIVE. Both draw the `link` module, so both print their own
--    address to anybody standing at them -- an identifier and never a
--    credential (docs/devices/addresses.md).
-- ---------------------------------------------------------------
local point = readout(open(9, 1, "access_point"), "address")
assert(point ~= nil and #point == 17, "the access point has an address: " .. tostring(point))
-- A machine rather than a structure, so the hit-test names the tile and
-- not an id (tests/network_test.luau's router).
local relay = readout(open(11, 1, nil), "address")
assert(relay ~= nil and #relay == 17, "and so does the transceiver: " .. tostring(relay))
assert(relay ~= point, "two boxes, two addresses")

-- ---------------------------------------------------------------
-- 2. A SHUT ALARM PROXIES NOTHING.
--
-- It is a hub with a card in it, so it has an address and a state; it
-- holds nobody, so there is nothing to draw. The reach pane is not
-- "empty rows": it is NO SECTION AT ALL, which is the difference
-- between a console reporting an empty room and a console that has not
-- been given one.
-- ---------------------------------------------------------------
local panel = open(6, 1, "air_alarm")
local alarm = readout(panel, "address")
assert(alarm ~= nil and #alarm == 17, "the alarm's own address is on it: " .. tostring(alarm))
assert(readout(panel, "state") == "online", "a hub tops its own tree")
assert(not rows(panel, "link_lock")[1].on, "and a fresh boot finds every lock shut")
assert(proxied(panel, "air vent") == nil, "and no machine is drawn under it")
assert(#scoped(panel) == 0, "not one row on it belongs to something else")

-- ---------------------------------------------------------------
-- 3. THE CLAIM OPENS IT, AND WHAT IT OFFERS IS ATMOSPHERICS ONLY.
--
-- Three machines stand inside the alarm's reach with a setting worth turning
-- -- the vent, the pump feeding it and the scrubber -- and so do two
-- network boxes. `accepts = { "atmos" }` is the whole difference: a
-- refused class is not a refused PRESS, it is never offered, so a
-- crewman reading this panel is not told what they may not have
-- (docs/content-schema/link.md).
-- ---------------------------------------------------------------
t.ui_close(p)
t.tick()
walk_to(7)
t.click(p, 7, 2, t.target_at(7, 2, "id_engineering"))
t.run_ticks(2)
assert(t.hands(p).held == "id_engineering", "the claim is in hand")

panel = open(6, 1, "air_alarm")
t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(p)
assert(rows(panel, "link_lock")[1].on, "engineering's claim opens it")

local candidates = {}
for _, row in ipairs(rows(panel, "link_join")) do
    candidates[#candidates + 1] = row.option
    assert(row.option ~= point, "the access point is not on offer: wrong class")
    assert(row.option ~= relay, "and neither is the transceiver")
end
assert(#candidates == 3, "the vent, the pump and the scrubber, and nothing else: " .. #candidates)

-- ...AND ASKING ANYWAY GETS NOTHING, which is the half a roster alone
-- does not prove. A forged press names a row this panel never drew, and
-- the seam rebuilds the window and matches field and option against it
-- before any gesture exists (`settings_act`, sim/ui/settings.rs) -- so
-- the press is not a refused join, it is not a join at all. That is why
-- the assertion below is an absence of BOTH: no edge, and no
-- `link_denied` row either, because nothing ever reached the forest to
-- be refused.
--
-- The refusal itself is the engine's and is tested there, where a
-- caller can reach past the panel: `devicenet_accept` answers
-- `ClassForbidden` and writes the one `class_forbidden` row
-- (crates/lunatic-server/src/sim/tests/devicenet/classes.rs,
-- `a_hub_that_names_classes_refuses_the_rest`). A pack spec asserts
-- what a player could cause, and a player cannot cause that one.
local before = #t.ledger_rows("link_denied")
t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', point))
t.tick()
t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', relay))
t.tick()
panel = t.ui(p)
assert(#rows(panel, "link_drop") == 0, "neither box is on the alarm")
for _, row in ipairs(rows(panel, "link_join")) do
    assert(row.option ~= point and row.option ~= relay, "and neither is on offer after the press")
end
assert(#t.ledger_rows("link_denied") == before,
    "a press no row owns is not a gesture, so there was nothing to refuse")

-- ---------------------------------------------------------------
-- 4. THE JOIN, AND THE ROOM APPEARS ON THE CONSOLE.
--
-- One section per machine, named for the machine AND its address,
-- because two vents in one room are told apart by the second half and
-- a shift log names only that half.
-- ---------------------------------------------------------------
for _, mac in ipairs(candidates) do
    t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', mac))
    t.tick()
end
panel = t.ui(p)
assert(#rows(panel, "link_drop") == 3, "the alarm holds all three")

local vent_section, vent = proxied(panel, "air vent")
assert(vent_section ~= nil, "the vent is drawn under its own heading")
assert(#vent == 17, "the heading carries its address: " .. vent_section)
assert(proxied(panel, "air scrubber") ~= nil, "and the scrubber under its")
assert(proxied(panel, "pump") ~= nil, "and the pump under its")
assert(proxied(panel, "radio transceiver") == nil, "the transceiver is in nobody's reach")

-- ---------------------------------------------------------------
-- 5. A DIAL ON THE ALARM IS THE VENT'S DIAL.
--
-- The whole point of the box, in one press. The row key is the
-- machine's address and the machine's own field name, so the alarm
-- invents no vocabulary: `setpoint` here is `setpoint` there.
-- ---------------------------------------------------------------
local key = vent .. "/setpoint"
near(dial(panel, key).value, ONE_ATM, 0.001, "the vent opens on tg's external_pressure_bound")

t.ui_act(p, "set", string.format('{"field":"%s/siphon","value":200.0}', vent))
t.run_ticks(2)
t.ui_act(p, "set", string.format('{"field":"%s","value":%f}', key, TUNED))
t.run_ticks(2)
panel = t.ui(p)
near(dial(panel, key).value, TUNED, 0.001, "and the alarm moved it to a hundred and fifty")
-- The proxy reuses the vent module's own `apply`, so the row is the
-- one a hand on the casing would have left and names the MACHINE
-- rather than the console (sim/ui/settings/vent.rs).
local turned = t.ledger_rows("machine_setpoint")
local moved = false
for _, row in ipairs(turned) do
    if row.field == "setpoint" and math.abs(row.value - TUNED) < 0.001 then
        moved = true
    end
end
assert(moved, "a press through the proxy lands on the record like any other: " .. #turned .. " rows")

-- ---------------------------------------------------------------
-- 6. AND THE VENT'S OWN CASING IS READ-ONLY.
--
-- This is the half that makes the console mean something. A machine
-- somebody else is driving must not also be a machine a passer-by
-- reaches down and re-sets, and it must SAY who has it -- an address
-- being the only thing anybody can act on afterwards.
-- ---------------------------------------------------------------
local casing = open(2, 1, "vent")
assert(#(casing.setpoints or {}) == 0, "a paired vent offers no dial at its casing")
assert(#(casing.toggles or {}) == 0, "and no switch either")
assert(casing.notice ~= nil, "it says why instead")
assert(casing.notice:find(alarm, 1, true) ~= nil,
    "and names the box that has it: " .. tostring(casing.notice))

-- ---------------------------------------------------------------
-- 7. LOCK IT AGAIN AND THE ROOM GOES AWAY WITH THE ROSTER.
--
-- A shut lock hides the alarm's members, and the proxied machines ARE
-- its members: hiding one and drawing the other would be a lock that
-- protects a list and hands over the controls it names
-- (docs/tgui/modules.md).
-- ---------------------------------------------------------------
panel = open(6, 1, "air_alarm")
t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(p)
assert(not rows(panel, "link_lock")[1].on, "the alarm is shut again")
assert(proxied(panel, "air vent") == nil, "and the room is off the console")
assert(dial(panel, key) == nil, "with no dial left to turn")
assert(readout(panel, "address") == alarm, "the address stays: it was never the secret")

-- ---------------------------------------------------------------
-- 8. AND THE BOX SAYS ALL OF THIS FROM ACROSS THE ROOM.
--
-- tg draws this panel shut with a teal lamp over it and draws NO lamp
-- at all while it is unpowered, broken or shorted
-- (_air_alarm.dm:557, :526-527). The engine derives two states off
-- the cord and the forest and they land on exactly those two pictures,
-- so a crewman walking past reads "this room's console is dead" without
-- opening anything (`appearance.device`,
-- docs/content-schema/appearance.md).
--
-- The face is a MOUNT face throughout: the box is hung north and stays
-- hung north through every swap, which is the half a flat picture would
-- silently break.
-- ---------------------------------------------------------------
t.ui_close(p)
t.tick()
assert(t.structure_at(6, 1).sprite == "air_alarm_lit_n",
    "fed and on the air, so the lamp is on: " .. tostring(t.structure_at(6, 1).sprite))
assert(t.structure_at(9, 1).sprite == "access_point_n",
    "and the comms box beside it draws standby: " .. tostring(t.structure_at(9, 1).sprite))

-- Pull the breaker. Both boxes hang on cords off the one socket in the
-- middle of the room, so both go dark together -- and they go dark by
-- two different pictures, because each names its own art.
t.outage()
t.run_ticks(80)
assert(t.structure_at(6, 1).sprite == "air_alarm_n",
    "a dead cord is tg's no-lamp face: " .. tostring(t.structure_at(6, 1).sprite))
assert(t.structure_at(9, 1).sprite == "access_point_off_n",
    "and the comms box wears its own: " .. tostring(t.structure_at(9, 1).sprite))
