-- What a multitool remembers between two clicks: the machine it last
-- logged (tg's `multitool.buffer`, code/game/objects/items/devices/
-- multitool.dm:37, `set_buffer` at :131). A handle does not outlive a
-- handler, so the buffer is the logged thing's tile and prototype, and a
-- read finds whatever of that prototype stands there now. A machine that
-- keeps a link of its own keeps the same `TileRef`.
export type TileRef = { x: number, y: number, z: number, prototype: string }

local multitool_buffer = {}

-- The item's script var (declared by items/tools/multitool.luau).
multitool_buffer.VAR = "lunatic/tfs:multitool_buffer"

function multitool_buffer.ref(target: Handle): TileRef
    local tile = target.tile
    return { x = tile.x, y = tile.y, z = tile.z, prototype = target.base or target.prototype or "" }
end

-- The live thing a ref names, read from `near`'s map; nil once it is gone.
function multitool_buffer.resolve(ref: unknown, near: TileAddress): Handle?
    if type(ref) ~= "table" then
        return nil
    end
    local stored = ref :: TileRef
    if
        type(stored.x) ~= "number"
        or type(stored.y) ~= "number"
        or type(stored.z) ~= "number"
        or type(stored.prototype) ~= "string"
    then
        return nil
    end
    local ok, at = pcall(sim.map_tile, near, stored.x, stored.y, stored.z)
    if not ok or at == nil then
        return nil
    end
    for _, candidate in ipairs(sim.query.range(at, 0, {})) do
        if candidate.alive and (candidate.base or candidate.prototype) == stored.prototype then
            return candidate
        end
    end
    return nil
end

function multitool_buffer.store(tool: Handle, target: Handle): ()
    tool.vars[multitool_buffer.VAR] = multitool_buffer.ref(target)
end

function multitool_buffer.read(tool: Handle, near: TileAddress): Handle?
    return multitool_buffer.resolve(tool.vars[multitool_buffer.VAR], near)
end

return multitool_buffer
