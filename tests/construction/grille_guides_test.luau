-- Reinforced glass tells a player which tool comes next. The first weld
-- also proves the same context row is unavailable until the welder is lit:
-- construction checks the live implement, while the hint remains visible.
local function hint(p: number, target: SpecObservedTarget, id: string): SpecActionDescriptor?
    for _, row in ipairs(t.action_hints(p, target)) do
        if row.id == id then
            return row
        end
    end
    return nil
end

t.world(
    [==[(
    name: "glass bay",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn"), (3, 2, "grille", "reinforced")],
    items: [
        (2, 2, "welder"), (2, 2, "screwdriver"), (2, 2, "crowbar"),
        (2, 2, "wirecutters"), (2, 2, "wrench"), (2, 2, "rglass"),
    ],
)]==],
    7
)

local p = t.join()
t.tick()
local target = assert(t.target_at(p, 3, 2, "grille"))

local function take(id: string)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.run_ticks(2)
    end
    t.click(p, 2, 2, assert(t.target_at(p, 2, 2, id)))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "picked up " .. id)
end

-- The next step is advertised before the tool is held.
local heat = assert(hint(p, target, "heat_reinforced_glass"))
assert(not heat.available, "the suggested welder is not in hand")

-- Holding an unlit welder still shows the same action, but cannot start it.
take("welder")
heat = assert(hint(p, target, "heat_reinforced_glass"))
assert(not heat.available, "an unlit welder cannot heat the security screws")
assert(heat.requirements[1].label.key == "engine.action.lit_tool", "the requirement specifies a lit tool")
assert(heat.requirements[1].count == 1, "the tool quantity is separate from its label")
t.use_self(p)
t.tick()
heat = assert(hint(p, target, "heat_reinforced_glass"))
assert(heat.available, "a lit welder can begin reinforced-glass deconstruction")
t.click(p, 3, 2, target)
t.run_seconds(15.5)
assert(assert(t.structure_at(3, 2)).state == "heated", "the first rung is heated")

-- A player can either continue or repair from the first intermediate rung.
t.drop(p)
t.run_ticks(2)
assert(hint(p, target, "remove_reinforced_glass_screws") ~= nil, "screwdriver continues the ladder")
assert(hint(p, target, "repair_reinforced_glass") ~= nil, "welder repairs the ladder")

take("welder")
t.click(p, 3, 2, target)
t.run_ticks(5)
t.use_self(p)
t.tick()
t.run_seconds(15.0)
assert(
    assert(t.structure_at(3, 2)).state == "heated",
    "extinguishing the welder interrupts repair"
)

take("welder")
t.use_self(p)
t.tick()
t.click(p, 3, 2, target)
t.run_seconds(15.5)
assert(assert(t.structure_at(3, 2)).state == "reinforced", "the repair returns the secure pane")

-- The repaired pane can start the same ladder again, and the next rung
-- remains discoverable after a screwdriver advances it.
t.click(p, 3, 2, target)
t.run_seconds(15.5)
take("screwdriver")
t.click(p, 3, 2, target)
t.run_seconds(5.5)
assert(assert(t.structure_at(3, 2)).state == "unscrewed", "the screws come out")
t.drop(p)
t.run_ticks(2)
assert(hint(p, target, "pry_reinforced_glass") ~= nil, "the crowbar continues the ladder")
assert(
    hint(p, target, "replace_reinforced_glass_screws") ~= nil,
    "the screwdriver repairs the screw rung"
)

local function step(tool: string, seconds: number, state: string)
    take(tool)
    t.click(p, 3, 2, target)
    t.run_seconds(seconds + 0.5)
    assert(assert(t.structure_at(3, 2)).state == state, tool .. " reaches " .. state)
end

local function choices(forward: string, reverse: string)
    t.drop(p)
    t.run_ticks(2)
    assert(hint(p, target, forward) ~= nil, "next deconstruction tool: " .. forward)
    assert(hint(p, target, reverse) ~= nil, "next repair tool: " .. reverse)
end

step("crowbar", 4, "popped")
choices("cut_reinforced_glass_bars", "reseat_reinforced_glass")
step("wirecutters", 2, "cut")
choices("unbolt_reinforced_glass", "weld_reinforced_glass_bars")

-- Every repair rung returns to a state whose next choices remain visible.
step("welder", 2, "popped")
step("crowbar", 4, "unscrewed")
step("screwdriver", 5, "heated")
choices("remove_reinforced_glass_screws", "repair_reinforced_glass")

step("screwdriver", 5, "unscrewed")
step("crowbar", 4, "popped")
step("wirecutters", 2, "cut")
step("wrench", 4, "bolted")
assert(t.item_at(3, 2, "rglass") ~= nil, "finishing recovers reinforced glass")
assert(hint(p, target, "rebuild_reinforced_glass") ~= nil, "the empty frame explains how to rebuild")
step("rglass", 2, "reinforced")
