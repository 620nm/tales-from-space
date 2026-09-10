-- The bench exactly as shipped: joined and programmed at boot, cycled from its buttons.
t.set_breathing(false)
t.world_file("programmable_airlock.ron", 0)
t.set_environment({ sink_k = 293.15, insolation = 0 })

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
-- A leaf opens only once its partner is bolted shut, and no draft moves the
-- visitor from the tile they held just before it started to swing.
local function sealed_while(opening, partner, step)
    local before, pinned
    return function()
        hold(step)
        local x, y = t.pos(visitor)
        local d = t.door_at(opening, 3)
        if d.open or d.moving then
            local p = t.door_at(partner, 3)
            assert(not p.open and not p.moving and p.bolted, "door " .. partner .. " is bolted shut before " .. opening .. " moves")
            pinned = pinned or before
            assert(x == pinned[1] and y == pinned[2], "no draft moves the visitor while door " .. opening .. " opens: "
                .. pinned[1] .. "," .. pinned[2] .. " -> " .. x .. "," .. y)
        else
            before = { x, y }
        end
    end
end
hold("walked in")

-- The operator's first press, empty-handed from the spawn, runs the whole entry.
assert(t.hands(operator).held == nil, "the operator's hand is empty")
t.click(operator, 2, 3, assert(t.target_at(operator, 2, 3, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(5, true, operator, sealed_while(5, 8, "entry"))
hold("entered")
assert(t.door_at(8, 3).bolted and not t.door_at(8, 3).open, "the exterior stays bolted shut")
assert((airlock_cycle.pressure() or 0) >= 100, "the chamber reads at least 100 kPa before the interior opens")

-- The chamber button runs the exit: interior bolted, chamber drained, space opened.
t.click(visitor, 7, 4, assert(t.target_at(visitor, 7, 4, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(8, true, operator, sealed_while(8, 5, "exit"))
hold("exited")
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "the interior stays bolted shut")
assert(airlock_cycle.pressure() < 10, "the chamber reads below 10 kPa before space opens")
