-- Why a close is refused (lib/closets/closing.luau, tg `can_close`,
-- `closets.dm:493-505`): a standing body on an open horizontal closet's tile,
-- and another closet on the tile. The player is told which.
local clock = require("@helpers/clock")

local TOO_LARGE_LINE = "There's something too large in the"
local IN_THE_WAY_LINE = "is in the way!"

local RIDER_MAP = [==[ (
    name: "close veto standing body",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "########",
            "#......#",
            "#......#",
            "#......#",
            "#......#",
            "#......#",
            "########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 5, "player_spawn", { "jobs": "medic" }),
            (5, 4, "player_spawn", { "jobs": "engineer" }),
            (4, 4, "crate"),
        ],
    )],
)]==]

local CLOSET_MAP = [==[ (
    name: "close veto other closet",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "########",
            "#......#",
            "#......#",
            "#......#",
            "#......#",
            "#......#",
            "########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 4, "locker"),
            (5, 4, "crate"),
        ],
    )],
)]==]

local function target(player: number, x: number, y: number, id: string): SpecObservedTarget
    return (assert(t.target_at(player, x, y, id), "the observed target exists"))
end

local function click(player: number, x: number, y: number, id: string): ()
    t.click(player, x, y, target(player, x, y, id))
    t.tick()
end

local function heard(player: number, fragment: string): boolean
    for _, message in ipairs(t.messages(player)) do
        if string.find(message, fragment, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function tile_has_body(x: number, y: number, player: number): boolean
    local wanted = t.body_id(player)
    for _, body in ipairs(t.bodies_at(x, y)) do
        if body.id == wanted then
            return true
        end
    end
    return false
end

-- A standing rider on the open crate keeps another body from hiding in it:
-- the hider is exempt as the entrant, the rider is not.
t.world(RIDER_MAP, 0)
local actor = t.join("assistant")
local hider = t.join("medic")
local rider = t.join("engineer")
t.run_ticks(3)
click(actor, 4, 4, "crate")
assert(assert(t.structure_at(4, 4)).state == "open", "the crate opens")
local function climb(climber: number): ()
    t.use_item(climber, target(climber, 4, 4, "crate"), "alt_primary")
    t.tick()
    t.run_ticks(clock.deadline_ticks(1.0) + 1)
    assert(t.seen(climber, climber).offset.y == 14, "the body climbs onto the open crate")
end
climb(hider)
local closes = #t.ledger_rows("container_closed")
-- The rider climbs on during the hider's wait: two stacked bodies leave no
-- crate pixel to aim at.
t.drag(hider, 4, 4, t.body_target(hider, hider), 4, 4, target(hider, 4, 4, "crate"))
t.tick()
climb(rider)
t.run_ticks(clock.deadline_ticks(4.0) + 2)
assert(assert(t.structure_at(4, 4)).state == "open", "a standing rider vetoes the close")
assert(#t.ledger_rows("container_closed") == closes, "the vetoed close writes no close")
assert(tile_has_body(4, 4, hider), "the hider stays on the crate")
assert(heard(hider, TOO_LARGE_LINE), "the veto tells the hider what is in the way")
assert(#t.script_errors() == 0, "the rider veto has no script errors")

-- A crate pulled onto an open locker's tile is another closet in the way.
t.world(CLOSET_MAP, 0)
actor = t.join("assistant")
t.run_ticks(3)
click(actor, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "open", "the locker opens")
t.move(actor, "east")
t.run_seconds(0.25)
t.pull(actor, 5, 4, target(actor, 5, 4, "crate"))
t.tick()
t.move(actor, "west")
t.run_ticks(6)
t.stop_pull(actor)
t.tick()
assert(t.target_at(actor, 4, 4, "crate") ~= nil, "the crate stands on the open locker's tile")
closes = #t.ledger_rows("container_closed")
click(actor, 4, 4, "locker")
assert(#t.ledger_rows("container_closed") == closes, "another closet on the tile vetoes the close")
assert(heard(actor, IN_THE_WAY_LINE), "the veto names the closet in the way")
assert(#t.script_errors() == 0, "the closet veto has no script errors")
print("container close veto: standing body and other closet")
