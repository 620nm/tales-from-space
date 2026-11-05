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

-- A run's heat capacity, J/K, as dE/dT: a probe of joules in, the rise
-- read before any tick, and the same joules straight back out. E / T is
-- not a capacity, because a mole of a substance with a phase diagram
-- holds cv*T plus its gas row's offset (the engine's
-- docs/matter/registry.md).
local CAPACITY_PROBE_J = 1000.0

function network_matter.capacity(x: number, y: number, channel: string?): number
    local before_k = assert(network_matter.temperature(x, y, channel))
    assert(network_matter.heat(x, y, CAPACITY_PROBE_J, channel), "the probe reaches the run")
    local after_k = assert(network_matter.temperature(x, y, channel))
    assert(network_matter.heat(x, y, -CAPACITY_PROBE_J, channel), "and leaves it")
    return CAPACITY_PROBE_J / (after_k - before_k)
end

return network_matter
