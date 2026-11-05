-- The core rotor's line check names the FIRST break in tg's order
-- (`activate_parts`, turbine.dm:497-559). Five broken east-facing lines
-- stand along the north wall, each built so that a check run out of order
-- names a different break: a reversed line has neither section where it
-- should be (:512-520), a perpendicular compressor also faces away from its
-- outlet (:526 before :557), and an outlet facing the other way is aligned
-- but not facing away (:543, :557).

local LINKED = "lunatic/tfs:turbine_linked"

t.world([==[(
    name: "turbine refusals",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####################",
                "#...................#",
                "#...................#",
                "#####################",
            ],
            structures: [
                (2, 2, "player_spawn"),
                (1, 1, "turbine_outlet", "closed", { "dir": "east" }),
                (2, 1, "core_rotor", "closed", { "dir": "east" }),
                (3, 1, "inlet_compressor", "closed", { "dir": "east" }),
                (6, 1, "core_rotor", "closed", { "dir": "east" }),
                (7, 1, "turbine_outlet", "closed", { "dir": "east" }),
                (9, 1, "inlet_compressor", "closed", { "dir": "east" }),
                (10, 1, "core_rotor", "closed", { "dir": "east" }),
                (11, 1, "turbine_outlet", "closed", { "dir": "west" }),
                (13, 1, "inlet_compressor", "closed", { "dir": "north" }),
                (14, 1, "core_rotor", "closed", { "dir": "east" }),
                (15, 1, "turbine_outlet", "closed", { "dir": "east" }),
                (17, 1, "inlet_compressor", "closed", { "dir": "east" }),
                (18, 1, "core_rotor", "closed", { "dir": "east" }),
            ],
            items: [(1, 2, "multitool")],
        ),
    ],
)]==])

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(p, 1, 2, "multitool"))
t.run_ticks(2)
assert(t.hands(p).held == "multitool", "the multitool in hand")

-- Every walk is along the south row, a step under the rotor it tests.
local function walk_to(x: number)
    for _ = 1, 24 do
        local at = t.pos(p)
        if at == x then
            return
        end
        local direction: "east" | "west" = if at < x then "east" else "west"
        t.move(p, direction)
        t.run_ticks(4)
    end
    error("could not walk to x=" .. x .. ", stuck at " .. t.pos(p))
end

local cases = {
    { x = 2, says = "The rotor is facing the wrong way!" },
    { x = 6, says = "The compressor is missing!" },
    { x = 10, says = "The turbine and the compressor are not facing away from each other!" },
    { x = 14, says = "The compressor is not aligned with the rotor!" },
    { x = 18, says = "The turbine is missing!" },
}
for _, case in ipairs(cases) do
    walk_to(case.x)
    local _ = t.messages(p)
    t.click(p, case.x, 1, t.target_at(p, case.x, 1, "core_rotor"))
    t.run_seconds(0.2)
    local heard = t.messages(p)
    assert(
        table.find(heard, case.says) ~= nil,
        "the rotor at x=" .. case.x .. " names its break: " .. table.concat(heard, " | ")
    )
    assert(table.find(heard, "All parts linked.") == nil, "and links nothing")
    assert(assert(t.structure_at(case.x, 1)).vars[LINKED] == nil, "nor remembers a link")
end
