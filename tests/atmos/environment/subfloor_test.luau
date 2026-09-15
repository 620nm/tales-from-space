local network_matter = require("@helpers/network_matter")
local network_channels = require("@helpers/network_channels")

local composition = require("@helpers/composition")

-- An intact floor tile hides its plumbing, and hiding it means hiding it
-- from tools as well as from eyes.
--
-- tg does this at the turf: `/turf/proc/levelupdate()` sends
-- COMSIG_OBJ_HIDE to everything standing in a covered tile
-- (code/game/turfs/turf.dm:503-506), which drops pipes, disposals and
-- wires to UNDERFLOOR_HIDDEN (code/__DEFINES/turfs.dm:50-54;
-- atmospherics registers for the signal in code/modules/atmospherics/
-- machinery/atmosmachinery.dm:135-145, `var/hide = TRUE` on line 38).
-- The rule is NOT "the tool declines" -- the buried thing is not there
-- to be clicked at all. So the wrench and the wirecutters answer a
-- covered tile with silence: no do_after, no ledger row, and above all
-- no message, because "you can't reach the pipe" would be a free survey
-- of what is buried under a station's floors.
--
-- Laying is the mirror case and speaks: you are placing something you
-- hold onto a floor you can see, so the refusal describes the floor and
-- gives nothing away.


local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m:find(want, 1, true) then
            return true
        end
    end
    return false
end

-- (2, 1) is open plating and (2, 2) a finished floor tile; the same run
-- of pipe and the same branch cable pass under both. Every assertion
-- below is that pair answering differently. (2, 3) is a bare covered
-- tile, for the laying half.
t.world(
    [==[(
    name: "subfloor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#.o.#",
        "#.o.#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn")],
    items: [
        (1, 1, "wrench"),
        (3, 1, "wirecutters"),
        (1, 3, "cable_coil"),
        (3, 3, "crowbar"),
        (1, 2, "pipe"),
        (3, 2, "wrench"),
    ],
    networks: [
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],

)]==],
    7
)

local p = t.join()
t.tick()

local function set_down_clear()
    t.move(p, "south")
    t.run_ticks(5)
    t.drop(p)
    t.run_ticks(2)
    t.move(p, "north")
    t.run_ticks(5)
end

assert(composition.matches(2, 1, { "station_base" }), "one tile is open")
assert(composition.matches(2, 2, { "station_base", "floor_tiles" }), "and its neighbour is tiled over")
assert(network_channels.at(2, 2, "pipe") == "l3", "the run passes under the tiled one")
assert(network_channels.at(2, 2, "power") == "l1", "and so does the cable")

-- ---------------------------------------------------------------
-- The wrench. Buried pipe under a tile is not wrenchable.
-- ---------------------------------------------------------------
t.click(p, 1, 1, t.target_at(p, 1, 1, "wrench")) -- pick up the wrench
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")
local _ = t.messages(p)

t.click(p, 2, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 2, "pipe") == "l3", "the buried run is untouched")
assert(not said(p, "unwrenching"), "and the wrench never started on it")
assert(#t.ledger_rows("NetworkRemoved") == 0, "nothing to put on the record")
assert(t.count_items("pipe") == 1, "no length came up (only the mapped one)")

-- The same click, one tile north where the deck is open, works. This is
-- what makes the silence above a rule about the floor and not a broken
-- handler.
t.click_network(p, 2, 1, assert(t.network_instance(2, 1, "pipe", "l3")))
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "pipe") == "", "open plating gives the length up")
assert(#t.ledger_rows("NetworkRemoved") == 1, "and that one IS on the record")
assert(t.count_items("pipe") == 2, "the removed length returned as a one-piece item")

-- ---------------------------------------------------------------
-- The wirecutters. Same rule, sabotage side.
-- ---------------------------------------------------------------
set_down_clear()
t.click(p, 3, 1, t.target_at(p, 3, 1, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
_ = t.messages(p)

t.click(p, 2, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 2, "power") == "l1", "the buried cable is untouched")
assert(not said(p, "snipping"), "and the cutters never bit")
assert(#t.ledger_rows("NetworkRemoved") == 1, "no cut to attribute")

t.click_network(p, 2, 1, assert(t.network_instance(2, 1, "power", "l1")))
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "power") == "", "open plating cuts fine")
assert(#t.ledger_rows("NetworkRemoved") == 2, "and that cut is attributed")
assert(t.count_items("cable_coil") == 2, "the cut line returned as a one-piece coil")

-- ---------------------------------------------------------------
-- Laying, both trades: no work is offered through a finished floor.
-- ---------------------------------------------------------------
local placements_before = #t.ledger_rows("NetworkPlaced")
set_down_clear()
t.click(p, 1, 3, t.target_at(p, 1, 3, "cable_coil")) -- the coil
t.run_ticks(2)
_ = t.messages(p)
for _, action in ipairs(t.action_hints(p, composition.deck_target(2, 3))) do
    assert(action.id ~= "lay_cable", "covered deck offers no cable laying")
end
t.click(p, 2, 3, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 3, "power") == "", "no cable goes down over a finished floor")
assert(#t.ledger_rows("NetworkPlaced") == placements_before, "nothing laid, nothing recorded")
assert(
    not said(p, "The floor is in the way. Pry the tile up first."),
    "the inapplicable cable handler does not execute"
)

set_down_clear()
t.click(p, 1, 2, t.target_at(p, 1, 2, "pipe")) -- the length of pipe
t.run_ticks(2)
_ = t.messages(p)
for _, action in ipairs(t.action_hints(p, composition.deck_target(2, 3))) do
    assert(action.id ~= "lay_pipe", "covered deck offers no pipe laying")
end
t.click(p, 2, 3, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 3, "pipe") == "", "no length goes down over a finished floor either")
assert(
    not said(p, "The floor is in the way. Pry the tile up first."),
    "the inapplicable pipe handler does not execute"
)

-- ---------------------------------------------------------------
-- Pry the tile up and the plumbing is ordinary work again.
-- ---------------------------------------------------------------
set_down_clear()
t.click(p, 3, 3, t.target_at(p, 3, 3, "crowbar")) -- the crowbar
t.run_ticks(2)
t.click(p, 2, 2, nil, -14, 14)
t.run_ticks(2)
assert(composition.matches(2, 2, { "station_base" }), "the tile came up")

t.move(p, "south")
t.run_ticks(5)
local lifted = assert(t.target_at(p, 2, 2, "floor_tile"))
assert(lifted ~= nil, "the pried tile is visible from beside it")
t.click(p, 2, 2, lifted)
t.run_ticks(2)
t.swap_hands(p)
t.drop(p)
t.run_ticks(2)
t.swap_hands(p)
t.move(p, "north")
t.run_ticks(5)

set_down_clear()
t.click(p, 3, 2, t.target_at(p, 3, 2, "wrench")) -- the spare wrench, kept clear of the pile at our feet
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand again")

t.move(p, "south")
t.run_ticks(5)
t.click_network(p, 2, 2, assert(t.network_instance(2, 2, "pipe", "l3")))
t.run_seconds(1.5)
assert(network_channels.at(2, 2, "pipe") == "", "the same click that did nothing now pulls the run")
assert(#t.ledger_rows("NetworkRemoved") == 3, "and the second pull is recorded")

-- ---------------------------------------------------------------
-- Covering open plumbing. The exact pixel the client picked does not
-- change the turf operation: floor tiles cover raw pipe and the
-- component which replaced a length of it, without deleting either.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "cover subfloor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    items: [(2, 2, "floor_tile")],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    structures: [(2, 2, "player_spawn"), (2, 1, "manual_valve"), (3, 1, "connector_port")],
)]==],
    7
)

local c = t.join()
t.tick()
t.click(c, 2, 2, t.target_at(c, 2, 2, "floor_tile"))
t.run_ticks(2)
assert(t.hands(c).held == "floor_tile", "the tile stack is in hand")

-- A visible pipe has its own exact click channel. Material construction
-- still belongs to the turf underneath that sprite.
t.click(c, 1, 1, nil, -14, 14)
t.run_seconds(2)
assert(composition.matches(1, 1, { "station_base", "floor_tiles" }), "a tile clicked on raw pipe covers the deck")
assert(network_channels.at(1, 1, "pipe") == "l3", "covering does not consume the raw pipe")

-- A binary machine is the length of pipe, and a unary connector is its
-- own centre plus a directional stub. Both are equally coverable when
-- the structure sprite itself was the exact target.
t.click(c, 2, 1, t.target_at(c, 2, 1, "manual_valve"))
t.run_seconds(2)
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "a floor tile covers a pipe device")
assert(assert(t.structure_at(2, 1)).id == "manual_valve", "the device remains under the tile")

t.click(c, 3, 1, t.target_at(c, 3, 1, "connector_port"))
t.run_seconds(2)
assert(composition.matches(3, 1, { "station_base", "floor_tiles" }), "a floor tile covers a connector")
assert(assert(t.structure_at(3, 1)).id == "connector_port", "the connector remains under the tile")
assert(network_channels.at(3, 1, "pipe") == "", "the unary connector still replaces its centre length")

-- The above cases clicked the plumbing art itself. A canister stacked over
-- its connector has transparent pixels around the bottle; those pixels name
-- ground, not whichever structure happens to be topmost on the tile. The
-- floor therefore slides over the port and under the still-fastened bottle.
t.world(
    [==[(
    name: "tile under canister",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        'c': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#.c.#",
        "#...#",
        "#####",
    ],
    items: [(2, 2, "floor_tile")],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (2, 2, "player_spawn"),
        (2, 1, "connector_port"),
        (2, 1, "canister", { "blend": "canister_air", "open": true }),
    ],
)]==],
    7
)

local d = t.join()
t.tick()
assert(t.target_at(d, 2, 1, "connector_port") ~= nil, "a real port starts under the canister")
assert(assert(t.canister_pressure(2, 1)) > 4000.0, "the canister starts fastened and full")
assert(assert(network_matter.pressure(1, 1)) > 90.0, "its port has charged the neighbouring run")
t.click(d, 2, 2, t.target_at(d, 2, 2, "floor_tile"))
t.run_ticks(2)

-- Naming the native canister is naming the bottle, not its connector and
-- not the turf. It must not collapse into the ground operation below.
local bottle = assert(t.target_at(d, 2, 1))
assert(bottle ~= nil, "the visible canister has an exact wire identity")
t.click(d, 2, 1, bottle)
t.run_seconds(2)
assert(composition.matches(2, 1, { "station_base" }), "an explicit canister click leaves the deck open")
assert(t.canister_pressure(2, 1) ~= nil, "the named bottle and port remain intact")

-- A visible corner pixel reaches the deck beside the canister and port.
t.click(d, 2, 1, nil, -14, 14)
t.run_seconds(2)
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "a ground pixel tiles beneath the canister")
assert(assert(t.structure_at(2, 1)).id == "canister", "the canister remains above the tile")
assert(t.canister_pressure(2, 1) ~= nil, "it remains anchored to its socket")
assert(network_channels.at(2, 1, "pipe") == "", "the connector did not become a hidden raw length")
assert(assert(network_matter.pressure(1, 1)) > 90.0, "the port remains plumbed to its neighbouring run")

-- ---------------------------------------------------------------
-- Floor panels control each network independently. A map can leave
-- both panels open, close both, or expose the cable while keeping
-- the pipe covered. The installed cover owns those states.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "authored decks",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles", controls: {"power": "open", "pipe": "open"})])),
        'c': (composition: (components: [(component: "station_base"), (component: "floor_tiles", controls: {"power": "closed", "pipe": "closed"})])),
        'p': (composition: (components: [(component: "station_base"), (component: "floor_tiles", controls: {"power": "open", "pipe": "closed"})])),
        'w': (composition: (components: [(component: "station_base"), (component: "floor_tiles", controls: {"power": "open", "pipe": "closed"})])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#poc#",
        "#w..#",
        "#...#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn")],
    items: [(2, 2, "wirecutters"), (3, 2, "wrench"), (1, 3, "cable_coil"), (3, 3, "pipe")],
    networks: [
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],

)]==],
    7
)

local e = t.join()
t.tick()
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "the panel is a finished floor")
assert(t.network_exposed(2, 1, "power"), "and its deck is open anyway")
assert(t.network_exposed(2, 1, "pipe"), "to both runs")
assert(composition.matches(3, 1, { "station_base", "floor_tiles" }), "its neighbour has a closed floor panel")
assert(not t.network_exposed(3, 1, "power"), "with its wiring boxed in")
assert(not t.network_exposed(3, 1, "pipe"), "and its plumbing too")

-- Both independently authored panels expose cable and conceal pipe.
assert(composition.matches(1, 1, { "station_base", "floor_tiles" }), "the corner panel is a finished floor")
assert(t.network_exposed(1, 1, "power"), "open to cable")
assert(not t.network_exposed(1, 1, "pipe"), "but not to pipe")
assert(composition.matches(1, 2, { "station_base", "floor_tiles" }), "the side tile is a finished floor")
assert(t.network_exposed(1, 2, "power"), "with its cable claim open")
assert(not t.network_exposed(1, 2, "pipe"), "and its pipe claim shut")

t.click(e, 2, 2, t.target_at(e, 2, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(e).held == "wirecutters", "cutters in hand")
_ = t.messages(e)

local picked, why = pcall(function()
    t.click_network(e, 3, 1, assert(t.network_instance(3, 1, "power", "l1")))
end)
assert(
    not picked and string.find(tostring(why), "instance has not been disclosed", 1, true),
    "the concealed run cannot be selected through the picture"
)
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "l1", "the closed floor panel keeps its run")
assert(not said(e, "snipping"), "and the cutters never bit")

t.click_network(e, 2, 1, assert(t.network_instance(2, 1, "power", "l1")))
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "power") == "", "the open panel gives its run up")
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "without becoming a different deck")

-- A claim that hides only the pipe still parts for the cutters.
t.click_network(e, 1, 1, assert(t.network_instance(1, 1, "power", "l1")))
t.run_seconds(1.5)
assert(network_channels.at(1, 1, "power") == "", "the pipe-only cover gives its cable up")
t.click_network(e, 1, 2, assert(t.network_instance(1, 2, "power", "l1")))
t.run_seconds(1.5)
assert(network_channels.at(1, 2, "power") == "", "and so does the floor with its cable claim open")
assert(composition.matches(1, 2, { "station_base", "floor_tiles" }), "which stays a finished floor")

-- The wrench reads the pipe control. The covered pipe is
-- unselectable through the picture, and a ground click
-- answers with silence.
t.drop(e)
t.run_ticks(2)
t.click(e, 3, 2, t.target_at(e, 3, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(e).held == "wrench", "wrench in hand")
_ = t.messages(e)

local plumbed, plumb_why = pcall(function()
    t.click_network(e, 1, 1, assert(t.network_instance(1, 1, "pipe", "l3")))
end)
assert(
    not plumbed and string.find(tostring(plumb_why), "instance has not been disclosed", 1, true),
    "the pipe cannot be selected through its closed floor panel"
)
t.click(e, 1, 1, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(1, 1, "pipe") == "l3", "the pipe-only cover keeps its run")
assert(not said(e, "unwrenching"), "and the wrench never started on it")

-- Laying follows the same split: the length of pipe is refused by
-- each split-claim tile, the coil works both. Pipe first, while no
-- fresh cable pixel is there to take the click.
t.drop(e)
t.run_ticks(2)
t.click(e, 3, 3, t.target_at(e, 3, 3, "pipe"))
t.run_ticks(2)
assert(t.hands(e).held == "pipe", "the length of pipe in hand")
_ = t.messages(e)

local function offers(id, x, y)
    for _, action in ipairs(t.action_hints(e, composition.deck_target(x, y))) do
        if action.id == id then
            return true
        end
    end
    return false
end

assert(not offers("lay_pipe", 1, 1), "the pipe-only cover offers no pipe laying")
t.click(e, 1, 1, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(1, 1, "pipe") == "l3", "no length goes down beside the boxed-in run")
assert(
    not said(e, "The floor is in the way. Pry the tile up first."),
    "the inapplicable pipe handler does not execute"
)
assert(not offers("lay_pipe", 1, 2), "the open cable claim offers no pipe laying")
t.click(e, 1, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(1, 2, "pipe") == "", "and no length goes down over the finished floor")
assert(
    not said(e, "The floor is in the way. Pry the tile up first."),
    "the inapplicable pipe handler does not execute there either"
)

-- Control: the panel open to BOTH runs takes the length.
assert(offers("lay_pipe", 2, 1), "the open panel still offers pipe laying")
t.click(e, 2, 1, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "pipe") == "l3", "and the length goes down")

-- Set the remaining pipe stack down before picking up the coil.
t.drop(e)
t.run_ticks(2)
t.click(e, 1, 3, t.target_at(e, 1, 3, "cable_coil"))
t.run_ticks(2)
assert(t.hands(e).held == "cable_coil", "coil in hand")
_ = t.messages(e)

assert(offers("lay_cable", 1, 1), "the pipe-only cover still offers cable laying")
t.click(e, 1, 1, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(1, 1, "power") == "l2", "and the line goes down on the coil's layer")
assert(offers("lay_cable", 1, 2), "the open cable claim offers laying over a finished floor")
t.click(e, 1, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(1, 2, "power") == "l2", "and cable goes down over the finished floor")
