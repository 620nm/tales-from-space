local ui_controls = require("@helpers/ui_controls")

-- One gas turbine section, built the long way and taken back apart: a
-- machine frame, the section's board, its part and the board's five lengths
-- of cable and five sheets (machine_circuitboards.dm:323-329), then the
-- maintenance panel it turns behind (turbine.dm:167-192, _machinery.dm:1069).

t.world([==[(
    name: "turbine bench",
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
            structures: [(3, 2, "player_spawn")],
            items: [
                (2, 1, "crowbar"),
                (2, 1, "metal", { "units": 5 }),
                (4, 1, "cable_coil", { "units": 5 }),
                (4, 1, "wrench"),
                (2, 2, "machine_board.inlet_compressor"),
                (4, 2, "screwdriver"),
                (2, 3, "compressor_part"),
                (3, 3, "cable_coil", { "units": 5 }),
                (4, 3, "metal", { "units": 5 }),
            ],
        ),
    ],
)]==])

local p = t.join()
t.tick()

local SITE_X, SITE_Y = 3, 1

-- What the player heard since the last drain.
local function heard(): { string }
    return t.messages(p)
end

-- Every supply lies on its own tile around the player, so none hides
-- another. One hand carries the screwdriver; the other takes each stack,
-- which the build uses up whole.
local function take(x: number, y: number, id: string)
    assert(t.hands(p).held == nil, "a free hand for " .. id)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

-- Bring the other hand up.
local function swap()
    t.swap_hands(p)
    t.run_ticks(1)
end

local function use_on_site(id: string, seconds: number)
    t.click(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, id)))
    t.run_seconds(seconds)
end

local function site(): SpecStructureAt
    return assert(t.structure_at(SITE_X, SITE_Y), "something stands on the site")
end

-- The frame, wired, boarded.
take(2, 1, "metal")
ui_controls.build(p, "metal", "machine_frame", SITE_X, SITE_Y)
t.run_seconds(8.5)
assert(site().id == "machine_frame", "five sheets box up into a frame")
take(4, 1, "cable_coil")
use_on_site("machine_frame", 2.5)
assert(site().state == "wired", "five lengths of cable wire it")
take(2, 2, "machine_board.inlet_compressor")
use_on_site("machine_frame", 0.2)
assert(site().state == "boarded", "the section's board clicks in")

-- The board asks for the section's part before anything else.
swap()
take(4, 2, "screwdriver")
local _ = t.messages(p)
use_on_site("machine_frame", 4.5)
local refusal = heard()
assert(
    table.find(refusal, "It still needs 1 x compressor part.") ~= nil,
    "the frame names the part: " .. table.concat(refusal, " | ")
)
swap()
take(2, 3, "compressor_part")
use_on_site("machine_frame", 0.2)
assert(t.hands(p).held == nil, "the part goes in whole")

-- Then five of each stack, one unit a click.
local supplies: { { x: number, y: number, id: string } } = {
    { x = 3, y = 3, id = "cable_coil" },
    { x = 4, y = 3, id = "metal" },
}
for _, supply in ipairs(supplies) do
    take(supply.x, supply.y, supply.id)
    for _ = 1, 5 do
        use_on_site("machine_frame", 0.2)
    end
    assert(t.hands(p).held == nil, "the board takes all five " .. supply.id)
end
swap()
assert(t.hands(p).held == "screwdriver", "the screwdriver in the other hand")
use_on_site("machine_frame", 4.5)
assert(site().id == "inlet_compressor", "the frame becomes the section its board names")
assert(site().state == "closed", "with its panel shut")
assert(site().sprite == "inlet_compressor_closed_s", "facing south, tg's default")

-- Open, Alt+click still does not turn it: a section declares no Alt turn,
-- only the wrench (_machinery.dm:1069-1077).
local _ = t.messages(p)
use_on_site("inlet_compressor", 0.2)
assert(site().state == "open", "the screwdriver opens the panel")
assert(table.find(heard(), "You open the maintenance panel.") ~= nil, "and says so")
for _, gesture in ipairs({ "alt_primary", "alt_secondary" }) do
    local section = assert(t.target_at(p, SITE_X, SITE_Y, "inlet_compressor"))
    local offered, why = pcall(t.use_item, p, section, gesture)
    assert(
        not offered and string.find(tostring(why), "does not offer that gesture", 1, true) ~= nil,
        "an open section offers no " .. gesture .. ": " .. tostring(why)
    )
end
t.run_ticks(2)
assert(site().sprite == "inlet_compressor_open_s", "Alt+click leaves an open section put")
assert(#t.ledger_rows("Rotated") == 0, "and records no turn")

-- The wrench turns it clockwise (tg `turn(dir, -90)`, _machinery.dm:1074).
swap()
take(4, 1, "wrench")
use_on_site("inlet_compressor", 0.2)
assert(
    site().sprite == "inlet_compressor_open_w",
    "the wrench turns an open section: " .. tostring(site().sprite)
)
assert(table.find(heard(), "You turn the section a quarter round.") ~= nil, "and says so")
assert(#t.ledger_rows("Rotated") == 1, "one turn on the record")
-- Put the wrench down and bring the screwdriver hand back up.
t.drop(p)
t.run_ticks(2)
swap()

-- The crowbar takes an open section apart into its frame and everything
-- that went into it.
local metal_before = t.count_items("metal")
local coil_before = t.count_items("cable_coil")
swap()
take(2, 1, "crowbar")
use_on_site("inlet_compressor", 0.2)
assert(site().id == "machine_frame", "a frame is left standing")
assert(t.count_items("compressor_part") == 1, "the part comes back out of its socket")
assert(t.count_items("machine_board.inlet_compressor") == 1, "and the board")
assert(t.count_items("metal") == metal_before + 1, "and one pile of the board's five sheets")
assert(t.count_items("cable_coil") == coil_before + 1, "and one pile of its ten lengths of cable")
