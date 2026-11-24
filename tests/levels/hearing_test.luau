-- A loud sound carries through solid floors: the roster's `explosion`
-- carries two levels (`carry_levels = 2`, content/sounds.luau), so a frag
-- grenade going off on level zero is heard one and two decks up and not on
-- the third, with no opening anywhere in the stack. The grenade bursts in
-- the hand that primed it (tests/weapons/frag_test.luau).
local FUSE_SECONDS = 5

t.set_breathing(false)
t.world(
    [==[(
    name: "hearing stack",
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn", { "jobs": "engineer" })],
            items: [(1, 1, "frag_grenade")],
        ),
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(3, 1, "player_spawn", { "jobs": "medic" })],
        ),
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(3, 1, "player_spawn", { "jobs": "security" })],
        ),
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(3, 1, "player_spawn", { "jobs": "assistant" })],
        ),
    ],
)]==],
    0,
    "free_build"
)

local function heard(player: number, sound: string): boolean
    return table.find(t.sounds(player), sound) ~= nil
end

local armer = t.join("engineer")
local one_up = t.join("medic")
local two_up = t.join("security")
local three_up = t.join("assistant")
t.run_ticks(4)

local grenade = assert(t.target_at(armer, 1, 1, "frag_grenade"), "the grenade is disclosed")
t.click(armer, 1, 1, grenade)
t.tick()
assert(t.hands(armer).held == "frag_grenade", "the grenade is in hand")
for _, player in ipairs({ one_up, two_up, three_up }) do
    t.sounds(player)
end
t.use_self(armer)
t.tick()
t.run_seconds(FUSE_SECONDS + 1)

assert(heard(armer, "explosion"), "its own level hears the blast")
assert(heard(one_up, "explosion"), "one deck up hears it through the floor")
assert(heard(two_up, "explosion"), "two decks up still hears it")
assert(not heard(three_up, "explosion"), "three decks up is past its carry")
assert(#t.script_errors() == 0, "the blast's handlers run cleanly")
