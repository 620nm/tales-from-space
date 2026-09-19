-- A laptop only claims clicks on what it could program: a networked door
-- keeps its ordinary click, whatever state the held laptop is in.
local LID = "The laptop's lid is closed. Open it first."
local OFF = "The laptop is off. Turn it on first."

t.world(
    [==[(
    name: "laptop passthrough",
    legend: {
        '.': (composition: (components: [(component: "station_base")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    rows: ["#######", "#.....#", "#GA.o##", "#######"],
    structures: [
        (4, 1, "player_spawn"),
        (4, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
        (5, 1, "airlock"),
        (2, 2, "apc"),
    ],
    networks: [
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
    links: [(4, 1, 5, 1)],
    items: [(4, 1, "laptop")],
)]==],
    0
)
local p = t.join()
t.run_ticks(20)

local function heard_any(lines: { string }, ...: string)
    for _, line in ipairs(lines) do
        for _, needle in ipairs({ ... }) do
            if line:find(needle, 1, true) then
                return true
            end
        end
    end
    return false
end

t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "laptop")))
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the closed laptop is in hand")
local door = assert(t.door_at(5, 1))
assert(door.powered and not door.open and not door.bolted, "a powered, shut, public door")

local _ = t.messages(p)
t.click(p, 5, 1, t.target_at(p, 5, 1))
t.run_ticks(20)
local lines = t.messages(p)
assert(assert(t.door_at(5, 1)).open, "a click with a closed laptop still opens the door")
assert(
    not heard_any(lines, LID, OFF),
    "and the laptop says nothing: " .. table.concat(lines, " | ")
)
assert(t.ui(p, "programming") == nil, "nothing connects to a door")
