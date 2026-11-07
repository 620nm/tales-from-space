-- The electrolyzer: its four baked states on the map (`standby`, `off`,
-- `working`, `open`), its examine line, and the full machine-frame build,
-- panel toggle, and crowbar deconstruction loop.

local FLAVOR = "A steel electrolysis cabinet topped with paired glass collection columns."

t.world(
    [==[(
    name: "electrolyzer bench",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#.....#",
                "#######",
            ],
            structures: [
                (1, 1, "electrolyzer", "standby"),
                (2, 1, "electrolyzer", "off"),
                (3, 1, "machine_frame", "empty"),
                (4, 1, "electrolyzer", "working"),
                (5, 1, "electrolyzer", "open"),
                (3, 2, "player_spawn"),
            ],
            items: [
                (2, 2, "cable_coil", { "units": 5 }),
                (3, 2, "machine_board.electrolyzer"),
                (4, 2, "cable_coil", { "units": 1 }),
                (2, 3, "glass", { "units": 1 }),
                (3, 3, "screwdriver"),
                (4, 3, "crowbar"),
            ],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

-- ---------------------------------------------------------------
-- 1. MAP-PLACED STATES & EXAMINE
-- ---------------------------------------------------------------
local MAPPED: { { x: number, y: number, state: string, sprite: string } } = {
    { x = 1, y = 1, state = "standby", sprite = "electrolyzer" },
    { x = 2, y = 1, state = "off", sprite = "electrolyzer_off" },
    { x = 4, y = 1, state = "working", sprite = "electrolyzer_on" },
    { x = 5, y = 1, state = "open", sprite = "electrolyzer_open" },
}

for _, row in ipairs(MAPPED) do
    local structure = assert(t.structure_at(row.x, row.y), "mapped electrolyzer at " .. row.x)
    assert(structure.id == "electrolyzer", "expected electrolyzer id")
    assert(
        structure.state == row.state,
        "expected state " .. row.state .. ", got " .. tostring(structure.state)
    )
    assert(
        structure.sprite == row.sprite,
        "expected sprite " .. row.sprite .. ", got " .. tostring(structure.sprite)
    )
    local target = assert(t.target_at(p, row.x, row.y, "electrolyzer"))
    local look = assert(t.examine(p, row.x, row.y, target), "electrolyzer answers examine")
    assert(look.title == "electrolyzer", "expected title electrolyzer, got " .. look.title)
    assert(
        table.find(look.lines, FLAVOR) ~= nil,
        "expected flavor line on state " .. row.state
    )
end

-- ---------------------------------------------------------------
-- 2. FRAME CONSTRUCTION, PANEL TOGGLES, AND DECONSTRUCTION
-- ---------------------------------------------------------------
local SITE_X, SITE_Y = 3, 1

local function site(): SpecStructureAt
    return assert(t.structure_at(SITE_X, SITE_Y), "structure stands at workbench")
end

local function take(x: number, y: number, id: string)
    assert(t.hands(p).held == nil, "expected empty hand before picking up " .. id)
    local item = assert(t.target_at(p, x, y, id), "expected " .. id .. " on tile")
    t.click(p, x, y, item)
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function click_site(id: string)
    local target = assert(t.target_at(p, SITE_X, SITE_Y, id), "expected " .. id .. " at site")
    t.click(p, SITE_X, SITE_Y, target)
end

assert(site().id == "machine_frame" and site().state == "empty", "starts as bare machine_frame")

-- Wire the frame with 5 cable_coil (2s).
take(2, 2, "cable_coil")
click_site("machine_frame")
t.run_seconds(2.5)
assert(site().state == "wired", "5 cable_coil wires the frame")
assert(t.hands(p).held == nil, "all 5 units of the coil were spent")

-- Seat the electrolyzer board.
take(3, 2, "machine_board.electrolyzer")
click_site("machine_frame")
t.run_ticks(2)
assert(site().state == "boarded", "the electrolyzer board clicks in")
assert(t.hands(p).held == nil, "the board is installed")

-- Add 1 cable_coil and 1 glass.
take(4, 2, "cable_coil")
click_site("machine_frame")
t.run_ticks(2)
assert(t.hands(p).held == nil, "the 1 cable_coil part is installed")

take(2, 3, "glass")
click_site("machine_frame")
t.run_ticks(2)
assert(t.hands(p).held == nil, "the 1 glass sheet is installed")

-- Finish with the screwdriver (4s) -> electrolyzer in standby.
take(3, 3, "screwdriver")
click_site("machine_frame")
t.run_seconds(4.5)
assert(site().id == "electrolyzer", "the frame finishes into an electrolyzer")
assert(site().state == "standby", "freshly built electrolyzer stands in standby")
assert(site().sprite == "electrolyzer", "wearing the standby sprite")

-- Toggle maintenance panel: standby -> open -> standby -> open.
local _ = t.messages(p)
click_site("electrolyzer")
t.run_ticks(2)
assert(site().state == "open", "screwdriver opens the panel")
assert(site().sprite == "electrolyzer_open", "wearing the open sprite")
assert(
    table.find(t.messages(p), "You open the electrolyzer's maintenance panel.") ~= nil,
    "reports opening the panel"
)

click_site("electrolyzer")
t.run_ticks(2)
assert(site().state == "standby", "screwdriver closes the panel")
assert(site().sprite == "electrolyzer", "back to the standby sprite")
assert(
    table.find(t.messages(p), "You close the electrolyzer's maintenance panel.") ~= nil,
    "reports closing the panel"
)

click_site("electrolyzer")
t.run_ticks(2)
assert(site().state == "open", "screwdriver reopens the panel for deconstruction")
assert(site().sprite == "electrolyzer_open", "wearing the open sprite again")

-- Pry apart at open with the crowbar (4s) -> bare machine_frame + board + 6 cable_coil + 1 glass.
t.swap_hands(p)
t.run_ticks(1)
take(4, 3, "crowbar")
local _ = t.messages(p)
click_site("electrolyzer")
t.run_seconds(4.5)

assert(site().id == "machine_frame", "crowbar leaves a machine_frame standing")
assert(site().state == "empty", "the left frame stands in empty state")

local pry_messages = t.messages(p)
assert(
    table.find(pry_messages, "You start prying the electrolyzer apart.") ~= nil,
    "reports starting to pry the electrolyzer apart"
)
assert(
    table.find(pry_messages, "The electrolyzer comes apart, leaving its frame standing.") ~= nil,
    "reports finishing prying the electrolyzer apart"
)

assert(
    t.item_at(SITE_X, SITE_Y, "machine_board.electrolyzer") ~= nil,
    "yields machine_board.electrolyzer on the tile"
)
assert(t.item_at(SITE_X, SITE_Y, "cable_coil") ~= nil, "yields cable_coil on the tile")
assert(
    t.stack_count(assert(t.target_at(p, SITE_X, SITE_Y, "cable_coil"))) == 6,
    "yields all 6 cable_coil (5 frame + 1 board)"
)
assert(t.item_at(SITE_X, SITE_Y, "glass") ~= nil, "yields glass on the tile")
assert(
    t.stack_count(assert(t.target_at(p, SITE_X, SITE_Y, "glass"))) == 1,
    "yields 1 glass sheet"
)
