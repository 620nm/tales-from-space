-- The wrench's bolt-down and bolt-up transitions for a structure that sits
-- `displaced` (loose) or `anchored` (fastened).
export type Words = { start: string?, done: string }
export type Spec = {
    sound: string,
    secs: number?,
    over: string?,
    anchor: Words?,
    unanchor: Words,
}

local anchorable = {}

-- Loose to fastened; `over` names the tile feature it must sit on.
function anchorable.anchor(spec: Spec): { [string]: any }
    local anchor = assert(spec.anchor, "anchorable.anchor wants anchor words")
    return {
        sound = spec.sound,
        at = "displaced",
        tool = "wrench",
        hint = { id = "anchor", label = "lunatic/tfs:ui.affordance.anchor" },
        over = spec.over,
        secs = spec.secs,
        to = "anchored",
        start = anchor.start,
        done = anchor.done,
    }
end

-- Fastened to loose, or (`leaves`) to the structure it unfolds into.
function anchorable.unanchor(spec: Spec, leaves: string?): { [string]: any }
    return {
        sound = spec.sound,
        at = "anchored",
        tool = "wrench",
        hint = { id = "unanchor", label = "lunatic/tfs:ui.affordance.unanchor" },
        secs = spec.secs,
        to = if leaves == nil then "displaced" else nil,
        gone = if leaves ~= nil then true else nil,
        leaves = leaves,
        start = spec.unanchor.start,
        done = spec.unanchor.done,
    }
end

-- Both rows, anchor first.
function anchorable.pair(spec: Spec): ({ [string]: any }, { [string]: any })
    return anchorable.anchor(spec), anchorable.unanchor(spec)
end

return anchorable
