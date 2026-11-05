-- Linking a gas turbine: a multitool on the core rotor checks the
-- compressor-rotor-outlet line in tg's order and names the first break
-- (turbine.dm:497-559); a whole line is logged in the multitool's buffer
-- (:456-472), which the control console reads to link to the rotor
-- (turbine_computer.dm:153-166). An opened panel breaks the line.

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
                "######",
            ],
            structures: [
                (3, 2, "player_spawn"),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "open", { "dir": "east" }),
            ],
            machines: [(4, 1, "turbine_computer")],
            items: [(3, 2, "multitool"), (3, 2, "screwdriver")],
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

local function take(id: string)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.run_ticks(2)
    end
    t.click(p, 3, 2, t.target_at(p, 3, 2, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function click(x: number, y: number, id: string, seconds: number)
    local _ = t.messages(p)
    t.click(p, x, y, t.target_at(p, x, y, id))
    t.run_seconds(seconds)
    heard = t.messages(p)
end

local function linked(): boolean
    return assert(t.structure_at(3, 3)).vars[LINKED] == true
end

-- An empty buffer links the console to nothing.
take("multitool")
click(4, 1, "turbine_computer", 0.5)
assert(said("Wrong machine type in the multitool's buffer..."), "an empty buffer is refused")

-- The outlet's panel is open: the rotor names it and links nothing.
click(3, 3, "core_rotor", 0.2)
assert(said("Close the turbine panel!"), "the first break is named")
assert(not linked(), "and the line stays unlinked")
assert(not said("All parts linked."), "nothing is logged")

-- Shut it, and the line is whole.
take("screwdriver")
click(4, 3, "turbine_outlet", 0.2)
assert(assert(t.structure_at(4, 3)).state == "closed", "the outlet's panel shuts")
take("multitool")
click(3, 3, "core_rotor", 0.2)
assert(said("All parts linked."), "a whole line links")
assert(said("You store linkage information in the multitool's buffer."), "and is logged")
assert(linked(), "the rotor remembers it")

-- The console reads the buffer after tg's fifth of a second.
click(4, 1, "turbine_computer", 0.5)
assert(said("You link the console to the rotor in the multitool's buffer."), "the console links")

-- Opening the compressor breaks the line; shutting it again does not relink
-- it, the rotor does (tg `activate_parts`, turbine.dm:216-221 against :497).
take("screwdriver")
click(2, 3, "inlet_compressor", 0.2)
assert(not linked(), "an open panel unlinks the rotor")
click(2, 3, "inlet_compressor", 0.2)
assert(not linked(), "a shut compressor waits for the rotor")
click(3, 3, "core_rotor", 0.2)
click(3, 3, "core_rotor", 0.2)
assert(linked(), "shutting the rotor's own panel links the whole line again")
