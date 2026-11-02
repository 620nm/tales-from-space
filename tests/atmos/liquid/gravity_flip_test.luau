local bench = require("@helpers/liquid_bench")
local matter_look = require("@helpers/matter_look")
local ui_controls = require("@helpers/ui_controls")

-- The same ten litres under a weightless sky: beads while the gravity
-- battery is down, a puddle that spreads while it runs. The books and the
-- client's picture read the one state.
local SMES = { x = 2, y = 2 }
local POOL = { x = 6, y = 2 }

local p = bench.world({
    environment = bench.ZERO_G,
    rows = { "#########", "#.......#", "#.......#", "#.......#", "#.......#", "#########" },
    structures = `(4, 2, "player_spawn", \{"jobs": "engineer"}), ({SMES.x}, {SMES.y}, "grav_smes", "standby")`,
    job = "engineer",
    pools = { { x = POOL.x, y = POOL.y, litres = 10 } },
})
t.set_store_charge(SMES.x, SMES.y, 1.0)

local function press(action: string)
    t.click(p, SMES.x + 1, SMES.y, t.target_at(p, SMES.x + 1, SMES.y, "grav_smes"))
    t.tick()
    ui_controls.toggle(p, "action", action)
    t.run_seconds(1.5)
    t.ui_close(p)
end

local function drawn(): SpecSeenMatterPart
    return assert(matter_look.parts(p, POOL.x, POOL.y, "puddle")[1], "the water is drawn")
end

t.run_seconds(5)
assert(bench.standing(POOL.x, POOL.y) > 9.9, "beads stay on their tile")
assert(drawn().weightless, "and are drawn as beads")

press("start")
t.run_seconds(10)
local settled = bench.standing(POOL.x, POOL.y)
assert(settled < 9.5, ("with weight on, the water spreads: %.2f L stays"):format(settled))
assert(bench.standing(POOL.x + 1, POOL.y) > 0, "onto the next tile")
assert(not drawn().weightless, "and is drawn as a puddle")

press("stop")
assert(drawn().weightless, "the field gone, what stands there floats again")
