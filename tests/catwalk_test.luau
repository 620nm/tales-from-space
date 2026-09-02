local function has(messages, wanted)
    for _, message in ipairs(messages) do
        if message == wanted then
            return true
        end
    end
    return false
end

-- Mapped supports smooth on load. The lattice sees the catwalk east of
-- it, while the first catwalk ignores that lattice and sees only the
-- second catwalk. East is junction bit 4 and west is bit 8.
t.world([==[(
    name: "EVA bridge pictures",
    legend: {
        '~': (turf: Space),
        '.': (turf: Floor),
    },
    rows: [
        "~~~~~",
        ".....",
    ],
    spawns: [(1, 1)],
    structures: [
        (0, 0, "lattice"), (1, 0, "catwalk"), (2, 0, "catwalk"),
    ],
)]==], 7)

local viewer = t.join()
t.tick()
assert(t.structure_at(0, 0).sprite == "lattice-4",
    "the mapped lattice joins the catwalk eastward")
assert(t.structure_at(1, 0).sprite == "catwalk-4",
    "the catwalk ignores lattice west and joins catwalk east")
assert(t.structure_at(2, 0).sprite == "catwalk-8",
    "the second catwalk joins the first westward")

local lattice_look = t.examine(viewer, 0, 0, t.target_at(0, 0, "lattice"))
assert(lattice_look.lines[1]
        == "A lightweight support lattice. These hold our station together.",
    "the lattice keeps tg's description")

-- One rod on Space raises a lattice; one more replaces it with a
-- catwalk. Build two sites so the cutter refunds can be walked back
-- through the same ladder: one rod stops at lattice, two reach catwalk.
t.world([==[(
    name: "EVA bridge work",
    legend: {
        '~': (turf: Space),
        '.': (turf: Floor),
    },
    rows: [
        "....",
        "..~.",
        ".~..",
        "....",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "rod"), (1, 1, "wirecutters")],
)]==], 7)

local builder = t.join()
t.tick()
t.click(builder, 1, 1, t.target_at(1, 1, "rod"))
t.run_ticks(2)
t.messages(builder)

t.click(builder, 2, 1)
t.run_ticks(2)
assert(t.structure_at(2, 1).id == "lattice", "one rod raises a lattice on Space")
assert(has(t.messages(builder), "You construct a lattice."),
    "the lattice construction uses tg's message")

t.click(builder, 2, 1, t.target_at(2, 1, "lattice"))
t.run_ticks(2)
assert(t.structure_at(2, 1).id == "catwalk", "a second rod replaces it with a catwalk")
assert(has(t.messages(builder), "You construct a catwalk."),
    "the catwalk construction uses tg's message")

t.click(builder, 1, 2)
t.run_ticks(2)
assert(t.structure_at(1, 2).id == "lattice", "the cutter test has a bare lattice")

t.drop(builder)
t.run_ticks(2)
t.click(builder, 1, 1, t.target_at(1, 1, "wirecutters"))
t.run_ticks(2)
t.messages(builder)
t.click(builder, 1, 2, t.target_at(1, 2, "lattice"))
t.tick()
assert(t.structure_at(1, 2) == nil, "wirecutters remove the lattice immediately")
assert(t.item_at(1, 2, "rod") ~= nil, "the lattice refunds rods")
assert(has(t.messages(builder), "Slicing lattice joints ..."),
    "the lattice cutter message matches tg")

t.click(builder, 2, 1, t.target_at(2, 1, "catwalk"))
t.tick()
assert(t.structure_at(2, 1) == nil, "wirecutters remove the catwalk immediately")
assert(t.item_at(2, 1, "rod") ~= nil, "the catwalk refunds rods")
assert(has(t.messages(builder), "Slicing catwalk joints ..."),
    "the catwalk cutter message matches tg")

-- Spend each refund back where it came from. The lattice's single rod
-- is exhausted after its first rung; the catwalk's two after its second.
t.drop(builder)
t.run_ticks(2)
t.click(builder, 1, 2, t.target_at(1, 2, "rod"))
t.run_ticks(2)
t.click(builder, 1, 2)
t.run_ticks(2)
assert(t.structure_at(1, 2).id == "lattice", "one refunded rod rebuilds the lattice")
assert(t.hands(builder).held == nil, "the lattice refunded exactly one rod")

t.click(builder, 2, 1, t.target_at(2, 1, "rod"))
t.run_ticks(2)
t.click(builder, 2, 1)
t.run_ticks(2)
t.click(builder, 2, 1, t.target_at(2, 1, "lattice"))
t.run_ticks(2)
assert(t.structure_at(2, 1).id == "catwalk", "two refunded rods rebuild the catwalk")
assert(t.hands(builder).held == nil, "the catwalk refunded exactly two rods")

-- A floor tile consumes the support and turns its Space into plating.
-- Pry two individual tiles first so an empty hand proves each was spent.
t.world([==[(
    name: "EVA bridge plating",
    legend: {
        '~': (turf: Space),
        '.': (turf: Floor),
    },
    rows: [
        ".....",
        "..~..",
        "...~.",
        ".....",
        ".....",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "crowbar")],
    structures: [(2, 1, "lattice"), (3, 2, "catwalk")],
)]==], 7)

local tiler = t.join()
t.tick()
t.click(tiler, 2, 2, t.target_at(2, 2, "crowbar"))
t.run_ticks(2)
t.click(tiler, 1, 2)
t.run_ticks(2)
t.click(tiler, 2, 3)
t.run_ticks(2)
t.drop(tiler)
t.run_ticks(2)

t.click(tiler, 1, 2, t.target_at(1, 2, "floor_tile"))
t.run_ticks(2)
t.click(tiler, 2, 1, t.target_at(2, 1, "lattice"))
t.run_ticks(2)
assert(t.turf(2, 1) == "plating", "a tile plates Space under a lattice")
assert(t.structure_at(2, 1) == nil, "the lattice is consumed by plating")
assert(t.hands(tiler).held == nil, "the lattice plating spent its one tile")

t.click(tiler, 2, 3, t.target_at(2, 3, "floor_tile"))
t.run_ticks(2)
t.click(tiler, 3, 2, t.target_at(3, 2, "catwalk"))
t.run_ticks(2)
assert(t.turf(3, 2) == "plating", "a tile plates Space under a catwalk")
assert(t.structure_at(3, 2) == nil, "the catwalk is consumed by plating")
assert(t.hands(tiler).held == nil, "the catwalk plating spent its one tile")
