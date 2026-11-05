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
                "#####",
                "#...#",
                "#...#",
                "#####",
            ],
            structures: [(2, 2, "player_spawn")],
            items: [
                (2, 2, "metal"),
                (2, 2, "cable_coil"),
                (2, 2, "machine_board.inlet_compressor"),
                (2, 2, "compressor_part"),
                (2, 2, "screwdriver"),
                (2, 2, "crowbar"),
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

-- Everything lies underfoot; the hand holds one thing at a time.
local function take(id: string)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.run_ticks(2)
    end
    t.click(p, 2, 2, t.target_at(p, 2, 2, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function use_on_site(id: string, seconds: number)
    t.click(p, SITE_X, SITE_Y, t.target_at(p, SITE_X, SITE_Y, id))
    t.run_seconds(seconds)
end

local function site(): SpecStructureAt
    return assert(t.structure_at(SITE_X, SITE_Y), "something stands on the site")
end

-- The frame, wired, boarded.
take("metal")
ui_controls.build(p, "metal", "machine_frame", SITE_X, SITE_Y)
t.run_seconds(8.5)
assert(site().id == "machine_frame", "five sheets box up into a frame")
take("cable_coil")
use_on_site("machine_frame", 2.5)
assert(site().state == "wired", "five lengths of cable wire it")
take("machine_board.inlet_compressor")
use_on_site("machine_frame", 0.2)
assert(site().state == "boarded", "the section's board clicks in")

-- The board asks for the section's part before anything else.
take("screwdriver")
local _ = t.messages(p)
use_on_site("machine_frame", 4.5)
local refusal = heard()
assert(
    table.find(refusal, "It still needs 1 x compressor part.") ~= nil,
    "the frame names the part: " .. table.concat(refusal, " | ")
)
take("compressor_part")
use_on_site("machine_frame", 0.2)
assert(t.hands(p).held == nil, "the part goes in whole")

-- Then five of each stack, one unit a click.
for _, stack in ipairs({ "cable_coil", "metal" }) do
    take(stack)
    for _ = 1, 5 do
        use_on_site("machine_frame", 0.2)
    end
end
take("screwdriver")
use_on_site("machine_frame", 4.5)
assert(site().id == "inlet_compressor", "the frame becomes the section its board names")
assert(site().state == "closed", "with its panel shut")
assert(site().sprite == "inlet_compressor_closed_s", "facing south, tg's default")

-- Shut, it does not turn.
t.rotate(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "inlet_compressor")), true)
t.run_ticks(2)
assert(site().sprite == "inlet_compressor_closed_s", "a shut section stays put")

-- Open, it turns clockwise (tg `turn(dir, -90)`, _machinery.dm:1074).
local _ = t.messages(p)
use_on_site("inlet_compressor", 0.2)
assert(site().state == "open", "the screwdriver opens the panel")
assert(table.find(heard(), "You open the maintenance panel.") ~= nil, "and says so")
t.rotate(p, SITE_X, SITE_Y, assert(t.target_at(p, SITE_X, SITE_Y, "inlet_compressor")), true)
t.run_ticks(2)
assert(site().sprite == "inlet_compressor_open_w", "an open section turns: " .. tostring(site().sprite))

-- The crowbar takes an open section apart into its frame and everything
-- that went into it.
local metal_before = t.count_items("metal")
local coil_before = t.count_items("cable_coil")
take("crowbar")
use_on_site("inlet_compressor", 0.2)
assert(site().id == "machine_frame", "a frame is left standing")
assert(t.count_items("compressor_part") == 1, "the part comes back out of its socket")
assert(t.count_items("machine_board.inlet_compressor") == 1, "and the board")
assert(t.count_items("metal") == metal_before + 1, "and one pile of the board's five sheets")
assert(t.count_items("cable_coil") == coil_before + 1, "and one pile of its ten lengths of cable")
