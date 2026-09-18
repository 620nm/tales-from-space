-- Floor-decal paint is game vocabulary shared by the decal painter, the
-- map editor's palette drawer and `compositions.luau`. The ids and hexes
-- are tg's `/obj/effect/turf_decal/tile/*` subtypes, verbatim
-- (code/game/objects/effects/decals/turfdecal/tilecoloring.dm). The
-- engine sees only ids and #RRGGBB values.
--
-- ALPHA IS NOT PER PAINT HERE. A decal declares ONE opacity for the
-- whole decal, so tg's two per-colour exceptions do not port: `bar` is
-- alpha 130 (tilecoloring.dm:100-103) and `neutral` alpha 50 (:125-128)
-- against everything else's 110. Both are carried at 110. For `bar`
-- that is imperceptible; for `neutral` it is a real divergence -- tg's
-- neutral grey is a whisper and ours is a statement.
local colors = {
    { id = "blue", hex = "#52B4E9" },        -- tilecoloring.dm:45-47
    { id = "dark_blue", hex = "#486091" },   -- :52-54
    { id = "green", hex = "#9FED58" },       -- :60-62
    { id = "dark_green", hex = "#439C1E" },  -- :68-70
    { id = "yellow", hex = "#EFB341" },      -- :76-78
    { id = "red", hex = "#DE3A3A" },         -- :84-86
    { id = "dark_red", hex = "#B11111" },    -- :92-94
    { id = "bar", hex = "#791500" },         -- :100-103 (alpha 130 dropped)
    { id = "purple", hex = "#D381C9" },      -- :109-111
    { id = "brown", hex = "#A46106" },       -- :117-119
    { id = "neutral", hex = "#D4D4D4" },     -- :125-128 (alpha 50 dropped)
    { id = "dark", hex = "#0E0F0F" },        -- :134-136
}

-- tg's holiday, rainbow and random tile subtypes (tilecoloring.dm:140-164)
-- are not here: they recolour themselves from a station trait at
-- Initialize, which is a mechanism and not a paint.
return {
    colors = colors,
    -- The swatches the editor's palette drawer opens on, and the order
    -- the painter's dial cycles from. tg's own maps reach for these six
    -- far more than the rest.
    defaults = { "blue", "red", "yellow", "green", "dark", "neutral" },
    -- tg alpha for a tile or trimline decal (tilecoloring.dm:5, :170).
    -- Markings and stripes take the base 255 (decal.dm:54-59).
    trim_opacity = 110,
    mark_opacity = 255,
}
