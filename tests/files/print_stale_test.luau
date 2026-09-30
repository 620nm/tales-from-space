-- A machine's busy var holds the sim second its job is due to end. The host
-- kills a task without cleanup (fuel, watchdog, quarantine) and no spec seam
-- can do that, so this pins the rule that frees such a machine: a var a
-- grace past its deadline is stale and the queue treats the machine as idle.
t.world([==[(name: "empty", legend: {'.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]))}, rows: ["..."])]==], 0)

local printing = t.content_module("printing")
local live = printing.live :: (unknown, number) -> boolean
local grace = printing.stale_grace_seconds :: number

assert(grace > 0 and grace <= 2, "the grace is small: " .. tostring(grace))
assert(not live(nil, 5), "no var, no job")
assert(not live("busy", 5), "only a deadline counts")
assert(live(10, 4), "a job before its deadline is live")
assert(live(10, 10), "a job at its deadline is live")
assert(live(10, 10 + grace), "the job is still live at the end of its grace")
assert(not live(10, 10 + grace + 0.05), "a var one tick past the grace is stale")
assert(not live(10, 600), "a long-dead job stays stale")
