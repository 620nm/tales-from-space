local composition = require("@helpers/composition")

-- Removing a station base reveals its retained substrate. A cover must
-- come up first, and a supported power run prevents unsafe removal.
local BENCH = [==[(
    name: "Retained substrate",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'b': (composition: (%s components: [(component: "station_base")%s])),
    },
    rows: ["#####", "#.b.#", "#...#", "#####"],
    environment: (gravity_m_s2: Exact(9.80665)),
    structures: [(2, 2, "player_spawn")],
    items: [(1, 2, "welder"), (3, 2, "crowbar"), (1, 1, "wirecutters")],
    networks: [%s],
)]==]

local function bench(substrate: string?, cover: string?, powered: boolean): number
    local substrate_ron = if substrate then 'substrate: Some("' .. substrate .. '"),' else ""
    local cover_ron = if cover then ', (component: "' .. cover .. '")' else ""
    local power_ron = if powered then
        '(x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15)' else ""
    t.world(string.format(BENCH, substrate_ron, cover_ron, power_ron), 7)
    local player = t.join()
    t.tick()
    return player
end

local function take(player: number, x: number, y: number, item: string)
    t.click(player, x, y, t.target_at(player, x, y, item))
    t.run_ticks(2)
    assert(t.hands(player).held == item)
end

for _, substrate in ipairs({ "space", "ground" }) do
    local player = bench(substrate, nil, false)
    take(player, 1, 2, "welder")
    assert(composition.matches(2, 1, { "station_base" }), "the base starts over the authored substrate")
    assert(assert(t.composition(2, 1)).substrate == substrate, "the explicit substrate stays authored")
    local before = t.count_items("metal")
    t.click_component(player, 2, 1, assert(t.component_instance(2, 1, "station_base")))
    t.run_seconds(2)
    assert(composition.matches(2, 1, { "station_base" }), "cutting a base takes the complete tool duration")
    t.run_seconds(2.5)
    assert(composition.bare(2, 1, substrate), "the retained substrate is exposed")
    assert(assert(t.composition(2, 1)).substrate == substrate, "removal preserves explicit substrate provenance")
    assert(t.is_breached(2, 1) == (substrate == "space"), "ground does not become a vacuum breach")
    assert(t.count_items("metal") == before, "base removal has no invented refund")
    assert(t.ledger_has("StructureStep", "plating", "remove_component"), "the base removal is attributed")
end

-- An omitted substrate is still retained when the inherited station deck opens.
local inherited = bench(nil, nil, false)
assert(assert(t.composition(2, 1)).substrate == nil, "the default substrate is inherited")
take(inherited, 1, 2, "welder")
t.click_component(inherited, 2, 1, assert(t.component_instance(2, 1, "station_base")))
t.run_seconds(4.5)
assert(composition.bare(2, 1, "space"), "the map inherits its environment's space substrate")
assert(assert(t.composition(2, 1)).substrate == nil, "opening the deck does not invent an override")

for _, cover in ipairs({ "floor_tiles", "grid_cover" }) do
    local player = bench("ground", cover, false)
    local base = assert(t.component_instance(2, 1, "station_base"))
    take(player, 1, 2, "welder")
    for _, hint in ipairs(t.action_hints(player, {
        Component = { tile = { x = 2, y = 1 }, instance = base },
    })) do
        assert(hint.id ~= "construction.plating.0" or not hint.available,
            "naming the protected base cannot expose its removal action")
    end
    local selected = pcall(function() t.click_component(player, 2, 1, base) end)
    if cover == "grid_cover" then assert(selected, "the base can be selected through the mesh") end
    t.run_seconds(4.5)
    assert(t.component_instance(2, 1, "station_base") == base, "a base token cannot bypass cover access")
    t.click_component(player, 2, 1, assert(t.component_instance(2, 1, cover)))
    t.run_seconds(4.5)
    assert(t.component_instance(2, 1, "station_base") == base, "the welder cannot bypass an installed cover")
    t.drop(player)
    t.run_ticks(2)
    take(player, 3, 2, "crowbar")
    t.click_component(player, 2, 1, assert(t.component_instance(2, 1, cover)))
    t.run_ticks(2)
    assert(composition.matches(2, 1, { "station_base" }), "prying a cover preserves the station base")
    assert(t.component_instance(2, 1, "station_base") == base, "the retained base keeps its identity")
    t.drop(player)
    t.run_ticks(2)
    take(player, 2, 2, "welder")
    t.click_component(player, 2, 1, assert(t.component_instance(2, 1, "station_base")))
    t.run_seconds(4.5)
    assert(composition.bare(2, 1, "ground"), "cutting the exposed base preserves the ground below it")
end

local player = bench("space", nil, true)
local cable = assert(t.network_instance(2, 1, "power", "l1"))
take(player, 1, 2, "welder")
t.click_component(player, 2, 1, assert(t.component_instance(2, 1, "station_base")))
t.run_seconds(4.5)
assert(composition.matches(2, 1, { "station_base" }), "a base supporting cable cannot be removed")
assert(t.network_instance(2, 1, "power", "l1") == cable, "the rejected operation preserves its run")
t.drop(player)
t.run_ticks(2)
take(player, 1, 1, "wirecutters")
t.click_network(player, 2, 1, cable)
t.run_seconds(1.5)
assert(t.network_instance(2, 1, "power", "l1") == nil, "the cable is removed through its tool action")
t.drop(player)
t.run_ticks(2)
take(player, 2, 2, "welder")
t.click_component(player, 2, 1, assert(t.component_instance(2, 1, "station_base")))
t.run_seconds(4.5)
assert(composition.bare(2, 1, "space"), "the unsupported base can now be removed")
