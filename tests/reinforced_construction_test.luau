-- The reinforced pair, built and taken apart the way a player would.
--
-- Two rods reinforce plating and a wrench takes them back out
-- (tg reinforced_floor.dm:44-53, plating.dm:50-71); a crowbar is not
-- part of that conversation at all, because there is no tile lying on
-- a reinforced floor to lift (`:41-42`). Plasteel struts a girder and
-- then plates it into hull (girders.dm:59-63, reinf_walls.dm:16), and
-- the way back down is tg's seven-rung `d_state` ladder
-- (reinf_walls.dm:50-191) — modelled here as one cut on the WALL and
-- six rungs on the frame it leaves standing, because a turf entry
-- cannot carry assembly states.

local function has(list, want)
    for _, v in ipairs(list) do
        if v == want then
            return true
        end
    end
    return false
end

-- Scenario 1: the deck. Bare plating, two rods, and a wrench.
t.world([==[(
    name: "engine deck",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(2, 1, "rod"), (2, 1, "crowbar"), (2, 1, "wrench")],
)]==], 7)

local p = t.join()
t.tick()

local function take(id)
    t.drop(p)
    t.tick()
    t.click(p, 2, 1, t.target_at(2, 1, id))
    t.tick()
    t.messages(p)
end

take("rod")
t.click(p, 1, 1) -- the plating beside the player
t.run_seconds(3.5)
assert(t.turf(1, 1) == "reinforced_floor",
    "two rods reinforce the deck, got " .. tostring(t.turf(1, 1)))
assert(has(t.messages(p), "The rods are wrenched down flush with the deck."),
    "and the work narrated itself")

-- A crowbar finds nothing to lift. tg's override is literally a bare
-- `return`, so the right shape of "no" is silence and an unchanged
-- deck, not a refusal about floor tiles.
take("crowbar")
t.click(p, 1, 1)
t.run_seconds(1.0)
assert(t.turf(1, 1) == "reinforced_floor", "the crowbar changed nothing")
local said = t.messages(p)
assert(not has(said, "You pry up the floor tile."), "and lifted no tile")
assert(#t.items_at(1, 1) == 0, "nothing came up off the deck")

-- The wrench does, and hands back exactly what the deck cost.
take("wrench")
t.click(p, 1, 1)
t.run_seconds(3.5)
assert(t.turf(1, 1) == "plating",
    "the rods come out, got " .. tostring(t.turf(1, 1)))
assert(has(t.items_at(1, 1), "rod"), "and are lying where they were fitted")
assert(has(t.messages(p), "The rods come up, leaving bare plating."),
    "the second half of the trade narrated too")

-- Scenario 2: the wall, and the ladder back down out of it.
t.world([==[(
    name: "hull site",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (2, 2, "plasteel"), (2, 2, "screwdriver"), (2, 2, "wirecutters"),
        (2, 2, "crowbar"), (2, 2, "welder"), (2, 2, "wrench"),
    ],
    structures: [(1, 2, "girder")],
)]==], 7)

p = t.join()
t.tick()

local function grab(id)
    t.drop(p)
    t.tick()
    t.click(p, 2, 2, t.target_at(2, 2, id))
    t.tick()
    t.messages(p)
end

local function frame_state()
    local s = t.structure_at(1, 2)
    return s ~= nil and s.id == "reinforced_wall_frame" and s.state or nil
end

grab("plasteel")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(5.5)
local girder = t.structure_at(1, 2)
assert(girder ~= nil and girder.id == "reinforced_girder",
    "one sheet struts the frame")

t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(5.5)
assert(t.turf(1, 2) == "reinforced_wall",
    "one more plates it into hull, got " .. tostring(t.turf(1, 2)))
assert(t.structure_at(1, 2) == nil, "and the girder is consumed into it")

-- A torch never opens one: tg overrides try_decon and there is no
-- welder branch in it. The cutters are the whole door.
grab("welder")
t.click(p, 1, 2)
t.run_seconds(10.5)
assert(t.turf(1, 2) == "reinforced_wall", "the torch got nowhere")

grab("wirecutters")
t.click(p, 1, 2)
t.run_ticks(4)
assert(t.turf(1, 2) == "plating", "the grille parts and the hull is open")
assert(frame_state() == "support_lines", "the frame is standing in it")

-- The first rung repairs: tg's INTACT/SUPPORT_LINES pair is a snip
-- either way, and going back up is a wall again.
t.click(p, 1, 2, t.target_at(1, 2))
t.run_ticks(4)
assert(t.turf(1, 2) == "reinforced_wall", "the grille is woven shut")
t.click(p, 1, 2)
t.run_ticks(4)
assert(frame_state() == "support_lines", "and open again for the ladder")

grab("screwdriver")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(4.5)
assert(frame_state() == "cover", "the support lines come unsecured")

grab("welder")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(6.5)
assert(frame_state() == "cut_cover", "the cover is sliced through")

grab("crowbar")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(10.5)
assert(frame_state() == "anchor_bolts", "the cover is pried away")

grab("wrench")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(4.5)
assert(frame_state() == "support_rods", "the anchoring bolts come out")

grab("welder")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(10.5)
assert(frame_state() == "sheath", "the support rods are sliced")

grab("crowbar")
t.click(p, 1, 2, t.target_at(1, 2))
t.run_seconds(10.5)
local left = t.structure_at(1, 2)
assert(left ~= nil and left.id == "reinforced_girder",
    "the sheath comes off and the girder is what is left standing")
assert(has(t.items_at(1, 2), "plasteel"),
    "with the sheet refunded, exactly as dismantle_wall hands it back")

-- Scenario 3: what the deck under a burn chamber is worth.
--
-- A reinforced floor is 62 500 J/K of slab (a project deviation from
-- tg's INFINITY, atmos/thermal.rs), and it leans on the walls beside
-- it: a reinforced wall is 312 500 J/K (reinf_walls.dm:20) shared among
-- the open tiles that touch it, and this one touches exactly one.
t.world([==[(
    name: "burn chamber corner",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'R': (turf: ReinforcedWall),
        'r': (turf: ReinforcedFloor),
    },
    rows: [
        "#####",
        "##.##",
        "#Rr.#",
        "##.##",
        "#####",
    ],
    spawns: [(3, 2)],
)]==], 7)

t.join()
t.tick()
local deck = t.deck(2, 2)
assert(deck ~= nil, "the reinforced deck is a finite reservoir, not a bath")
assert(math.abs(deck.capacity - 375000.0) < 1.0,
    "62 500 of deck plus one reinforced wall's 312 500, got " .. deck.capacity)
