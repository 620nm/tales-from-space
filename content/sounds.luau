-- The sound roster (the engine's docs/content-schema/sounds.md): every sound
-- a slot, a `sounds` table or a `sim.sound.play` names, keyed by the
-- assets/sounds.ron delivery key it plays, so an id and its asset are one
-- spelling. A sound is heard 15 tiles through walls (capabilities.luau
-- `hearing`; tg's `ignore_walls = TRUE` default,
-- tgstation/code/game/sound/sound.dm:19); a row says only how it departs.
return {
    -- Computers and their slots (tg computer.dm:313,562,1032).
    computer_start = { asset = "computer_start" },
    computer_end = { asset = "computer_end" },
    card_slide = { asset = "card_slide" },
    terminal_insert_disc = { asset = "terminal_insert_disc" },
    -- Tools at work.
    weld = { asset = "weld" },
    welder_activate = { asset = "welder_activate" },
    welder_deactivate = { asset = "welder_deactivate" },
    crowbar = { asset = "crowbar" },
    crowbar_pry = { asset = "crowbar_pry" },
    wirecutter = { asset = "wirecutter" },
    ratchet = { asset = "ratchet" },
    part_swap = { asset = "part_swap" },
    -- Teardown and breakage; `smash` is every machine's `sounds.teardown`.
    smash = { asset = "smash" },
    glass_break = { asset = "glass_break" },
    -- Vendors' and docks' `sounds.dispense`.
    vend = { asset = "vend" },
    -- Doors: every airlock's `sounds.open` / `sounds.close`, and its bolts.
    airlock_open = { asset = "airlock_open" },
    airlock_close = { asset = "airlock_close" },
    airlock_bolts_up = { asset = "airlock_bolts_up" },
    airlock_bolts_down = { asset = "airlock_bolts_down" },
    -- Closets, crates and the cadaver chamber.
    crate_open = { asset = "crate_open" },
    crate_close = { asset = "crate_close" },
    locker_open = { asset = "locker_open" },
    locker_close = { asset = "locker_close" },
    closet_lock = { asset = "closet_lock" },
    closet_unlock = { asset = "closet_unlock" },
    morgue_clank = { asset = "morgue_clank" },
    cadaver_alert = { asset = "cadaver_alert" },
    -- Panels and handles: `click` is a switched machine's `sounds.toggle` and
    -- a setpoint panel's `sounds.adjust`; `valve` is the manual valve's wheel
    -- (tg valve.dm:28); `hiss` is a canister's `sounds.open`, its release
    -- coming open.
    click = { asset = "click" },
    valve = { asset = "valve" },
    hiss = { asset = "hiss" },
    switch_click = { asset = "switch_click" },
    -- Liquids and sprays.
    drink = { asset = "drink" },
    spray = { asset = "spray" },
    slosh = { asset = "slosh" },
    paint_spray = { asset = "paint_spray" },
    -- Body noises from the base-cold emotes (emote.dm:379-420): tg plays an
    -- emote's sound only to those who see it (`sound_wall_ignore = FALSE`,
    -- tgstation/code/datums/emotes.dm:61,146).
    sneeze = { asset = "sneeze", through_walls = false },
    cough = { asset = "cough", through_walls = false },
    -- Games.
    dice_roll = { asset = "dice_roll" },
    card_flip = { asset = "card_flip" },
    card_shuffle = { asset = "card_shuffle" },
    -- Picking a thing up and setting it down. tg plays these to those who
    -- see it (`sound_chain`, tgstation/code/game/objects/items.dm:672).
    crowbar_pickup = { asset = "crowbar_pickup", through_walls = false },
    crowbar_drop = { asset = "crowbar_drop", through_walls = false },
    wrench_pickup = { asset = "wrench_pickup", through_walls = false },
    wrench_drop = { asset = "wrench_drop", through_walls = false },
    screwdriver_pickup = { asset = "screwdriver_pickup", through_walls = false },
    screwdriver_drop = { asset = "screwdriver_drop", through_walls = false },
    welder_pickup = { asset = "welder_pickup", through_walls = false },
    welder_drop = { asset = "welder_drop", through_walls = false },
    wirecutter_pickup = { asset = "wirecutter_pickup", through_walls = false },
    wirecutter_drop = { asset = "wirecutter_drop", through_walls = false },
    multitool_pickup = { asset = "multitool_pickup", through_walls = false },
    multitool_drop = { asset = "multitool_drop", through_walls = false },
    rpd_pickup = { asset = "rpd_pickup", through_walls = false },
    rpd_drop = { asset = "rpd_drop", through_walls = false },
    toolbox_pickup = { asset = "toolbox_pickup", through_walls = false },
    toolbox_drop = { asset = "toolbox_drop", through_walls = false },
    toolbelt_pickup = { asset = "toolbelt_pickup", through_walls = false },
    toolbelt_drop = { asset = "toolbelt_drop", through_walls = false },
    backpack_pickup = { asset = "backpack_pickup", through_walls = false },
    backpack_drop = { asset = "backpack_drop", through_walls = false },
    analyzer_pickup = { asset = "analyzer_pickup", through_walls = false },
    analyzer_drop = { asset = "analyzer_drop", through_walls = false },
    id_card_pickup = { asset = "id_card_pickup", through_walls = false },
    id_card_drop = { asset = "id_card_drop", through_walls = false },
    cloth_pickup = { asset = "cloth_pickup", through_walls = false },
    cloth_drop = { asset = "cloth_drop", through_walls = false },
    metal_pickup = { asset = "metal_pickup", through_walls = false },
    metal_drop = { asset = "metal_drop", through_walls = false },
    glass_pickup = { asset = "glass_pickup", through_walls = false },
    glass_drop = { asset = "glass_drop", through_walls = false },
    rod_pickup = { asset = "rod_pickup", through_walls = false },
    gas_tank_pickup = { asset = "gas_tank_pickup", through_walls = false },
    gas_tank_drop = { asset = "gas_tank_drop", through_walls = false },
    helmet_pickup = { asset = "helmet_pickup", through_walls = false },
    helmet_drop = { asset = "helmet_drop", through_walls = false },
    grenade_pickup = { asset = "grenade_pickup", through_walls = false },
    grenade_drop = { asset = "grenade_drop", through_walls = false },
    smg_pickup = { asset = "smg_pickup", through_walls = false },
    smg_drop = { asset = "smg_drop", through_walls = false },
    -- Medicine.
    defib_zap = { asset = "defib_zap" },
    defib_success = { asset = "defib_success" },
    defib_failed = { asset = "defib_failed" },
    health_analyzer_scan = { asset = "health_analyzer_scan" },
    twobeep_high = { asset = "twobeep_high" },
    -- Violence.
    grenade_arm = { asset = "grenade_arm" },
    punch = { asset = "punch" },
    smg_shot = { asset = "smg_shot" },
    smg_rack = { asset = "smg_rack" },
    -- A blast is heard across the deck and through the decks beside it. tg
    -- plays it to every listener on the blast's z: up to its far distance
    -- (15 for a frag grenade), then as an echo "through the hull"
    -- (tgstation/code/controllers/subsystem/explosions.dm:378-380,548,561),
    -- walls never asked. The range is the engine's cap; tg stops at the z
    -- (explosions.dm:535), and a level here is a deck of the same hull, so
    -- the echo carries two decks up and down.
    explosion = { asset = "explosion", range = 32, carry_levels = 2 },
}
