-- Alt+click turns a faced thing one stop: tg's `simple_rotation` element
-- (code/datums/elements/rotation.dm:26-27), Alt+click counter-clockwise
-- (`rotate_left`, :52-54) and Alt+right-click clockwise (`rotate_right`,
-- :47-49). The engine's `sim.facing.turn` owns the stop and its record.
local turning = {}

local ROTATE = "lunatic/tfs:ui.affordance.rotate"
local NO_OTHER_FACING = "lunatic/tfs:lib.turning.no_other_facing"

-- The two pointer slots a turnable thing declares in `gestures`.
turning.GESTURES = { "alt_primary", "alt_secondary" }

export type RowOptions = { state: string? }
export type AttachOptions = { route: "self" | "interact" }

-- An item's two hint rows; `state` limits both to that appearance state.
function turning.rows(opts: RowOptions?): { { [string]: any } }
    local state = if opts ~= nil then opts.state else nil
    local target = if state ~= nil then { fact = "target.state", value = state } else nil
    local function row(id: string, gesture: string): { [string]: any }
        return { id = id, gesture = gesture, route = "self_use", label = ROTATE, target = target }
    end
    return { row("turn_ccw", "alt_primary"), row("turn_cw", "alt_secondary") }
end

-- A structure's `interaction_labels` for the two slots; structures take
-- receiver rows only, so their hint is the gesture label.
function turning.labels(): { [string]: { label: string } }
    return { alt_primary = { label = ROTATE }, alt_secondary = { label = ROTATE } }
end

-- Turns the pointed thing on either slot and declines every other click.
local function turn(ev: InteractionUsePayload): boolean | { [string]: any }
    local clockwise: boolean
    if ev.gesture == "alt_secondary" then
        clockwise = true
    elseif ev.gesture == "alt_primary" then
        clockwise = false
    else
        return { replaced = false }
    end
    local why = sim.facing.turn({ entity = ev.subject, clockwise = clockwise })
    if why == "no_other_facing" then
        return { refused = NO_OTHER_FACING }
    end
    return true
end

-- Binds `turn`; `route` is `self` for an item and `interact` for a structure.
function turning.attach(definition: Definition, opts: AttachOptions): ()
    definition:handle("interaction.use", { kind = "replace", route = opts.route }, turn)
end

return turning
