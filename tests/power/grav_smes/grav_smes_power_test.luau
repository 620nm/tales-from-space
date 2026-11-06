local bench = require("@helpers/grav_bench")
local ui_controls = require("@helpers/ui_controls")

-- The finished gravity battery runs: a start button that wants standby
-- and charge, 0.8 s of spin-up, weight on deck that starts within thirty
-- tiles and on all deck joined to it, however far it runs, while the store
-- pays the field's draw, and none on deck the field cannot reach. A battery that runs dry spins itself down; the
-- stop button does the same on purpose; and a supply cable under an
-- emitter's cell charges the store.
--
-- Weight is read the way a crewman feels it. Under a weightless sky a
-- body on bare deck with nothing to brace on cannot step at all, so a
-- probe standing in the open tries a step and reports whether it moved.
-- The battery stands on the main deck at (7, 5), cells (6..8, 4..6); a
-- causeway runs east from it along y = 5, past thirty tiles; a
-- three-by-three island of deck floats apart from both, beyond thirty.
local WIDTH = 44
local HEIGHT = 11
local CENTRE_X = 7
local CENTRE_Y = 5
local STANDBY = "^standby"

-- Probe spots: open deck with no wall or machine in reach.
local NEAR = { x = 12, y = 2 } -- main deck, ~5 tiles away
local MID = { x = 30, y = 5 } -- causeway, 23 tiles away: inside the field
local FAR = { x = 40, y = 5 } -- same causeway, 33 tiles away: joined, so inside
local ISLAND = { x = 41, y = 9 } -- deck 34 tiles away that nothing joins to the battery
local OPERATOR = { x = 9, y = 5 }

local function deck_at(x: number, y: number): boolean
    if x >= 1 and x <= 13 and y >= 1 and y <= 9 then
        return true
    end
    if y == 5 and x >= 14 and x <= 42 then
        return true
    end
    return x >= 40 and x <= 42 and y >= 8 and y <= 10
end

local function rows(supplied: boolean): string
    local lines = {}
    for y = 0, HEIGHT - 1 do
        local line = table.create(WIDTH, " ")
        for x = 0, WIDTH - 1 do
            if deck_at(x, y) then
                line[x + 1] = "."
            end
        end
        if supplied and y == CENTRE_Y then
            line[4] = "G"
        end
        table.insert(lines, `"{table.concat(line)}"`)
    end
    return table.concat(lines, ",\n")
end

-- Every deck tile starts airless: air venting off open deck into space
-- would blow a weightless body off its spot before any step is tried.
local function airless(): string
    local lines = {}
    for y = 0, HEIGHT - 1 do
        for x = 0, WIDTH - 1 do
            if deck_at(x, y) then
                table.insert(lines, `({x}, {y}, "airless")`)
            end
        end
    end
    return table.concat(lines, ", ")
end

local function cables(): string
    local lines = {}
    for x = 3, 5 do
        table.insert(
            lines,
            `(x: {x}, y: {CENTRE_Y}, network: "power", channel: "l2", kind: "cable", facing: 15)`
        )
    end
    -- The west emitter's cell is the last cable's tile.
    table.insert(
        lines,
        `(x: {CENTRE_X - 1}, y: {CENTRE_Y}, network: "power", channel: "l2", kind: "cable", facing: 15)`
    )
    return table.concat(lines, ",\n")
end

type Probe = { player: number, x: number }

type Bench = {
    operator: number,
    near: Probe,
    mid: Probe,
    far: Probe,
    island: Probe,
}

-- The bay: a battery at its center, and with `supplied` a generator whose
-- backbone runs under the west emitter's cell.
local function build(supplied: boolean): Bench
    t.world(
        string.format(
            [==[(
    name: "gravity bay",
    environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    levels: [
        (
            rows: [
%s
            ],
            structures: [
                (%d, %d, "player_spawn", { "jobs": "engineer" }),
                (%d, %d, "player_spawn", { "jobs": "assistant" }),
                (%d, %d, "player_spawn", { "jobs": "medic" }),
                (%d, %d, "player_spawn", { "jobs": "security" }),
                (%d, %d, "player_spawn", { "jobs": "captain" }),
                (%d, %d, "grav_smes", "standby"),
            ],
            networks: [
%s
            ],
            painted: [%s],
        ),
    ],
    blends: { "airless": (rows: [], temperature_k: 2.7, amount: per_m3) },
)]==],
            rows(supplied),
            OPERATOR.x,
            OPERATOR.y,
            NEAR.x,
            NEAR.y,
            MID.x,
            MID.y,
            FAR.x,
            FAR.y,
            ISLAND.x,
            ISLAND.y,
            CENTRE_X,
            CENTRE_Y,
            if supplied then cables() else "",
            airless()
        ),
        7
    )
    local operator = t.join("engineer")
    local near = t.join("assistant")
    local mid = t.join("medic")
    local far = t.join("security")
    local island = t.join("captain")
    t.set_breathing(false)
    t.run_ticks(4)
    return {
        operator = operator,
        near = { player = near, x = NEAR.x },
        mid = { player = mid, x = MID.x },
        far = { player = far, x = FAR.x },
        island = { player = island, x = ISLAND.x },
    }
end

-- Whether a step off the spot succeeds: east from home, west back again.
local function weighs(probe: Probe): boolean
    local before = t.pos(probe.player)
    local dir = if before > probe.x then "west" else "east"
    t.move(probe.player, dir)
    t.run_seconds(0.6)
    return t.pos(probe.player) ~= before
end

type Weights = { near: boolean, mid: boolean, far: boolean, island: boolean }

local function weights(b: Bench): Weights
    return {
        near = weighs(b.near),
        mid = weighs(b.mid),
        far = weighs(b.far),
        island = weighs(b.island),
    }
end

local function assert_weights(b: Bench, want: Weights, why: string)
    local got = weights(b)
    assert(got.near == want.near, why .. ": the near deck weighs " .. tostring(got.near))
    assert(got.mid == want.mid, why .. ": the causeway weighs " .. tostring(got.mid))
    assert(got.far == want.far, why .. ": the causeway past thirty tiles weighs " .. tostring(got.far))
    assert(got.island == want.island, why .. ": the island weighs " .. tostring(got.island))
end

local NONE: Weights = { near = false, mid = false, far = false, island = false }
local FIELD: Weights = { near = true, mid = true, far = true, island = false }

local function state(): string
    return tostring(assert(t.structure_at(CENTRE_X, CENTRE_Y)).state)
end

local function press(b: Bench, key: string)
    t.click(
        b.operator,
        CENTRE_X + 1,
        CENTRE_Y,
        t.target_at(b.operator, CENTRE_X + 1, CENTRE_Y, "grav_smes")
    )
    t.run_ticks(2)
    ui_controls.toggle(b.operator, "action", key)
    t.run_ticks(2)
end

local function start_to_active(b: Bench)
    press(b, "start")
    t.run_ticks(4)
    assert(state() == "startup", "a start begins the spin-up, got " .. state())
    t.run_seconds(1.2)
    assert(string.find(state(), "^active") ~= nil, "and the spin-up ends active, got " .. state())
    t.run_seconds(2.0)
end

-- ---------------------------------------------------------------
-- A BATTERY WITH NO SUPPLY runs off its own charge.
-- ---------------------------------------------------------------
local b = build(false)
assert(
    assert(t.environment().profile).gravity_m_s2 == 0,
    "the sky has no field of its own: " .. t.environment().id
)
assert(string.find(state(), STANDBY) ~= nil, "the battery stands in standby, got " .. state())
assert_weights(b, NONE, "standby")

-- Too little charge refuses the start and says so.
t.set_store_charge(CENTRE_X, CENTRE_Y, 0.0)
t.messages(b.operator)
press(b, "start")
assert(
    bench.told(b.operator, "The gravity battery holds too little charge to start."),
    "an empty battery will not start"
)
assert(string.find(state(), STANDBY) ~= nil, "and stays in standby, got " .. state())
assert_weights(b, NONE, "a refused start")

-- A charged one spins up and holds weight on connected deck in range.
t.set_store_charge(CENTRE_X, CENTRE_Y, 1.0)
start_to_active(b)
assert(state() == "active_discharging", "running off its store reads discharging, got " .. state())
assert_weights(b, FIELD, "running")

-- A battery that runs dry spins itself down, and the weight goes.
t.set_store_charge(CENTRE_X, CENTRE_Y, 0.0)
t.run_seconds(5.0)
assert(string.find(state(), STANDBY) ~= nil, "a drained battery spins down to standby, got " .. state())
assert_weights(b, NONE, "drained")

-- The stop button spins a running battery down on purpose.
t.set_store_charge(CENTRE_X, CENTRE_Y, 1.0)
start_to_active(b)
press(b, "stop")
t.run_ticks(4)
assert(state() == "shutdown", "stop begins the spin-down, got " .. state())
t.run_seconds(1.2)
assert(string.find(state(), STANDBY) ~= nil, "and the spin-down ends in standby, got " .. state())
assert_weights(b, NONE, "stopped")

t.messages(b.operator)
press(b, "stop")
assert(
    bench.told(b.operator, "The gravity battery is not running."),
    "stopping a stopped battery says so"
)

-- ---------------------------------------------------------------
-- A CABLE UNDER AN EMITTER'S CELL CHARGES THE STORE.
-- ---------------------------------------------------------------
local fed = build(true)
t.set_store_charge(CENTRE_X, CENTRE_Y, 0.0)
t.run_seconds(6.0)
local store = assert(t.store_at(CENTRE_X, CENTRE_Y))
assert(store.charge_j > 0.0, "the west cell's backbone charged the store: " .. store.charge_j)
assert(
    string.find(state(), "^standby_charging") ~= nil,
    "and the panel glyph says charging, got " .. state()
)
start_to_active(fed)
assert_weights(fed, FIELD, "running off the grid")
