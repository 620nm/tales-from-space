-- Which engine announcements this pack keeps durable (the engine's
-- docs/ledger/streams.md): one sealed log of every row per round, the
-- audit and replay record staff read (docs/STAFF.md).
return {
    streams = {
        audit = { scope = "round", select = { groups = { "all" } } },
    },
}
