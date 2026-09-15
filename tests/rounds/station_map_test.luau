local network_matter = require("@helpers/network_matter")
local network_channels = require("@helpers/network_channels")

local composition = require("@helpers/composition")

-- The shipped station as content: commissioned machinery, powered rooms,
-- bounded sight, hull windows, and a real vestibule at either way out.
-- Mechanism benches belong in Rust; every noun and coordinate here belongs
-- to the map players actually load.

local function standing(x: number, y: number, id: string, state: string?)
    local found = t.structure_at(x, y)
    assert(found ~= nil, "a structure stands at " .. x .. "," .. y)
    assert(found.id == id, "at " .. x .. "," .. y .. ": " .. tostring(found.id))
    if state ~= nil then
        assert(
            found.state == state,
            id .. " at " .. x .. "," .. y .. " ships " .. state .. ", not " .. tostring(found.state)
        )
    end
end

t.world_file("chillstation.ron", 7)
local p = t.join()
t.run_seconds(10)
local spawn_x, spawn_y = t.pos(p)
while spawn_x > 18 do
    t.move(p, "west")
    t.run_ticks(6)
    spawn_x, spawn_y = t.pos(p)
end
while spawn_x < 18 do
    t.move(p, "east")
    t.run_ticks(6)
    spawn_x, spawn_y = t.pos(p)
end
assert(spawn_x == 18 and spawn_y == 16, "the crew reaches the Commons start")

-- The Commons north wall carries the two public displays where the
-- waking crew can see them.
standing(21, 13, "digital_clock")
standing(22, 13, "status_display")
for _, device in ipairs({
    { x = 23, y = 14, id = "fax" },
    { x = 24, y = 18, id = "photocopier" },
    { x = 21, y = 6, id = "fax" },
}) do
    local machine = t.machine_at(device.x, device.y)
    assert(machine and machine.id == device.id, device.id .. " stands at its document station")
end
standing(22, 18, "access_point")
standing(24, 6, "access_point")

-- Atmospherics is commissioned rather than merely drawn.
for _, row in ipairs({
    { x = 21, y = 23, id = "filter.co2", state = "running" },
    { x = 23, y = 23, id = "mixer.airmix", state = "running" },
    { x = 25, y = 23, id = "pump", state = "running" },
    { x = 18, y = 26, id = "pump", state = "running" }, -- the waste lift: a pressure pump,
    -- because a volumetric one refuses the drained main's trickle
    { x = 14, y = 25, id = "pump", state = "running" }, -- the wheel feed's regulator
    { x = 18, y = 23, id = "pump", state = "running" }, -- the process inlet's regulator
    -- Switched on and drawn OFF, and both are true. This one is the
    -- department's CO2 recovery leg (maps/chillstation.ron): a roster of
    -- one gas, in a room that at roundstart holds none of it. A machine
    -- is drawn by what the last atmos pass saw it do rather than by its
    -- switch (docs/ATMOS.md SS8), so it lights up the moment somebody
    -- breathes in that room and not a pass before.
    { x = 16, y = 17, id = "air_scrubber", state = "off" },
    { x = 15, y = 33, id = "air_injector", state = "injecting" },
    -- The map ships this one turned round -- it is a vestibule's pump
    -- down -- and at roundstart the chamber is still at station
    -- pressure, so it is drawn as the ordinary scrubber it is currently
    -- being. The third picture is a warning about a room going EMPTY,
    -- and it arrives when the chamber does (docs/ATMOS.md SS8;
    -- device_looks_test.luau owns the crossing).
    { x = 15, y = 34, id = "air_scrubber", state = "scrubbing" },
    { x = 14, y = 28, id = "manual_valve", state = "open" },
    { x = 26, y = 24, id = "layer_adapter", state = "anchored" },
    { x = 22, y = 20, id = "layer_adapter", state = "anchored" },
    { x = 17, y = 27, id = "layer_adapter", state = "anchored" },
}) do
    standing(row.x, row.y, row.id, row.state)
end

-- Supply and process mains share a shaft without becoming one run.
local shaft = network_channels.at(18, 25, "pipe")
assert(shaft == "l3,l4", "the process and supply layers alone cross the shaft: " .. tostring(shaft))
assert(network_matter.pressure(18, 25, "l3") ~= nil, "the process layer has its own gas")
assert(network_matter.pressure(18, 25, "l4") ~= nil, "the supply layer has its own gas")

-- Representative rooms are live on the station grid, including both ends
-- of the corridor ring rather than only the spawn room.
for _, row in ipairs({
    { 20, 13, 19, 15 },
    { 6, 4, 8, 6 },
    { 21, 11, 20, 11 },
    { 5, 27, 8, 30 },
}) do
    assert(t.lit(row[1], row[2]), "the station grid lights " .. row[1] .. "," .. row[2])
    assert(
        assert(t.room_pressure(row[3], row[4])) > 90.0,
        "the room at " .. row[3] .. "," .. row[4] .. " holds air"
    )
end

-- A closed door is the view boundary. The player starts in the Commons:
-- an examine in the room succeeds and a forged claim through its west door
-- is refused by the same FOV-filtered seam the browser uses.
assert(t.examine(p, 17, 14) ~= nil, "the player sees their own room")
assert(not pcall(function()
    t.examine(p, 13, 15)
end), "the west hall stays behind the shut door")

-- Both EVA exits are vestibules: outer door, three tiles of chamber, inner
-- door, with vacuum beyond and air held between the leaves.
for _, row in ipairs({
    { 3, 15, 5, 15, 2, 15, 4, 15 },
    { 36, 15, 34, 15, 37, 15, 35, 15 },
}) do
    assert(t.door_at(row[1], row[2]), "the outer vestibule leaf exists")
    assert(t.door_at(row[3], row[4]), "the inner vestibule leaf exists")
    assert(composition.bare(row[5], row[6], "space"), "the outer leaf opens to space")
    assert(composition.matches(row[7], row[8], { "station_base" }), "the chamber is bare deck")
    assert(assert(t.room_pressure(row[7], row[8])) > 90.0, "the shut vestibule holds air")
end

-- The hull gallery is glazing, not decorative mesh over a hole, and the
-- room behind it holds pressure on the live map.
for _, at in ipairs({ { 29, 3 }, { 30, 3 }, { 31, 3 }, { 3, 23 }, { 36, 25 } }) do
    standing(at[1], at[2], "grille", "reinforced")
    assert(composition.matches(at[1], at[2], { "station_base" }), "the pane replaces the hull on deck")
end
assert(composition.bare(30, 2, "space"), "the north gallery looks into vacuum")
assert(assert(t.room_pressure(30, 6)) > 90.0, "the cargo bay holds air through its panes")

-- The Common transceiver is commissioned, not merely drawn: it stands
-- on the Commons' north rank at (22, 13), its cord reaches the port
-- at (24, 14), and its variant key is seated -- all three asserted in
-- one sentence, because the status line refuses each failure in its
-- own words (lib/radio.luau: dark, keyless, or on the air). The walk
-- is the spawn room's own floor; the empty-hand click is the fixture's
-- gate (fixtures/transceiver.luau). Without this tower the crew's
-- shipped Common headsets make a ten-tile bubble
-- (radio_coverage_test.luau owns that exact boundary).
local route: { "east" | "north" | "south" | "west" } =
    { "east", "east", "east", "east", "north", "north" }
for _, dir in ipairs(route) do
    t.move(p, dir)
    t.run_ticks(6)
end
local px, py = t.pos(p)
assert(px == 22 and py == 14, "standing under the Common tower: " .. px .. "," .. py)
local _ = t.messages(p)
t.click(p, 22, 13, t.target_at(p, 22, 13))
t.tick()
local heard = t.messages(p)
local on_air = false
for _, m in ipairs(heard) do
    -- Relayed: the Commons APC is a hub and every device it powers
    -- is hardwired under it (../lunatic/docs/devices/joining.md).
    if m == "The transceiver is on the air, carrying Common, relayed through its network." then
        on_air = true
    end
end
assert(on_air, "the Commons tower ships powered and keyed: " .. table.concat(heard, " | "))
