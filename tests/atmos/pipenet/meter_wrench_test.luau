-- Wrenching a meter down: a lone run takes whatever layer it is, a
-- crossing needs the dial set first, and the in-hand key turns that
-- dial. The apply-to-pipe programming this builds on is
-- `meter_layers_test.luau`; the refusal on bare deck is
-- `meter_test.luau`.

local function said(p: number, line: string): boolean
    for _, message in ipairs(t.messages(p)) do
        if message == line then
            return true
        end
    end
    return false
end

local function lying_at(x: number, y: number, id: string): boolean
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

local function entity_action(p: number, entity: SpecObservedTarget, id: string): SpecActionDescriptor?
    for _, action in ipairs(t.action_hints(p, { Entity = entity })) do
        if action.id == id then
            return action
        end
    end
    return nil
end

-- A lone layer-2 run, a lone layer-4 run, and a layer-1-over-5
-- crossing, each with a default-dialled fitting waiting on it.
t.world(
    [==[(
    name: "meter wrench",
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "######",
    ],
    structures: [(1, 2, "player_spawn")],
    items: [(1, 2, "wrench"), (3, 2, "wrench"), (2, 1, "pipe_meter"), (4, 1, "pipe_meter")],
    networks: [
        (x: 2, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 3, y: 1, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l1", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l5", kind: "standard", facing: 15),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(p, 1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")

-- ---- the hover card promises the fastening, not a pickup ----
local lone = assert(t.target_at(p, 2, 1, "pipe_meter"))
local fasten = entity_action(p, lone, "construction.meter")
assert(fasten ~= nil, "a wrench over a fitting offers the fastening")
assert(fasten.gesture == "primary", "as the click it is")
assert(
    entity_action(p, lone, "engine.action.take") == nil,
    "and never a pickup the click would not take"
)

-- ---- a lone run takes whatever layer it is ----
t.click(p, 2, 1, lone)
t.run_seconds(2.5)
assert(assert(t.structure_at(2, 1)).id == "meter", "the default-dialled meter fastens to layer 2")
t.click_network(p, 2, 1, assert(t.network_instance(2, 1, "pipe", "l2")))
t.run_seconds(2.5)
assert(t.structure_at(2, 1) == nil, "its run coming up drops it")
assert(lying_at(2, 1, "pipe_meter"), "the meter is loose on the deck")

-- ---- one run wins over the dial ----
t.drop(p)
t.run_ticks(2)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "pipe_meter")))
t.run_ticks(2)
assert(t.hands(p).held == "pipe_meter", "the loose meter is back in hand")
local _ = t.messages(p)
t.use_self(p)
t.run_ticks(2)
assert(said(p, "Meter layer set to 4. Drop it before fastening."), "the in-hand key turns the dial")
t.use_self(p)
t.run_ticks(2)
assert(said(p, "Meter layer set to 5. Drop it before fastening."), "and turns it again")
local self_row: SpecActionDescriptor? = nil
for _, view in ipairs(t.actions(p)) do
    for _, action in ipairs(view.actions) do
        if action.gesture == "self" and action.label.key == "lunatic/tfs:ui.affordance.set_layer" then
            self_row = action
        end
    end
end
assert(self_row ~= nil, "the held meter lists its layer on its own card")
assert(self_row.id == "cycle_layer", "as its own row, not the pipe's")
walk(p, "east")
walk(p, "east")
walk(p, "north")
t.drop(p)
t.run_ticks(2)
-- Back off the tile: a fitting underfoot cannot be wrenched down.
walk(p, "south")
t.click(p, 3, 2, assert(t.target_at(p, 3, 2, "wrench")))
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "pipe_meter")))
t.run_seconds(2.5)
assert(assert(t.structure_at(3, 1)).id == "meter", "a dialled-5 meter still fastens to lone layer 4")
t.click_network(p, 3, 1, assert(t.network_instance(3, 1, "pipe", "l4")))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "it bound the run beneath it, not the dial")

-- ---- a crossing still needs the dial first ----
local _ = t.messages(p)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "pipe_meter")))
t.run_ticks(2)
assert(said(p, "You can't build that there."), "an unset dial refuses a crossing")
assert(t.structure_at(4, 1) == nil, "nothing was bolted to two runs")
assert(lying_at(4, 1, "pipe_meter"), "and the fitting survived the attempt")
