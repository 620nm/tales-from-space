-- A laptop only claims clicks on what it could program: a networked door
-- keeps its ordinary click, whatever state the held laptop is in.
local LID = "The laptop's lid is closed. Open it first."
local OFF = "The laptop is off. Turn it on first."

t.world([==[(
    name: "laptop passthrough",
    legend: {
        '.': (turf: Plating), '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'A': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    rows: ["#######", "#.....#", "#GA.o##", "#######"],
    structures: [
        (4, 1, "player_spawn"),
        (4, 1, "access_point", { "network_1": "network_card" }),
        (5, 1, "airlock"),
    ],
    mounts: [(4, 1, North)],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1),
        (3, 1, 1), (4, 1, 1), (5, 1, 1)],
    links: [(4, 1, 5, 1)],
    items: [(4, 1, "laptop")],
)]==], 0)
local p = t.join()
t.run_ticks(20)

local function heard_any(lines, ...)
    for _, line in ipairs(lines) do
        for _, needle in ipairs({ ... }) do
            if line:find(needle, 1, true) then return true end
        end
    end
    return false
end

t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "laptop")))
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the closed laptop is in hand")
local door = t.door_at(5, 1)
assert(door.powered and not door.open and not door.bolted, "a powered, shut, public door")

local _ = t.messages(p)
t.click(p, 5, 1, t.target_at(p, 5, 1))
t.run_ticks(20)
local lines = t.messages(p)
assert(t.door_at(5, 1).open, "a click with a closed laptop still opens the door")
assert(not heard_any(lines, LID, OFF), "and the laptop says nothing: " .. table.concat(lines, " | "))
assert(t.ui(p, "programming") == nil, "nothing connects to a door")
