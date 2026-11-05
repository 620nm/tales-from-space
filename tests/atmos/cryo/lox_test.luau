-- Pure oxygen at 3 bar outdoors on the cryo-hydrocarbon world is liquid
-- oxygen in the making: at 94 K its saturation is about 146 kPa, so a
-- canister holding 3 bar's worth condenses LOX at once and comes to rest on
-- its saturation line, cooled by the 94 K air around it.
--
-- O2's line is its boil spelling (the `o2` substance: boils 90.19 K at one
-- atmosphere, l_vap 6820 J/mol):
--   p_sat(T) = 101.325 kPa * exp(-6820/8.314 * (1/T - 1/90.19)),
--   p_sat(94) = 101.325 * exp(0.3686) = 146.5 kPa.
-- The charge is 3 bar of gas at 94 K in the 2000 L shell
-- (content/structures/atmos/canister.luau): n = 300000 * 2 / (8.314 * 94).
local R = 8.314
local SURFACE_K = 94.0 -- content/environments/cryo_hydrocarbon.luau
local SHELL_M3 = 2.0
local CHARGE_PA = 300000.0
local CHARGE_MOLES = CHARGE_PA * SHELL_M3 / (R * SURFACE_K)

local O2_BOIL_K = 90.19
local O2_L_VAP = 6820.0
local ONE_ATMOSPHERE_KPA = 101.325

local function saturation_kpa(kelvin: number): number
    return ONE_ATMOSPHERE_KPA * math.exp(-O2_L_VAP / R * (1.0 / kelvin - 1.0 / O2_BOIL_K))
end
assert(math.abs(saturation_kpa(SURFACE_K) - 146.5) < 0.5, "the line this spec reads against")

local MAP = [==[(
    name: "oxygen outdoors",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(94.0)),
    legend: {
        'o': (outdoors: true, composition: ()),
    },
    levels: [
        (
            rows: [
                "ooooo",
                "ooooo",
                "ooooo",
            ],
            structures: [(1, 1, "player_spawn"), (3, 1, "canister", { "blend": "oxygen_charge" })],
        ),
    ],
    blends: {
        "oxygen_charge": (rows: [("o2:gas", %.3f)], temperature_k: 94.0, amount: total),
    },
)]==]

t.world(MAP:format(CHARGE_MOLES), 0, "free_build")
assert(t.environment().id == "cryo_hydrocarbon", "a 94 K map rolls the cryo-hydrocarbon world")

local function oxygen(): (SpecMatterVessel, number)
    local bottle = assert(t.vessel_at(3, 1, "canister"), "the canister is a vessel")
    local o2 = bottle.contents.o2
    return bottle, if o2 then o2.liquid or 0 else 0
end

t.run_ticks(4)
local early_bottle, early_lox = oxygen()
assert(early_bottle.volume_l == SHELL_M3 * 1000, "the 2000 L shell, got " .. early_bottle.volume_l)
assert(early_lox > 0, "3 bar of oxygen at 94 K condenses at once")

-- The first flash warms the bottle with its latent heat (to about 102 K,
-- where the line reaches the gas's own pressure); the 94 K air outside
-- draws that heat off, and more oxygen condenses as it does.
t.run_seconds(600)
local bottle, lox = oxygen()
assert(
    bottle.temp_k < early_bottle.temp_k,
    "the air outside cools the bottle: " .. early_bottle.temp_k .. " K then " .. bottle.temp_k
)
assert(lox > early_lox, "and more oxygen condenses: " .. early_lox .. " mol then " .. lox)
assert(lox < CHARGE_MOLES, "with a headspace of gas over it")
local line = saturation_kpa(bottle.temp_k)
assert(
    math.abs(bottle.pressure_kpa - line) < line * 0.03,
    "its headspace sits on oxygen's saturation line: " .. bottle.pressure_kpa .. " against " .. line
)
