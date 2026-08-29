-- Map-authoring choices. Names stay in TfS and the engine carries only
-- this declared roster to whichever editor is connected.
local paints = {}
for _, paint in ipairs(pipe_paints.colors) do
    paints[#paints + 1] = { name = paint.name, color = paint.hex }
end

return {
    pipe_paints = paints,
    pipe_defaults = pipe_paints.defaults,
}
