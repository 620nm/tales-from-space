local composition = require("@helpers/composition")
local network_channels = require("@helpers/network_channels")
local ui_controls = require("@helpers/ui_controls")

-- Cable support comes from the installed catwalk, which remains unsealed.
t.world([==[(
    name: "EVA cable support",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        's': (composition: (substrate: Some("space"))),
        'l': (composition: (substrate: Some("space"), components: [(component: "lattice")])),
        'c': (composition: (substrate: Some("space"), components: [(component: "catwalk")]), outdoors: true),
    },
    rows: ["#####", "#slc#", "#...#", "#####"],
    environment: (gravity_m_s2: Exact(9.80665)),
    structures: [(2, 2, "player_spawn")],
    items: [(1, 2, "cable_coil")],
)]==], 7)
local player = t.join()
t.tick()
t.click(player, 1, 2, t.target_at(player, 1, 2, "cable_coil"))
t.run_ticks(2)
assert(t.hands(player).held == "cable_coil")
t.use_self(player)
t.run_ticks(2)
t.use_self(player)
t.run_ticks(2)
t.click_turf(player, 1, 1)
t.run_seconds(1.5)
assert(network_channels.at(1, 1, "power") == "", "bare Space cannot support cable")
t.click_component(player, 2, 1, assert(t.component_instance(2, 1, "lattice")))
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "power") == "", "lattice cannot support cable")
assert(t.is_breached(3, 1), "the catwalk does not seal its Space substrate")
assert(t.outdoors(3, 1), "the catwalk retains the map's outdoor flag")
t.click_component(player, 3, 1, assert(t.component_instance(3, 1, "catwalk")))
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "l1", "the catwalk supports the selected cable channel")
assert(t.is_breached(3, 1), "installing cable does not seal the catwalk")
assert(t.outdoors(3, 1), "cable installation does not change outdoors")
assert(assert(t.composition(3, 1)).substrate == "space", "the catwalk retains its explicit substrate")

local BRIDGE = [==[(
    name: "EVA supported runs",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'c': (composition: (substrate: Some("space"), components: [(component: "catwalk")]), outdoors: true),
    },
    rows: ["#####", "#.c.#", "#...#", "#####"],
    environment: (gravity_m_s2: Exact(9.80665)),
    structures: [(2, 2, "player_spawn")],
    items: [(1, 2, "%s")],
    networks: [
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
)]==]

for _, item in ipairs({ "wirecutters", "floor_tile" }) do
    t.world(string.format(BRIDGE, item), 7)
    player = t.join()
    t.tick()
    local catwalk = assert(t.component_instance(2, 1, "catwalk"))
    assert(t.outdoors(2, 1), "the supported bridge starts outdoors")
    local pipe = assert(t.network_instance(2, 1, "pipe", "l3"))
    local cables: {[number]: boolean} = {}
    for _, channel in ipairs({ "l1", "l2", "l3" }) do
        cables[assert(t.network_instance(2, 1, "power", channel))] = true
    end
    t.click(player, 1, 2, t.target_at(player, 1, 2, item))
    t.run_ticks(2)
    t.click_component(player, 2, 1, catwalk)
    t.run_ticks(2)
    assert(t.component_instance(2, 1, "catwalk") == nil, "the chosen catwalk component is removed")
    assert(t.outdoors(2, 1), "removal and base replacement both preserve outdoors")
    assert(t.network_instance(2, 1, "pipe", "l3") == pipe, "the independent pipe retains its identity")
    if item == "wirecutters" then
        assert(composition.bare(2, 1, "space"), "cutting the catwalk reveals its retained Space")
        assert(network_channels.at(2, 1, "power") == "", "all unsupported cable channels leave together")
        local removed = t.ledger_rows("NetworkRemoved")
        assert(#removed == 3, "each dependent cable removal is attributed")
        local tick = removed[1].tick
        for _, row in ipairs(removed) do
            local instance = ui_controls.number(ui_controls.record(row.target).instance)
            assert(cables[instance], "each removal names a cable that the catwalk supported")
            cables[instance] = nil
            assert(row.tick == tick, "the dependent removals occur in one transaction tick")
            assert(ui_controls.record(row.actor).kind == "player", "the cutter user owns every dependent removal")
        end
    else
        assert(composition.matches(2, 1, { "station_base" }), "a tile replaces the catwalk with a base")
        assert(not t.is_breached(2, 1), "the replacement base seals the retained Space")
        assert(network_channels.at(2, 1, "power") == "l1,l2,l3", "the new support preserves every valid cable")
        for _, channel in ipairs({ "l1", "l2", "l3" }) do
            assert(cables[assert(t.network_instance(2, 1, "power", channel))], "replacement preserves cable identity")
        end
        assert(#t.ledger_rows("NetworkRemoved") == 0, "a supported replacement removes no networks")
    end
end
