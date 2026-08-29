-- Pipe paint is game vocabulary shared by the painter, the RPD and the
-- map editor. The first twelve rows are tg's
-- `GLOB.pipe_paint_colors` in order
-- (code/_globalvars/lists/piping_colors_lists.dm:2-15, resolving through
-- code/__DEFINES/colors.dm); white is TfS's additional clean process-line
-- colour. The engine sees only names and #RRGGBB values.
local colors = {
    { name = "omni", hex = "#EEEEEE" },
    { name = "green", hex = "#00FF00" },
    { name = "blue", hex = "#0000FF" },
    { name = "red", hex = "#FF0000" },
    { name = "orange", hex = "#FFA62B" },
    { name = "cyan", hex = "#00FFFF" },
    { name = "dark", hex = "#454545" },
    { name = "yellow", hex = "#FFFF00" },
    { name = "brown", hex = "#BA9F6D" },
    { name = "pink", hex = "#FF3CC8" },
    { name = "purple", hex = "#800080" },
    { name = "violet", hex = "#6927C5" },
    { name = "white", hex = "#FFFFFF" },
}

return {
    colors = colors,
    -- The five map-editor base swatches, L1 through L5.
    defaults = { "yellow", "blue", "white", "red", "dark" },
}
