-- Pipe-run gauges select retained components on the authored channel.
local network_matter = {}

local function instance(x: number, y: number, channel: string?): number?
    return t.network_instance(x, y, "pipe", channel or "l3")
end

function network_matter.pressure(x: number, y: number, channel: string?): number?
    local id = instance(x, y, channel)
    return if id then t.network_pressure(x, y, id) else nil
end

function network_matter.temperature(x: number, y: number, channel: string?): number?
    local id = instance(x, y, channel)
    return if id then t.network_temperature(x, y, id) else nil
end

function network_matter.energy(x: number, y: number, channel: string?): number?
    local id = instance(x, y, channel)
    return if id then t.network_energy(x, y, id) else nil
end

function network_matter.gas(x: number, y: number, channel: string?): { [string]: number }?
    local id = instance(x, y, channel)
    return if id then t.network_gas(x, y, id) else nil
end

function network_matter.heat(x: number, y: number, joules: number, channel: string?): boolean
    local id = instance(x, y, channel)
    return if id then t.heat_network(x, y, id, joules) else false
end

return network_matter
