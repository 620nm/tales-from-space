-- What the station's two big vessels do when somebody fills them past
-- what they are rated to.
--
-- The engine owns the arithmetic (one pass over every vessel that can
-- fail); the numbers are all in the two content files, and this spec
-- is the proof that the numbers reach the pass: a canister rated to
-- 500 000 kPa breaking at 40% of 300 integrity, and a reservoir rated
-- to 46 000 kPa that takes 0.1 a pass and has all shift to be noticed.
--
-- Filling one past its rating is not something a crewman can do -- the
-- station's pumps top out three orders of magnitude below it -- so the
-- charge comes from `t.charge_vessel`, a precondition setter with the
-- standing of `network_matter.heat`. Everything asserted afterwards is what a
-- crewman sees: a pressure, a picture, a look, and the room.

-- ---------------------------------------------------------------
-- THE CANISTER. It does not leak and it does not explode: it hands
-- over everything it is holding at once and stands there split open
-- (tg's `canister_break`).
-- ---------------------------------------------------------------
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "canister bay",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'c': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (2, 1, "player_spawn"),
        (2, 2, "canister", { "blend": "canister_air", "open": true }),
    ],
    rows: [
        "#####",
        "#...#",
        "#.c.#",
        "#...#",
        "#####",
    ],
)]==],
    7
)

local p = t.join()
t.tick()
t.run_seconds(5)

local room_start = assert(t.room_pressure(1, 2))
assert(assert(t.canister_pressure(2, 2)) > 4000.0, "the bottle starts full")

-- Shut the valve first, through the panel, the way a crewman shuts
-- one: a loose canister with its valve open is pointed at the room and
-- would spend itself into the floor instead of straining.
t.click(p, 2, 2, t.target_at(p, 2, 2))
t.tick()
assert(ui_controls.rows(ui_controls.state(p).toggles)[1].field == "valve")
ui_controls.toggle(p, "valve")
t.tick()
assert(ui_controls.rows(ui_controls.state(p).toggles)[1].on == false, "the valve is shut")

-- Sixty times the sticker. tg's damage is the RATIO of pressure to
-- rating, clamped to 5..50 a pass, so this is the ceiling: 300
-- integrity, breaking at 40% of it, is four passes.
assert(t.charge_vessel(2, 2, "n2", 30000000.0), "a canister takes a charge")
-- Open immediately before rupture. The room is already at the valve's
-- release setpoint, so this tick must not drain the charged vessel first.
ui_controls.toggle(p, "valve")
t.tick()
local opened_rows = ui_controls.rows(ui_controls.state(p).toggles)
assert(opened_rows[1].field == "valve", "the canister valve row should remain visible")
assert(opened_rows[1].on == true, "the canister must be open immediately before rupture")
t.run_seconds(4)

local rupture_rows = t.ledger_rows("pressure_ruptured")
assert(#rupture_rows == 1, "the canister should rupture exactly once")
assert(rupture_rows[1].fragment == false, "a canister rupture must not create a fragment")
assert(
    assert(t.canister_pressure(2, 2)) < 1.0,
    "and the canister is empty: " .. assert(t.canister_pressure(2, 2))
)
assert(
    assert(t.room_pressure(1, 2)) > room_start,
    "because the room took all of it: " .. room_start .. " -> " .. assert(t.room_pressure(1, 2))
)

-- It is still there, and it looks like what happened to it.
local broken_target = assert(t.target_at(p, 2, 2), "the broken canister should remain disclosed")
local broken_layers = t.layers(p, broken_target)
local has_broken_sprite = false
for _, sprite in ipairs(broken_layers) do
    if sprite == "canister_broken" then
        has_broken_sprite = true
    end
end
assert(has_broken_sprite, "the disclosed canister should use its broken sprite")

local broken_seen = t.seen(p, broken_target)
local seen_broken_sprite = false
for _, layer in ipairs(broken_seen.layers) do
    if layer.sprite == "canister_broken" then
        seen_broken_sprite = true
    end
end
assert(seen_broken_sprite, "the disclosed canister appearance should include its broken sprite")

local closed_rows = ui_controls.rows(ui_controls.state(p).toggles)
assert(closed_rows[1].field == "valve", "the canister valve row should remain visible after rupture")
assert(closed_rows[1].on == false, "rupture must force the canister valve closed")

-- A broken canister is no longer dense: the player must be able to enter its
-- tile, while the vessel entity itself remains present for inspection.
t.move(p, "south")
t.tick()
local player_x, player_y = t.pos(p)
assert(player_x == 2 and player_y == 2, "the player should walk through a broken canister")

local look = t.examine(p, 2, 2, broken_target)
assert(look ~= nil, "a broken canister is still a thing you can look at")
assert(
    table.concat(look.lines, " | "):find("broken"),
    "and the look says so: " .. table.concat(look.lines, " | ")
)

-- ...AND IT NEVER GOES AGAIN. Breaking is an EDGE and it is crossed
-- once: what it was holding is in the room, so there is nothing left
-- inside to press on anything, and the pass that reads an empty vessel
-- finds nothing to take off it. The two counts below are the whole
-- claim -- a canister that ruptured on every pass would be the largest
-- mutation this model can make, on a loop, for the rest of the shift.
local ruptures = #rupture_rows
local damages = #t.ledger_rows("pressure_damaged")
assert(ruptures == 1, "it went exactly once, got " .. ruptures)
assert(damages > 0, "after the passes that chewed through it: " .. damages)

-- The broken shell is loose, so decompression wind may move it after the
-- immediate appearance, inspection, and walk-through assertions above.
t.run_seconds(12) -- three times the four passes the break itself took

local later_ruptures = #t.ledger_rows("pressure_ruptured")
local later_damages = #t.ledger_rows("pressure_damaged")
assert(later_ruptures == ruptures, "and not a second time: " .. later_ruptures)
assert(later_damages == damages, "nor is it still being damaged: " .. later_damages)

-- Still furniture, a dozen seconds on, wherever the wind left it: the
-- same shell, with a pressure to read and a look to take, and the look
-- still says what happened. Found by the target, over the room's floor.
local shell_x, shell_y = nil, nil
for y = 1, 3 do
    for x = 1, 3 do
        local here = t.target_at(p, x, y, broken_target)
        if here ~= nil and t.same_target(here, broken_target) then
            shell_x, shell_y = x, y
        end
    end
end
assert(shell_x ~= nil and shell_y ~= nil, "the broken shell is still in the room")
local shell_kpa = assert(t.canister_pressure(shell_x, shell_y), "still a canister where it came to rest")
assert(shell_kpa < 1.0, "and still empty: " .. shell_kpa)
local since = assert(t.examine(p, shell_x, shell_y, broken_target), "still a thing you can look at")
assert(
    table.concat(since.lines, " | "):find("broken"),
    "and still says broken: " .. table.concat(since.lines, " | ")
)

-- ---------------------------------------------------------------
-- THE RESERVOIR. Same pass, other rule: one rating, a flat 0.1 a
-- pass past it, and 800 integrity to chew through -- so what a spec
-- can see in a few seconds is the DAMAGE starting, and the sticker
-- being what starts it.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "tank room",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn"), (2, 2, "stationary_tank")],
)]==],
    7
)

local q = t.join()
t.tick()
t.run_seconds(2)

-- Charged to just under the sticker: a full tank is not a failing one,
-- which is the negative that makes the rest mean anything.
assert(t.charge_vessel(2, 2, "n2", 40000.0), "a reservoir takes a charge")
t.run_seconds(5)
assert(#t.ledger_rows("pressure_damaged") == 0, "a tank inside its rating is doing nothing at all")
local look_sound = assert(t.examine(q, 2, 2, t.target_at(q, 2, 2)))
assert(
    not table.concat(look_sound.lines, " | "):find("strain"),
    "and says nothing about strain: " .. table.concat(look_sound.lines, " | ")
)

-- ...and past it, the same tank is visibly working.
assert(t.charge_vessel(2, 2, "n2", 20000.0), "topped up over the sticker")
assert(
    assert(t.tank_pressure(2, 2)) > 46000.0,
    "past tg's max_pressure: " .. assert(t.tank_pressure(2, 2))
)
t.run_seconds(5)

local damage = t.ledger_rows("pressure_damaged")
assert(#damage > 0, "the record shows it taking damage")
local amount = ui_controls.number(damage[1].amount)
assert(math.abs(amount - 0.1) < 1e-4, "at tg's flat 0.1 a pass: " .. tostring(damage[1].amount))
assert(t.tank_pressure(2, 2) ~= nil, "and it is still standing -- 800 integrity is most of a shift")
local strained = assert(t.examine(q, 2, 2, t.target_at(q, 2, 2)))
assert(
    table.concat(strained.lines, " | "):find("strain"),
    "which is what a look says: " .. table.concat(strained.lines, " | ")
)
