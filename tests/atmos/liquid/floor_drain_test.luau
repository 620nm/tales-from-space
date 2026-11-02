local bench = require("@helpers/liquid_bench")

-- A floor drain takes a deck down to its film and no further, stops when
-- its line is full, and leaves beads alone. One drain on a dead-end line
-- of one length: the drain's port and the length hold 270 L, 256.5 of it
-- water at the fill cap.
local function pocket(environment: string, litres: number)
    bench.world({
        environment = environment,
        rows = { "#####", "#.#.#", "#####" },
        structures = '(3, 1, "player_spawn"), (1, 1, "floor_drain", {"pipe": "east"})',
        run = { { x = 2, y = 1 } },
        pools = { { x = 1, y = 1, litres = litres } },
    })
end

-- Ten litres on the grating: 6.7 over the film at half a litre a second.
pocket(bench.ONE_G, 10)
t.run_seconds(30)
local left = bench.standing(1, 1)
assert(
    math.abs(left - bench.FILM_L) < 0.35,
    ("the deck falls to its film, %.3f L left"):format(left)
)

-- Three hundred litres overfill the line, and the rest stands on the deck.
pocket(bench.ONE_G, 300)
t.run_seconds(640)
left = bench.standing(1, 1)
assert(math.abs(left - 43.5) < 3, ("a full line backs up, %.1f L left"):format(left))

-- Without weight nothing settles, and a drain takes only what has.
pocket(bench.ZERO_G, 10)
t.run_seconds(30)
left = bench.standing(1, 1)
assert(left > 9.9, ("beads float over the grating, %.3f L left"):format(left))

-- Wrenched down from its fitting it joins the run by itself and takes the
-- floor as a mapped one does, and a wrench gives the fitting back.
local p = bench.world({
    environment = bench.ONE_G,
    rows = { "#####", "#.#.#", "#####" },
    structures = '(1, 1, "player_spawn")',
    items = '(1, 1, "wrench"), (1, 1, "floor_drain_fitting")',
    run = { { x = 2, y = 1 } },
    pools = { { x = 1, y = 1, litres = 10 } },
})
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "wrench")))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "floor_drain_fitting")))
t.run_seconds(2.5)
local built = t.structure_at(1, 1)
assert(built and built.id == "floor_drain", "the fitting becomes a drain")
assert(t.count_items("floor_drain_fitting") == 0, "and is spent into it")
t.run_seconds(30)
left = bench.standing(1, 1)
assert(
    math.abs(left - bench.FILM_L) < 0.35,
    ("a built drain takes the floor to its film, %.3f L left"):format(left)
)
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "floor_drain")))
t.run_seconds(2.5)
assert(
    t.structure_at(1, 1) == nil and t.count_items("floor_drain_fitting") == 1,
    "a wrench brings the fitting back"
)
