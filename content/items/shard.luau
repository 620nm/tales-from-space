-- A broken pane: the improvised scalpel (tg glass.dm:307-326). force 5 --
-- under the 10 a saw needs, which is why the floor rescue can open a
-- chest but never saw the ribs (docs/SURGERY.md 6.3). Reuses the glass
-- sheet's picture until a shard sprite is baked.
return {
    id = "shard", name = "shard", sprite = "glass",
    force = 5, sharp = "edged",
}
