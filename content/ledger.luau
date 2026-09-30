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
    },
    streams = {
        audit = { scope = "round", select = { groups = { "all" } } },
    },
}
