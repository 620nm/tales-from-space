-- The janitor's device: one click puts a fresh tube in a dead fitting.
--
-- It is pure data, and that is the point. The replacer does not know
-- what a light fixture is; the fixture knows what a replacer does to it
-- (tfs/content/fixtures/light.luau). tg's `uses` = 10 at spawn out of
-- max_uses = 20 (lightreplacer.dm:49-51); ours mints ten and the
-- refill (tubes and glass back into the device) is not written yet.
return {
    id = "light_replacer",
    name = "light replacer",
    sprite = "light_replacer",
    -- Charges, not a stack: an empty replacer stays in your hand and
    -- says so, where a spent stack would simply be gone.
    uses = 10,
}
