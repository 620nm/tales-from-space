local composition = require("@helpers/composition")

-- What a stroke lifts besides a settled puddle (docs/janitorial/mop.md):
-- floating beads where the deck has no gravity, a loose deposit, a head that
-- fills and says so, and ice, which stays put with what lies on it.
t.world(
    [==[(
    name: "weightless deck",
    environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#.#.#",
                "##.##",
                "#.#.#",
                "#####",
            ],
            // Walled apart at the corners: ice would chill and freeze its neighbors.
            painted: [(3, 1, "beads"), (1, 3, "ash_drift"), (1, 1, "iced"), (3, 3, "salt_flood")],
            structures: [(2, 2, "player_spawn")],
            items: [(2, 2, "mop")],
        ),
    ],
    blends: {
        "beads": (rows: [("water", 5.0), ("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15, amount: total),
        "ash_drift": (rows: [("ash", 2.0), ("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15, amount: total),
        "iced": (rows: [("water:solid", 200.0), ("ash", 1.0), ("o2", 8.73), ("n2", 32.84)], temperature_k: 200.0, amount: total),
        "salt_flood": (rows: [("water", 111.0), ("salt", 10.0), ("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15, amount: total),
    },
)]==],
    0
)

local p = t.join()
t.tick()
local mop = assert(t.target_at(p, 2, 2, "mop"))
t.click(p, 2, 2, mop)
t.tick()

local function said(): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

local function stroke(x: number, y: number)
    composition.click_deck(p, x, y)
    t.tick()
    t.run_seconds(1.6)
end

-- Ice: frozen on the tile, it stays, and so does the ash lying with it.
stroke(1, 1)
local pinned_line = said()
assert(pinned_line == "The deck here is dry.", "nothing loose to lift: " .. pinned_line)
assert(not assert(t.contents(mop)).ash, "pinned ash stays on the tile")

-- Beads: the head takes floating liquid and names it.
stroke(3, 1)
assert(said() == "You chase the floating beads into the mop.", "beads are named")
assert((assert(t.room_liquid(3, 1)).water or 0) < 0.001, "the beads are gone")
local head = assert(t.contents(mop))
assert((head.water or 0) > 1, ("and in the head: %g"):format(head.water or 0))

-- A deposit: a solid on its own comes up and is named, and the head is shared.
stroke(1, 3)
local deposit_line = said()
assert(deposit_line == "You scrape the deposit up into the mop.", "the deposit is named: " .. deposit_line)
assert((assert(t.contents(mop)).ash or 0) > 1.9, "the ash is in the head")

-- Sediment in a flood comes up with the water, until the head is full.
stroke(3, 3)
stroke(3, 3)
stroke(3, 3)
assert(said() == "The mop is soaked through.", "a full head says so")
assert(assert(t.vessel(mop)).headspace_l < 0.01, "and has no room left")
assert((assert(t.contents(mop)).salt or 0) > 0, "the salt rose with the water")
