-- The power network's load classes: what a panel switches whole, in
-- the order compositions.luau declares them -- tg's three area
-- channels (code/__DEFINES/machines.dm:3-5). A caller walking them
-- walks this order, so a ladder's gate writes and a probe's sentence
-- key come out the same every time (docs/POWER.md).
--
-- Prototypes under `structures/` cannot read `lib/`, so a consumer
-- there spells its own class word (`load_class = "environment"`).
local load_classes = {
    power = { "equipment", "lighting", "environment" },
    -- What a consumer naming no class draws on: tg's machine default,
    -- AREA_USAGE_EQUIP (_machinery.dm:118).
    power_default = "equipment",
}

return load_classes
