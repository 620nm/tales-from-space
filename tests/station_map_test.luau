-- The shipped station as content: commissioned machinery, powered rooms,
-- bounded sight, hull windows, and a real vestibule at either way out.
-- Mechanism benches belong in Rust; every noun and coordinate here belongs
-- to the map players actually load.

local function standing(x, y, id, state)
    local found = t.structure_at(x, y)
    assert(found ~= nil, "a structure stands at " .. x .. "," .. y)
    assert(found.id == id, "at " .. x .. "," .. y .. ": " .. tostring(found.id))
    if state ~= nil then
        assert(found.state == state,
            id .. " at " .. x .. "," .. y .. " ships " .. state
                .. ", not " .. tostring(found.state))
    end
end

t.world_file("chillstation.ron", 7)
local p = t.join()
t.run_seconds(10)

-- The Commons north wall carries the two public displays where the
-- waking crew can see them.
standing(21, 13, "digital_clock")
standing(22, 13, "status_display")

-- Atmospherics is commissioned rather than merely drawn.
for _, row in ipairs({
    { 21, 23, "gas_filter.co2", "running" },
    { 23, 23, "gas_mixer.airmix", "running" },
    { 25, 23, "gas_pump", "running" },
    { 18, 26, "gas_pump", "running" }, -- the waste lift: a pressure pump,
    -- because a volumetric one refuses the drained main's trickle
    { 14, 25, "gas_pump", "running" }, -- the wheel feed's regulator
    { 18, 23, "gas_pump", "running" }, -- the process inlet's regulator
    -- Switched on and drawn OFF, and both are true. This one is the
    -- department's CO2 recovery leg (maps/chillstation.ron): a roster of
    -- one gas, in a room that at roundstart holds none of it. A machine
    -- is drawn by what the last atmos pass saw it do rather than by its
    -- switch (docs/ATMOS.md SS8), so it lights up the moment somebody
    -- breathes in that room and not a pass before.
    { 16, 17, "air_scrubber", "off" },
    { 15, 33, "air_injector", "injecting" },
    -- The map ships this one turned round -- it is a vestibule's pump
    -- down -- and at roundstart the chamber is still at station
    -- pressure, so it is drawn as the ordinary scrubber it is currently
    -- being. The third picture is a warning about a room going EMPTY,
    -- and it arrives when the chamber does (docs/ATMOS.md SS8;
    -- device_looks_test.luau owns the crossing).
    { 15, 34, "air_scrubber", "scrubbing" },
    { 14, 28, "manual_valve", "open" },
    { 26, 24, "layer_adapter", "anchored" },
    { 22, 20, "layer_adapter", "anchored" },
    { 17, 27, "layer_adapter", "anchored" },
}) do
    standing(row[1], row[2], row[3], row[4])
end

-- Supply and process mains share a shaft without becoming one run.
local shaft = t.pipe(18, 25)
assert(shaft == 12, "the process and supply layers alone cross the shaft: " .. tostring(shaft))
assert(t.pipe_pressure(18, 25, 4) ~= nil, "the process layer has its own gas")
assert(t.pipe_pressure(18, 25, 8) ~= nil, "the supply layer has its own gas")

-- Representative rooms are live on the station grid, including both ends
-- of the corridor ring rather than only the spawn room.
for _, row in ipairs({
    { 20, 13, 19, 15 },
    { 6, 4, 8, 6 },
    { 21, 11, 20, 11 },
    { 5, 27, 8, 30 },
}) do
    assert(t.lit(row[1], row[2]), "the station grid lights " .. row[1] .. "," .. row[2])
    assert(t.room_pressure(row[3], row[4]) > 90.0,
        "the room at " .. row[3] .. "," .. row[4] .. " holds air")
end

-- A closed door is the view boundary. The player starts in the Commons:
-- an examine in the room succeeds and a forged claim through its west door
-- is refused by the same FOV-filtered seam the browser uses.
assert(t.examine(p, 17, 14) ~= nil, "the player sees their own room")
assert(t.examine(p, 13, 15) == nil, "the west hall stays behind the shut door")

-- Both EVA exits are vestibules: outer door, three tiles of chamber, inner
-- door, with vacuum beyond and air held between the leaves.
for _, row in ipairs({
    { 3, 15, 5, 15, 2, 15, 4, 15 },
    { 36, 15, 34, 15, 37, 15, 35, 15 },
}) do
    assert(t.door_at(row[1], row[2]), "the outer vestibule leaf exists")
    assert(t.door_at(row[3], row[4]), "the inner vestibule leaf exists")
    assert(t.turf(row[5], row[6]) == "space", "the outer leaf opens to space")
    assert(t.turf(row[7], row[8]) == "plating", "the chamber is bare deck")
    assert(t.room_pressure(row[7], row[8]) > 90.0, "the shut vestibule holds air")
end

-- The hull gallery is glazing, not decorative mesh over a hole, and the
-- room behind it holds pressure on the live map.
for _, at in ipairs({ { 29, 3 }, { 30, 3 }, { 31, 3 }, { 3, 23 }, { 36, 25 } }) do
    standing(at[1], at[2], "grille", "reinforced")
    assert(t.turf(at[1], at[2]) == "plating", "the pane replaces the hull on deck")
end
assert(t.turf(30, 2) == "space", "the north gallery looks into vacuum")
assert(t.room_pressure(30, 6) > 90.0, "the cargo bay holds air through its panes")

-- The Common transceiver is commissioned, not merely drawn: it stands
-- on the Commons' north rank at (22, 13), its cord reaches the outlet
-- at (24, 14), and its variant key is seated -- all three asserted in
-- one sentence, because the status line refuses each failure in its
-- own words (lib/radio.luau: dark, keyless, or on the air). The walk
-- is the spawn room's own floor; the empty-hand click is the fixture's
-- gate (fixtures/transceiver.luau). Without this tower the crew's
-- shipped Common headsets make a ten-tile bubble
-- (radio_coverage_test.luau owns that exact boundary).
for _, dir in ipairs({ "east", "east", "east", "east", "north", "north" }) do
    t.move(p, dir)
    t.run_ticks(6)
end
local px, py = t.pos(p)
assert(px == 22 and py == 14, "standing under the Common tower: " .. px .. "," .. py)
local _ = t.messages(p)
t.click(p, 22, 13, t.target_at(22, 13))
t.tick()
local heard = t.messages(p)
local on_air = false
for _, m in ipairs(heard) do
    if m == "The transceiver is on the air, carrying Common." then
        on_air = true
    end
end
assert(on_air,
    "the Commons tower ships powered and keyed: " .. table.concat(heard, " | "))
