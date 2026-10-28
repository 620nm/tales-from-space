-- Hiding in or stuffing a body into an open closet from the next tile: the
-- drag waits four seconds, then the close takes the body off its own tile
-- (`closets.dm:987-1020`; lib/body_drag.luau, lib/closets/closing.luau).
local clock = require("@helpers/clock")

local function map(prototype: string): string
    local source = [==[ (
        name: "adjacent entry",
        legend: {
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#.....#",
                "#######",
            ],
            structures: [
                (2, 2, "player_spawn", { "jobs": "assistant" }),
                (2, 3, "player_spawn", { "jobs": "medic" }),
                (3, 2, "PROTOTYPE"),
            ],
        )],
    )]==]
    local filled = string.gsub(source, "PROTOTYPE", prototype)
    return filled
end

local function on_tile(x: number, y: number, player: number): boolean
    local wanted = t.body_id(player)
    for _, body in ipairs(t.bodies_at(x, y)) do
        if body.id == wanted then
            return true
        end
    end
    return false
end

-- Opens the container, then `actor` drags `subject` onto it; both stand beside it.
local function drag_into(prototype: string, actor: number, subject: number, subject_x: number, subject_y: number): ()
    t.click(actor, 3, 2, (assert(t.target_at(actor, 3, 2, prototype), "the container is observed")))
    t.tick()
    assert(assert(t.structure_at(3, 2)).state == "open", prototype .. " opens")
    t.drag(
        actor,
        subject_x,
        subject_y,
        t.body_target(actor, subject),
        3,
        2,
        (assert(t.target_at(actor, 3, 2, prototype), "the open container is observed"))
    )
    t.tick()
    t.run_ticks(clock.deadline_ticks(4.0) + 3)
end

for _, prototype in ipairs({ "crate", "locker" }) do
    -- Self-hide from the next tile.
    t.world(map(prototype), 0)
    local hider = t.join("assistant")
    t.run_ticks(3)
    assert(on_tile(2, 2, hider), prototype .. ": the hider stands beside the container")
    drag_into(prototype, hider, hider, 2, 2)
    assert(assert(t.structure_at(3, 2)).state == "closed", prototype .. ": the close commits around the hider")
    assert(not on_tile(2, 2, hider), prototype .. ": the hider left its tile")
    assert(not on_tile(3, 2, hider), prototype .. ": the hider is inside, not on the container tile")
    assert(#t.script_errors() == 0, prototype .. ": adjacent self-hide has no script errors")

    -- Stuffing another body from the next tile knocks it down.
    t.world(map(prototype), 0)
    local actor = t.join("assistant")
    local victim = t.join("medic")
    t.run_ticks(3)
    assert(on_tile(2, 2, actor) and on_tile(2, 3, victim), prototype .. ": both stand beside the container")
    drag_into(prototype, actor, victim, 2, 3)
    assert(assert(t.structure_at(3, 2)).state == "closed", prototype .. ": the close commits around the victim")
    assert(not on_tile(2, 3, victim), prototype .. ": the victim left its tile")
    assert(on_tile(2, 2, actor), prototype .. ": the stuffer stays outside")
    assert(assert(t.body(victim)).posture == "lying", prototype .. ": the stuffed body is knocked down")
    assert(#t.script_errors() == 0, prototype .. ": adjacent stuffing has no script errors")
end
print("container adjacent entry: self-hide and stuffing from the next tile")
