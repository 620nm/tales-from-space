-- The gravitational generator: one machine standing on nine tiles, and
-- the first thing in this pack to declare a `footprint`
-- (docs/FOOTPRINTS.md).
--
-- NINE CELLS IN TG'S OWN ORDER. tg builds this out of eight part
-- objects around one machine, numbering them in `setup_parts()` by
-- counting DOWN from 10 over the 3x3 block whose bottom-middle tile is
-- the machine's own, x-fastest from the bottom-left
-- (`CORNER_BLOCK_OFFSET(our_turf, 3, 3, -1, 0)`,
-- gravitygenerator.dm:179-198). That makes the top row 3, 2, 1 read
-- left to right, the centre 5, and the mapper's own tile 8 — which is
-- why `main` wears `on_8` (`:118`). The `footprint` below lists the
-- cells in exactly that order, because `state_sprites` names one
-- picture per cell in footprint order and the numbers in the sprite
-- names are tg's part numbers.
--
-- THE TOP ROW IS WALK-UNDER. tg drops the density of the three parts it
-- numbered 1-3 and lifts them to `WALL_OBJ_LAYER` (`:191-193`), so a
-- player walks behind the machine's head and is drawn under it. That is
-- `dense = false, layer = "overhead"` here, per cell; the six cells
-- below stay solid.
--
-- NOT OPAQUE. tg's generator never sets `opacity`, so it defaults to 0
-- and you can see straight through nine tiles of machine. Said out loud
-- because this is a big dense thing and the assumption would otherwise
-- go the other way.
--
-- SIX STATES. `on` and `off` are the working pair (`main` :118 and
-- `main/off` :156, which is the same machine mapped with its breaker
-- shut); `fix0`-`fix3` are the four rungs a BROKEN generator climbs,
-- each named for the tool it wants next (`GRAV_NEEDS_*`, `:13-16`).
-- Only the working pair is offered in the editor palette: a mapper
-- places a generator, not a stage of somebody's repair.
--
-- The charge ramp, the interface, the shake and gravity itself are
-- deferred (docs/FOOTPRINTS.md §10). What is here is the body, the
-- picture, and the repair.
local ORDER = {
    -- Top row, walk-under: tg's parts 1, 2, 3.
    { 1, -2 }, { 0, -2 }, { -1, -2 },
    -- Middle row: 4, 5 (the centre, which wears the charge overlay), 6.
    { 1, -1 }, { 0, -1 }, { -1, -1 },
    -- Bottom row: 7, then 8 — the mapper's tile — then 9.
    { 1, 0 }, { 0, 0 }, { -1, 0 },
}

local STATUSES = { "off", "on", "fix0", "fix1", "fix2", "fix3" }

local footprint = {}
for n, at in ipairs(ORDER) do
    -- Everything but the head takes the entry's own density.
    footprint[n] = n <= 3
        and { at = at, dense = false, layer = "overhead" }
        or { at = at }
end

-- Fifty-four pictures is a loop, not fifty-four lines: the sheet is
-- named `[status]_[part number]` and the footprint is in part-number
-- order, so cell `n` in status `s` is `gravgen_<s>_<n>`.
local state_sprites = {}
for _, status in ipairs(STATUSES) do
    local row = {}
    for n = 1, #ORDER do
        row[n] = "gravgen_" .. status .. "_" .. n
    end
    state_sprites[status] = row
end
-- A running generator hangs its charge overlay on the middle part alone
-- (`center_part.add_overlay("activated")`, `:167`), and a generator that
-- boots up already on wears the full one from the start.
state_sprites.on[5] = { "gravgen_on_5", "gravgen_activated" }

return {
    id = "gravity_generator",
    name_label = "lunatic/tfs:entity.gravity_generator.name",
    name = "gravitational generator",
    sprite = "gravgen_off_8",
    dense = true,
    opaque = false,
    category = "power",
    states = STATUSES,
    palette_states = { "on", "off" },
    footprint = footprint,
    state_sprites = state_sprites,
    examine = {
        flavor = "A device which produces a graviton field when set up.",
    },
    -- The repair ladder, verbatim from tg's four `*_act` procs. Every
    -- rung is instant: tg passes a zero delay to `use_tool` on the
    -- welder (`:257`) and never calls it at all on the other three, so
    -- fixing a generator is four clicks and the cost of the plasteel.
    transitions = {
        -- "The entire frame is barely holding together, the screws need
        -- to be refastened." (`:224`, `screwdriver_act` :272-278)
        {
            at = "fix0",
            tool = "screwdriver",
            to = "fix1",
            start = "You start refastening the screws of the framework.",
            done = "You secure the screws of the framework.",
        },
        -- "There's lots of broken seals on the framework, it could use
        -- some welding." (`:226`, `welder_act` :254-262)
        {
            at = "fix1",
            tool = "welder",
            to = "fix2",
            start = "You start mending the broken seals.",
            done = "You mend the damaged framework.",
        },
        -- "Some of this damaged plating needs full replacement. 10
        -- plasteel should be enough." (`:228`, `item_interaction`
        -- :238-252, which takes exactly ten sheets)
        {
            at = "fix2",
            with = { plasteel = 10 },
            to = "fix3",
            start = "You start plating over the damaged framework.",
            done = "You add the plating to the framework.",
        },
        -- "The new plating just needs to be bolted into place now."
        -- (`:230`, `wrench_act` :264-270, whose `set_fix()` clears the
        -- break outright — the generator comes back shut down, and
        -- somebody has to throw its breaker.)
        {
            at = "fix3",
            tool = "wrench",
            to = "off",
            start = "You start bolting the new plating down.",
            done = "You secure the plating to the framework.",
        },
    },
}
