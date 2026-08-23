-- An operating table: the best surface to operate on (tg's optable, the
-- 1.0 location modifier, _operation.dm:789). Not dense -- a patient lies
-- ON it -- and it stands on the deck rather than being built here.
-- Reuses the table picture until an optable sprite is baked.
return {
    id = "optable", name = "operating table", sprite = "table-0",
    surgery_surface = 1.0,
}
