local iv_flow = require("@lib/medical/iv_flow")
local iv_line = require("@lib/medical/iv_line")
local iv_drag = require("@lib/medical/iv_drag")
local deconstruction = require("@lib/closets/deconstruction")

local content = {
    id = "iv_drip",
}

if sim ~= nil then
    sim.define("sound", "lunatic/tfs:sound/twobeep_high", { asset = "twobeep_high" })
    local definition = sim.define("behavior", "lunatic/tfs:iv_drip", { prototype = content.id })

    sim.define("message", "lunatic/tfs:action.iv_drip.deconstruct_occupied", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.deconstruct_start", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.deconstruct_stopped", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.deconstruct_refused", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.connect_refused", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.disconnect_refused", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.mode_draw", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.mode_inject", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.mode_refused", { placeholders = {} })
    sim.define("message", "lunatic/tfs:action.iv_drip.rate_set", { placeholders = { "rate" } })
    sim.define("message", "lunatic/tfs:action.iv_drip.rate_refused", { placeholders = {} })

    iv_line.attach()

    -- Receipts name the issuer but no endpoint or request. The bag-flow
    -- module owns the per-issuer FIFO across stands for this dispatcher.
    definition:handle("matter.transfer.done", { kind = "react" }, iv_flow.on_transfer_done)

    -- The helper owns stand despawn and metal payout; this caller owns the
    -- wrench chore, empty-dock rule, and safe line disconnect.
    local request_deconstruction = deconstruction.attach(definition, "iv_drip", {
        definition = "metal",
        count = 1,
        units = 1,
    })

    local function send(user: Handle, message: Message): ()
        sim.message.send({ recipient = user, message = message })
    end

    local function safe_tile(entity: Handle): TileAddress?
        if not entity.alive then
            return nil
        end
        local ok, tile = pcall(function()
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

    local function can_reach_stand(actor: Handle, drip: Handle): boolean
        local actor_tile = safe_tile(actor)
        local drip_tile = safe_tile(drip)
        return actor_tile ~= nil
            and drip_tile ~= nil
            and within_one_tile(actor_tile, drip_tile)
            and sim.query.los(actor, drip)
    end

    local function rate_cents(rate: number): number?
        if rate ~= rate or rate < 0 or rate > 5 then
            return nil
        end
        local scaled = rate * 100
        local rounded = math.floor(scaled + 0.5)
        if scaled < rounded - 0.000001 or scaled > rounded + 0.000001 then
            return nil
        end
        return rounded
    end

    local function rate_text(cents: number): string
        local whole = cents // 100
        local fraction = cents % 100
        if fraction == 0 then
            return tostring(whole)
        end
        if fraction % 10 == 0 then
            return tostring(whole) .. "." .. tostring(fraction // 10)
        end
        return tostring(whole) .. "." .. (fraction < 10 and "0" or "") .. tostring(fraction)
    end

    local function set_rate(drip: Handle, actor: Handle, cents: number): ()
        iv_line.set_rate(drip, cents / 100)
        send(
            actor,
            sim.msg("lunatic/tfs:action.iv_drip.rate_set", { rate = rate_text(cents) })
        )
    end

    definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local drip, actor, implement = ev.subject, ev.actor, ev.implement
        if drip == nil or actor == nil or implement == nil then
            return { replaced = false }
        end
        if not implement.alive or implement.prototype ~= "wrench" then
            return { replaced = false }
        end
        if not drip.alive or not actor.alive then
            return true
        end
        if not can_reach_stand(actor, drip) then
            return true
        end
        if drip:docked() ~= nil then
            send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_occupied", {}))
            return true
        end

        send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_start", {}))
        sim.spawn_task(actor, function()
            if sim.do_after(actor, sim.ticks(4), {}) ~= "ok" then
                if actor.alive then
                    send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_stopped", {}))
                end
                return
            end
            if not actor.alive or not implement.alive or implement.prototype ~= "wrench" then
                if actor.alive then
                    send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_refused", {}))
                end
                return
            end
            if not can_reach_stand(actor, drip) then
                if actor.alive then
                    send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_refused", {}))
                end
                return
            end
            if drip:docked() ~= nil then
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_occupied", {}))
                return
            end

            iv_line.disconnect(drip)
            if not request_deconstruction(drip) then
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.deconstruct_refused", {}))
            end
        end)
        return true
    end)

    local function act(ev): boolean | { replaced: boolean }
        local drip, actor, action = ev.subject, ev.actor, ev.action
        if drip == nil or actor == nil or not drip.alive or not actor.alive then
            return true
        end

        if action == "disconnect" then
            if not iv_line.mode_state(drip).connected then
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.disconnect_refused", {}))
            else
                iv_line.disconnect(drip)
            end
            return true
        end

        if action == "toggle_mode" then
            local state = iv_line.mode_state(drip)
            if state.mode == "inject" then
                iv_line.set_mode(drip, "draw")
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.mode_draw", {}))
            elseif state.mode == "draw" then
                iv_line.set_mode(drip, "inject")
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.mode_inject", {}))
            else
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.mode_refused", {}))
            end
            return true
        end

        if action == "flow_up" or action == "flow_down" then
            local current = rate_cents(iv_line.mode_state(drip).rate)
            if current == nil then
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.rate_refused", {}))
                return true
            end
            local next_rate = current + (action == "flow_up" and 1 or -1)
            if next_rate < 0 then
                next_rate = 0
            elseif next_rate > 500 then
                next_rate = 500
            end
            set_rate(drip, actor, next_rate)
            return true
        end

        if action == "flow_max" then
            set_rate(drip, actor, 500)
            return true
        end

        if action == "flow_off" then
            set_rate(drip, actor, 0)
            return true
        end

        if action == "rate" then
            local value = ev.value
            local entered = if type(value) == "string" then tonumber(value) else nil
            local cents = if entered == nil then nil else rate_cents(entered)
            if cents == nil then
                send(actor, sim.msg("lunatic/tfs:action.iv_drip.rate_refused", {}))
            else
                set_rate(drip, actor, cents)
            end
            return true
        end

        return { replaced = false }
    end

    definition:handle("interaction.act", { kind = "replace", route = "act" }, act)
    definition:handle("interaction.drag", { kind = "replace", route = "drag" }, iv_drag.on_drag)
end

return content
