-- Pipe paint is game vocabulary shared by the painter, the RPD and the
-- map editor. Names and order follow tg's `GLOB.pipe_paint_colors`
-- (code/_globalvars/lists/piping_colors_lists.dm:2-15); the muted shades
-- are pack-owned, with an additional white process-line paint.
-- The engine sees only names and #RRGGBB values.
local colors = {
    -- The wildcard value in lunatic-server/src/pipes/paint.rs:value_of.
    { name = "omni", hex = "#EEEEEE" },
    { name = "green", hex = "#50BE5F" },
    { name = "blue", hex = "#5491E8" },
    { name = "red", hex = "#F04137" },
    { name = "orange", hex = "#DDA257" },
    { name = "cyan", hex = "#62C6CE" },
    { name = "dark", hex = "#55585C" },
    { name = "yellow", hex = "#F0DA50" },
    { name = "brown", hex = "#AC9672" },
    { name = "pink", hex = "#DC79B4" },
    { name = "purple", hex = "#9F6CA8" },
    { name = "violet", hex = "#997ACE" },
    { name = "white", hex = "#EDEAE3" },
}

return {
    colors = colors,
    -- The five map-editor base swatches, L1 through L5.
    defaults = { "yellow", "blue", "white", "red", "dark" },
}
