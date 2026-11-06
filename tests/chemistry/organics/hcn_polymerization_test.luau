-- LIQUID HCN POLYMERISES WITH A BASE IN IT AND KEEPS WITH AN ACID.
--
-- Three sealed lab flasks of liquid hydrogen cyanide at room temperature,
-- each in a world of its own so no flask's gas reaches another:
--
-- * with a trace of ammonia it polymerises to tholin and runs hot
--   (content/reactions/organics/hcn_polymerization.luau);
-- * with the same ammonia and a little sulphuric acid it keeps: the acid
--   blocks the rule, as stabilised HCN is kept in industry;
-- * with nothing in it, it keeps too: the ammonia is the catalyst.
local HCN_MOL = 0.5
-- Over the rule's 0.025 mol gate for the catalyst and for the inhibitor.
local AMMONIA_MOL = 0.05
local ACID_MOL = 0.05
local ROOM_K = 293.15
local SETTLE_SECONDS = 30

local function flask_world(rows: string)
    t.world(
        string.format(
            [==[(
    name: "hcn flask",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [(1, 1, "player_spawn")],
            items: [(2, 1, "lab_flask", { "blend": "hcn_charge" })],
        ),
    ],
    blends: {
        "hcn_charge": (rows: [%s], temperature_k: %.2f, amount: total),
    },
)]==],
            rows,
            ROOM_K
        ),
        0
    )
    local p = t.join()
    t.tick()
    return assert(t.target_at(p, 2, 1, "lab_flask"), "the charged flask is present")
end

local function phases(flask: SpecObservedTarget, key: string): SpecMatterContents
    return assert(t.vessel(flask)).contents[key] or { name = key }
end

type Outcome = { tholin: number, hcn_liquid: number, peak_k: number }

local function run(rows: string): Outcome
    local flask = flask_world(rows)
    assert((phases(flask, "hcn").liquid or 0) > 0, "the flask starts with liquid HCN")
    local peak_k = 0.0
    for _ = 1, SETTLE_SECONDS do
        t.run_seconds(1)
        peak_k = math.max(peak_k, assert(t.holder_k(flask)))
    end
    return {
        tholin = phases(flask, "tholin").solid or 0,
        hcn_liquid = phases(flask, "hcn").liquid or 0,
        peak_k = peak_k,
    }
end

local hcn = string.format('("hcn:liquid", %.4f)', HCN_MOL)
local ammonia = string.format('("ammonia:gas", %.4f)', AMMONIA_MOL)
local acid = string.format('("sulfuric_acid:liquid", %.4f)', ACID_MOL)

local catalyzed = run(hcn .. ", " .. ammonia)
assert(
    catalyzed.tholin > 0.001,
    ("ammonia sets the HCN polymerizing: %.4f mol tholin"):format(catalyzed.tholin)
)
assert(
    catalyzed.peak_k > ROOM_K + 5,
    ("and the polymerization runs hot: peak %.1f K"):format(catalyzed.peak_k)
)

local stabilized = run(hcn .. ", " .. ammonia .. ", " .. acid)
assert(
    stabilized.tholin == 0,
    ("sulfuric acid keeps it: %.4f mol tholin"):format(stabilized.tholin)
)
assert(stabilized.hcn_liquid > 0, "and the HCN is still liquid")

local plain = run(hcn)
assert(plain.tholin == 0, ("with no base it keeps: %.4f mol tholin"):format(plain.tholin))
