-- An empty hand at a crewman pokes them.
--
-- The engine's poke answers a swing nothing claimed only for a pack that
-- declares it (`interactions.poke`, content/capabilities.luau): this one
-- does, standing in for tg's help-intent touch on another mob
-- (code/_onclick/click.dm, the unarmed branch). The sentence and its
-- `poked` row are the whole contract.

local ARENA = [==[(
    name: "corridor",
    legend: { ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    rows: [ "#####", "#...#", "#####" ],
    structures: [
        (1, 1, "player_spawn", { "jobs": "assistant" }),
        (2, 1, "player_spawn", { "jobs": "engineer" }),
    ],
)]==]

local function said(who: number, needle: string)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end

t.world(ARENA, 0)
local poker = t.join("assistant")
local crewman = t.join("engineer")
t.run_ticks(3)
while t.hands(poker).held ~= nil do
    t.drop(poker)
    t.tick()
end
t.messages(poker)
local before = #t.ledger_rows("poked")

t.click(poker, 2, 1, t.body_target(poker, crewman))
t.run_ticks(2)
assert(said(poker, "You poke"), "the empty hand pokes the crewman it named")
assert(#t.ledger_rows("poked") == before + 1, "and the poke is on the record")
