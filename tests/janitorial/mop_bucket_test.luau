local composition = require("@helpers/composition")

-- The bucket and the mop bucket (docs/janitorial/): a mop wrung into a bucket
-- that pours on, a tub that refuses what cannot pour, overflow, a pull, and a
-- crowbar dump that a walk away interrupts.
t.world(
    [==[(
    name: "closet",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#########",
            ],
            painted: [(5, 1, "flood")],
            structures: [(4, 1, "player_spawn")],
            items: [
                (4, 1, "mop"),
                (4, 1, "crowbar"),
                (3, 1, "mop_bucket"),
                (3, 1, "bucket"),
                (5, 1, "beaker"),
                (5, 1, "water_bottle"),
            ],
        ),
    ],
    blends: {
        "flood": (rows: [("water", 277.5), ("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15, amount: total),
    },
)]==],
    0
)

local p = t.join()
t.tick()
local bucket = assert(t.target_at(p, 3, 1, "bucket"))
local bottle = assert(t.target_at(p, 5, 1, "water_bottle"))
local tub = assert(t.target_at(p, 3, 1, "mop_bucket"))

local function said(): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

local function water(handle): number
    return assert(t.contents(handle)).water or 0
end

local function lift(x: number, handle)
    t.click(p, x, 1, handle)
    t.tick()
end

local function put_down()
    t.drop(p)
    t.tick()
end

local function soak_head()
    composition.click_deck(p, 5, 1)
    t.tick()
    t.run_seconds(1.6)
end

-- What cannot pour is refused with a line.
lift(5, bottle)
t.use_item(p, tub, "secondary")
t.tick()
assert(said() == "Open the vessel before pouring.", "a sealed source refuses")
assert(water(tub) == 0, "and pours nothing")
put_down()

lift(5, assert(t.target_at(p, 5, 1, "beaker")))
t.use_item(p, tub, "secondary")
t.tick()
assert(said() == "There is nothing in your hand to pour.", "an empty source refuses")
put_down()

-- The bucket takes a wrung head and pours on, 740 units at a time.
lift(4, assert(t.target_at(p, 4, 1, "mop")))
soak_head()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "bucket")))
t.tick()
local wrung = water(bucket)
assert(wrung > 13, ("the bucket holds the head: %g"):format(wrung))
put_down()
lift(3, assert(t.target_at(p, 3, 1, "bucket")))
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "beaker")))
t.tick()
assert(water(assert(t.target_at(p, 4, 1, "beaker"))) > 0, "the bucket pours")
assert(water(bucket) < wrung, "and is lighter for it")
put_down()

-- A tub takes heads until the rest runs over its side, and says so.
tub = assert(t.target_at(p, 3, 1, "mop_bucket"))
lift(4, assert(t.target_at(p, 4, 1, "mop")))
local last = ""
for _ = 1, 7 do
    soak_head()
    t.use_item(p, tub, "secondary")
    t.tick()
    t.tick()
    last = said()
end
assert(last == "You pour into the mop bucket, and the rest runs over the side.", "overflow is told: " .. last)
assert(assert(t.vessel(tub)).headspace_l < 0.01, "and the tub is brimming")
put_down()

-- A walk away stops a dump.
lift(4, assert(t.target_at(p, 4, 1, "crowbar")))
local full = water(tub)
t.use_item(p, tub, "secondary")
t.tick()
assert(said() == "You begin to dump the mop bucket...", "the dump starts")
t.move(p, "east")
t.run_seconds(5.1)
assert(water(tub) >= full - 1, "nothing came out")
t.move(p, "west")
t.run_seconds(0.5)

-- It rolls on a pull, with its water.
t.pull(p, 3, 1, tub)
t.tick()
t.move(p, "east")
t.run_seconds(0.5)
tub = assert(t.target_at(p, 4, 1, "mop_bucket"), "the tub follows")
assert(water(tub) >= full - 1, "wet")

-- A crowbar empties it where it stands.
t.messages(p)
t.use_item(p, tub, "secondary")
t.tick()
t.run_seconds(5.1)
assert(said() == "You dump the mop bucket onto the deck.", "the dump lands")
assert(water(tub) < 0.05, "the tub is empty")
