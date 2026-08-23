-- The area power controller: the box on the wall that decides what the
-- room it serves is allowed to draw, and the only thing bridging the
-- backbone to a room's own branch (docs/POWER.md).
--
-- What the engine owns is the bridge itself -- charge, budget, the
-- three channels and their LEDs -- because that is per-tick arithmetic
-- on a graph. What lives here is what a player sees and can be told: a
-- name, a picture, and the fact that it hangs on a wall.
--
-- A map may tell one which way each cable layer runs, and label it with
-- the room it serves:
--
--   (12, 5, "apc", { "l2": "input" }), labels: [(12, 5, "The Commons")]
return {
    id = "apc",
    name = "APC",
    sprite = "apc",
    fixture = "Apc",
    category = "power",
    examine = {
        flavor = "A wall box with a row of indicator lamps. It takes the "
            .. "station's power and decides how much of it this room gets.",
    },
}
