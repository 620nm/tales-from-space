-- Linking a gas turbine's line: a bare hand on the core rotor checks the
-- compressor-rotor-outlet line in tg's order and names the first break
-- (turbine.dm:497-559). A line placed whole links at init
-- (turbine.dm:39-42); an opened panel breaks it. Which console drives it
-- is the device network's business, covered by console_test.luau and
-- gas_turbine_network_test.luau.

local LINKED = "lunatic/tfs:turbine_linked"

t.world([==[(
    name: "turbine hall",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "######",
                "#....#",
                "#....#",
                "#....#",
                "#....#",
                "#....#",
                "######",
            ],
            structures: [
                (3, 2, "player_spawn"),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "open", { "dir": "east" }),
                (2, 5, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 5, "core_rotor", "closed", { "dir": "east" }),
                (4, 5, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            items: [(3, 1, "screwdriver")],
        ),
    ],
)]==])

local p = t.join()
t.tick()

-- What the player heard, drained once per click.
local heard: { string } = {}

local function said(line: string): boolean
    return table.find(heard, line) ~= nil
end

t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "screwdriver")))
t.run_ticks(2)
assert(t.hands(p).held == "screwdriver", "the screwdriver in hand")
t.swap_hands(p)
t.run_ticks(1)

local function bare()
    if t.hands(p).held ~= nil then
        t.swap_hands(p)
        t.run_ticks(1)
    end
    assert(t.hands(p).held == nil, "a bare hand for the check")
end

local function tool()
    if t.hands(p).held ~= "screwdriver" then
        t.swap_hands(p)
        t.run_ticks(1)
    end
    assert(t.hands(p).held == "screwdriver", "the screwdriver in hand")
end

local function click(x: number, y: number, id: string, seconds: number)
    local _ = t.messages(p)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_seconds(seconds)
    heard = t.messages(p)
end

local function linked_at(y: number): boolean
    return assert(t.structure_at(3, y)).vars[LINKED] == true
end

local function linked(): boolean
    return linked_at(3)
end

-- The whole mapped line links as it stands up; the open one does not.
assert(linked_at(5), "a line mapped whole is linked at init")
assert(not linked(), "a line mapped with a panel open is not")

-- The outlet's panel is open: the check names it and links nothing.
bare()
click(3, 3, "core_rotor", 0.2)
assert(said("The outlet's panel is open. Shut it first."), "the first break is named")
assert(not linked(), "and the line stays unlinked")
assert(not said("The compressor, rotor and outlet lock into one line."), "nothing links")

-- Shut it, and the line is whole.
tool()
click(4, 3, "turbine_outlet", 0.2)
assert(assert(t.structure_at(4, 3)).state == "closed", "the outlet's panel shuts")
bare()
click(3, 3, "core_rotor", 0.2)
assert(said("The compressor, rotor and outlet lock into one line."), "a whole line links")
assert(linked(), "the rotor remembers it")

-- Opening the compressor breaks the line; shutting it again does not relink
-- it, the rotor does (tg `activate_parts`, turbine.dm:216-221 against :497).
tool()
click(2, 3, "inlet_compressor", 0.2)
assert(not linked(), "an open panel unlinks the rotor")
click(2, 3, "inlet_compressor", 0.2)
assert(not linked(), "a shut compressor waits for the rotor")
click(3, 3, "core_rotor", 0.2)
click(3, 3, "core_rotor", 0.2)
assert(linked(), "shutting the rotor's own panel links the whole line again")
