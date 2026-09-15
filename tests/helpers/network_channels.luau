-- Channel names sorted for exact topology assertions and diagnostics.
local network_channels = {}

-- Composition network and channel IDs are the wire's typed identity fields.
-- They follow the declaration order in content/compositions.luau.
local NETWORK_IDS: {[string]: number} = { power = 0, pipe = 1 }
local CHANNEL_IDS: {[string]: {[string]: number}} = {
    power = { l1 = 0, l2 = 1, l3 = 2 },
    pipe = { l1 = 0, l2 = 1, l3 = 2, l4 = 3, l5 = 4 },
}

function network_channels.at(x: number, y: number, network: string): string
    local channels = t.network_channels(x, y, network)
    table.sort(channels)
    return table.concat(channels, ",")
end

function network_channels.target(
    x: number,
    y: number,
    network: string,
    channel: string,
    instance: number
): SpecActionTarget
    local target = {
        Network = {
            tile = { x = x, y = y },
            network = assert(NETWORK_IDS[network]),
            channel = assert(CHANNEL_IDS[network][channel]),
            instance = instance,
        },
    }
    -- The checked binding predates the network and channel identity fields.
    return target :: any
end

return network_channels
