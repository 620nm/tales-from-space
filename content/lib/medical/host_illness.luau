local host_illness = {}

local illnesses = require("@lib/medical/illnesses")
local contagion = require("@lib/medical/contagion")
local illness_course = require("@lib/medical/illness_course")

export type ExposureRoute = "fluid" | "airborne"

export type InfectionSnapshot = {
    id: string,
    index: number,
    stage: number,
    max_stages: number,
}

type InfectionRecord = illness_course.InfectionRecord
type IllnessDefinition = illnesses.IllnessDefinition
type ResistanceMap = { [string]: boolean }
type OrganSocket = { ok: boolean }
type SocketMap = { [string]: OrganSocket | false }

local INFECTIONS_KEY = "lunatic/tfs:illnesses"
local RESISTANCE_KEY = "lunatic/tfs:illness_resistance"

local function valid_number(value: any): boolean
    return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function read_infections(body: Handle): { InfectionRecord }
    return illness_course.copy_records(sim.var(body, INFECTIONS_KEY))
end

local function copy_resistance(body: Handle): ResistanceMap
    local raw: any = sim.var(body, RESISTANCE_KEY)
    local resistance: ResistanceMap = {}
    if typeof(raw) ~= "table" then
        return resistance
    end
    for id, immune in pairs(raw) do
        if typeof(id) == "string" and immune == true then
            resistance[id] = true
        end
    end
    return resistance
end

local function write_infections(body: Handle, records: { InfectionRecord }): ()
    sim.script_var.set({ scope = body, key = INFECTIONS_KEY, value = records })
end

local function write_resistance(body: Handle, resistance: ResistanceMap): ()
    sim.script_var.set({ scope = body, key = RESISTANCE_KEY, value = resistance })
end

local function active_indices(records: { InfectionRecord }, state: any): { number }
    local indices: { number } = {}
    if state == nil or not valid_number(state.blood) or state.blood <= 0 then
        return indices
    end
    for _, infection in ipairs(records) do
        table.insert(indices, infection.index)
    end
    return indices
end

local function synchronize_blood(body: Handle, records: { InfectionRecord }, state: any): ()
    contagion.replace_indices(body, active_indices(records, state))
end

local function sockets_for(body: Handle): SocketMap?
    return sim.sockets(body) :: SocketMap?
end

local function has_required_organs(sockets: SocketMap?, definition: IllnessDefinition): boolean
    if sockets == nil then
        return false
    end
    for _, id in ipairs(definition.required_organs) do
        local socket = sockets[id]
        if socket == nil or socket == false or not socket.ok then
            return false
        end
    end
    return true
end

local function can_host(body: Handle, state: any): boolean
    return body.alive and state ~= nil and state.animate and state.plan == "human"
end

local function grant_resistance(resistance: ResistanceMap, illness_id: string): ResistanceMap
    local next_resistance: ResistanceMap = {}
    for id, immune in pairs(resistance) do
        if immune then
            next_resistance[id] = true
        end
    end
    next_resistance[illness_id] = true
    return next_resistance
end

function host_illness.snapshot(body: Handle): { InfectionSnapshot }
    local rows: { InfectionSnapshot } = {}
    if not body.alive then
        return rows
    end
    for _, infection in ipairs(read_infections(body)) do
        local definition = illnesses.get(infection.index)
        if definition ~= nil then
            table.insert(rows, {
                id = definition.id,
                index = definition.index,
                stage = infection.stage,
                max_stages = definition.max_stages,
            })
        end
    end
    return rows
end

function host_illness.resistant(body: Handle, id: string): boolean
    if not body.alive then
        return false
    end
    local resistance: any = sim.var(body, RESISTANCE_KEY)
    return typeof(resistance) == "table" and resistance[id] == true
end

function host_illness.expose(body: Handle, indices: { number }, route: ExposureRoute): ()
    if not body.alive then
        return
    end

    local state = sim.body.read(body)
    if state == nil then
        contagion.replace_indices(body, {})
        return
    end

    local records = read_infections(body)
    if not can_host(body, state) then
        synchronize_blood(body, records, state)
        return
    end

    local sockets = sockets_for(body)
    local can_accept = sockets ~= nil
    if route == "fluid" then
        local heart = sockets and sockets.heart
        can_accept = can_accept
            and heart ~= nil
            and heart ~= false
            and heart.ok
            and valid_number(state.blood)
            and state.blood > 0
    elseif route ~= "airborne" then
        can_accept = false
    end

    if can_accept then
        local resistance = copy_resistance(body)
        local active: { [number]: boolean } = {}
        local prior_count = #records
        for _, infection in ipairs(records) do
            active[infection.index] = true
        end

        for _, index in ipairs(illness_course.canonical_indices(indices)) do
            local definition = illnesses.get(index)
            if definition ~= nil
                and has_required_organs(sockets, definition)
                and not active[index]
                and resistance[definition.id] ~= true
            then
                table.insert(records, {
                    id = definition.id,
                    index = definition.index,
                    stage = 1,
                    half_stage = false,
                    stage_peaked = false,
                    peaked_cycles = 0,
                })
                active[index] = true
            end
        end
        table.sort(records, function(left: InfectionRecord, right: InfectionRecord): boolean
            return left.index < right.index
        end)
        if #records > prior_count then
            write_infections(body, records)
        end
    end

    synchronize_blood(body, records, state)
end

function host_illness.attach(): ()
    sim.define("script_var", INFECTIONS_KEY, { replicate = "server", private = true })
    sim.define("script_var", RESISTANCE_KEY, { replicate = "server", private = true })
end

function host_illness.on_life(ev: MobLifePayload): ()
    local body = ev.entity
    if not body.alive then
        return
    end

    local state = sim.body.read(body)
    if not can_host(body, state) then
        return
    end

    local elapsed_seconds = ev.elapsed_seconds
    if not valid_number(elapsed_seconds) or elapsed_seconds <= 0 then
        return
    end

    local records = read_infections(body)
    local resistance = copy_resistance(body)
    local next_records: { InfectionRecord } = {}
    local resistance_changed = false
    local sockets = sockets_for(body)

    for _, infection in ipairs(records) do
        local definition = illnesses.get(infection.index)
        if definition ~= nil and has_required_organs(sockets, definition) then
            local result = illness_course.tick(body, definition, infection, state, elapsed_seconds)
            if result.cured then
                if result.resistance then
                    resistance = grant_resistance(resistance, infection.id)
                    resistance_changed = true
                end
            else
                table.insert(next_records, infection)
            end
        end
    end

    if #records > 0 then
        write_infections(body, next_records)
    end
    if resistance_changed then
        write_resistance(body, resistance)
    end
    synchronize_blood(body, next_records, sim.body.read(body))
end

return host_illness
