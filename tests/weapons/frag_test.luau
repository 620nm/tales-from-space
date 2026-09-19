local ui_controls = require("@helpers/ui_controls")

-- The frag grenade: primed in the hand, five seconds, and then the blast
-- where it IS -- dropped, thrown or still held. Four grenades, one room,
-- each proving a different half: the first goes off in the hand that
-- primed it, the second on the deck under its armer, the third where a
-- throw put it, and the fourth past corner walls that cannot stop it.
--
-- Burn is the witness everywhere below. The direct blast is the only
-- thing on the station that deals it -- the volley flies impact, bleed
-- and organ rolls -- so a burn pool names its band no matter how the
-- fragments fell. The ring names it exactly, its 25 fitting every part;
-- the center names it exactly where the seam routes wide and as a floor
-- where a limb caps its 60 at 50. Brute is a floor throughout: the
-- blast's share plus the volley's.
t.world(
    [==[(
    name: "grenade range",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "###########",
        "#.........#",
        "#........##",
        "#.......#.#",
        "#.........#",
        "#.........#",
        "#.........#",
        "###########",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [
        (1, 1, "frag_grenade"),
        (4, 2, "frag_grenade"),
        (3, 3, "frag_grenade"),
        (8, 2, "frag_grenade"),
    ],
)]==],
    0
)

local p0 = t.join()
local p1 = t.join()
local v1 = t.join()
local v2 = t.join()
local vl = t.join()
local p2 = t.join()
local v3 = t.join()
t.tick()

local function walk(p: number, moves: { string }): ()
    for _, dir in ipairs(moves) do
        if dir == "north" then
            t.move(p, "north")
        elseif dir == "south" then
            t.move(p, "south")
        elseif dir == "east" then
            t.move(p, "east")
        else
            t.move(p, "west")
        end
        t.run_ticks(6)
    end
end

local function burn(p: number): number
    return ui_controls.number(t.health(p).burn)
end

local function brute(p: number): number
    return ui_controls.number(t.health(p).brute)
end

local function has(list: { string }, want: string): boolean
    for _, got in ipairs(list) do
        if got == want then
            return true
        end
    end
    return false
end

local function said(p: number): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

local function destroyed(): number
    return #t.ledger_rows("item_destroyed")
end

local function at(x: number, y: number): boolean
    return t.item_at(x, y, "frag_grenade") ~= nil
end

-- ---------------------------------------------------------------
-- HELD: primed and never let go. A grenade in a hand carries no tile
-- of its own, so this is the nested-position edge: it bursts where
-- its armer stands.
-- ---------------------------------------------------------------
t.click(p0, 1, 1, t.target_at(p0, 1, 1, "frag_grenade"))
t.tick()
assert(t.hands(p0).held == "frag_grenade", "the grenade is in hand")
assert(has(t.sounds(p0), "grenade_pickup"), "picked up on its own noise")

walk(p0, { "south", "south", "south", "south" })
local hx, hy = t.pos(p0)
assert(hx == 1 and hy == 5, "the holder stages alone")

t.use_self(p0)
t.tick()
assert(
    said(p0) == "You prime the frag grenade! Five seconds!",
    "priming is reported: " .. said(p0)
)
assert(has(t.sounds(p0), "grenade_arm"), "and clicked")

t.run_seconds(6)
assert(destroyed() == 1, "one fuse, one detonation")
assert(has(t.sounds(p0), "explosion"), "the room hears the blast")
assert(math.abs(burn(p0) - 20) < 0.01, ("the holder takes the center: %g burn"):format(burn(p0)))
assert(brute(p0) >= 40, ("and the center's brute: %g"):format(brute(p0)))
assert(burn(v1) == 0, "four tiles off, the spawn stack feels nothing")

-- ---------------------------------------------------------------
-- STATIONS: everyone walks out before the next three go off.
-- ---------------------------------------------------------------
walk(vl, { "east", "east", "east", "east", "south", "south", "south", "south", "south" })
walk(v1, { "east", "east", "east", "east", "south" })
walk(p1, { "east", "east", "east", "south" })
walk(p2, { "east", "east", "east", "east", "east", "east", "east", "south" })
walk(v2, {
    "east",
    "east",
    "east",
    "east",
    "east",
    "east",
    "south",
    "south",
    "south",
    "south",
    "south",
    "east",
})
walk(v3, {
    "east",
    "east",
    "east",
    "east",
    "east",
    "east",
    "south",
    "south",
    "south",
    "east",
    "east",
    "north",
})
local function placed(p: number, x: number, y: number, who: string): ()
    local px, py = t.pos(p)
    assert(px == x and py == y, ("%s stands at (%d, %d), got (%d, %d)"):format(who, x, y, px, py))
end
placed(vl, 5, 6, "the landing witness")
placed(v1, 5, 2, "the ring witness")
placed(p1, 4, 2, "the armer")
placed(p2, 8, 2, "the second armer")
placed(v2, 8, 6, "the far witness")
placed(v3, 9, 3, "the diagonal witness")

-- ---------------------------------------------------------------
-- DECK: armed, refused twice, dropped, and the fuse watched.
-- ---------------------------------------------------------------
t.click(p1, 4, 2, t.target_at(p1, 4, 2, "frag_grenade"))
t.tick()
t.use_self(p1)
t.tick()
assert(
    said(p1) == "You prime the frag grenade! Five seconds!",
    "the second priming is reported too"
)
t.use_self(p1)
t.tick()
assert(
    said(p1) == "The frag grenade is already primed.",
    "a second pin-pull is refused: " .. said(p1)
)
t.drop(p1)
t.tick()
assert(has(t.sounds(p1), "grenade_drop"), "dropped on its own noise")
assert(
    (assert(t.item_at(4, 2, "frag_grenade"))).state == "armed",
    "lying armed where it was dropped"
)

t.run_seconds(2)
assert(at(4, 2), "two seconds in, the fuse is still burning")
t.run_seconds(2)
assert(at(4, 2), "and at four seconds it still is")
t.run_seconds(2)
assert(destroyed() == 2, "past five, it went off -- once")
assert(has(t.sounds(p1), "explosion"), "the armer hears it")

-- The bands: the center takes 40 and 20, the ring 15 and 10, and
-- everyone past arm's length takes no burn at all.
assert(math.abs(burn(p1) - 20) < 0.01, ("center burn: %g"):format(burn(p1)))
assert(brute(p1) >= 40, ("center brute floor: %g"):format(brute(p1)))
assert(math.abs(burn(v1) - 10) < 0.01, ("ring burn: %g"):format(burn(v1)))
assert(brute(v1) >= 15, ("ring brute floor: %g"):format(brute(v1)))
assert(burn(v2) == 0, "past the blast, no burn")
assert(burn(vl) == 0, "four tiles off, no burn")
assert(burn(p2) == 0, "four tiles off, no burn")
assert(burn(v3) == 0, "five tiles off, no burn")
assert(math.abs(burn(p0) - 20) < 0.01, "and the first blast's victim is untouched")

-- Every blast throws one volley and the tick settles it: intent here,
-- aggregate there.
assert(#t.ledger_rows("volley_discharged") == 2, "two blasts, two volleys")
assert(#t.ledger_rows("volley_settled") == 2, "both settled")

-- ---------------------------------------------------------------
-- THROWN: primed, then thrown. The fuse outlives the flight and the
-- blast goes off where the grenade came to rest, not where it left.
-- ---------------------------------------------------------------
t.click(p1, 3, 3, t.target_at(p1, 3, 3, "frag_grenade"))
t.tick()
assert(t.hands(p1).held == "frag_grenade", "the second grenade is in hand")
t.use_self(p1)
t.tick()
t.throw(p1, 5, 5)
t.tick()
assert(t.hands(p1).held == nil, "it left the hand primed")
t.run_ticks(10)
assert(at(5, 5), "and came to rest on the landing tile")
assert(
    (assert(t.item_at(5, 5, "frag_grenade"))).state == "armed",
    "still armed after the flight"
)
assert(has(t.sounds(p1), "grenade_drop"), "landing on the drop sound, tg's chain")

-- Onto the landing tile while the fuse still burns: bodies keep out
-- of the flight path, not out of the blast.
walk(vl, { "north" })
placed(vl, 5, 5, "the landing witness")

t.run_seconds(6)
assert(destroyed() == 3, "the thrown grenade went off")
-- Floors, not exact: the seam routes zone-less blows and caps them at
-- the part's max, so a center blow caught by a limb lands short. The
-- ring below is exact because 25 fits every part; the center exactness
-- is proven by the two deck blasts above.
assert(burn(vl) >= 10, ("the landing tile is the center: %g burn"):format(burn(vl)))
assert(brute(vl) >= 40, "with the center's brute")
assert(math.abs(burn(p1) - 20) < 0.01, "three tiles back, the thrower is untouched")
assert(#t.ledger_rows("volley_discharged") == 3, "the thrown blast threw too")
assert(#t.ledger_rows("volley_settled") == 3, "and settled")

-- ---------------------------------------------------------------
-- DIAGONAL: both orthogonal corners are wall, and the ring takes its
-- full share anyway. The engine's line of sight asks only the tiles
-- strictly between the ends, and adjacent tiles have none -- so this
-- pins the corner rule rather than the wall.
-- ---------------------------------------------------------------
t.click(p2, 8, 2, t.target_at(p2, 8, 2, "frag_grenade"))
t.tick()
t.use_self(p2)
t.tick()
t.drop(p2)
t.tick()
t.run_seconds(6)
assert(destroyed() == 4, "the fourth grenade went off")
assert(math.abs(burn(p2) - 20) < 0.01, "its armer takes the center")
assert(math.abs(burn(v3) - 10) < 0.01, ("past corner walls, the full ring: %g"):format(burn(v3)))
assert(burn(v2) == 0, "four tiles down, still no burn")
assert(#t.ledger_rows("volley_discharged") == 4, "four blasts, four volleys")
assert(#t.ledger_rows("volley_settled") == 4, "four settles")
