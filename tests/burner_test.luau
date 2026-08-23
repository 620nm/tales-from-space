-- The bench burner: strike it, hold it under a beaker, and watch the
-- numbers tg wrote come out.
--
-- The one that matters is the FIRST CLICK. tg's exposure is
-- `temp_delta = (temperature - chem_temp) * 0.02` (holder.dm:769-778),
-- and ethanol burns at 2193 K (drinks/alcohol_reagents.dm:13), so a
-- beaker at room temperature gains (2193 - 293.15) * 0.02 = 37.997 K
-- and not a tenth of a kelvin more. Every later click is the same line
-- with a smaller gap, which is why the thing approaches its flame
-- asymptotically and can never reach it.
local T20C = 293.15
local ETHANOL_K = 2193.0
local COEFF = 0.02

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

t.world([==[(
    name: "chem bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [
        (1, 1, "burner"),
        (2, 1, "beaker_libital"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local burner = t.target_at(1, 1, "burner")
local beaker = t.target_at(2, 1, "beaker_libital")

-- It ships with tg's 15 units of spirit in it, through the documented
-- bridge: 15 x 0.025 = 0.375 mol (items.dm:164-172).
local fuel = t.contents(burner)
near(fuel.ethanol, 0.375, 1e-9, "the tank arrives with tg's 15 units")
assert(t.item_at(1, 1, "burner").state == "cold", "and unlit")

t.click(p, 1, 1, burner)
t.tick()
assert(t.hands(p).held == "burner", "picked up")

-- ---------------------------------------------------------------
-- AN UNLIT BURNER IS A PAPERWEIGHT.
-- ---------------------------------------------------------------
t.click(p, 2, 1, beaker)
t.tick()
near(t.holder_k(beaker), T20C, 1e-9, "cold, it heats nothing")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("isn't lit", 1, true), "and it says so: " .. msgs)

-- ---------------------------------------------------------------
-- STRUCK.
-- ---------------------------------------------------------------
t.use_self(p)
t.tick()
assert(t.hands(p).held == "burner", "still in hand")
assert(t.ledger_has("FuelBurnSet"), "striking a light is on the record")

-- ---------------------------------------------------------------
-- ONE CLICK IS ONE EXPOSURE, AND IT IS TG'S ARITHMETIC EXACTLY.
-- ---------------------------------------------------------------
local before = t.holder_k(beaker)
t.click(p, 2, 1, beaker)
t.tick()
local first = t.holder_k(beaker)
near(first - before, (ETHANOL_K - before) * COEFF, 1e-6, "the first click is tg's delta")
near(first - before, 37.997, 0.01, "which is the +38 K a chemist feels")

-- The second click is the same line with a smaller gap, so it moves
-- LESS -- the asymptote is the whole shape of the mechanic.
local second_before = first
t.click(p, 2, 1, beaker)
t.tick()
local second = t.holder_k(beaker)
near(second - second_before, (ETHANOL_K - second_before) * COEFF, 1e-6, "and so is the second")
assert(second - second_before < first - before, "each click buys less than the last")

-- ...and enough of them never reach the flame. Two hundred exposures is
-- far past the point where a linear model would have sailed through
-- 2193 K.
for _ = 1, 200 do
    t.click(p, 2, 1, beaker)
    t.tick()
end
assert(t.holder_k(beaker) < ETHANOL_K, "no number of clicks reaches the flame itself")
assert(t.holder_k(beaker) > 1000.0, "though it gets seriously hot: " .. t.holder_k(beaker))

-- ---------------------------------------------------------------
-- AND IT BURNS ITSELF OUT.
--
-- tg spends `burning_volume` of every burnable reagent per process
-- tick and calls `set_lit(FALSE)` the moment none is left
-- (items.dm:275-286). 15 u at 0.1 u per 2 s is five minutes, and this
-- is that five minutes.
-- ---------------------------------------------------------------
t.drop(p)
t.run_seconds(60)
local left = t.contents(burner).ethanol
assert(left ~= nil and left < 0.375, "a minute in, some of the tank is gone: " .. left)
assert(left > 0.2, "but nothing like all of it: " .. left)
assert(t.item_at(1, 1, "burner").state == "lit", "and it is still burning")

t.run_seconds(300)
assert((t.contents(burner).ethanol or 0) < 1e-6, "five minutes and the tank is dry")
assert(t.item_at(1, 1, "burner").state == "cold", "so the flame goes out on its own")
assert(t.item_at(1, 1, "burner").sprite == "burner", "and the picture follows the flame")

-- A dead burner heats nothing, which is tg's `get_temperature()`
-- returning `lit * heat` (items.dm:290-291).
t.click(p, 1, 1, t.target_at(1, 1, "burner"))
t.tick()
local cold = t.holder_k(beaker)
t.click(p, 2, 1, beaker)
t.tick()
near(t.holder_k(beaker), cold, 1e-9, "a burnt-out burner is a paperweight again")
