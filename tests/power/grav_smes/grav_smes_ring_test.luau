local bench = require("@helpers/grav_bench")

-- A wrench unfolds a packed ring into the corner arc between the two bolted
-- emitters beside it, and refuses without exactly two meeting at a corner.
-- A wrench on the set ring packs it back onto its cart.

local TOO_FEW = "The ring has to go between two bolted-down emitters."
local TOO_MANY = "There are more than two emitters here; the ring only fits between two."
local OPPOSITE = "The two emitters must meet at a corner for the ring to fit between them."
local NEEDS_WRENCH = "The packed ring needs a wrench to set it between two emitters."

local function emitter(x: number, y: number, state: string): string
    return string.format('(%d, %d, "grav_emitter", "%s", { "dir": "north" })', x, y, state)
end

-- One room per ask: the cart at (5, 4), the emitters beside it, the player
-- at (4, 3) with a wrench.
local function room(emitters: { string }): number
    local parts = { '(4, 3, "player_spawn")', '(5, 4, "grav_supermagnet")' }
    for _, row in ipairs(emitters) do
        table.insert(parts, row)
    end
    bench.world(table.concat(parts, ", "), '(4, 3, "wrench")')
    local p = t.join()
    t.tick()
    bench.hold(p, "wrench", { { 4, 3 } })
    return p
end

local function wrench_cart(p: number)
    t.click(p, 5, 4, assert(t.target_at(p, 5, 4, "grav_supermagnet")))
    t.run_seconds(1.5)
end

local function refuses(emitters: { string }, line: string)
    local p = room(emitters)
    local _ = t.messages(p)
    wrench_cart(p)
    assert(bench.told(p, line), "the wrench should say: " .. line)
    local standing = assert(t.structure_at(5, 4))
    assert(standing.id == "grav_supermagnet", "and the cart stays packed: " .. tostring(standing.id))
end

-- Each corner: the two emitters name the arc.
for _, case in ipairs({
    { x = { 6, 5 }, y = { 4, 5 }, sprite = "north" },
    { x = { 4, 5 }, y = { 4, 5 }, sprite = "east" },
    { x = { 4, 5 }, y = { 4, 3 }, sprite = "south" },
    { x = { 6, 5 }, y = { 4, 3 }, sprite = "west" },
}) do
    local p = room({
        emitter(case.x[1], case.y[1], "anchored"),
        emitter(case.x[2], case.y[2], "anchored"),
    })
    local _ = t.messages(p)
    wrench_cart(p)
    local ring = assert(t.structure_at(5, 4), "the ring stands")
    assert(ring.id == "grav_supermagnet_ring", "the cart unfolded: " .. tostring(ring.id))
    assert(
        ring.sprite == "grav_supermagnet_ring_" .. case.sprite,
        case.sprite .. " arc, wearing " .. tostring(ring.sprite)
    )
    assert(
        bench.told(p, "The supermagnet ring locks into the corner between the emitters."),
        "the wrench says it took"
    )

    -- And back onto its cart.
    t.click(p, 5, 4, assert(t.target_at(p, 5, 4, "grav_supermagnet_ring")))
    t.run_seconds(1.5)
    assert(
        bench.told(p, "The supermagnet ring folds back onto its cart."),
        "packing it up reads as a sentence"
    )
    local cart = assert(t.structure_at(5, 4), "the cart stands")
    assert(cart.id == "grav_supermagnet", "packed again: " .. tostring(cart.id))
end

-- Any other tool is told what the cart wants; an empty hand hears nothing.
for _, tool in ipairs({ "crowbar", "welder" }) do
    bench.world('(4, 3, "player_spawn"), (5, 4, "grav_supermagnet")', string.format('(4, 3, "%s")', tool))
    local p = t.join()
    t.tick()
    t.click(p, 5, 4, assert(t.target_at(p, 5, 4, "grav_supermagnet")))
    t.tick()
    assert(not bench.told(p, NEEDS_WRENCH), "an empty hand says nothing")
    bench.hold(p, tool, { { 4, 3 } })
    local _ = t.messages(p)
    t.click(p, 5, 4, assert(t.target_at(p, 5, 4, "grav_supermagnet")))
    t.tick()
    assert(bench.told(p, NEEDS_WRENCH), tool .. " should hear what the cart wants")
    assert((assert(t.structure_at(5, 4))).id == "grav_supermagnet", "and the cart stays packed")
end

refuses({}, TOO_FEW)
refuses({ emitter(6, 4, "anchored") }, TOO_FEW)
-- A loose emitter is no anchor for a ring.
refuses({ emitter(6, 4, "anchored"), emitter(5, 5, "displaced") }, TOO_FEW)
refuses({ emitter(4, 4, "anchored"), emitter(6, 4, "anchored") }, OPPOSITE)
refuses({ emitter(5, 3, "anchored"), emitter(5, 5, "anchored") }, OPPOSITE)
refuses({
    emitter(4, 4, "anchored"),
    emitter(6, 4, "anchored"),
    emitter(5, 5, "anchored"),
}, TOO_MANY)
