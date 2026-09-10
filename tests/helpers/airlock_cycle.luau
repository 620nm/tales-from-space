-- One airlock cycle as a spec watches it: a leaf at rest and bolted, the guest idle.
local cycle = {}

-- The latest native pressure-watch completion, in kPa.
function cycle.pressure()
    local found
    for _, row in ipairs(t.ledger_rows("machine_setpoint")) do
        if row.field == "pressure_watch_result" then found = row.value end
    end
    return found
end

-- Step until the door at (x, 3) rests `open`, bolted, with the guest idle.
-- `each` runs before every step; a timeout quotes what `observer` heard.
function cycle.until_door(x, open, observer, each)
    for _ = 1, 160 do
        if each then each() end
        local d = t.door_at(x, 3)
        local latest_status
        for _, row in ipairs(t.ledger_rows("disl_run")) do
            local value = row.value.Map
            if value and value.status then latest_status = value.status.String end
        end
        if d.open == open and d.bolted and not d.moving and latest_status == "idle" then return end
        t.run_ticks(4)
    end
    local debug = { "sounds=" .. table.concat(t.sounds(observer), ","),
        "messages=" .. table.concat(t.messages(observer), " | ") }
    for _, row in ipairs(t.ledger_rows("disl_fault")) do table.insert(debug, "fault=" .. tostring(row.fault) .. ":" .. tostring(row.message)) end
    for _, row in ipairs(t.ledger_rows("script_error")) do table.insert(debug, "script=" .. tostring(row.file) .. ":" .. tostring(row.why)) end
    for _, row in ipairs(t.ledger_rows("script_var_refused")) do table.insert(debug, "var=" .. tostring(row.why)) end
    local runs = t.ledger_rows("disl_run")
    for index = math.max(1, #runs - 14), #runs do
        local row = runs[index]
        local event = row.env.Map.event.Map
        table.insert(debug, event.kind.String .. ":" .. (event.id and event.id.String or "") .. " -> "
            .. tostring(row.value.Map and row.value.Map.status and row.value.Map.status.String))
    end
    error("door rest x=" .. x .. " pressure=" .. t.room_pressure(6, 3) .. " " .. table.concat(debug, " | "))
end

return cycle
