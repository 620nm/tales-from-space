-- A nitrogen filter: a gas filter that arrives already set, and
-- already running.
--
-- tg's `/obj/machinery/atmospherics/components/trinary/filter/atmos/n2`
-- (filter.dm:224-229) -- one of eighteen such subtypes, each a base
-- filter with `on = TRUE` and one gas in `filter_type`. They exist
-- because a waste loop is a CHAIN of filters and a mapper laying one
-- should not have to open eighteen panels to set them up. A machine
-- somebody has to configure before it does anything is a machine that
-- ships mis-configured.
--
-- The whole difference from gas_filter.luau is three lines of the atmos
-- block, which is the point of `filter` being a schema field: the next
-- preset (`plasma`, `co2`, `n2o` -- tg has them all) is a copy of this
-- file with one word changed, and no engine edit at all.
--
-- The gases are named by their registry KEY, which is what content
-- calls a substance everywhere else. A key nothing answers to is
-- dropped with a warning when the machine is stamped rather than taking
-- the whole file down: a filter set to divert a gas this shift's
-- chemistry does not define is a filter that passes everything, which
-- is what an empty roster already means.
return {
    id = "gas_filter_n2",
    name = "nitrogen filter",
    sprite = "filter_on_n",
    dense = false,
    states = { "off", "running" },
    facing_sprites = {
        off = {
            north = "filter_off_n",
            south = "filter_off_s",
            east = "filter_off_e",
            west = "filter_off_w",
        },
        running = {
            north = "filter_on_n",
            south = "filter_on_s",
            east = "filter_on_e",
            west = "filter_on_w",
        },
    },
    atmos = {
        device = "filter",
        positions = { "off", "running" },
        rate_lps = 200.0,
        max_rate_lps = 200.0,
        on = true,
        filter = { "n2" },
    },
    -- No build rule: a preset is something a MAP lays, not something a
    -- player raises. tg is the same -- every preset filter shares the
    -- base machine's `construction_type`, so the fitting in your hands
    -- only ever knows how to become a plain gas filter, and setting one
    -- up is what the panel is for. It also keeps the fitting
    -- unambiguous: one item, one machine, no menu.
    transitions = {
        {
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { gas_filter_fitting = 1 },
            start = "You start unbolting the nitrogen filter.",
            done = "The nitrogen filter comes up off the pipe.",
        },
    },
}
