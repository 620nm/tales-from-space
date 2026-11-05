-- The gas turbine's three installable parts and the ladder each climbs,
-- tg's `/obj/item/turbine_parts` (code/modules/power/turbine/turbine_parts.dm).
-- One socket kind per section; four tiers (TURBINE_PART_TIER_ONE..FOUR,
-- code/__DEFINES/turbine_defines.dm:26-29). `component.efficiency` carries
-- tg's TURBINE_MAX_EFFICIENCY verbatim rather than this pack's stock-part
-- ladder (lib/stock_parts.luau). The rated rpm and temperature each tier
-- carries are said on the part's examine line (`examine`) and are the
-- ratings the running turbine reads (lib/power/gas_turbine_record.luau).
export type PartKind = "compressor" | "rotor" | "stator"

local turbine_parts = {}

turbine_parts.TIERS = 4

-- `get_tier_value(TURBINE_MAX_EFFICIENCY)`: 0.25, then +0.2 a tier
-- (turbine_parts.dm:49-53); the stator's override starts at 0.85 and adds
-- 0.015 (turbine_parts.dm:107-115).
local EFFICIENCY_BASE: { [PartKind]: number } = { compressor = 0.25, rotor = 0.25, stator = 0.85 }
local EFFICIENCY_STEP: { [PartKind]: number } = { compressor = 0.2, rotor = 0.2, stator = 0.015 }

function turbine_parts.efficiency(kind: PartKind, tier: number): number
    return EFFICIENCY_BASE[kind] + EFFICIENCY_STEP[kind] * (tier - 1)
end

-- `get_tier_value(TURBINE_MAX_RPM)`: TURBINE_MAX_BASE_RPM (50000,
-- turbine_defines.dm:8), times 2.5 a tier (turbine_parts.dm:37-41).
function turbine_parts.max_rpm(tier: number): number
    return 50000 * math.pow(2.5, tier - 1)
end

-- `get_tier_value(TURBINE_MAX_TEMP)`: 50000 K, raised to the 1.2th power a
-- tier (turbine_parts.dm:43-47).
function turbine_parts.max_temperature_k(tier: number): number
    local value = 50000
    for _ = 2, tier do
        value = math.pow(value, 1.2)
    end
    return value
end

-- What each part is, in the pack's words (tg's descs are
-- turbine_parts.dm:94, :99, :104).
local PURPOSE: { [PartKind]: string } = {
    compressor = "A ring of compressor blades, cut to fit a turbine's intake.",
    rotor = "A balanced turbine shaft, the part a core rotor turns on.",
    stator = "A stator ring that a turbine's exhaust is driven through.",
}

-- One tier's examine block: what the part is, then the limits stamped on
-- it. tg states the tier's rated rpm and temperature on examine
-- (turbine_parts.dm:18); the numbers are tg's, the words the pack's.
function turbine_parts.examine(kind: PartKind, tier: number): { flavor: string }
    local plate = string.format(
        "Its plate is stamped %.0f rpm and %.0f K.",
        turbine_parts.max_rpm(tier),
        turbine_parts.max_temperature_k(tier)
    )
    return { flavor = PURPOSE[kind] .. " " .. plate }
end

-- The base item's whole `component` block.
function turbine_parts.base(kind: PartKind): { kind: string, tier: number, efficiency: number }
    return { kind = kind, tier = 1, efficiency = turbine_parts.efficiency(kind, 1) }
end

-- A tier variant's override; `kind` stays the base item's.
function turbine_parts.rung(kind: PartKind, tier: number): { tier: number, efficiency: number }
    return { tier = tier, efficiency = turbine_parts.efficiency(kind, tier) }
end

return turbine_parts
