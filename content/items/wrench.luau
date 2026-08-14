-- Anchors and unanchors. Nothing in the shipped chain calls for it yet;
-- it exists because a toolbox without one is not a toolbox, and because
-- the first structure that wants anchoring should not also have to
-- invent the tool.
return {
    id = "wrench",
    name = "wrench",
    sprite = "wrench",
    inhand_sprite = { "held_wrench_l", "held_wrench_r" },
    tool = "wrench",
}
