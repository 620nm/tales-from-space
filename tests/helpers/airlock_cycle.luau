-- One airlock cycle as a spec watches it: a press the guest accepted, then a
-- leaf at rest and bolted with the guest idle and the controller unfaulted.
local cycle = {}
local FAULT = "The controller has stopped the airlock cycle."

-- A press mark: how many guest runs the ledger holds just before a press.
function cycle.mark()
    return #t.ledger_rows("disl_run")
end

local function watch_rows()
    local rows = {}
    for _, row in ipairs(t.ledger_rows("machine_setpoint")) do
        if row.field == "pressure_watch_result" then table.insert(rows, row) end
    end
    return rows
end
-- The latest native pressure-watch completion, in kPa.
function cycle.pressure()
    local rows = watch_rows()
    return rows[#rows] and rows[#rows].value
end
-- How many pressure watches have completed so far.
function cycle.watches()
    return #watch_rows()
end

-- Whether the guest accepted a press after `since` and a later run went idle.
local function settled(since)
    local runs = t.ledger_rows("disl_run")
    local accepted
    for index = since + 1, #runs do
        local row = runs[index]
        local value = row.value and row.value.Map
        if row.env.Map.event.Map.kind.String == "button" and value and value.accepted and value.accepted.Bool then
            accepted = index
        end
    end
    if accepted == nil then return false end
    local latest, idle_tick
    for index = accepted + 1, #runs do
        local value = runs[index].value and runs[index].value.Map
        if value and value.status then
            latest = value.status.String
            if latest == "idle" then idle_tick = runs[index].tick end
        end
    end
    if latest ~= "idle" then return false end
    for _, row in ipairs(t.ledger_rows("disl_fault")) do
        assert(row.tick < idle_tick, "the guest faulted after going idle: " .. tostring(row.fault))
    end
    return true
end

-- Step until the door at (x, 3) rests `open` and bolted once the press marked
-- `since` has settled; `each` runs before every step. Fails as soon as `observer`
-- hears the controller stop the cycle; returns everything `observer` heard.
function cycle.until_door(x, open, observer, since, each)
    local heard = {}
    for _ = 1, 160 do
        if each then each() end
        for _, line in ipairs(t.messages(observer)) do
            table.insert(heard, line)
            assert(not line:find(FAULT, 1, true), "the controller stopped the cycle: " .. table.concat(heard, " | "))
        end
        local d = t.door_at(x, 3)
        if d.open == open and d.bolted and not d.moving and settled(since) then return heard end
        t.run_ticks(4)
    end
    local debug = { "sounds=" .. table.concat(t.sounds(observer), ","), "messages=" .. table.concat(heard, " | ") }
    for _, row in ipairs(t.ledger_rows("disl_fault")) do table.insert(debug, "fault=" .. tostring(row.fault) .. ":" .. tostring(row.message)) end
    for _, row in ipairs(t.ledger_rows("script_error")) do table.insert(debug, "script=" .. tostring(row.file) .. ":" .. tostring(row.why)) end
    for _, row in ipairs(t.ledger_rows("script_var_refused")) do table.insert(debug, "var=" .. tostring(row.why)) end
    local runs = t.ledger_rows("disl_run")
    for index = math.max(1, #runs - 14), #runs do
        local row = runs[index]
        local event = row.env.Map.event.Map
        local value = row.value and row.value.Map
        table.insert(debug, event.kind.String .. ":" .. (event.id and event.id.String or "") .. " -> "
            .. tostring(value and value.status and value.status.String))
    end
    error("door rest x=" .. x .. " since=" .. since .. " pressure=" .. t.room_pressure(6, 3) .. " " .. table.concat(debug, " | "))
end

return cycle
