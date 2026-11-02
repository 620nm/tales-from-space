local bench = require("@helpers/liquid_bench")
local network_matter = require("@helpers/network_matter")
local ui_controls = require("@helpers/ui_controls")

-- A sump pump takes a deck bone dry over its reach, film and all, bills by
-- reach, stops at a full line and leaves gas and beads alone. The stock dial
-- is 10 L/s of 50, so 2 kW bills 400 W a tile.
local RING = {
    { x = 4, y = 3 },
    { x = 3, y = 3 },
    { x = 5, y = 3 },
    { x = 4, y = 2 },
    { x = 4, y = 4 },
    { x = 3, y = 2 },
    { x = 5, y = 2 },
    { x = 3, y = 4 },
    { x = 5, y = 4 },
}
local BEYOND = { x = 6, y = 2 }
local APC = { x = 6, y = 3 }

local function room(gravity: string): number
    local pools = {}
    for _, tile in ipairs(RING) do
        table.insert(pools, { x = tile.x, y = tile.y, litres = 2 })
    end
    table.insert(pools, { x = BEYOND.x, y = BEYOND.y, litres = 2 })
    return bench.world({
        environment = gravity,
        rows = {
            "#########",
            "#.......#",
            "#.......#",
            "#......g#",
            "#.......#",
            "#.......#",
            "#########",
        },
        structures = `(5, 3, "player_spawn"), ({APC.x}, {APC.y}, "apc"), (4, 3, "sump_pump", "pumping", \{"pipe": "west"})`,
        run = { { x = 3, y = 3 } },
        cables = {
            { x = 4, y = 3, channel = "l1" },
            { x = 5, y = 3, channel = "l1" },
            { x = 6, y = 3, channel = "l1" },
            { x = 6, y = 3, channel = "l2" },
            { x = 7, y = 3, channel = "l2" },
        },
        pools = pools,
    })
end

-- Two litres a tile, under the film: a passive mouth could not touch them.
for _, service in ipairs({ 1, 5, 9 }) do
    local p = room(bench.ONE_G)
    local gas_before = assert(network_matter.gas(3, 3))
    t.click(p, 4, 3, t.target_at(p, 4, 3, "sump_pump"))
    t.tick()
    ui_controls.toggle(p, "service", tostring(service))
    t.run_seconds(3)

    for index, tile in ipairs(RING) do
        local left = bench.standing(tile.x, tile.y)
        if index <= service then
            assert(left < 1e-6, `reach {service} dries ({tile.x}, {tile.y}): {left} L`)
        else
            assert(left > 1.9, `reach {service} leaves ({tile.x}, {tile.y}): {left} L`)
        end
    end
    assert(bench.standing(BEYOND.x, BEYOND.y) > 1.9, "nothing past the ring")

    local billed = t.ports_at(APC.x, APC.y, "power").channels["l1"].out_w
    local owed = 400 * service
    assert(math.abs(billed - owed) < owed * 0.05, `reach {service} bills {owed} W, got {billed}`)

    local gas_after = assert(network_matter.gas(3, 3))
    for _, id in ipairs({ "o2", "n2" }) do
        assert(
            math.abs((gas_after[id] or 0) - (gas_before[id] or 0)) < 1e-6,
            `no {id} goes down the pump`
        )
    end
end

local function strip(gravity: string, litres: number): number
    local pools = {}
    for x = 1, 4 do
        table.insert(pools, { x = x, y = 1, litres = litres })
    end
    return bench.world({
        environment = gravity,
        rows = { "######", "#..g.#", "######" },
        structures = '(2, 1, "player_spawn"), (4, 1, "apc"), (1, 1, "sump_pump", "pumping", {"pipe": "north"})',
        run = { { x = 1, y = 0 } },
        cables = {
            { x = 1, y = 1, channel = "l1" },
            { x = 2, y = 1, channel = "l1" },
            { x = 3, y = 1, channel = "l1" },
            { x = 4, y = 1, channel = "l1" },
            { x = 3, y = 1, channel = "l2" },
            { x = 4, y = 1, channel = "l2" },
        },
        pools = pools,
    })
end

-- Three hundred litres and a port with a length: 256.5 L fills the line.
local p = strip(bench.ONE_G, 75)
t.run_seconds(40)
local left = 0
for x = 1, 4 do
    left += bench.standing(x, 1)
end
assert(math.abs(left - 43.5) < 3, `a full line stops the pump, {left} L left`)
assert(assert(t.structure_at(1, 1)).state == "fault", "and the fault lamp comes on")
t.click(p, 1, 1, t.target_at(p, 1, 1, "sump_pump"))
t.tick()
local said = {}
for _, row in ipairs(ui_controls.rows(ui_controls.state(p).readouts)) do
    said[ui_controls.word(row.label)] = ui_controls.word(row.value)
end
assert(said["scrubber.blocked"] == "scrubber.blocked.fill", "and the panel says why")

-- Without weight it is not a deck's water to take.
strip(bench.ZERO_G, 10)
t.run_seconds(5)
assert(bench.standing(1, 1) > 9.9, "beads float past the pump")
assert(assert(t.structure_at(1, 1)).state == "off", "and it has nothing to do")
