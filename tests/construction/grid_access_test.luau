-- A grid discloses its runs through the mesh while denying tool access.
local network_channels = require("@helpers/network_channels")

local BENCH = [==[(
    name: "Protective grid",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'g': (composition: (components: [(component: "station_base")%s])),
    },
    rows: ["#####", "#.g.#", "#...#", "#####"],
    structures: [(2, 2, "player_spawn")],
    items: [(1, 2, "wirecutters"), (3, 2, "wrench")],
    networks: [
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
)]==]

local function bench(cover: string): number
    t.world(string.format(BENCH, cover), 7)
    local player = t.join()
    t.tick()
    return player
end

local function take(player: number, network: string)
    local x = if network == "power" then 1 else 3
    local item = if network == "power" then "wirecutters" else "wrench"
    t.click(player, x, 2, t.target_at(player, x, 2, item))
    t.run_ticks(2)
    assert(t.hands(player).held == item)
end

for _, state in ipairs({ "closed", "open" }) do
    for _, network in ipairs({ "power", "pipe" }) do
        local channel = if network == "power" then "l1" else "l3"
        local player = bench(string.format(
            ', (component: "grid_cover", controls: {"power": "%s", "pipe": "%s"})', state, state
        ))
        take(player, network)
        local instance = assert(t.network_instance(2, 1, network, channel))
        assert(t.examine_network(player, 2, 1, instance), "the run remains examinable through the mesh")
        assert(not t.network_exposed(2, 1, network), "every installed grid state denies tools")
        local action = if network == "power" then "cut_cable" else "unfasten_pipe"
        for _, hint in ipairs(t.action_hints(player, network_channels.target(2, 1, network, channel, instance))) do
            assert(hint.id ~= action, "a named disclosed run offers no forbidden tool action")
        end
        t.click_network(player, 2, 1, instance)
        t.run_seconds(1.5)
        assert(t.network_instance(2, 1, network, channel) == instance, "a click through the grid preserves the run")
        assert(#t.ledger_rows("NetworkRemoved") == 0, "the refused click records no removal")
    end
end

-- A tool already in progress revalidates the newly installed cover.
for _, network in ipairs({ "power", "pipe" }) do
    local channel = if network == "power" then "l1" else "l3"
    local player = bench("")
    take(player, network)
    local instance = assert(t.network_instance(2, 1, network, channel))
    assert(t.network_exposed(2, 1, network), "the bare base permits the initial tool action")
    local other_network = if network == "power" then "pipe" else "power"
    local other_channel = if network == "power" then "l3" else "l1"
    local other = assert(t.network_instance(2, 1, other_network, other_channel))
    local action = if network == "power" then "cut_cable" else "unfasten_pipe"
    for _, hint in ipairs(t.action_hints(
        player,
        network_channels.target(2, 1, other_network, other_channel, other)
    )) do
        assert(hint.id ~= action, "the tool does not claim another network sharing its tile")
    end
    local starts_before = #t.ledger_rows("DoAfterStarted")
    t.click_network(player, 2, 1, other)
    t.run_seconds(1.5)
    assert(t.network_instance(2, 1, other_network, other_channel) == other,
        "the exact wrong-network target remains untouched")
    assert(#t.ledger_rows("NetworkRemoved") == 0, "the wrong-network click performs no removal")
    assert(#t.ledger_rows("DoAfterStarted") == starts_before, "the wrong-network click starts no tool work")
    t.click_network(player, 2, 1, instance)
    t.run_ticks(2)
    assert(#t.ledger_rows("DoAfterStarted") == starts_before + 1, "the correct tool starts before the cover is installed")
    assert(t.set_composition(2, 1, "grid"), "the grid is the changed precondition")
    t.run_seconds(1.5)
    assert(t.network_instance(2, 1, network, channel) == instance, "completion rechecks the grid's access policy")
    assert(#t.ledger_rows("NetworkRemoved") == 0, "the interrupted tool records no removal")
end

-- A solid wall conceals both networks, even when their identities are named.
for _, network in ipairs({ "power", "pipe" }) do
    local channel = if network == "power" then "l1" else "l3"
    local player = bench(', (component: "wall")')
    take(player, network)
    local instance = assert(t.network_instance(2, 1, network, channel))
    assert(not t.network_exposed(2, 1, network), "a wall closes access to its buried run")
    assert(
        #t.action_hints(player, network_channels.target(2, 1, network, channel, instance)) == 0,
        "a named concealed run discloses no actions"
    )
    local examined, result = pcall(function() return t.examine_network(player, 2, 1, instance) end)
    assert(not examined or result == nil, "a wall discloses no network examination")
    local clicked = pcall(function() t.click_network(player, 2, 1, instance) end)
    assert(not clicked, "the observed picture cannot target a network through a wall")
    t.run_seconds(1.5)
    assert(t.network_instance(2, 1, network, channel) == instance, "the concealed run stays installed")
end
