local composition = require("@helpers/composition")
local network_channels = require("@helpers/network_channels")
local ui_controls = require("@helpers/ui_controls")

-- One station drawing is exercised under both kinds of sky. Only the mode's
-- tag differs: the authored composition, outdoor flags, and network rows do
-- not get a second fixture for terrestrial play.
local STATION = [==[(
    name: "composition retention",
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (components: []), outdoors: true),
        'b': (composition: (components: [(component: "station_base")]), outdoors: true),
        'e': (composition: (substrate: Some("space"), components: [(component: "station_base")]), outdoors: true),
        'n': (composition: (components: [(component: "station_base")])),
    },
    rows: [
        "#########",
        "#.gben..#",
        "#.......#",
        "#########",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "floor_tile"), (1, 2, "crowbar"), (2, 2, "welder")],
    networks: [
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l4", kind: "standard", facing: 15),
    ],
)]==]

local TERRESTRIAL_STATION = STATION:gsub(
    'name: "composition retention",',
    'name: "terrestrial composition retention", tags: ["terrestrial"],'
)

local function assert_retained(x: number, y: number, authored: string?, resolved: string)
    local tile = assert(t.composition(x, y))
    assert(tile.substrate == authored, "authored substrate provenance is retained")
    assert(tile.resolved_substrate == resolved, "the selected substrate is resolved")
    assert(t.outdoors(x, y), "the tile keeps its authored outdoor flag")
    return tile
end

local function take(player: number, id: string)
    for y = 0, 3 do
        for x = 0, 8 do
            local target = t.target_at(player, x, y, id)
            if target ~= nil then
                t.click(player, x, y, target)
                t.run_ticks(2)
                if t.hands(player).held == id then
                    return
                end
            end
        end
    end
    error("the player could not take " .. id)
end

local function exercise(map: string, expected_kind: string, substrate: string, recipe: string)
    t.world(map, 7, "free_build")
    local environment = t.environment()
    assert(environment.kind == expected_kind, "the map uses the requested environment profile")

    -- The omitted value stays omitted while its selected environment changes;
    -- an authored space substrate remains an explicit override on land too.
    assert_retained(3, 1, nil, substrate)
    assert_retained(4, 1, "space", "space")
    assert(composition.matches(5, 1, { "station_base" }), "the network deck starts complete")
    local power = assert(t.network_instance(5, 1, "power", "l2"))
    local pipe = assert(t.network_instance(5, 1, "pipe", "l4"))
    assert(network_channels.at(5, 1, "power") == "l2", "the authored power channel is present")
    assert(network_channels.at(5, 1, "pipe") == "l4", "the authored pipe channel is present")

    local player = t.join()
    t.tick()
    local sx, sy = t.pos(player)
    assert(sx == 1 and sy == 1, "the spawn marker seats the builder at the map marker")

    -- Build the ordinary deck through the disclosed build window. The item
    -- owns the same floor transition that a player would use in either sky.
    take(player, "floor_tile")
    ui_controls.build(player, "floor_tile", recipe, 2, 1)
    t.run_ticks(40)
    assert(composition.matches(2, 1, { "station_base" }), "the ordinary base is built")
    local base = assert(t.component_instance(2, 1, "station_base"))
    assert_retained(2, 1, nil, substrate)
    ui_controls.build(player, "floor_tile", "plating", 2, 1)
    t.run_ticks(20)
    assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "the floor cover is built")
    assert(t.component_instance(2, 1, "station_base") == base, "floor construction keeps the base identity")
    assert_retained(2, 1, nil, substrate)

    -- The crowbar is the real deconstruction transition; the retained base,
    -- substrate provenance, and outdoors flag survive it.
    t.drop(player)
    t.run_ticks(2)
    take(player, "crowbar")
    composition.click_deck(player, 2, 1)
    t.tick()
    assert(composition.matches(2, 1, { "station_base" }), "floor deconstruction leaves the base")
    assert(t.component_instance(2, 1, "station_base") == base, "floor removal keeps the base identity")
    assert_retained(2, 1, nil, substrate)

    -- Grid is a declared composition preset. Its cover is then removed by
    -- the same ordinary crowbar transition as floor tiles.
    assert(t.set_composition(2, 1, "grid"), "the declared grid preset is available")
    t.tick()
    assert(composition.matches(2, 1, { "station_base", "grid_cover" }), "the grid cover is installed")
    local grid_base = assert(t.component_instance(2, 1, "station_base"))
    assert_retained(2, 1, nil, substrate)
    composition.click_deck(player, 2, 1)
    t.tick()
    assert(composition.matches(2, 1, { "station_base" }), "grid deconstruction leaves the base")
    assert(t.component_instance(2, 1, "station_base") == grid_base, "grid removal keeps the base identity")
    assert_retained(2, 1, nil, substrate)

    -- Removing the station base exposes the retained substrate, including an
    -- inherited one, without changing outdoors or inventing an override.
    t.drop(player)
    t.run_ticks(2)
    t.move(player, "south")
    t.run_ticks(5)
    t.move(player, "east")
    t.run_ticks(5)
    take(player, "welder")
    t.use_self(player)
    t.tick()
    t.move(player, "north")
    t.run_ticks(5)
    t.move(player, "east")
    t.run_ticks(5)
    t.move(player, "east")
    t.run_ticks(5)
    t.click_component(player, 3, 1, assert(t.component_instance(3, 1, "station_base")))
    t.run_seconds(4.5)
    assert(composition.bare(3, 1, substrate), "base removal exposes the inherited substrate")
    assert_retained(3, 1, nil, substrate)
    assert(t.is_breached(3, 1) == (substrate == "space"), "the exposed substrate owns the boundary")

    t.move(player, "east")
    t.run_ticks(5)
    t.click_component(player, 4, 1, assert(t.component_instance(4, 1, "station_base")))
    t.run_seconds(4.5)
    assert(composition.bare(4, 1, "space"), "base removal exposes the explicit substrate")
    assert_retained(4, 1, "space", "space")
    assert(t.is_breached(4, 1), "the explicit space substrate owns the boundary")

    -- Composition edits do not touch authored network identity or channel
    -- names on a neighboring tile.
    assert(t.network_instance(5, 1, "power", "l2") == power, "the power instance survives composition edits")
    assert(t.network_instance(5, 1, "pipe", "l4") == pipe, "the pipe instance survives composition edits")
    assert(network_channels.at(5, 1, "power") == "l2", "power authoring remains named")
    assert(network_channels.at(5, 1, "pipe") == "l4", "pipe authoring remains named")
end

exercise(STATION, "space", "space", "space")
exercise(TERRESTRIAL_STATION, "terrestrial", "ground", "ground")

-- The spec harness intentionally exposes composition/network reads and
-- `t.world`, but no live map-export query. Server map-export tests cover the
-- export/reload serialization seam; this acceptance spec keeps its checks on
-- player actions and declared content transitions instead of manufacturing a
-- supposedly live exported document.
