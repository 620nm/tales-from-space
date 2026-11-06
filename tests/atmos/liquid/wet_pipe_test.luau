local bench = require("@helpers/liquid_bench")

-- A wet length pulled up spills its share into the room, and the books close.
-- Forty litres down a drain into three lengths on open plating.
local p = bench.world({
    environment = bench.ONE_G,
    rows = { "#######", "#.#___#", "#######" },
    structures = '(5, 1, "player_spawn"), (1, 1, "floor_drain", {"pipe": "east"})',
    items = '(5, 1, "wrench")',
    run = { { x = 2, y = 1 }, { x = 3, y = 1 }, { x = 4, y = 1 } },
    pools = { { x = 1, y = 1, liters = 40 } },
})
t.set_breathing(false)
t.click(p, 5, 1, assert(t.target_at(p, 5, 1, "wrench")))
t.run_ticks(2)
t.run_seconds(90)
assert(bench.standing(1, 1) < bench.FILM_L + 1, "the water is down the line")
assert(bench.standing(4, 1) == 0, "and the plating over the run is dry")

local booked = t.matter_totals().substances.water
t.click_network(p, 4, 1, assert(t.network_instance(4, 1, "pipe", "l3")))
t.run_seconds(1.5)
assert(t.network_instance(4, 1, "pipe", "l3") == nil, "the length came up")
t.run_seconds(5)
local spilled = bench.standing(3, 1) + bench.standing(4, 1) + bench.standing(5, 1)
assert(spilled > 1, ("what it held spills on the deck: %.3f L"):format(spilled))
local closed = t.matter_totals().substances.water
assert(math.abs(closed - booked) < 1e-3, ("the books close: %.6f of %.6f mol"):format(closed, booked))
