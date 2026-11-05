-- Hydrogen cyanide: HCN, a cold world's snow, and a poison once warm.
--
-- interactions we use:
--   4 HCN + 5 O2 -> 4 CO2 + 2 H2O + 2 N2 (hcn_fire)
-- interactions which require catalysts:
--   4 HCN(l) -> tholin, catalyst ammonia, blocked by sulfuric_acid (hcn_polymerisation)
-- interactions we know exist but don't need:
--   HCN + Cl2 -> ClCN + HCl: cyanogen chloride and HCl have no
--     substance here
--   HCN + NaOH -> NaCN + H2O: lye scrubbing; sodium cyanide has no
--     substance, and a scrubber already takes HCN out of a room
--   HCN + H2O -> HCONH2: hydrolysis to formamide is slow without an
--     acid or base, and formamide has no substance
--
-- Numbers are the NIST WebBook's for HCN (C74908): triple point
-- 259.86 K, normal boiling point 299.0 K, heat of vaporization
-- 25.22 kJ/mol at 298.85 K, heat of fusion 8.406 kJ/mol; the critical
-- temperature, 456.7 K, is CRC's. Liquid density 0.687 g/mL at 293 K (CRC); the solid's
-- 0.9 is approximate. Gas cv 27.6 is the 298 K cp of 35.9 less R; the
-- liquid's is its cp of 70.6, the solid's approximate.
--
-- THE BOIL SPELLING: at the melting point the vapour line stands at
--   101.325 * exp((25220 / 8.3145) * (1/299.0 - 1/259.86)) = 22.0 kPa
-- (the real triple point is 18.6 kPa), under 1 atm, so the spelling is
-- legal. At 94 K the sublimation line (L = 25.22 + 8.406 kJ/mol) is at
-- 2.6e-8 Pa: outside, HCN snow neither sublimes nor melts. At 293 K the
-- liquid's vapour stands at 83 kPa, so snow carried indoors melts at
-- 260 K and fills the room with gas.
--
-- WHAT IT DOES TO YOU, and where 680 000 comes from. Cyanide stops a
-- cell using the oxygen it is given, so the harm is oxy. NIOSH's IDLH
-- is 50 ppm; about 300 ppm kills within minutes. One breath (1.99 L)
-- at 100 ppm, 0.01 kPa of partial pressure, is
--   n = 10 * 0.00199 / (8.314 * 293.15) = 8.17e-6 mol
-- and `inhale = 0.9` keeps 7.35e-6 mol. Times 680 000 that is 5 oxy,
-- the BREATH_OXY_HEAL floor (substances/chlorine.luau): 100 ppm is
-- where it starts to show, and 300 ppm is 15 oxy a breath, 10 net,
-- down in about ten breaths. MAX_SCRIPT_HIT caps one call at 40.
-- There is no warning sentence: cyanide gives none, and the first a
-- body knows is the oxy it cannot heal.
--
-- Flow is the liquid near 293 K, approximate (CRC).
local content = {
    id = "hcn",
    name = "hydrogen cyanide",
    molar_mass = 27.025,
    cv = { solid = 46.0, liquid = 70.6, gas = 27.6 },
    phase = { melt = 259.86, boil = 299.0, l_fus = 8406, l_vap = 25220, critical = 456.7 },
    density = { solid = 0.9, liquid = 0.687 },
    flow = { viscosity = 0.2, surface_tension = 18.0, contact_angle = 15 },
    inhale = 0.9,
    metabolism_rate = 0.02,
    color = "#E6EEF0",
    -- Colourless as a liquid; as snow, a pale frost.
    appearance = {
        liquid = { profile = "puddle", tint = "#C8DCE0" },
        solid = { profile = "crystalline", tint = "#F2F4F6" },
    },
    -- A thing the station is built to keep away from itself.
    dangerous = true,
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel): a poison nobody
    -- commissions a room with.
    relevance = 10,
    group = "poison",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for hydrogen cyanide. A poison, so any trace counts.
    hazard = { health = 4, fire = 4, instability = 2 },
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- `mob.life`: the moles metabolized this tick, as `ev.amount`.
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        sim.damage.apply({ target = ev.entity, amounts = { oxy = ev.amount * 680000 } })
    end)
end

return content
