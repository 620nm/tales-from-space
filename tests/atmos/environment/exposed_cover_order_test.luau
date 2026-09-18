-- Cover artwork moves below disclosed infrastructure only when its own
-- network controls expose that artwork. The rows here are the player's
-- received composition delta, rather than the authoritative tile query.

local MAP = [==[(
    name: "exposed cover order",
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'f': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'm': (composition: (components: [(component: "station_base"), (component: "floor_tiles", controls: {"power": "open"})])),
        'r': (composition: (components: [(component: "station_base"), (component: "reinforcement")])),
        'g': (composition: (components: [(component: "station_base"), (component: "grid_cover")])),
        'o': (composition: (components: [(component: "station_base"), (component: "grid_cover", controls: {"power": "open", "pipe": "open"})])),
        'p': (composition: (components: [(component: "station_base"), (component: "floor_tiles", controls: {"pipe": "open"})])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "#########",
        "#fmrgop.#",
        "#########",
    ],
    structures: [(1, 1, "player_spawn")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
)]==]

local POWER_NETWORK = 0
local PIPE_NETWORK = 1
local L1_CHANNEL = 0
local L3_CHANNEL = 2

local function row(rows: {SpecSeenCompositionRow}, sprite: string): SpecSeenCompositionRow?
    for _, received in ipairs(rows) do
        if received.sprite == sprite then return received end
    end
    return nil
end

local function network_row(rows: {SpecSeenCompositionRow}, network: number, channel: number): SpecSeenCompositionRow?
    for _, received in ipairs(rows) do
        if received.kind == "network" and received.network == network and received.channel == channel then
            return received
        end
    end
    return nil
end

local function starts_with(value: string, prefix: string): boolean
    return string.sub(value, 1, #prefix) == prefix
end

local function drawn(rows: {SpecSeenCompositionRow}, sprite: string, label: string): SpecSeenCompositionRow
    local received = assert(row(rows, sprite), label .. " sprite is received")
    assert(received.appearance, label .. " appearance is drawn")
    assert(received.pickable, label .. " row is pickable")
    return received
end

local function drawn_network(rows: {SpecSeenCompositionRow}, network: number, channel: number, prefix: string, label: string): SpecSeenCompositionRow
    local received = assert(network_row(rows, network, channel), label .. " row is received")
    assert(starts_with(received.sprite, prefix), label .. " has expected sprite")
    assert(received.appearance, label .. " appearance is drawn")
    assert(received.pickable, label .. " row is pickable")
    return received
end

local function ordered(rows: {SpecSeenCompositionRow})
    for index = 2, #rows do
        assert(rows[index - 1].visual_rank <= rows[index].visual_rank, "received rows follow bottom-up draw order")
    end
end

local function received(player: number, x: number, y: number): {SpecSeenCompositionRow}
    t.tick()
    return t.seen_composition(player, x, y)
end

t.world(MAP, 7)
local player = t.join()
t.tick()

-- A closed tiled cover shows its own art and discloses neither run.
local floor_closed = t.seen_composition(player, 1, 1)
drawn(floor_closed, "floor", "closed floor")
assert(network_row(floor_closed, POWER_NETWORK, L1_CHANNEL) == nil, "a closed floor hides power")
assert(network_row(floor_closed, PIPE_NETWORK, L3_CHANNEL) == nil, "a closed floor hides pipe")

-- One open control is enough to move the whole floor artwork and disclose
-- that network; the other network remains concealed by its own control.
local mixed = t.seen_composition(player, 2, 1)
local mixed_cover = drawn(mixed, "open_floor", "power-open floor")
local mixed_power = drawn_network(mixed, POWER_NETWORK, L1_CHANNEL, "cable_l1_", "power-open cable")
assert(network_row(mixed, PIPE_NETWORK, L3_CHANNEL) == nil, "mixed floor keeps pipe concealed")
assert(mixed_cover.visual_rank < mixed_power.visual_rank, "exposed cover is below power")

-- A closed reinforced cover keeps its sprite and conceals both networks.
local reinforced_closed = t.seen_composition(player, 3, 1)
drawn(reinforced_closed, "reinforced_floor", "closed reinforcement")
assert(network_row(reinforced_closed, POWER_NETWORK, L1_CHANNEL) == nil, "closed reinforcement hides power")
assert(network_row(reinforced_closed, PIPE_NETWORK, L3_CHANNEL) == nil, "closed reinforcement hides pipe")

-- The opposite single-control path moves the same cover and discloses only
-- pipe, proving the last active control is not accidentally power-specific.
local pipe_mixed = t.seen_composition(player, 6, 1)
local pipe_cover = drawn(pipe_mixed, "open_floor", "pipe-open floor")
local pipe_row = drawn_network(pipe_mixed, PIPE_NETWORK, L3_CHANNEL, "pipe_l3_", "pipe-open pipe")
assert(network_row(pipe_mixed, POWER_NETWORK, L1_CHANNEL) == nil, "pipe-open floor keeps power concealed")
assert(pipe_cover.visual_rank < pipe_row.visual_rank, "pipe-open cover is below pipe")

-- Grid disclosure/access controls continue to show both runs, while the
-- cover remains on its original layer in both control states.
local grid_closed = t.seen_composition(player, 4, 1)
local grid_open = t.seen_composition(player, 5, 1)
ordered(grid_closed)
ordered(grid_open)
local grid_closed_cover = drawn(grid_closed, "open_floor", "closed grid")
local grid_open_cover = drawn(grid_open, "open_floor", "open grid")
local grid_closed_pipe = drawn_network(grid_closed, PIPE_NETWORK, L3_CHANNEL, "pipe_l3_", "closed grid pipe")
local grid_open_pipe = drawn_network(grid_open, PIPE_NETWORK, L3_CHANNEL, "pipe_l3_", "open grid pipe")
local grid_closed_power = drawn_network(grid_closed, POWER_NETWORK, L1_CHANNEL, "cable_l1_", "closed grid power")
local grid_open_power = drawn_network(grid_open, POWER_NETWORK, L1_CHANNEL, "cable_l1_", "open grid power")
assert(grid_closed_cover.visual_rank > grid_closed_pipe.visual_rank, "grid cover stays above pipe")
assert(grid_closed_cover.visual_rank > grid_closed_power.visual_rank, "grid cover stays above power")
assert(grid_closed_pipe.visual_rank < grid_closed_power.visual_rank, "grid pipe stays below power")
assert(grid_open_cover.visual_rank == grid_closed_cover.visual_rank, "grid controls do not move the cover")
assert(grid_open_pipe.visual_rank == grid_closed_pipe.visual_rank, "grid pipe rank is unchanged")
assert(grid_open_power.visual_rank == grid_closed_power.visual_rank, "grid power rank is unchanged")

-- The exposed preset has the intended picture and complete ordering. Closing
-- it withdraws both network rows, and reopening restores their same sprites.
assert(t.set_composition(1, 1, "floor_exposed"), "the exposed floor preset applies")
local exposed_floor = received(player, 1, 1)
ordered(exposed_floor)
local exposed_cover = drawn(exposed_floor, "open_floor", "exposed floor")
local exposed_pipe = drawn_network(exposed_floor, PIPE_NETWORK, L3_CHANNEL, "pipe_l3_", "exposed floor pipe")
local exposed_power = drawn_network(exposed_floor, POWER_NETWORK, L1_CHANNEL, "cable_l1_", "exposed floor power")
assert(exposed_cover.visual_rank < exposed_pipe.visual_rank, "exposed cover is below pipe")
assert(exposed_pipe.visual_rank < exposed_power.visual_rank, "pipe is below power")

assert(t.set_composition(1, 1, "floor"), "the floor closes again")
local closed_again = received(player, 1, 1)
assert(drawn(closed_again, "floor", "closed-again floor").visual_rank == drawn(floor_closed, "floor", "initial floor").visual_rank, "closing restores the original rank")
assert(network_row(closed_again, POWER_NETWORK, L1_CHANNEL) == nil, "closing withdraws power")
assert(network_row(closed_again, PIPE_NETWORK, L3_CHANNEL) == nil, "closing withdraws pipe")

assert(t.set_composition(3, 1, "reinforced_floor_exposed"), "the exposed reinforcement preset applies")
local exposed_reinforcement = received(player, 3, 1)
ordered(exposed_reinforcement)
local reinforcement_cover = drawn(exposed_reinforcement, "reinforced_floor", "exposed reinforcement")
local reinforcement_pipe = drawn_network(exposed_reinforcement, PIPE_NETWORK, L3_CHANNEL, "pipe_l3_", "exposed reinforcement pipe")
local reinforcement_power = drawn_network(exposed_reinforcement, POWER_NETWORK, L1_CHANNEL, "cable_l1_", "exposed reinforcement power")
assert(reinforcement_cover.visual_rank < reinforcement_pipe.visual_rank, "exposed reinforcement is below pipe")
assert(reinforcement_pipe.visual_rank < reinforcement_power.visual_rank, "reinforcement pipe is below power")

assert(t.set_composition(1, 1, "floor_exposed"), "the exposed floor reopens")
local reopened = received(player, 1, 1)
ordered(reopened)
assert(drawn(reopened, "open_floor", "reopened floor").visual_rank == exposed_cover.visual_rank, "reopening restores the lowered rank")
local reopened_pipe = drawn_network(reopened, PIPE_NETWORK, L3_CHANNEL, "pipe_l3_", "reopened pipe")
local reopened_power = drawn_network(reopened, POWER_NETWORK, L1_CHANNEL, "cable_l1_", "reopened power")
assert(reopened_pipe.sprite == exposed_pipe.sprite and reopened_pipe.instance == exposed_pipe.instance, "reopening preserves pipe identity and artwork")
assert(reopened_power.sprite == exposed_power.sprite and reopened_power.instance == exposed_power.instance, "reopening preserves cable identity and artwork")
