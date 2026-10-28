local content = { id = "utility_outlet_port" }

if sim ~= nil then
    local definition = sim.define("behavior", "lunatic/tfs:utility_outlet_port", { prototype = content.id })

    local function safe_tile(entity: Handle): TileAddress?
        if not entity.alive then
            return nil
        end
        local ok, tile = pcall(function(): TileAddress
            return entity.tile
        end)
        if not ok or tile == nil then
            return nil
        end
        return tile
    end

    local function within_one_tile(first: TileAddress, second: TileAddress): boolean
        if first.instance ~= second.instance or first.z ~= second.z then
            return false
        end
        local dx = first.x - second.x
        local dy = first.y - second.y
        return dx >= -1 and dx <= 1 and dy >= -1 and dy <= 1
    end

    local function can_reach(actor: Handle, port: Handle): boolean
        local actor_tile = safe_tile(actor)
        local port_tile = safe_tile(port)
        return actor_tile ~= nil
            and port_tile ~= nil
            and within_one_tile(actor_tile, port_tile)
            and sim.query.los(actor, port)
    end

    definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local port, actor = ev.subject, ev.actor
        if ev.implement ~= nil or ev.gesture ~= "primary" then
            return { replaced = false }
        end
        if port == nil or actor == nil or not port.alive or not actor.alive then
            return true
        end
        if not can_reach(actor, port) then
            return true
        end

        sim.appearance.set_state({
            entity = port,
            state = if port.state == "open" then "closed" else "open",
        })
        return true
    end)
end

return content
