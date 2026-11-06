-- What a multitool remembers between two clicks: the machine it last
-- logged (tg's `multitool.buffer`, code/game/objects/items/devices/
-- multitool.dm:37, `set_buffer` at :131). The buffer is an entity ref
-- (`handle:ref()`), weak like tg's weakref: it names that one thing, so a
-- thing gone, or rebuilt in its place, resolves to nothing.
local multitool_buffer = {}

-- The item's script var (declared, replicate = "server", by
-- items/tools/multitool.luau): a ref is refused by any other replication.
multitool_buffer.VAR = "lunatic/tfs:multitool_buffer"

-- The live thing a stored ref names; nil for an empty ref or a thing gone.
function multitool_buffer.resolve(ref: unknown): Handle?
    if ref == nil then
        return nil
    end
    return sim.resolve(ref :: EntityRef)
end

function multitool_buffer.store(tool: Handle, target: Handle): ()
    tool.vars[multitool_buffer.VAR] = target:ref()
end

function multitool_buffer.read(tool: Handle): Handle?
    return multitool_buffer.resolve(tool.vars[multitool_buffer.VAR])
end

return multitool_buffer
