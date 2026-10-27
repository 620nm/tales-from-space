-- Which engine announcements this pack keeps durable (the engine's
-- docs/ledger/streams.md): one sealed log of every row per round, the
-- audit and replay record staff read (docs/STAFF.md). `kinds` are this pack's
-- own rows (the engine's docs/luau-api/ledger.md).
return {
    kinds = {
        -- A print job whose task raised: the machine, whether the job or its
        -- notice failed, and the error text (lib/printing.luau).
        ["lunatic/tfs:print_job_failed"] = {
            fields = { machine = "entity", stage = "text", error = "text" },
        },
        -- A device that still awaited its cap of door and latch completions
        -- when another order was issued: they are forgotten, so their
        -- completions are ignored (lib/device_queue.luau).
        ["lunatic/tfs:device_orders_dropped"] = {
            fields = { device = "entity", dropped = "int" },
        },
        -- A shut-in occupant who forced a sealed closet: the latches cleared
        -- (comma-joined ids) and the lock it broke, if the closet declares one
        -- (lib/closets/closet.luau).
        ["lunatic/tfs:closet_broken_out"] = {
            fields = { container = "entity", body = "body", cleared = "text", broken = "text?" },
        },
        -- A breakout wait that ended without opening and left no engine row:
        -- `not_inside`, `not_secured`, `latch_unconfirmed` or `open_refused`
        -- (lib/closets/closet.luau).
        ["lunatic/tfs:closet_breakout_lapsed"] = {
            fields = { container = "entity", body = "body", reason = "text" },
        },
        -- A round that did not start: no host map named, or the install of
        -- the named one was refused (lib/map_boot.luau).
        ["lunatic/tfs:map_boot_failed"] = {
            fields = { stage = "text", source = "text?", reason = "text?" },
        },
    },
    streams = {
        audit = { scope = "round", select = { groups = { "all" } } },
    },
}
