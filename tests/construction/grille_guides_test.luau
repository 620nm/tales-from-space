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
    structures: [
        (2, 2, "player_spawn"),
        (3, 2, "grille", "reinforced"),
        (1, 2, "grille", "bolted"),
    ],
    items: [
        (2, 2, "welder"), (2, 2, "screwdriver"), (2, 2, "crowbar"),
        (2, 2, "wirecutters"), (2, 2, "wrench"), (2, 2, "rglass"),
        (2, 1, "glass"),
    ],
)]==],
    7
)

local p = t.join()
t.tick()
local target = assert(t.target_at(p, 3, 2, "grille"))

-- Picking something up off a named tile. A thing is targetable only
-- where a pixel of it is the topmost thing drawn, exactly as a pointer
-- finds it, and items that declare no scatter all land on the same
-- offset -- so a tile's items are one stacked pile and the bottom of a
-- deep one is unclickable. Six is what the pile under the player holds;
-- the glass sheets wait on their own tile rather than make it seven.
local function take_at(x: number, y: number, id: string)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.run_ticks(2)
    end
    t.click(p, x, y, assert(t.target_at(p, x, y, id), "no " .. id .. " to point at in " .. x .. "," .. y))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "picked up " .. id)
end

local function take(id: string)
    take_at(2, 2, id)
end

-- What a thing in the bay is DRAWN as, bottom-first and exactly as the
-- wire carried it (tests/atmos/pipenet/meter_test.luau:151-155 reads a
-- dial the same way).
local function looks_like(what: SpecObservedTarget, want: { string }, whose: string)
    local drawn = t.layers(p, what)
    assert(#drawn == #want, whose .. " is drawn in " .. #drawn .. " layers, wanted " .. #want)
    for i, sprite in ipairs(want) do
        assert(drawn[i] == sprite, whose .. "'s layer " .. i .. " is " .. tostring(drawn[i]))
    end
end

-- Every rung of the reinforced ladder is drawn the same, and the
-- content file says so in words (content/structures/access/grille.luau:
-- 83-90): all five states resolve to { "grille", "rwindow" }. You
-- cannot tell from across the room that somebody is half a minute into
-- taking your window out. Bare mesh wears nothing at all, and plain
-- glass is its own pane -- the mesh shows THROUGH either one, which is
-- why the base sprite is underneath rather than replaced.
local SECURE = { "grille", "rwindow" }
local LOOKS: { [string]: { string } } = {
    bolted = { "grille" },
    glazed = { "grille", "window" },
    reinforced = SECURE,
    heated = SECURE,
    unscrewed = SECURE,
    popped = SECURE,
    cut = SECURE,
}

-- What the ladder CHARGES, keyed by the rung and filled in as the walk
-- actually times each one.
local charged: { [string]: number } = {}

looks_like(target, LOOKS.reinforced, "the secure pane")

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
looks_like(target, LOOKS.heated, "a pane somebody has started on")

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

-- One rung of the ladder, walked in the world: not finished a breath
-- early, finished a breath later, and wearing the picture its state is
-- supposed to wear the moment it lands. Each rung's cost is banked, so
-- the asymmetry at the bottom of this file is added up from durations
-- this walk proved rather than read off the content file.
local function step(tool: string, seconds: number, state: string)
    take(tool)
    local was = assert(assert(t.structure_at(3, 2)).state, "a rung knows which one it is")
    t.click(p, 3, 2, target)
    t.run_seconds(seconds - 0.2)
    assert(
        assert(t.structure_at(3, 2)).state == was,
        tool .. " is still working a breath short of " .. seconds .. " seconds"
    )
    t.run_seconds(0.7)
    assert(assert(t.structure_at(3, 2)).state == state, tool .. " reaches " .. state)
    looks_like(target, assert(LOOKS[state], "a state this file knows the picture of"), state)
    charged[was .. ">" .. state] = seconds
end

local function choices(forward: string, reverse: string)
    t.drop(p)
    t.run_ticks(2)
    assert(hint(p, target, forward) ~= nil, "next deconstruction tool: " .. forward)
    assert(hint(p, target, reverse) ~= nil, "next repair tool: " .. reverse)
end

-- The repaired pane can start the same ladder again, and the next rung
-- remains discoverable after a screwdriver advances it.
step("welder", 15, "heated")
step("screwdriver", 5, "unscrewed")
t.drop(p)
t.run_ticks(2)
assert(hint(p, target, "pry_reinforced_glass") ~= nil, "the crowbar continues the ladder")
assert(
    hint(p, target, "replace_reinforced_glass_screws") ~= nil,
    "the screwdriver repairs the screw rung"
)

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

-- The asymmetry, added up out of rungs this walk timed itself: fifteen
-- seconds of welding, five of unscrewing, four of prying, two of
-- cutting and four of unbolting to get a reinforced pane out (tg's
-- window.dm:577, 591, 604, 617 and 630 -- the `*_act_secondary` chain),
-- against two seconds to fit one (grille.dm:267). Thirty out, two in.
-- A window is cheap to put up and expensive to take down, which is
-- most of what makes one worth putting up.
local out = charged["reinforced>heated"]
    + charged["heated>unscrewed"]
    + charged["unscrewed>popped"]
    + charged["popped>cut"]
    + charged["cut>bolted"]
local fit = charged["bolted>reinforced"]
assert(out == 30, "five tools and thirty seconds get a reinforced pane out, got " .. out)
assert(fit == 2, "two seconds fit one, got " .. fit)
assert(out >= 10 * fit, "taking one out costs ten times fitting it: " .. out .. " against " .. fit)

-- The bay's other grille is bolted-down mesh with nothing in it, and
-- bare mesh is ONE picture: the same probe that has read two layers off
-- every rung above reads one off this. Plain glass then hangs a
-- different pane on the same mesh -- two seconds, and the grille is
-- still underneath it.
local bare = assert(t.target_at(p, 1, 2, "grille"))
looks_like(bare, LOOKS.bolted, "an empty grille")
take_at(2, 1, "glass")
t.click(p, 1, 2, bare)
t.run_seconds(1.8)
assert(assert(t.structure_at(1, 2)).state == "bolted", "two seconds of fitting is two seconds")
t.run_seconds(0.7)
assert(assert(t.structure_at(1, 2)).state == "glazed", "the pane settles into the frame")
looks_like(bare, LOOKS.glazed, "a glazed grille")
