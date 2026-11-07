-- A rotor taken apart and built again on the same tile is a different
-- entity, but the physical line is the line: a finished frame faces
-- south (tg sets no dir,
-- machine_frame.dm:458), so the line here runs south and the built
-- rotor stands up onto it whole, linking silently (turbine.dm:39-42),
-- and a bare-hand check at the new rotor says so.

local LINKED = "lunatic/tfs:turbine_linked"
local LINE_WHOLE = "The compressor, rotor and outlet lock into one line."

t.world([==[(
    name: "turbine rebuild",
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
                "#.....#",
                "#######",
            ],
            structures: [
                (2, 2, "player_spawn"),
                (3, 1, "inlet_compressor", "closed", { "dir": "south" }),
                (3, 2, "core_rotor", "closed", { "dir": "south" }),
                (3, 3, "turbine_outlet", "closed", { "dir": "south" }),
            ],
            items: [
                (1, 2, "screwdriver"),
                (2, 1, "crowbar"),
                (5, 4, "cable_coil", { "units": 10 }),
                (5, 3, "machine_board.core_rotor"),
                (5, 2, "rotor_part"),
                (4, 4, "metal", { "units": 5 }),
            ],
        ),
    ],
)]==])

local p = t.join()
t.tick()

local heard: { string } = {}

local function said(line: string): boolean
    return table.find(heard, line) ~= nil
end

-- Each supply lies alone on its own tile, so none hides another.
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

local function put_down()
    t.drop(p)
    t.run_ticks(2)
    assert(t.hands(p).held == nil, "the hand is empty")
end

local function click(x: number, y: number, id: string, seconds: number)
    local _ = t.messages(p)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_seconds(seconds)
    heard = t.messages(p)
end

type Step = "north" | "south" | "east" | "west"

-- One step at a time, plus the move cooldown, round the line's south end.
local function walk(steps: { Step }, to_x: number, to_y: number)
    for _, dir in ipairs(steps) do
        t.move(p, dir)
        t.run_ticks(5)
    end
    local x, y = t.pos(p)
    assert(x == to_x and y == to_y, "the walk ends at " .. to_x .. "," .. to_y)
end

local function rotor(): SpecStructureAt
    return assert(t.structure_at(3, 2), "something stands on the rotor's tile")
end

-- The mapped line stands linked, and a bare-hand check says so.
take(1, 2, "screwdriver")
swap()
assert(rotor().vars[LINKED] == true, "the mapped line is linked")
click(3, 2, "core_rotor", 0.2)
assert(said(LINE_WHOLE), "the check finds the first rotor's line whole")

-- Open the rotor and pry it apart; its frame stays on the tile.
swap()
click(3, 2, "core_rotor", 0.2)
assert(rotor().state == "open", "the rotor's panel opens")
swap()
take(2, 1, "crowbar")
click(3, 2, "core_rotor", 0.2)
assert(rotor().id == "machine_frame", "the rotor comes apart into its frame")

-- Round to the east side and build it again from fresh supplies.
walk({ "south" }, 2, 3)
put_down()
walk({ "south", "east", "east", "north" }, 4, 3)
take(5, 4, "cable_coil")
click(3, 2, "machine_frame", 2.5)
assert(rotor().state == "wired", "five lengths wire the frame")
swap()
put_down()
take(5, 3, "machine_board.core_rotor")
click(3, 2, "machine_frame", 0.2)
assert(rotor().state == "boarded", "the rotor's board goes in")
take(5, 2, "rotor_part")
click(3, 2, "machine_frame", 0.2)
assert(t.hands(p).held == nil, "the rotor part goes in")
swap()
for _ = 1, 5 do
    click(3, 2, "machine_frame", 0.2)
end
assert(t.hands(p).held == nil, "the board takes the other five lengths")
take(4, 4, "metal")
for _ = 1, 5 do
    click(3, 2, "machine_frame", 0.2)
end
assert(t.hands(p).held == nil, "and five sheets")

-- A step north, the screwdriver back up from where it was put down, finish.
walk({ "north" }, 4, 2)
take(4, 3, "screwdriver")
click(3, 2, "machine_frame", 4.5)
assert(rotor().id == "core_rotor", "the frame becomes a rotor again")
assert(rotor().vars[LINKED] == true, "a built rotor standing up onto a whole line links it")

-- And the new rotor answers a check as the old one did.
swap()
click(3, 2, "core_rotor", 0.2)
assert(said(LINE_WHOLE), "the check finds the rebuilt rotor's line whole")
