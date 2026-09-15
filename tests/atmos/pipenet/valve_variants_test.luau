local network_matter = require("@helpers/network_matter")
local network_channels = require("@helpers/network_channels")

-- The valve roster: the two layer-pinned wheels, and the digital twin.
--
-- atmos_devices_test.luau proves what a manual valve does to gas on the
-- distribution layer; flow_windows_test.luau proves that the digital
-- one answers a panel where the manual one answers a hand. Neither asks
-- the two questions a ROSTER raises:
--
--   * a wheel a MAP moved onto another main has to be deaf to every
--     other one. A station's mains are stacked ON THE SAME TILES --
--     distro, scrubbers and supply cross each other everywhere -- so a
--     wheel that fused the wrong pair would dump the waste main into
--     the air people breathe, and it would look exactly like a working
--     valve from above. tg says which main by setting `piping_layer` on
--     the instance (`HELPER_PIPING_LAYER`, pipes/mapping.dm); this pack
--     used to say it by shipping the same file three times over, once
--     per layer, which is a roster that grows with the alphabet.
--   * and the digital valve has never been shown to BE a valve. Its
--     panel is specced; its topology is not. tg's two valves are the
--     same subtype differing in one flag (valve.dm:13 vs 86), so the
--     net they make must be identical to the mole.
--
-- Pipe channels select the independent mains; l3 is distribution.

local ui_controls = require("@helpers/ui_controls")

local PIPE_M3 = 0.070
local PORT_M3 = 0.200

local function near(a: number?, b: number?, slack: number, what: string)
    assert(a ~= nil and b ~= nil, what .. ": both readings are present")
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function moles(x: number, y: number, layer: string?)
    local held = network_matter.gas(x, y, layer)
    if not held then
        return 0.0
    end
    local n = 0.0
    for _, amount in pairs(held) do
        n = n + amount
    end
    return n
end

-- ---------------------------------------------------------------
-- A PINNED WHEEL TURNS ONE MAIN AND NOTHING ELSE.
--
-- Three mains stacked on one line of tiles -- layers 2, 3 and 4 -- with
-- a valve standing in ONE of them. Its own layer has no length under
-- the machine (a run does not pass through a valve); the other two do,
-- and cross beneath it untouched.
--
-- The west half of the pinned main is warmed first, so the wheel has
-- something visible to do and the crossing runs have something to
-- wrongly notice. Then the only assertion that matters: after the
-- wheel, the two mains this valve is not on read the same pressure,
-- the same temperature and the same joules they did before anybody
-- touched anything.
-- ---------------------------------------------------------------
local CROSSING = [==[(
    name: "stacked mains",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    // Every tile of the line carries all three mains. The valve's OWN
    // layer is the one length that is missing under it -- a run does
    // not pass through a machine, and a map that draws one there is
    // refused at boot ("conflicting atmospherics", sim/mod.rs), so
    // this mask is the only legal way to draw a crossing.
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 1, y: 1, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        %s,
        (x: 4, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l4", kind: "standard", facing: 15),
    ],
    structures: [(3, 2, "player_spawn"), (3, 1, "manual_valve", { "channel": "%s" })],
)]==]

-- One placed valve, proved against the two layers it is not on.
-- The same channel ID selects the valve and its run.
local function pinned(mine: string, others: { string }, heat: number)
    local crossing = {}
    local channels = {}
    for _, other in ipairs(others) do
        table.insert(channels, other)
        table.insert(crossing, string.format(
            '(x: 3, y: 1, network: "pipe", channel: "%s", kind: "standard", facing: 15)', other
        ))
    end
    table.sort(channels)
    t.world(CROSSING:format(table.concat(crossing, ", "), mine), 7)
    local p = t.join()
    t.tick()

    local id = "manual_valve"
    assert(assert(t.structure_at(3, 1)).id == id, "the map stood one wheel on the line")
    assert(assert(t.structure_at(3, 1)).state == "shut", "shut, like every valve")
    assert(network_channels.at(3, 1, "pipe") == table.concat(channels, ","), "the crossing mains keep a length under it: " .. network_channels.at(3, 1, "pipe"))
    assert(network_matter.pressure(3, 1, mine) == nil, "and no net of its own layer claims its tile")

    -- Warm the west half of the pinned main. Scaffolding, and the only
    -- way to make a shut valve's two sides tell themselves apart.
    assert(network_matter.heat(1, 1, heat, mine), "the west half takes the heat")
    t.tick()
    local west_k = assert(network_matter.temperature(1, 1, mine))
    local east_k = assert(network_matter.temperature(5, 1, mine))
    assert(
        west_k > east_k + 80.0,
        "a shut valve is a wall to heat too: " .. west_k .. " / " .. east_k
    )

    -- What the crossing mains read while all this is going on. Each is
    -- one net from end to end, straight under the machine.
    local was = {}
    for _, layer in ipairs(others) do
        assert(
            assert(network_matter.pressure(3, 1, layer)) > 90.0,
            "the crossing main runs under the valve"
        )
        was[layer] = {
            kpa = assert(network_matter.pressure(1, 1, layer)),
            k = assert(network_matter.temperature(1, 1, layer)),
            j = assert(network_matter.energy(1, 1, layer)),
            n = moles(5, 1, layer),
        }
    end

    -- Turn it. tg gives the wheel its second (valve.dm:69).
    t.click(p, 3, 1, t.target_at(p, 3, 1, id))
    t.run_seconds(2)
    assert(assert(t.structure_at(3, 1)).state == "open", "the wheel turns")
    t.run_seconds(1)

    -- Its own main is one body of gas now: the heat crossed.
    near(
        assert(network_matter.temperature(1, 1, mine)),
        assert(network_matter.temperature(5, 1, mine)),
        0.001,
        "the pinned main fused, so both halves read one temperature"
    )
    assert(
        assert(network_matter.temperature(5, 1, mine)) > east_k + 20.0,
        "and the cold half got the warmth: "
            .. east_k
            .. " -> "
            .. assert(network_matter.temperature(5, 1, mine))
    )

    -- And the mains it is NOT on never noticed a thing.
    for _, layer in ipairs(others) do
        local before = was[layer]
        near(
            assert(network_matter.pressure(1, 1, layer)),
            before.kpa,
            1e-9,
            "layer " .. layer .. " kept its pressure"
        )
        near(
            assert(network_matter.temperature(1, 1, layer)),
            before.k,
            1e-9,
            "layer " .. layer .. " kept its temperature"
        )
        near(
            assert(network_matter.energy(1, 1, layer)),
            before.j,
            1e-9,
            "layer " .. layer .. " kept every joule"
        )
        near(moles(5, 1, layer), before.n, 1e-9, "layer " .. layer .. " kept every mole")
    end
end

-- The scrubbers main, and the supply main. One content file, one
-- prototype, and one number on the placement.
pinned("l2", { "l3", "l4" }, 40000.0)
pinned("l4", { "l2", "l3" }, 40000.0)

-- ---------------------------------------------------------------
-- THE DIGITAL VALVE IS A VALVE.
--
-- Two identical mains that never touch -- one on row 1 with a wheel in
-- it, one on row 3 with a panel -- warmed identically, opened, and shut
-- again. A valve does not pump: an open one FUSES its two pipelines and
-- lets them reconcile as one (`custom_reconcilation`, valve.dm:56-61),
-- so the proof is topological rather than a flow rate. One net means
-- both ends report the same body of gas, and shutting divides it back
-- by VOLUME, to the mole.
--
-- Every number the digital valve produces is then held against the
-- number the manual one produced from the same start. They are the same
-- subtype in tg; here they are two content files, and the only thing
-- that may differ between them is the surface a player touches.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "two valves, one law",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "##########",
        "#........#",
        "#........#",
        "#........#",
        "##########",
    ],
    // Row 2 carries no pipe at all, so the two mains are never
    // adjacent: one walkway between them, and no plumbing across it.
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 6, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 7, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 8, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 1, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 6, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 7, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 8, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    structures: [(4, 2, "player_spawn"), (4, 1, "manual_valve"), (4, 3, "digital_valve")],
)]==],
    7
)

local v = t.join()
t.tick()
assert(assert(t.structure_at(4, 1)).state == "shut", "the wheel starts shut")
assert(assert(t.structure_at(4, 3)).state == "shut", "and so does the panel's valve")

local WEST_M3 = 3 * PIPE_M3 + PORT_M3
local EAST_M3 = 4 * PIPE_M3 + PORT_M3

-- The same joules into the west half of each main.
assert(network_matter.heat(1, 1, 40000.0), "the wheel's west half takes the heat")
assert(network_matter.heat(1, 3, 40000.0), "and the panel's west half takes the same")
t.tick()

local function main_reading(y: number, name: string)
    local west_n, east_n = moles(1, y), moles(8, y)
    return {
        y = y,
        name = name,
        west_k = assert(network_matter.temperature(1, y)),
        east_k = assert(network_matter.temperature(8, y)),
        west_n = west_n,
        east_n = east_n,
        books = west_n + east_n,
        energy = assert(network_matter.energy(1, y)) + assert(network_matter.energy(8, y)),
    }
end
local rows = { main_reading(1, "the manual main"), main_reading(3, "the digital main") }
for _, m in ipairs(rows) do
    assert(m.west_k > m.east_k + 80.0, m.name .. " is hot at one end: " .. m.west_k)
    near(m.west_n / m.east_n, WEST_M3 / EAST_M3, 0.02, m.name .. " holds gas by volume")
end
near(rows[1].books, rows[2].books, 1e-9, "the two mains start with the same gas in them")
near(rows[1].west_k, rows[2].west_k, 1e-9, "at the same two temperatures")

-- ---- open both, each the way its own machine is opened ----
t.click(v, 4, 1, t.target_at(v, 4, 1, "manual_valve"))
t.run_seconds(2)
assert(assert(t.structure_at(4, 1)).state == "open", "the wheel is over")

t.click(v, 4, 3, t.target_at(v, 4, 3, "digital_valve"))
t.tick()
local panel = ui_controls.record(t.ui(v))
assert(
    ui_controls.record(ui_controls.rows(panel.toggles)[1].label).id == "flow.switch.valve",
    "the digital valve answers with a panel"
)
ui_controls.toggle(v, "power")
t.run_ticks(2)
assert(assert(t.structure_at(4, 3)).state == "open", "which throws on the command, with no wheel")
t.run_seconds(1)

for _, m in ipairs(rows) do
    -- ONE NET. Both ends of the main report the same body of gas, and
    -- that body is exactly the two halves added together -- which no
    -- amount of pumping between two nets could ever produce.
    near(moles(1, m.y), moles(8, m.y), 1e-9, m.name .. ": both ends report one net")
    near(moles(1, m.y), m.books, 1e-9, m.name .. ": holding both halves at once")
    near(
        assert(network_matter.temperature(1, m.y)),
        (m.west_n * m.west_k + m.east_n * m.east_k) / m.books,
        0.01,
        m.name .. ": at the blend of the two halves it swallowed"
    )
end
near(
    assert(network_matter.pressure(1, 1)),
    assert(network_matter.pressure(1, 3)),
    1e-9,
    "and the panel's valve made exactly the net the wheel did"
)

-- ---- shut both again ----
t.click(v, 4, 1, t.target_at(v, 4, 1, "manual_valve"))
t.run_seconds(2)
assert(assert(t.structure_at(4, 1)).state == "shut", "the wheel is back")
ui_controls.toggle(v, "power")
t.run_ticks(2)
assert(assert(t.structure_at(4, 3)).state == "shut", "and the panel's valve with it")
t.run_seconds(1)

for _, m in ipairs(rows) do
    near(
        moles(1, m.y) / moles(8, m.y),
        WEST_M3 / EAST_M3,
        1e-6,
        m.name .. ": the gas divided back by volume"
    )
    near(moles(1, m.y) + moles(8, m.y), m.books, 1e-9, m.name .. ": and not a mole was lost")
    near(
        assert(network_matter.energy(1, m.y)) + assert(network_matter.energy(8, m.y)),
        m.energy,
        1.0,
        m.name .. ": nor a joule"
    )
    near(
        assert(network_matter.temperature(1, m.y)),
        assert(network_matter.temperature(8, m.y)),
        1e-9,
        m.name .. ": and the halves are level, because they were one body of gas"
    )
end
near(moles(1, 1), moles(1, 3), 1e-9, "the two machines split it identically as well")
