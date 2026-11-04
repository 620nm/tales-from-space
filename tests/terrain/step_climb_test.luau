-- The ledge veto (content/lib/climbing.luau) judges only a walk up onto a
-- step on one level: a broken climb leaves the body free to climb again, a
-- crate on a step is climbed as a crate, a body on a crate steps across onto
-- the ledge beside it, and a stair landing on a step is not vetoed.
t.world(
    [==[(
    name: "step_climb",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
    legend: {
        'a': (composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'c': (composition: ()),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "aaccaaaa",
                "aaccaaaa",
                "aaccaaaa",
                "aaaaaaaa",
            ],
            structures: [
                (1, 1, "player_spawn"),
                (2, 0, "crate"),
                (1, 2, "crate"),
                (5, 2, "stairs", { "dir": "east" }),
            ],
            solid: [
                (2, 0, StepOf("half", Blend("basalt_ground"))),
                (3, 0, StepOf("half", Blend("basalt_ground"))),
                (2, 1, StepOf("half", Blend("basalt_ground"))),
                (3, 1, StepOf("half", Blend("basalt_ground"))),
                (2, 2, StepOf("half", Blend("basalt_ground"))),
                (3, 2, StepOf("half", Blend("basalt_ground"))),
            ],
        ),
        (
            rows: [
                "cccccccc",
                "cccccccc",
                "cccccocc",
                "cccccccc",
            ],
            solid: [(6, 2, StepOf("half", Blend("basalt_ground")))],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local START = "You start climbing."
local ON_LEDGE = "You climb up onto the ledge."
local ON_CRATE = "You climb onto the structure."

local p = t.join()
t.run_ticks(4)

local function step(direction: "north" | "south" | "east" | "west")
    t.move(p, direction)
    t.run_seconds(0.5)
end

local function at(x: number, y: number, why: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, why .. ": at " .. px .. "," .. py)
end

local function heard(): { string }
    return t.messages(p)
end

local function said(): string
    local lines = heard()
    return lines[#lines] or ""
end

local function heard_line(wanted: string): boolean
    for _, line in ipairs(heard()) do
        if line == wanted then
            return true
        end
    end
    return false
end

local function climb_crate(x: number, y: number)
    local px, py = t.pos(p)
    local crate = assert(t.target_at(p, x, y, "crate"), "a crate at " .. x .. "," .. y)
    t.drag(p, px, py, t.body_target(p, p), x, y, crate)
    t.run_seconds(2.5)
end

-- 1. A climb broken by walking away leaves no attempt behind: the next walk
-- up starts a fresh climb, which lands.
heard()
step("east")
at(1, 1, "a ledge stops a walk")
assert(said() == START, "the refused walk starts a climb: " .. said())
step("west")
t.run_seconds(2.5)
at(0, 1, "walking away breaks the climb")
assert(said() ~= ON_LEDGE, "the broken climb never lands")
step("east")
step("east")
at(1, 1, "the ledge stops the walk again")
assert(said() == START, "the body may climb again: " .. said())
t.run_seconds(2.5)
at(2, 1, "the second climb lands")
assert(said() == ON_LEDGE, "and is told so: " .. said())
step("west")
at(1, 1, "down off the ledge")

-- 2. A crate standing on a step is climbed as a crate: its climb's own
-- crossing up onto the step passes the veto.
step("north")
at(1, 0, "beside the crate on the step")
heard()
climb_crate(2, 0)
at(2, 0, "the body climbs onto the crate on the step")
assert(said() == ON_CRATE, "the crate's climb lands: " .. said())
step("west")
at(1, 0, "down off the crate")

-- 3. A body on a crate stands above the ledge beside it and steps across.
step("south")
at(1, 1, "beside the crate on flat ground")
climb_crate(1, 2)
at(1, 2, "the body climbs onto the crate")
heard()
step("east")
at(2, 2, "the body steps from the crate onto the ledge")
assert(not heard_line(START), "stepping off a crate starts no climb")

-- 4. A stair landing on a step one level up is not vetoed, and no climb
-- follows it.
step("east")
step("east")
at(4, 2, "along the ledge and down off it")
t.move(p, "east")
t.run_seconds(1)
at(5, 2, "onto the flight")
heard()
t.move(p, "east")
t.run_seconds(1)
at(6, 2, "the stair lands on the step one level up")
local moves = t.ledger_rows("level_changed")
assert(#moves == 1 and moves[1].via == "link", "one level change via the link, got " .. #moves)
t.run_seconds(2.5)
assert(not heard_line(START), "a stair crossing starts no climb")
at(6, 2, "the body stays on the landing")
