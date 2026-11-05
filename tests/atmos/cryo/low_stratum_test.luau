-- The cryo-hydrocarbon world's low country, level -1 and below: HCN snow
-- falls on its open sky, blinds whoever stands in it, and piles to 1 cm of
-- frost a tile and no deeper (content/environments/cryo_hydrocarbon.luau).
--
-- Sight: the snow's extinction is 0.87 per m, so Koschmieder's 3.912 / 0.87
-- = 4.50 m caps a viewer at four tiles (the engine's
-- docs/sim/sight-extinction.md). A crowbar three tiles off is seen and one six
-- off is not; on the upper level, which has no snow, both are.
--
-- Fallout: 0.01 kg/m2/s in 10 s batches is 0.1 kg a tile a batch. The cap is
-- 1 cm of condensed matter, 0.01 m3 of HCN frost at 0.9 g/mL (the `hcn`
-- substance's solid): 9 kg, reached on the 90th batch, after which a batch
-- of capped tiles writes no `fallout_deposited` row.
local KG_PER_M2_S = 0.01
local INTERVAL_S = 10
local CAP_M = 0.01
local HCN_SOLID_KG_PER_M3 = 900

local tile = assert(t.tile())
local FLOOR_M2 = tile.width_m * tile.depth_m
local BATCH_KG = KG_PER_M2_S * INTERVAL_S * FLOOR_M2
local CAP_KG = CAP_M * FLOOR_M2 * HCN_SOLID_KG_PER_M3
local BASIN_TILES = 27 -- the 9 x 3 level -1 below

local function seen(viewer: number, x: number): boolean
    for _, name in t.drawn_at(viewer, x, 1) do
        if name == "crowbar" then
            return true
        end
    end
    return false
end

-- The upper air: no snow, so sight runs past six tiles.
t.world(
    [==[(
    name: "cryo upland",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(94.0)),
    legend: { 'o': (outdoors: true, composition: ()) },
    levels: [
        (
            rows: ["ooooooooo", "ooooooooo", "ooooooooo"],
            structures: [(1, 1, "player_spawn")],
            items: [(4, 1, "crowbar"), (7, 1, "crowbar")],
        ),
    ],
)]==],
    0,
    "free_build"
)
assert(t.environment().id == "cryo_hydrocarbon", "a 94 K map rolls the cryo-hydrocarbon world")
local upland = t.join()
t.run_ticks(4)
assert(seen(upland, 4) and seen(upland, 7), "in the upper air both crowbars are in sight")

-- The low country: every column is carved one level down (`height: -1`), so
-- level -1 is blank outdoor ground on the sheet ice with level 0 open above.
-- Level -1 lists first.
t.world(
    [==[(
    name: "cryo basin",
    needs: ["gravity"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(94.0)),
    legend: { 'o': (outdoors: true, composition: ()) },
    ground: (legend: { 'v': (height: -1) }, rows: ["vvvvvvvvv", "vvvvvvvvv", "vvvvvvvvv"]),
    levels: [
        (
            rows: ["ooooooooo", "ooooooooo", "ooooooooo"],
            structures: [(1, 1, "player_spawn")],
            items: [(4, 1, "crowbar"), (7, 1, "crowbar")],
        ),
        (rows: ["ooooooooo", "ooooooooo", "ooooooooo"]),
    ],
)]==],
    0,
    "free_build"
)
local lowland = t.join()
t.run_ticks(4)
assert(seen(lowland, 4), "in the snow a crowbar three tiles off is in sight")
assert(not seen(lowland, 7), "and one six tiles off is lost in it")

local function deposits(): { SpecLedgerRow }
    return t.ledger_rows("fallout_deposited")
end

t.run_seconds(60)
local first = deposits()
assert(#first >= 5, "the snow falls every ten seconds, got " .. #first .. " batches in a minute")
local open_sky = assert(first[1].cells :: number)
assert(first[1].stratum == "lowland", "on the low stratum, got " .. tostring(first[1].stratum))
assert(open_sky == BASIN_TILES, "on every basin tile, got " .. open_sky)
local none_full = (first[1].capped :: number) == 0 and (first[1].refused :: number) == 0
assert(none_full, "none full yet, none refused")
local first_kg = first[1].kg :: number
local batch_kg = open_sky * BATCH_KG
assert(math.abs(first_kg - batch_kg) < 1e-6 * batch_kg, "0.1 kg a tile a batch: " .. first_kg)

-- Fifteen minutes fill a tile; a little more and every tile is capped.
t.run_seconds(960)
local filled = deposits()
local fallen = 0
for _, row in filled do
    fallen += row.kg :: number
    assert((row.refused :: number) == 0, "no batch is refused")
end
local per_tile = fallen / open_sky
assert(
    per_tile >= CAP_KG - 1e-6 and per_tile <= CAP_KG + BATCH_KG + 1e-6,
    "the frost piles to 1 cm, at most one batch over: " .. per_tile .. " kg against " .. CAP_KG
)

t.run_seconds(120)
local later = #deposits()
assert(later == #filled, "and then the snow lands nowhere: " .. #filled .. " then " .. later)
