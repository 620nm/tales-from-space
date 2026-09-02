-- Dragging a canister down the hall.
--
-- Ctrl+click takes hold of a loose thing and it follows you (tg's
-- `start_pulling`). The station's own example is the gas bottle: it is
-- fastened to a socket at roundstart and bolted things do not drag, so
-- moving one is two decisions -- unfasten it, then take hold -- which
-- is exactly what plumbing a spare supply into a breached room costs.
t.world([==[(
    name: "haulage",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating),
    },
    rows: [
        "######",
        "#...c#",
        "######",
    ],
    spawns: [(3, 1)],
    items: [(3, 1, "wrench")],
    pipes: [(3, 1, 4)],
    // Without the socket the bottle is furniture; with it, the bottle
    // starts fastened, which is the state that refuses a grab.
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (4, 1, "connector_port"),
        (4, 1, "canister", { "blend": "canister_air", "open": true }),
    ],
)]==], 7)

local p = t.join()
t.tick()

local canister = t.target_at(4, 1, "canister")
assert(canister ~= nil, "the streamed canister is targetable")
assert(t.structure_at(4, 1).state == "anchored", "it starts on the socket")

-- Fastened is bolted, and bolted refuses. tg drops a pull the moment
-- `pulling.anchored` is true and never starts one on an anchored atom
-- (atoms_movable.dm:1739).
t.pull(p, 4, 1, canister)
t.tick()
assert(#t.ledger_rows("PullStarted") == 0, "a fastened bottle refuses the grab")

-- Unfasten it: one ratchet, no do_after, exactly as tg's portable
-- atmos `wrench_act`.
t.click(p, 3, 1, t.target_at(3, 1, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "the wrench is in hand")
t.click(p, 4, 1, canister)
t.run_ticks(2)
assert(t.structure_at(4, 1).state == "displaced", "it came off the socket")

-- Now it drags. The follow step puts it on the tile the player just
-- left, which is what makes a drag a drag rather than a teleport.
t.pull(p, 4, 1, canister)
t.tick()
assert(#t.ledger_rows("PullStarted") == 1, "the grab is on the record")

t.move(p, "west")
t.run_ticks(6)
local x, y = t.pos(p)
assert(x == 2 and y == 1, "the player walked west")
assert(t.target_at(3, 1, "canister") == canister, "the bottle followed into the vacated tile")
assert(t.target_at(4, 1, "canister") == nil, "and is off the socket tile")

-- Letting go has its own key. Ctrl+clicking the bottle again does the
-- same thing: the grab click is a toggle here, where tg's is a no-op
-- (living.dm:408-410).
t.stop_pull(p)
t.tick()
assert(#t.ledger_rows("PullEnded") == 1, "and putting it down is on the record too")

t.move(p, "west")
t.run_ticks(6)
x, y = t.pos(p)
assert(x == 1 and y == 1, "the player walks on")
assert(t.target_at(3, 1, "canister") == canister, "the bottle stays where it was let go")
