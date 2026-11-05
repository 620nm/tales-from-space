-- What a multitool remembers between two clicks: the machine it last
-- logged (tg's `multitool.buffer`, code/game/objects/items/devices/
-- multitool.dm:37, `set_buffer` at :131). A handle does not outlive a
-- handler, so a ref is the logged thing's tile, slot-local and absolute,
-- its prototype and an identity stamped on it at its first logging; a read
-- finds the thing on that tile of the reader's map that carries the same
-- identity, so a thing rebuilt in place or a tile on another map is not it.
export type TileRef = {
    x: number,
    y: number,
    z: number,
    absolute_x: number,
    absolute_y: number,
    prototype: string,
    identity: number,
}

local multitool_buffer = {}

-- The item's script var, the logged thing's identity var and the counter
-- that mints identities (all declared by items/tools/multitool.luau).
multitool_buffer.VAR = "lunatic/tfs:multitool_buffer"
multitool_buffer.IDENTITY = "lunatic/tfs:buffer_identity"
multitool_buffer.SERIAL = "lunatic/tfs:buffer_serial"
-- A mod-scope key is read and written by its short name (lib/controller.luau).
local SERIAL_KEY = "buffer_serial"

-- The thing's identity, minted from the mod-scope counter on first use.
local function identity_of(target: Handle): number
    local stamped = target.vars[multitool_buffer.IDENTITY]
    if type(stamped) == "number" then
        return stamped
    end
    local serial = ((sim.var("mod", SERIAL_KEY) :: number?) or 0) + 1
    sim.script_var.set({ scope = "mod", key = SERIAL_KEY, value = serial })
    target.vars[multitool_buffer.IDENTITY] = serial
    return serial
end

function multitool_buffer.ref(target: Handle): TileRef
    local prototype = target.base or target.prototype
    if prototype == nil then
        error("multitool_buffer.ref: a thing with no prototype cannot be logged")
    end
    local tile = target.tile
    return {
        x = tile.x,
        y = tile.y,
        z = tile.z,
        absolute_x = tile.absolute_x,
        absolute_y = tile.absolute_y,
        prototype = prototype,
        identity = identity_of(target),
    }
end

-- Only `ref` writes a ref, so anything but nil or a whole ref is a fault.
local function checked(value: unknown): TileRef?
    if value == nil then
        return nil
    end
    local stored = value :: TileRef
    if
        type(value) ~= "table"
        or type(stored.x) ~= "number"
        or type(stored.y) ~= "number"
        or type(stored.z) ~= "number"
        or type(stored.absolute_x) ~= "number"
        or type(stored.absolute_y) ~= "number"
        or type(stored.prototype) ~= "string"
        or type(stored.identity) ~= "number"
    then
        error("multitool_buffer: a stored ref is malformed")
    end
    return stored
end

-- The live thing a ref names on `near`'s map; nil for an empty ref, a tile
-- this map does not hold (`sim.map_tile` refuses one outside its slot), a
-- tile in another slot, or a thing gone or rebuilt since.
function multitool_buffer.resolve(ref: unknown, near: TileAddress): Handle?
    local stored = checked(ref)
    if stored == nil then
        return nil
    end
    local ok, at = pcall(sim.map_tile, near, stored.x, stored.y, stored.z)
    if not ok or at == nil then
        return nil
    end
    if at.absolute_x ~= stored.absolute_x or at.absolute_y ~= stored.absolute_y then
        return nil
    end
    for _, candidate in ipairs(sim.query.range(at, 0, {})) do
        if
            candidate.alive
            and (candidate.base or candidate.prototype) == stored.prototype
            and candidate.vars[multitool_buffer.IDENTITY] == stored.identity
        then
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
