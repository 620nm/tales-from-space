-- What a client was told to draw on a tile, read through `t.seen_matter`
-- (the engine's docs/looks/matter.md section 7).
local matter_look = {}

-- The part of one look and rung at a tile, nil when that rung is not drawn.
function matter_look.find(player: number, x: number, y: number, look: string, rung: number): SpecSeenMatterPart?
    for _, part in ipairs(t.seen_matter(player, x, y)) do
        if part.look == look and part.rung == rung then
            return part
        end
    end
    return nil
end

-- The highest rung of one look drawn at a tile, 0 when the look draws nothing there.
function matter_look.top_rung(player: number, x: number, y: number, look: string): number
    local top = 0
    for _, part in ipairs(t.seen_matter(player, x, y)) do
        if part.look == look and part.rung > top then
            top = part.rung
        end
    end
    return top
end

-- A shell part's joins and quadrants, asserted present.
function matter_look.edges(part: SpecSeenMatterPart): (SpecSeenMatterJoins, SpecSeenMatterQuadrants)
    local joins = assert(part.joins, part.look .. " rung " .. part.rung .. " is a picture, not a shell")
    local quadrants = assert(part.quadrants, part.look .. " rung " .. part.rung .. " has no quadrants")
    return joins, quadrants
end

return matter_look
