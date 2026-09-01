-- The public status display. tg's device has blank, message, shuttle,
-- alert and picture commands; this one deliberately imports the first
-- two only (`code/game/machinery/status_display.dm:797-874`). Its two
-- text ports are forty characters apiece
-- (`code/__DEFINES/machines.dm:156`), and `set_messages` uppercases both
-- before showing them (`code/game/machinery/status_display.dm:98-113`).
--
-- The two values are sight-replicated ScriptVars: content owns what the
-- board says, while the atlas display declaration owns how those words
-- become bounded, scrolling pixels. An empty pair is the blank mode.
return {
    id = "status_display",
    name = "status display",
    sprite = "status_display",
    mount = true,
    appearance = {
        mounted = {
            north = "status_display_n", south = "status_display_s",
            east = "status_display_e", west = "status_display_w",
        },
    },
    ui = {
        modules = { "actions" },
        actions = {
            {
                key = "line1",
                label = "set top line",
                input = { label = "top line", max_length = 40 },
            },
            {
                key = "line2",
                label = "set bottom line",
                input = { label = "bottom line", max_length = 40 },
            },
            { key = "clear", label = "clear" },
        },
    },
    script = "status_display",
    examine = {
        flavor = "A two-line public message board in a metal wall frame.",
    },
}
