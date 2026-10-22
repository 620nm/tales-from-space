local illnesses = require("@lib/medical/illnesses")
local host_illness = require("@lib/medical/host_illness")

local BREATH_INTERVAL_SECONDS = 8
local SPREAD_RANGE = 2
local RANGE_QUERY_RADIUS = 3

local function read_tile(body: Handle): TileAddress
    return body.tile
end

local function wears_breath_mask(body: Handle): boolean
    for _, inventory_item in ipairs(sim.inventory(body)) do
        local item = inventory_item.item
        if inventory_item.location.kind == "worn"
            and (item.prototype == "breath_mask" or item.base == "breath_mask")
        then
            return true
        end
    end
    return false
end

local function can_breathe(body: Handle): boolean
    if not body.alive or wears_breath_mask(body) then
        return false
    end
    local capacity = sim.capacity(body, "breathing")
    return capacity ~= nil and capacity > 0
end

type OrganSocket = { ok: boolean }
type SocketMap = { [string]: OrganSocket | false }

local function has_working_lungs(body: Handle): boolean
    local sockets = sim.sockets(body) :: SocketMap?
    if sockets == nil then
        return false
    end
    local lungs = sockets.lungs
    return lungs ~= nil and lungs ~= false and lungs.ok == true
end

local function within_spread_range(origin: TileAddress, target: TileAddress): boolean
    local dx = math.abs(origin.absolute_x - target.absolute_x)
    local dy = math.abs(origin.absolute_y - target.absolute_y)
    return math.max(dx, dy) <= SPREAD_RANGE
end

local airborne = {}

-- tg: code/datums/diseases/cold.dm:1-12 and code/datums/diseases/_disease.dm:24-60,300-335,419-423.
-- tg: code/datums/diseases/_MobProcs.dm:102-109,136-186 and code/__DEFINES/maths.dm:244-247.
-- The 8 s cadence follows code/modules/mob/living/carbon/life.dm:46-57.
-- Range plus native LOS approximates shared air; it does not model atmos or FOV.
function airborne.on_life(ev: MobLifePayload): ()
    if sim.tick() % sim.ticks(BREATH_INTERVAL_SECONDS) ~= 0 then
        return
    end

    local source = ev.entity
    if not source.alive then
        return
    end
    local source_facts = sim.body(source)
    if source_facts == nil or source_facts.animate ~= true then
        return
    end
    if not has_working_lungs(source) or not can_breathe(source) then
        return
    end

    -- A live unplaced body can lack a tile; Handle.tile raises in that case.
    local tile_ok, source_tile = pcall(read_tile, source)
    if not tile_ok or source_tile == nil then
        return
    end

    for _, infection in ipairs(host_illness.snapshot(source)) do
        local definition = illnesses.get(infection.index)
        if definition ~= nil then
            local breath_probability = 1 - math.pow(1 - (definition.infectivity * 4) / 100, 2)
            local source_purpose = "medical.airborne.source." .. definition.id
            if sim.random_for(source_purpose, source) < breath_probability then
                local exposure_probability = math.min(50 * definition.spreading_modifier - 1, 50) / 100
                local target_purpose = "medical.airborne.target." .. definition.id
                local exposure_indices = { infection.index }

                for _, candidate in ipairs(sim.query.range(source_tile, RANGE_QUERY_RADIUS, {})) do
                    if candidate ~= source and candidate.alive then
                        local target_facts = sim.body(candidate)
                        if target_facts ~= nil and target_facts.animate == true and can_breathe(candidate) then
                            local target_tile = candidate.tile
                            if within_spread_range(source_tile, target_tile)
                                and sim.query.los(source, candidate)
                                and sim.random_for(target_purpose, candidate) < exposure_probability
                            then
                                host_illness.expose(candidate, exposure_indices, "airborne")
                            end
                        end
                    end
                end
            end
        end
    end
end

return airborne
