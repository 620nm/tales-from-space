-- Screws an assembly together, which is the step that turns a boarded
-- frame into whatever its board said it was. Like every tool, this file
-- says only what the thing IS; the frame knows what a screwdriver does
-- to a frame.
return {
    id = "screwdriver",
    name = "screwdriver",
    sprite = "screwdriver",
    inhand_sprite = { "held_screwdriver_l", "held_screwdriver_r" },
    -- What it looks like riding a belt that shows its contents.
    stowed_sprite = "belt_screwdriver",
    tool = "screwdriver",
}
