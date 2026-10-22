local illnesses = require("@lib/medical/illnesses")
local host_illness = require("@lib/medical/host_illness")

local BREATH_INTERVAL_SECONDS = 8
local AIRBORNE_ELAPSED_SECONDS_VAR = "lunatic/tfs:biology.airborne_elapsed_seconds"
local BIO_PROTECTION_VAR = "lunatic/tfs:biology.bio_protection"
local SPREAD_RANGE = 2
local RANGE_QUERY_RADIUS = 3

type AirborneInventoryRow = {
    item: Handle,
    location: { kind: string, equipment_slot: string? },
    breath_supply: boolean?,
}

local function inventory_rows(body: Handle): { AirborneInventoryRow }
    return sim.inventory(body) :: any
end

local function read_tile(body: Handle): TileAddress
    return body.tile
end

local function wears_breath_mask(body: Handle): boolean
    for _, inventory_item in ipairs(inventory_rows(body)) do
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
    if not body.alive then
        return false
    end
    local capacity = sim.capacity(body, "breathing")
    return capacity ~= nil and capacity > 0
end

local function uses_internals(body: Handle): boolean
    for _, inventory_item in ipairs(inventory_rows(body)) do
        local location_kind = inventory_item.location.kind
        if (location_kind == "hand" or location_kind == "worn")
            and inventory_item.breath_supply == true
        then
            return true
        end
    end
    return false
end

local function source_is_blocked(masked: boolean, internals_active: boolean): boolean
    return masked or internals_active
end

local function body_source_is_blocked(body: Handle): boolean
    return source_is_blocked(wears_breath_mask(body), uses_internals(body))
end

local function bio_protection_from_inventory(inventory: { AirborneInventoryRow }): number
    local protection = 0
    for _, inventory_item in ipairs(inventory) do
        local location = inventory_item.location
        if location.kind == "worn"
            and (location.equipment_slot == "head" or location.equipment_slot == "mask")
        then
            local item_protection = inventory_item.item.vars[BIO_PROTECTION_VAR]
            if type(item_protection) == "number" then
                protection += item_protection
            end
        end
    end
    return math.max(0, math.min(protection, 100))
end

local function bio_protection(body: Handle): number
    return bio_protection_from_inventory(inventory_rows(body))
end

type ProtectionStage = "internals" | "bio"
type ProtectionRoll = (ProtectionStage) -> number

local function protection_allows_catch(
    bio_points: number,
    internals_active: boolean,
    roll: ProtectionRoll
): boolean
    if internals_active and roll("internals") < 0.75 then
        return false
    end
    local bio_probability = math.max(0, math.min(bio_points, 100)) / 100
    if bio_probability > 0 and roll("bio") < bio_probability then
        return false
    end
    return true
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
airborne.bio_protection = bio_protection
airborne.bio_protection_from_inventory = bio_protection_from_inventory
airborne.protection_allows_catch = protection_allows_catch
airborne.source_is_blocked = source_is_blocked
airborne.body_source_is_blocked = body_source_is_blocked
airborne.uses_internals = uses_internals

-- tg: code/datums/diseases/cold.dm:1-12 and code/datums/diseases/_disease.dm:24-60,300-335,419-423.
-- tg: code/datums/diseases/_MobProcs.dm:102-109,136-186 and code/__DEFINES/maths.dm:244-247.
-- The 8 s cadence follows code/modules/mob/living/carbon/life.dm:46-57.
-- Range plus native LOS approximates shared air; it does not model atmos or FOV.
function airborne.on_life(ev: MobLifePayload): ()
    local source = ev.entity
    local previous_elapsed = source.vars[AIRBORNE_ELAPSED_SECONDS_VAR]
    local elapsed_seconds = if type(previous_elapsed) == "number" then previous_elapsed else 0
    local accumulated_seconds = elapsed_seconds + ev.elapsed_seconds
    local breaths_due = math.floor(accumulated_seconds / BREATH_INTERVAL_SECONDS)
    source.vars[AIRBORNE_ELAPSED_SECONDS_VAR] =
        accumulated_seconds - breaths_due * BREATH_INTERVAL_SECONDS
    if breaths_due == 0 then
        return
    end

    if not source.alive then
        return
    end
    local source_facts = sim.body(source)
    if source_facts == nil or source_facts.animate ~= true then
        return
    end
    if not has_working_lungs(source)
        or not can_breathe(source)
        or body_source_is_blocked(source)
    then
        return
    end

    -- A live unplaced body can lack a tile; Handle.tile raises in that case.
    local tile_ok, source_tile = pcall(read_tile, source)
    if not tile_ok or source_tile == nil then
        return
    end

    for _ = 1, breaths_due do
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
                            if target_facts ~= nil
                                and target_facts.animate == true
                                and can_breathe(candidate)
                            then
                                local target_tile = candidate.tile
                                if within_spread_range(source_tile, target_tile)
                                    and sim.query.los(source, candidate)
                                then
                                    local protection_passes = protection_allows_catch(
                                        bio_protection(candidate),
                                        uses_internals(candidate),
                                        function(stage: ProtectionStage): number
                                            return sim.random_for(
                                                "medical.airborne.target." .. stage .. "." .. definition.id,
                                                candidate
                                            )
                                        end
                                    )
                                    if protection_passes
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
    end
end

return airborne
