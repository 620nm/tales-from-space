-- Linking a gas turbine: a multitool on the core rotor checks the
-- compressor-rotor-outlet line in tg's order and names the first break
-- (turbine.dm:497-559); a whole line is logged in the multitool's buffer
-- (:456-472), which the control console reads to link to the rotor
-- (turbine_computer.dm:24-37). A line placed whole links at init
-- (turbine.dm:39-42); an opened panel breaks it.

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
            machines: [(4, 1, "turbine_computer")],
            items: [(2, 1, "multitool"), (3, 1, "screwdriver")],
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

-- Each tool lies on its own tile beside the player, so neither hides the
-- other; one goes in each hand and a swap brings the other up.
local function pick(x: number, y: number, id: string)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

pick(2, 1, "multitool")
t.swap_hands(p)
pick(3, 1, "screwdriver")

local function take(id: string)
    if t.hands(p).held ~= id then
        t.swap_hands(p)
        t.run_ticks(1)
    end
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
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

-- An empty buffer links the console to nothing.
take("multitool")
click(4, 1, "turbine_computer", 0.5)
assert(
    said("The multitool has no rotor logged that this console can reach."),
    "an empty buffer is refused"
)

-- The outlet's panel is open: the rotor names it and links nothing.
click(3, 3, "core_rotor", 0.2)
assert(said("The outlet's panel is open. Shut it first."), "the first break is named")
assert(not linked(), "and the line stays unlinked")
assert(not said("The compressor, rotor and outlet lock into one line."), "nothing is logged")

-- Shut it, and the line is whole.
take("screwdriver")
click(4, 3, "turbine_outlet", 0.2)
assert(assert(t.structure_at(4, 3)).state == "closed", "the outlet's panel shuts")
take("multitool")
click(3, 3, "core_rotor", 0.2)
assert(said("The compressor, rotor and outlet lock into one line."), "a whole line links")
assert(said("The multitool logs the rotor."), "and is logged")
assert(linked(), "the rotor remembers it")

-- The console reads the buffer after tg's fifth of a second; linking it a
-- second time says it already held a link (turbine_computer.dm:29-30).
local CONSOLE_LINKED = "The console links to the rotor the multitool logged."
local RELINKING = "The console lets go of the rotor it was linked to."
click(4, 1, "turbine_computer", 0.5)
assert(said(CONSOLE_LINKED), "the console links")
assert(not said(RELINKING), "a console with no link has none to change")
click(4, 1, "turbine_computer", 0.5)
assert(said(RELINKING) and said(CONSOLE_LINKED), "the console remembers the rotor it holds")

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
