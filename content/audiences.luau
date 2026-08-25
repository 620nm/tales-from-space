-- Named delivery rosters. An audience answers "who is this for" for
-- facts that have no place to be seen from -- a shift's outcome, a
-- channel every ear is on. The engine calls the resolver and delivers
-- to exactly the Minds it names; it never adds one of its own
-- (docs/LUAU-API.md §8.1, §8.4).
--
-- The roster is legal-empty: a pack that declares no audience simply
-- has no unplaced delivery, and every var and notification that names
-- one is checked against this file at load.

-- Everyone aboard, for the whole shift. `sim.query.minds()` is every
-- continuity identity this round minted, so a player who ghosted, or
-- who is watching without a body, is in it: a fact about the station is
-- a fact for whoever is still watching the station.
sim.define("audience", "lunatic/tfs:round", {
    resolve = function()
        return sim.query.minds()
    end,
})
