-- The pyrolyzer asset structure: its four baked states (`standby`, `off`,
-- `working`, `open`), examine prose, and the full frame construction and
-- deconstruction loop through `machine_board.pyrolyzer`.

local FLAVOR = "A domed thermal retort drum with a top riser and a lower carbon drawer."

t.world(
    [==[(
    name: "pyrolyzer bench",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#.......#",
                "#.......#",
                "#########",
            ],
            structures: [
                (1, 1, "pyrolyzer", "standby"),
                (2, 1, "pyrolyzer", "off"),
                (6, 1, "pyrolyzer", "working"),
                (7, 1, "pyrolyzer", "open"),
                (4, 1, "machine_frame"),
                (4, 2, "player_spawn"),
            ],
            items: [
                (3, 1, "cable_coil", { "units": 5 }),
                (5, 1, "cable_coil", { "units": 1 }),
                (3, 2, "machine_board.pyrolyzer"),
                (5, 2, "glass", { "units": 1 }),
                (3, 3, "screwdriver"),
                (5, 3, "crowbar"),
            ],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local SITE_X, SITE_Y = 4, 1

local function site(): SpecStructureAt
    return assert(t.structure_at(SITE_X, SITE_Y), "expected structure at workbench site")
end

local function take(x: number, y: number, id: string)
    assert(t.hands(p).held == nil, "expected empty hand before picking up " .. id)
    local target = assert(t.target_at(p, x, y, id), "expected " .. id .. " on tile")
    t.click(p, x, y, target)
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

-- ---------------------------------------------------------------
-- 1. Map-placed states, sprites, and examine prose.
-- ---------------------------------------------------------------
local mapped: { { x: number, y: number, state: string, sprite: string } } = {
    { x = 1, y = 1, state = "standby", sprite = "pyrolyzer" },
    { x = 2, y = 1, state = "off", sprite = "pyrolyzer_off" },
    { x = 6, y = 1, state = "working", sprite = "pyrolyzer_on" },
    { x = 7, y = 1, state = "open", sprite = "pyrolyzer_open" },
}

for _, row in ipairs(mapped) do
    local unit = assert(t.structure_at(row.x, row.y), "mapped pyrolyzer at " .. row.state)
    assert(unit.id == "pyrolyzer", "expected pyrolyzer id")
    assert(unit.state == row.state, "expected state " .. row.state .. ", got " .. tostring(unit.state))
    assert(
        unit.sprite == row.sprite,
        "expected sprite " .. row.sprite .. " for state " .. row.state .. ", got " .. tostring(unit.sprite)
    )

    local target = assert(t.target_at(p, row.x, row.y, "pyrolyzer"), "targetable pyrolyzer")
    local look = assert(t.examine(p, row.x, row.y, target), "pyrolyzer answers examine")
    assert(look.title == "pyrolyzer", "expected examine title pyrolyzer, got " .. look.title)
    assert(look.sprite == row.sprite, "examine sprite matches state sprite")
    assert(table.find(look.lines, FLAVOR) ~= nil, "examine includes flavor prose")
end

-- ---------------------------------------------------------------
-- 2. Frame construction, panel toggling, and deconstruction.
-- ---------------------------------------------------------------
assert(site().id == "machine_frame" and site().state == "empty", "starts as an empty machine frame")

-- Wire the frame with 5 cable_coil (2s).
take(3, 1, "cable_coil")
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "machine_frame")))
t.run_seconds(2.5)
assert(site().state == "wired", "five lengths of cable wire the frame")
assert(t.hands(p).held == nil, "wiring consumes the five-unit coil")

-- Insert machine_board.pyrolyzer.
take(3, 2, "machine_board.pyrolyzer")
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "machine_frame")))
t.run_ticks(2)
assert(site().state == "boarded", "the pyrolyzer board clicks into place")
assert(t.hands(p).held == nil, "the board is installed")

-- Add 1 cable_coil and 1 glass.
take(5, 1, "cable_coil")
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "machine_frame")))
t.run_ticks(2)
assert(t.hands(p).held == nil, "one unit of cable is installed")

take(5, 2, "glass")
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "machine_frame")))
t.run_ticks(2)
assert(t.hands(p).held == nil, "one sheet of glass is installed")

-- Finish assembly with screwdriver (4s) -> pyrolyzer in standby.
take(3, 3, "screwdriver")
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "machine_frame")))
t.run_seconds(4.5)
assert(site().id == "pyrolyzer", "the frame becomes a pyrolyzer")
assert(site().state == "standby", "freshly assembled pyrolyzer stands in standby")
assert(site().sprite == "pyrolyzer", "wearing the standby sprite")

-- Toggle maintenance panel with screwdriver: standby -> open -> standby -> open.
local _ = t.messages(p)
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "pyrolyzer")))
t.run_ticks(2)
assert(site().state == "open" and site().sprite == "pyrolyzer_open", "screwdriver opens the panel")
assert(
    table.find(t.messages(p), "You open the pyrolyzer's maintenance panel.") ~= nil,
    "opening the panel reports its message"
)

t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "pyrolyzer")))
t.run_ticks(2)
assert(site().state == "standby" and site().sprite == "pyrolyzer", "screwdriver closes the panel")
assert(
    table.find(t.messages(p), "You close the pyrolyzer's maintenance panel.") ~= nil,
    "closing the panel reports its message"
)

t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "pyrolyzer")))
t.run_ticks(2)
assert(site().state == "open" and site().sprite == "pyrolyzer_open", "screwdriver reopens the panel")

-- Deconstruct open pyrolyzer with crowbar (4s) -> empty machine_frame + board + 6 cable_coil + 1 glass.
t.swap_hands(p)
t.run_ticks(1)
take(5, 3, "crowbar")
local _ = t.messages(p)
t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "pyrolyzer")))
t.run_seconds(4.5)

assert(site().id == "machine_frame" and site().state == "empty", "deconstruction leaves an empty machine frame")
assert(
    table.find(t.messages(p), "The pyrolyzer comes apart, leaving its frame standing.") ~= nil,
    "deconstruction reports completion"
)
assert(t.item_at(SITE_X, SITE_Y, "machine_board.pyrolyzer") ~= nil, "the pyrolyzer board is yielded on the tile")
assert(t.item_at(SITE_X, SITE_Y, "cable_coil") ~= nil, "cable coil is yielded on the tile")
assert(
    t.stack_count(assert(t.target_at(p, SITE_X, SITE_Y, "cable_coil"))) == 6,
    "six lengths of cable (five frame + one board) come back"
)
assert(t.item_at(SITE_X, SITE_Y, "glass") ~= nil, "glass is yielded on the tile")
assert(
    t.stack_count(assert(t.target_at(p, SITE_X, SITE_Y, "glass"))) == 1,
    "one glass sheet comes back"
)
