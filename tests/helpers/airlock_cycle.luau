-- One airlock cycle as a spec watches it: a press the guest accepted, then a
-- leaf at rest and bolted with the guest idle and the controller unfaulted.
local cycle = {}
local FAULT = "The controller has stopped the airlock cycle."

-- A press mark: how many guest runs the ledger holds just before a press.
function cycle.mark(): number
    return #t.ledger_rows("disl_run")
end

local function watch_rows(): { SpecLedgerRow }
    local rows: { SpecLedgerRow } = {}
    for _, row in ipairs(t.ledger_rows("machine_setpoint")) do
        if row.field == "pressure_watch_result" then
            table.insert(rows, row)
        end
    end
    return rows
end
-- The latest native pressure-watch completion, in kPa.
function cycle.pressure(): number?
    local rows = watch_rows()
    local row = rows[#rows]
    if row == nil then
        return nil
    end
    local value = row.value
    assert(type(value) == "number", "pressure watch reports a numeric result")
    return value
end
-- How many pressure watches have completed so far.
function cycle.watches(): number
    return #watch_rows()
end

-- Whether the guest handled a press after `since`; the door state checked by
-- the caller is the authoritative idle result. Transcript payloads are
-- bounded hashes and intentionally do not expose event map keys.
local function settled(since: number): boolean
    local runs = t.ledger_rows("disl_run")
    return #runs > since
end

-- Step `step` ticks (4) at a time until the door at (x, 3) rests `open` and bolted
-- once the press marked `since` settled; `each` runs before every step. Fails as soon
-- as `observer` hears the controller stop the cycle; returns all `observer` heard.
function cycle.until_door(
    x: number,
    open: boolean,
    observer: number,
    since: number,
    each: (() -> ())?,
    step: number?
): { string }
    step = step or 4
    local heard: { string } = {}
    for _ = 1, math.ceil(640 / step) do
        if each then
            each()
        end
        for _, line in ipairs(t.messages(observer)) do
            table.insert(heard, line)
            assert(
                not line:find(FAULT, 1, true),
                "the controller stopped the cycle: " .. table.concat(heard, " | ")
            )
        end
        local d = assert(t.door_at(x, 3), "the watched door exists")
        if d.open == open and d.bolted and not d.moving and settled(since) then
            return heard
        end
        t.run_ticks(step)
    end
    local debug = {
        "sounds=" .. table.concat(t.sounds(observer), ","),
        "messages=" .. table.concat(heard, " | "),
    }
    for _, row in ipairs(t.ledger_rows("disl_fault")) do
        table.insert(debug, "fault=" .. tostring(row.fault) .. ":" .. tostring(row.message))
    end
    for _, row in ipairs(t.ledger_rows("script_error")) do
        table.insert(debug, "script=" .. tostring(row.file) .. ":" .. tostring(row.why))
    end
    for _, row in ipairs(t.ledger_rows("script_var_refused")) do
        table.insert(debug, "var=" .. tostring(row.why))
    end
    local runs = t.ledger_rows("disl_run")
    table.insert(debug, "runs=" .. tostring(#runs) .. " since=" .. tostring(since))
    error(
        "door rest x="
            .. x
            .. " since="
            .. since
            .. " pressure="
            .. tostring(t.room_pressure(6, 3))
            .. " "
            .. table.concat(debug, " | ")
    )
end

return cycle
