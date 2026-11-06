-- A wrench turns a gas turbine section only with its panel open: tg's
-- `default_change_direction_wrench` refuses a shut panel and otherwise sets
-- `turn(dir, -90)`, a quarter clockwise (_machinery.dm:1069-1077), so a
-- compressor facing south faces west after one turn.

local TURNED = "You turn the section a quarter round."

t.world([==[(
    name: "turbine wrench turn",
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
                "#...#",
                "#####",
            ],
            structures: [
                (2, 2, "player_spawn"),
                (3, 2, "inlet_compressor", "closed", { "dir": "south" }),
            ],
            items: [
                (1, 1, "wrench"),
                (1, 2, "screwdriver"),
            ],
        ),
    ],
)]==])

local p = t.join()
t.tick()

local function take(x: number, y: number, id: string)
    assert(t.hands(p).held == nil, "a free hand for " .. id)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function swap()
    t.swap_hands(p)
    t.run_ticks(1)
end

local function click_section(): { string }
    local _ = t.messages(p)
    t.click(p, 3, 2, assert(t.target_at(p, 3, 2, "inlet_compressor")))
    t.run_ticks(2)
    return t.messages(p)
end

local function section(): SpecStructureAt
    return assert(t.structure_at(3, 2), "the compressor stands")
end

take(1, 1, "wrench")
swap()
take(1, 2, "screwdriver")
swap()

-- Panel shut: the wrench does nothing.
local heard = click_section()
assert(table.find(heard, TURNED) == nil, "a shut section does not turn")
assert(section().sprite == "inlet_compressor_closed_s", "it still faces south")
assert(#t.ledger_rows("Rotated") == 0, "no turn is recorded")

-- Open the panel, then the wrench turns it a quarter clockwise.
swap()
click_section()
assert(section().state == "open", "the screwdriver opens the panel")
swap()
heard = click_section()
assert(table.find(heard, TURNED) ~= nil, "the wrench says it turned the section")
assert(section().sprite == "inlet_compressor_open_w", "south turns clockwise to west")
assert(#t.ledger_rows("Rotated") == 1, "the turn is recorded once")
