-- A grenade going off at the edge of the map loses nothing: the tiles past
-- the edge are simply not there to catch.
t.world(
    [==[(
    name: "grenade edge",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: ["..."],
            structures: [(2, 0, "player_spawn")],
            items: [(1, 0, "frag_grenade")],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()
t.click(p, 1, 0, assert(t.target_at(p, 1, 0, "frag_grenade")))
t.tick()
assert(t.hands(p).held == "frag_grenade", "the grenade is in hand")
t.use_self(p)
t.tick()
t.drop(p)
t.tick()
t.run_seconds(6)
assert(t.item_at(1, 0, "frag_grenade") == nil and t.item_at(2, 0, "frag_grenade") == nil, "the shell is spent")
assert(#t.ledger_rows("item_destroyed") >= 1, "the blast ran to its end")
