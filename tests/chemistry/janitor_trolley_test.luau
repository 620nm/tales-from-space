local composition = require("@helpers/composition")

-- The bucket, the mop bucket and the cart (docs/janitorial/trolley.md): a mop
-- wrung into a tub, a tub too heavy to lift, a rack that stows and shows, a
-- crowbar that dumps it, and overflow onto the deck.
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
                "#######",
                "#.....#",
                "#######",
            ],
            painted: [(4, 1, "flood")],
            structures: [(3, 1, "player_spawn")],
            items: [
                (3, 1, "mop"),
                (3, 1, "crowbar"),
                (2, 1, "janitor_trolley"),
            ],
        ),
    ],
    blends: {
        "flood": (rows: [("water", 166.53), ("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15, amount: total),
    },
)]==],
    0
)

local p = t.join()
t.tick()
local mop = assert(t.target_at(p, 3, 1, "mop"))
local crowbar = assert(t.target_at(p, 3, 1, "crowbar"))
local cart = assert(t.target_at(p, 2, 1, "janitor_trolley"))

local function said(): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

local function tub(): number
    return (assert(t.contents(cart)).water or 0)
end

-- A bare hand does not lift it, and says so.
t.click(p, 2, 1, cart)
t.tick()
assert(said() == "Too heavy to lift; pull it instead", "the cart refuses a lift")

-- A mop wrung into the tub empties, and the tub wears the water.
t.click(p, 3, 1, mop)
t.tick()
composition.click_deck(p, 4, 1)
t.tick()
t.run_seconds(1.6)
t.use_item(p, cart, "secondary")
t.tick()
assert(said() == "You pour into the cart.", "the wring is reported")
assert((assert(t.contents(mop)).water or 0) < 1e-6, "the head is empty")
assert(tub() > 13, ("the tub holds it, got %g"):format(tub()))
assert(assert(t.item_at(2, 1, "janitor_trolley")).sprite == "janitor_trolley", "the base picture stays")

-- The rack takes the mop, out of the hand and off the deck.
t.click(p, 2, 1, cart)
t.tick()
assert(t.target_at(p, 3, 1, "mop") == nil, "the mop is not on the deck")
t.click(p, 3, 1, crowbar)
t.tick()

-- A crowbar dumps the tub onto the cart's own tile, after tg's five seconds.
t.use_item(p, cart, "secondary")
t.tick()
assert(said() == "You begin to dump the cart...", "the dump starts")
t.run_seconds(5.1)
assert(said() == "You dump the cart onto the deck.", "the dump lands")
assert(tub() < 1e-6, "the tub is empty")
assert((assert(t.room_liquid(2, 1)).water or 0) > 0.2, "and the deck under it is wet")

-- Dry, it says so at once.
t.use_item(p, cart, "secondary")
t.tick()
assert(said() == "The cart is empty.", "an empty tub refuses")
