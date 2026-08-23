-- The medic's roll of surgical tools (tg's surgical tray/belt). A belt
-- container, filled at spawn. Reuses the toolbelt picture for now.
return {
    id = "surgical_kit", name = "surgical kit", sprite = "toolbelt",
    slot = "belt", storage = 8, show_contents = false,
    holds = {
        "scalpel", "hemostat", "retractor", "cautery",
        "circular_saw", "surgical_drill", "bone_gel", "suture",
    },
}
