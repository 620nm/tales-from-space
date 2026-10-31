local matter_look = require("@helpers/matter_look")

-- The ladders in content/matter_appearances.luau, read off real spills.
--
-- A tile here is a square metre under three metres of air, so a litre of
-- water is a millimetre deep and the film water stops thinning at is
-- 3.3 L. Water also dries at about 20 mL a second, which is why every
-- liquid reading below is taken the tick after the spill. What a crewman
-- should see:
--   a few drops                    a splatter       (rung 1, from 5 mL)
--   a beaker tipped out    50 mL   a splash         (rung 2, from 30 mL)
--   a large beaker        120 mL   a spill          (rung 3, from 100 mL)
--   a bottle, a mop       1 L      a puddle shell   (rung 4, from 250 mL)
--   an extinguisher       4 L      still a puddle: the shell is as deep as a
--                                  film lets one tile get
--   a flood (20 L, ten seconds on) a pool in the middle (rung 5, from 4.5 L),
--                                  puddle at the rim, which holds one film
-- and a chlorine canister (100 mol) cloud at the valve, thinning to smoke,
-- then to mist, with the opacity falling the whole way.

t.set_breathing(false)

local ROOM = [==[(
    name: "spill ladder",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "###########",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "###########",
            ],
            structures: [(1, 1, "player_spawn")],
            painted: [(5, 3, "spill")],
        ),
    ],
    blends: {
        "spill": (rows: [%s, ("o2", 26.19), ("n2", 98.53)], temperature_k: 293.15, amount: total),
    },
)]==]

local function spill(rows: string): number
    t.world(ROOM:format(rows), 0)
    local p = t.join()
    t.tick()
    return p
end

-- Millilitres of water: 55.51 mol a litre.
local function water(ml: number): string
    return string.format('("water", %.4f)', ml * 0.05551)
end

local function top_water(p: number, x: number, y: number): number
    return matter_look.top_rung(p, x, y, "puddle")
end

assert(top_water(spill(water(4)), 5, 3) == 0, "four millilitres is under the first rung and is not drawn")
assert(top_water(spill(water(8)), 5, 3) == 1, "a few drops are a splatter")
assert(top_water(spill(water(50)), 5, 3) == 2, "a beaker is a splash")
assert(top_water(spill(water(120)), 5, 3) == 3, "a large beaker is a spill")
assert(top_water(spill(water(1000)), 5, 3) == 4, "a litre is a puddle")
assert(top_water(spill(water(4000)), 5, 3) == 4, "an extinguisher's four litres is still a puddle")

-- A flood: ten seconds on the middle tile holds about 5.6 L and its
-- neighbours the 3.4 L film.
local flood = spill(water(20000))
t.run_seconds(10)
assert(top_water(flood, 5, 3) == 5, "the middle of a flood is a pool")
assert(top_water(flood, 4, 3) == 4, "and its rim is a puddle")

-- A gas leaks outward and thins, and the opacity thins with it.
local function cloud_alpha(p: number, x: number, y: number): number
    local mist = assert(matter_look.find(p, x, y, "cloud", 1), "the mist rung draws wherever chlorine shows")
    return mist.alpha
end

local release = spill('("chlorine", 100.0)')
assert(matter_look.top_rung(release, 5, 3, "cloud") == 3, "a canister's worth at the valve is a cloud")
local at_valve = cloud_alpha(release, 5, 3)
t.run_seconds(5)
assert(matter_look.top_rung(release, 5, 3, "cloud") == 2, "five seconds on the middle is smoke")
assert(matter_look.top_rung(release, 2, 3, "cloud") == 1, "and the far side of the room is mist")
local after_five = cloud_alpha(release, 5, 3)
t.run_seconds(15)
assert(matter_look.top_rung(release, 5, 3, "cloud") == 1, "once the room has taken it, it is mist everywhere")
local settled = cloud_alpha(release, 5, 3)
assert(at_valve > after_five and after_five > settled, "and the opacity thins the whole way")

-- Solids: a pinch is a scattering of grains, a handful a sheet.
local function ash(ml: number): string
    return string.format('("ash", %.4f)', ml / 45.45)
end

assert(matter_look.top_rung(spill(ash(3)), 5, 3, "powder") == 1, "a pinch of ash is a few grains")
assert(matter_look.top_rung(spill(ash(60)), 5, 3, "powder") == 2, "sixty millilitres is a sheet")
