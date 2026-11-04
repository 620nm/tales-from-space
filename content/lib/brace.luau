-- What a weightless body may push off, decided by the pack. Both modes bind
-- this mode-scoped transform with `brace.install`; the engine holds no brace
-- rule of its own and asks at most once per body, tile and step cadence.
local ignition = require("@lib/ignition")

local brace = {}

type Step = { word: string, dx: number, dy: number }

local STEPS: { Step } = {
    { word = "north", dx = 0, dy = -1 },
    { word = "south", dx = 0, dy = 1 },
    { word = "east", dx = 1, dy = 0 },
    { word = "west", dx = -1, dy = 0 },
    { word = "northeast", dx = 1, dy = -1 },
    { word = "northwest", dx = -1, dy = -1 },
    { word = "southeast", dx = 1, dy = 1 },
    { word = "southwest", dx = -1, dy = 1 },
}

-- Who grips at all: a conscious body. A corpse, a crit or a sleeper coasts
-- until it hits something. tg asks no hand either (`get_spacemove_backup`,
-- code/modules/mob/mob_movement.dm:306).
local function grips(actor: Handle): boolean
    local body = sim.body.read(actor)
    return body ~= nil and body.conscious == true
end

-- A dense thing `actor` can push off: anchored, and not itself. A loose thing
-- is a reaction mass, which the engine's push-off answers, never a brace.
local function anchors(actor: Handle, solid: TileSolidity): boolean
    for _, thing in solid.dense do
        if thing ~= actor and thing.anchored == true then
            return true
        end
    end
    return false
end

-- Open the directions `solid`, at (`dx`, `dy`) from the tile judged, gives
-- `actor`. A wall or handhold gives all of them; an anchored thing all but the
-- step into it: tg "Can't push off of something that you're walking into"
-- (code/modules/mob/mob_movement.dm:346-348).
local function open_from(actor: Handle, solid: TileSolidity, dx: number, dy: number, open: { [string]: boolean }): ()
    local whole = solid.blocking or solid.handhold
    if not (whole or anchors(actor, solid)) then
        return
    end
    for _, step in STEPS do
        if whole or step.dx ~= dx or step.dy ~= dy then
            open[step.word] = true
        end
    end
end

-- The tile and its eight neighbours, on the tile's own level (tg `range(1,
-- get_turf(src))` is one z, code/modules/mob/mob_movement.dm:309).
function brace.toward(ev: MoveBracePayload): { toward: { string } }
    if not grips(ev.actor) then
        return { toward = {} }
    end
    local open: { [string]: boolean } = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local tile = ignition.tile_beside(ev.at, dx, dy)
            local solid = if tile ~= nil then sim.solid_at(tile) else nil
            if solid ~= nil then
                open_from(ev.actor, solid, dx, dy, open)
            end
        end
    end
    local toward: { string } = {}
    for word in open do
        table.insert(toward, word)
    end
    return { toward = toward }
end

function brace.install(behavior: Definition): ()
    behavior:handle("move.brace", { kind = "transform", route = "lifecycle" }, brace.toward)
end

return brace
