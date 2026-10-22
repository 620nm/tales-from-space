local contagion = {}

local illnesses = require("@lib/medical/illnesses")
local disinfection = require("@lib/medical/disinfection")

contagion.KIND = "contagion"

export type FluidExposure = (body: Handle, indices: { number }) -> ()

type RiderRead = {
    id: string,
    fields: { [any]: any },
    pending: boolean?,
}

local function canonical_indices(indices: { number }): { number }
    local seen: { [number]: boolean } = {}
    local canonical: { number } = {}
    for _, index in ipairs(indices) do
        if typeof(index) ~= "number"
            or index ~= index
            or index < 0
            or index % 1 ~= 0
            or illnesses.get(index) == nil
        then
            error("invalid contagion illness index")
        end
        if not seen[index] then
            seen[index] = true
            table.insert(canonical, index)
        end
    end
    table.sort(canonical)
    return canonical
end

local function rider_rows(owner: Handle): { RiderRead }?
    if not owner.alive then
        return nil
    end
    return sim.riders(owner) :: { RiderRead }?
end

local function row_indices(row: RiderRead): { number }
    local raw = row.fields.illnesses
    if typeof(raw) ~= "table" then
        error("contagion rider has no illness reference set")
    end
    return canonical_indices(raw :: { number })
end

local function same_indices(left: { number }, right: { number }): boolean
    if #left ~= #right then
        return false
    end
    for index, value in ipairs(left) do
        if value ~= right[index] then
            return false
        end
    end
    return true
end

local function settled_matches(rows: { RiderRead }?, desired: { number }): boolean
    if rows == nil then
        return false
    end
    local count = 0
    for _, row in ipairs(rows) do
        if row.id == contagion.KIND then
            count += 1
            if count ~= 1 or row.pending == true then
                return false
            end
            if not same_indices(row_indices(row), desired) then
                return false
            end
        end
    end
    return count == 1
end

local function has_rider(rows: { RiderRead }?): boolean
    if rows == nil then
        return false
    end
    for _, row in ipairs(rows) do
        if row.id == contagion.KIND then
            return true
        end
    end
    return false
end

function contagion.indices(owner: Handle): { number }
    local found: { [number]: boolean } = {}
    local rows = rider_rows(owner)
    if rows ~= nil then
        for _, row in ipairs(rows) do
            if row.id == contagion.KIND then
                for _, index in ipairs(row_indices(row)) do
                    found[index] = true
                end
            end
        end
    end
    local result: { number } = {}
    for index, present in pairs(found) do
        if present then
            table.insert(result, index)
        end
    end
    table.sort(result)
    return result
end

function contagion.replace_indices(owner: Handle, indices: { number }): ()
    local desired = canonical_indices(indices)
    if not owner.alive then
        return
    end

    local rows = rider_rows(owner)
    if #desired == 0 then
        if has_rider(rows) then
            sim.clear_rider(owner, contagion.KIND)
        end
        return
    end

    if rows == nil then
        error("cannot write contagion without owner matter")
    end
    if settled_matches(rows, desired) then
        return
    end
    sim.set_rider(owner, contagion.KIND, { illnesses = desired })
end

function contagion.seed_vessel(vessel: Handle, ids: { string }): ()
    local requested: { number } = {}
    for _, id in ipairs(ids) do
        if typeof(id) ~= "string" then
            error("invalid contagion illness id")
        end
        local index = illnesses.index_of(id)
        if index == nil then
            error("unknown contagion illness id")
        end
        table.insert(requested, index)
    end

    local combined = contagion.indices(vessel)
    for _, index in ipairs(requested) do
        table.insert(combined, index)
    end
    local desired = canonical_indices(combined)
    if not vessel.alive then
        return
    end
    contagion.replace_indices(vessel, desired)
    disinfection.arrived(vessel, desired)
end

local function on_arrived(expose_fluid: FluidExposure, ev: MatterRiderArrivedPayload): ()
    if ev.rider ~= contagion.KIND or ev.outcome ~= "completed" then
        return
    end
    local indices = contagion.indices(ev.holder)
    if ev.body ~= nil then
        expose_fluid(ev.body, indices)
    else
        disinfection.arrived(ev.holder, indices)
    end
end

local function on_meet(expose_fluid: FluidExposure, ev: MatterRiderMeetPayload): ()
    if ev.rider ~= contagion.KIND or ev.outcome ~= "completed" then
        return
    end
    local indices = contagion.indices(ev.holder)
    if ev.body ~= nil then
        -- Exposure owns host acceptance and synchronizes the bloodstream rider.
        expose_fluid(ev.body, indices)
        return
    end

    contagion.replace_indices(ev.holder, indices)
    disinfection.arrived(ev.holder, indices)
end

local function on_cleared(ev: MatterRiderClearedPayload): ()
    if ev.rider == contagion.KIND and ev.outcome == "completed" and ev.body == nil then
        disinfection.cleared(ev.holder)
    end
end

function contagion.attach(expose_fluid: FluidExposure): ()
    local definition = sim.define("behavior", "lunatic/tfs:" .. contagion.KIND, {
        prototype = contagion.KIND,
    })
    definition:handle("matter.rider.arrived", { kind = "react" }, function(ev: MatterRiderArrivedPayload): ()
        on_arrived(expose_fluid, ev)
    end)
    definition:handle("matter.rider.meet", { kind = "react" }, function(ev: MatterRiderMeetPayload): ()
        on_meet(expose_fluid, ev)
    end)
    definition:handle("matter.rider.cleared", { kind = "observe" }, on_cleared)
end

return contagion
