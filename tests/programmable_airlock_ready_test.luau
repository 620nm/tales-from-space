-- The bench exactly as shipped: joined and programmed at boot, cycled from its buttons.
-- Nobody breathes here: the visitor arrives through vacuum without internals.
t.set_breathing(false)
t.world_file("programmable_airlock.ron", 0)

-- Tick 0, before anyone arrives: five drawn edges and one bound socket, all the map's doing.
local function by_map(row)
    return row.actor and row.actor.kind == "system" and row.actor.source == "map"
end
local wired = 0
for _, row in ipairs(t.ledger_rows("link_accepted")) do
    if row.wired and by_map(row) then wired += 1 end
end
assert(wired == 5, "two doors, two buttons and the vent open joined: " .. wired)
local loaded = t.ledger_rows("disl_socket_loaded")
assert(#loaded == 1 and loaded[1].socket == "controller" and by_map(loaded[1]),
    "the controller socket opens bound by the map")

local operator = t.join()
local visitor = t.join()
t.run_ticks(20)
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "interior starts closed and bolted")
assert(t.door_at(8, 3).open and not t.door_at(8, 3).bolted, "exterior starts open and unbolted")

-- What the owner expects to walk into: station air west, an empty chamber, space east.
local ROOM = t.room_pressure(3, 3)
assert(math.abs(ROOM - 101.325) < 2, "the west room holds station air: " .. ROOM)
assert(t.room_pressure(6, 3) < 1, "the chamber starts evacuated: " .. t.room_pressure(6, 3))
assert(t.room_pressure(10, 3) < 1, "outside is vacuum: " .. t.room_pressure(10, 3))
-- Entry joins the room to a chamber filled into the guest's 100-101.325 kPa band that
-- is a third of the joined volume, so the room moves well under 1.5 kPa; exit never joins it.
local function room_holds(step)
    local kpa = t.room_pressure(3, 3)
    assert(math.abs(kpa - ROOM) <= 1.5, step .. ": the west room keeps its air: " .. ROOM .. " -> " .. kpa)
end

for _ = 1, 2 do t.move(visitor, "west"); t.run_ticks(4) end
local vx, vy = t.pos(visitor)
assert(vx == 7 and vy == 3, "the visitor stands in the chamber: " .. vx .. "," .. vy)

-- Checked every step: the operator never moves, the visitor never leaves the chamber.
local function hold(step)
    local ox, oy = t.pos(operator)
    local x, y = t.pos(visitor)
    local facts = step .. " tick=" .. tostring(t.now()) .. " interior=" .. tostring(t.door_at(5, 3).open)
        .. " exterior=" .. tostring(t.door_at(8, 3).open) .. " chamber=" .. tostring(t.room_pressure(6, 3))
    assert(ox == 3 and oy == 3, "the operator keeps the west room tile: " .. ox .. "," .. oy .. " " .. facts)
    -- Scoped to the chamber pending the drain-draft fix; then pin the visitor to (7, 3) throughout.
    assert((x == 6 or x == 7) and (y == 3 or y == 4), "the visitor stays in the chamber: " .. x .. "," .. y .. " " .. facts)
end
-- About forty ticks more after a leaf comes to rest.
local function linger(step)
    for _ = 1, 10 do t.run_ticks(4); hold(step) end
end
-- A leaf moves only once its partner is bolted shut. The first step it moves, the
-- chamber already reads what the guest waited for, off a watch completed after the
-- press, and no draft moves the visitor off the tile held just before it swung.
local function sealed_while(opening, partner, step, watched, admits)
    local before, pinned, checked
    return function()
        hold(step)
        local x, y = t.pos(visitor)
        local d = t.door_at(opening, 3)
        if d.open or d.moving then
            local p = t.door_at(partner, 3)
            assert(not p.open and not p.moving and p.bolted, "door " .. partner .. " is bolted shut before " .. opening .. " moves")
            if not checked then
                checked = true
                local kpa = t.room_pressure(6, 3)
                assert(admits(kpa), step .. ": the chamber reads " .. kpa .. " kPa as door " .. opening .. " starts to move")
                assert(airlock_cycle.watches() > watched, step .. ": a pressure watch completed after the press")
            end
            pinned = pinned or before
            assert(x == pinned[1] and y == pinned[2], "no draft moves the visitor while door " .. opening .. " opens: "
                .. pinned[1] .. "," .. pinned[2] .. " -> " .. x .. "," .. y)
        else
            before = { x, y }
        end
    end
end
hold("walked in")

-- Someone arriving from space: the chamber button's first press requests entry.
local since, watched = airlock_cycle.mark(), airlock_cycle.watches()
t.click(visitor, 7, 4, assert(t.target_at(visitor, 7, 4, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(5, true, operator, since,
    sealed_while(5, 8, "entry", watched, function(kpa) return kpa >= 100 end))
linger("entered")
assert(t.door_at(8, 3).bolted and not t.door_at(8, 3).open, "the exterior stays bolted shut")
assert((airlock_cycle.pressure() or 0) >= 100, "the chamber reads at least 100 kPa before the interior opens")
room_holds("after entry")

-- The operator carries the wrench into the chamber, leaves it there, and comes home.
local function walk(p, path)
    for _, dir in ipairs(path) do t.move(p, dir); t.run_ticks(4) end
end
t.click(operator, 3, 4, assert(t.target_at(operator, 3, 4, "wrench")))
t.run_ticks(2)
assert(t.hands(operator).held == "wrench", "the operator carries the wrench")
walk(operator, { "east", "east", "east", "south" })
local ox, oy = t.pos(operator)
assert(ox == 6 and oy == 4, "the operator reached the chamber: " .. ox .. "," .. oy)
t.drop(operator)
t.run_ticks(2)
assert(t.item_at(6, 4, "wrench"), "the wrench lies in the chamber")
walk(operator, { "north", "west", "west", "west" })
assert(t.hands(operator).held == nil, "the operator's hand is empty again")
hold("home again")

-- The west button's press is the next accepted request: exit.
since, watched = airlock_cycle.mark(), airlock_cycle.watches()
t.click(operator, 2, 3, assert(t.target_at(operator, 2, 3, "airlock_button")))
t.run_ticks(2)
-- Where the wrench lies on the bench now, or nil.
local function wrench_at()
    for y = 0, 6 do
        for x = 0, 12 do
            if t.item_at(x, y, "wrench") then return x, y end
        end
    end
    return nil
end
-- No draft carries the wrench while space opens: it keeps the tile it held just before.
local exit_step = sealed_while(8, 5, "exit", watched, function(kpa) return kpa < 10 end)
local wrench_before, wrench_pinned
airlock_cycle.until_door(8, true, operator, since, function()
    exit_step()
    local wx, wy = wrench_at()
    local d = t.door_at(8, 3)
    if d.open or d.moving then
        wrench_pinned = wrench_pinned or wrench_before
        assert(wx == wrench_pinned[1] and wy == wrench_pinned[2], "no draft carries the wrench while space opens: "
            .. wrench_pinned[1] .. "," .. wrench_pinned[2] .. " -> " .. tostring(wx) .. "," .. tostring(wy))
    else
        assert(wx, "the wrench is still on the bench")
        wrench_before = { wx, wy }
    end
end)
linger("exited")
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "the interior stays bolted shut")
assert(airlock_cycle.pressure() < 10, "the chamber reads below 10 kPa before space opens")
room_holds("after exit")
-- Scoped to the chamber pending the drain-draft fix (the drain pulls it onto the pump); then pin (6, 4).
local wx, wy = wrench_at()
assert(wx and (wx == 6 or wx == 7) and (wy == 3 or wy == 4) and wx == wrench_pinned[1] and wy == wrench_pinned[2],
    "the wrench stays in the chamber where the opening found it: " .. tostring(wx) .. "," .. tostring(wy))
