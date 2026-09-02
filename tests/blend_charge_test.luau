-- What a map says is IN a beaker it stands on the bench.
--
-- A station is allowed to open the shift with the infirmary shelf
-- stocked and the bench already holding something, and saying so used
-- to mean a whole prototype per fill. It is a `blends` block now: the map
-- declares named Matter Blends and a placement names one
-- (docs/map-properties/blends.md). The glass is one noun; what somebody left
-- in it is a fact about the station.
--
-- Three sentences, all read through `t.vessel`, which is what a pair of
-- eyes and a gauge could tell:
--   * a bare beaker holds exactly the charge the map declared
--   * a charge REPLACES a variant's own fill rather than joining it
--   * a beaker nobody charged still holds what its file says

t.world([==[(
    name: "charge bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    blends: {
        "rinse": (rows: [("water", 0.20)], temperature_k: 293.15, amount: total),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(1, 1)],
    items: [
        (2, 1, "beaker", { "blend": "rinse" }),
        (3, 1, "beaker.libital", { "blend": "rinse" }),
        (4, 1, "beaker.libital"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local function near(got, want, tol, what)
    assert(got ~= nil, what .. ": nothing was answered")
    assert(math.abs(got - want) <= tol,
        ("%s: wanted %g, got %g"):format(what, want, got))
end

-- ---------------------------------------------------------------
-- The glass off the shelf, filled by the map. A charge is an
-- AMOUNT, not a density: 0.20 mol is 0.20 mol whatever the shell.
-- ---------------------------------------------------------------
local charged = t.vessel(t.target_at(2, 1, "beaker"))
assert(charged ~= nil, "a beaker has an inside")
assert(charged.contents.water ~= nil, "the map put water in it")
near(charged.contents.water.liquid, 0.20, 1e-9, "the charge's own amount")
near(charged.temp_k, 293.15, 0.5, "at the temperature the charge names")

-- ---------------------------------------------------------------
-- The infirmary's beaker, overruled. `beaker.libital` ships with
-- water and libital in it (content/items/beaker.luau); the
-- placement says rinse, and rinse is what is in it -- a preset
-- STATES what is in the vessel, so placement beats variant beats
-- base and nothing is ever the sum of two of them.
-- ---------------------------------------------------------------
local overruled = t.vessel(t.target_at(3, 1, "beaker.libital"))
assert(overruled ~= nil, "a variant is a beaker like any other")
near(overruled.contents.water.liquid, 0.20, 1e-9,
    "the map's amount, not the variant's 0.20 plus it")
assert(overruled.contents.libital == nil,
    "and the variant's own drug is gone, because the charge replaced the fill")

-- ---------------------------------------------------------------
-- ...and the one nobody said anything about is untouched by all of
-- it: what its own file declares, which is what it has always been.
-- ---------------------------------------------------------------
local untouched = t.vessel(t.target_at(4, 1, "beaker.libital"))
assert(untouched ~= nil, "the third glass has an inside too")
assert(untouched.contents.libital ~= nil,
    "a placement that says nothing gets the prototype's own fill")
assert(untouched.contents.libital.liquid > 0,
    "standing as liquid: " .. tostring(untouched.contents.libital.liquid))

