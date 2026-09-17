local composition = require("@helpers/composition")

local function has(messages, wanted)
    for _, message in ipairs(messages) do
        if message == wanted then
            return true
        end
    end
    return false
end

-- Mapped supports smooth on load. The lattice sees the catwalk east of
-- it and the floor south of it, while the first catwalk ignores that
-- lattice and sees only the second catwalk and the floor. East is
-- junction bit 4, west bit 8, south bit 2, southeast bit 32 and
-- southwest bit 64.
t.world(
    [==[(
    name: "EVA bridge pictures",
    legend: {
        '~': (composition: (substrate: Some("space"))),
        'l': (composition: (substrate: Some("space"), components: [(component: "lattice")])),
        'c': (composition: (substrate: Some("space"), components: [(component: "catwalk")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "lcc~~",
        ".....",
    ],
    structures: [
        (1, 1, "player_spawn"),
    ],
)]==],
    7
)

local viewer = t.join()
t.tick()
local lattice_look = assert(t.examine_component(viewer, 0, 0, assert(t.component_instance(0, 0, "lattice"))))
assert(lattice_look.sprite == "lattice-38", "the mapped lattice joins the catwalk east and the floor south")
assert(
    lattice_look.lines[1] == "A lightweight support lattice. These hold our station together.",
    "the lattice keeps tg's description"
)
t.run_ticks(10)
local west_catwalk = assert(t.examine_component(viewer, 1, 0, assert(t.component_instance(1, 0, "catwalk"))))
assert(west_catwalk.sprite == "catwalk-38", "the catwalk ignores lattice west and joins catwalk east and floor south")
t.run_ticks(10)
local east_catwalk = assert(t.examine_component(viewer, 2, 0, assert(t.component_instance(2, 0, "catwalk"))))
assert(east_catwalk.sprite == "catwalk-74", "the second catwalk joins the first west and the floor south")

-- One rod on Space raises a lattice; one more replaces it with a
-- catwalk. Build two sites so the cutter refunds can be walked back
-- through the same ladder: one rod stops at lattice, two reach catwalk.
t.world(
    [==[(
    name: "EVA bridge work",
    legend: {
        '~': (composition: (substrate: Some("space"))),
        'l': (composition: (substrate: Some("space"), components: [(component: "lattice")])),
        'c': (composition: (substrate: Some("space"), components: [(component: "catwalk")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "....",
        "..~.",
        ".~..",
        "....",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "rod"), (1, 1, "wirecutters")],
)]==],
    7
)

local builder = t.join()
t.tick()
t.click(builder, 1, 1, t.target_at(builder, 1, 1, "rod"))
t.run_ticks(2)
t.messages(builder)

t.click(builder, 2, 1)
t.run_ticks(2)
assert(composition.matches(2, 1, { "lattice" }), "one rod raises a lattice on Space")
assert(
    has(t.messages(builder), "You construct a lattice."),
    "the lattice construction uses tg's message"
)

t.click_component(builder, 2, 1, assert(t.component_instance(2, 1, "lattice")))
t.run_ticks(2)
assert(composition.matches(2, 1, { "catwalk" }), "a second rod replaces it with a catwalk")
assert(
    has(t.messages(builder), "You construct a catwalk."),
    "the catwalk construction uses tg's message"
)

t.click(builder, 1, 2)
t.run_ticks(2)
assert(composition.matches(1, 2, { "lattice" }), "the cutter test has a bare lattice")

t.drop(builder)
t.run_ticks(2)
t.click(builder, 1, 1, t.target_at(builder, 1, 1, "wirecutters"))
t.run_ticks(2)
t.messages(builder)
t.click_component(builder, 1, 2, assert(t.component_instance(1, 2, "lattice")))
t.tick()
assert(t.component_instance(1, 2, "lattice") == nil, "wirecutters remove the lattice immediately")
assert(t.item_at(1, 2, "rod") ~= nil, "the lattice refunds rods")
assert(
    has(t.messages(builder), "Slicing lattice joints ..."),
    "the lattice cutter message matches tg"
)

t.click_component(builder, 2, 1, assert(t.component_instance(2, 1, "catwalk")))
t.tick()
assert(t.component_instance(2, 1, "catwalk") == nil, "wirecutters remove the catwalk immediately")
assert(t.item_at(2, 1, "rod") ~= nil, "the catwalk refunds rods")
assert(
    has(t.messages(builder), "Slicing catwalk joints ..."),
    "the catwalk cutter message matches tg"
)

-- Spend each refund back where it came from. The lattice's single rod
-- is exhausted after its first rung; the catwalk's two after its second.
t.drop(builder)
t.run_ticks(2)
t.click(builder, 1, 2, t.target_at(builder, 1, 2, "rod"))
t.run_ticks(2)
t.click(builder, 1, 2)
t.run_ticks(2)
assert(composition.matches(1, 2, { "lattice" }), "one refunded rod rebuilds the lattice")
assert(t.hands(builder).held == nil, "the lattice refunded exactly one rod")

t.click(builder, 2, 1, t.target_at(builder, 2, 1, "rod"))
t.run_ticks(2)
t.click(builder, 2, 1)
t.run_ticks(2)
t.click_component(builder, 2, 1, assert(t.component_instance(2, 1, "lattice")))
t.run_ticks(2)
assert(composition.matches(2, 1, { "catwalk" }), "two refunded rods rebuild the catwalk")
assert(t.hands(builder).held == nil, "the catwalk refunded exactly two rods")

-- A floor tile replaces the support with a base over its retained Space.
-- Pry two individual tiles first so an empty hand proves each was spent.
t.world(
    [==[(
    name: "EVA bridge plating",
    legend: {
        '~': (composition: (substrate: Some("space"))),
        'l': (composition: (substrate: Some("space"), components: [(component: "lattice")])),
        'c': (composition: (substrate: Some("space"), components: [(component: "catwalk")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        ".....",
        "..l..",
        "...c.",
        ".....",
        ".....",
    ],
    items: [(2, 2, "crowbar")],
    structures: [(2, 2, "player_spawn")],
)]==],
    7
)

local tiler = t.join()
t.tick()
t.click(tiler, 2, 2, t.target_at(tiler, 2, 2, "crowbar"))
t.run_ticks(2)
t.click(tiler, 1, 2)
t.run_ticks(2)
t.click(tiler, 2, 3)
t.run_ticks(2)
t.drop(tiler)
t.run_ticks(2)

t.click(tiler, 1, 2, t.target_at(tiler, 1, 2, "floor_tile"))
t.run_ticks(2)
t.click_component(tiler, 2, 1, assert(t.component_instance(2, 1, "lattice")))
t.run_ticks(2)
assert(composition.matches(2, 1, { "station_base" }), "a tile plates Space under a lattice")
assert(t.component_instance(2, 1, "lattice") == nil, "the lattice is consumed by plating")
assert(t.hands(tiler).held == nil, "the lattice plating spent its one tile")

t.click(tiler, 2, 3, t.target_at(tiler, 2, 3, "floor_tile"))
t.run_ticks(2)
t.click_component(tiler, 3, 2, assert(t.component_instance(3, 2, "catwalk")))
t.run_ticks(2)
assert(composition.matches(3, 2, { "station_base" }), "a tile plates Space under a catwalk")
assert(t.component_instance(3, 2, "catwalk") == nil, "the catwalk is consumed by plating")
assert(t.hands(tiler).held == nil, "the catwalk plating spent its one tile")
