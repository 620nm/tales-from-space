-- Shared by the art kits (tools/art/*/): run on a drawn source so every set of
-- identical cels in one layer becomes ONE image linked across its frames
-- (docs/art-reference/aseprite-documents.md, "One drawing is one image").
-- Works in batch mode; saves the sprite in place.
local s = app.activeSprite
for _, l in ipairs(s.layers) do
  local groups, order = {}, {}
  for _, c in ipairs(l.cels) do
    local k = c.position.x .. "," .. c.position.y .. ":" .. c.opacity .. ":"
      .. c.image.width .. "x" .. c.image.height .. ":" .. c.image.bytes
    if not groups[k] then groups[k] = {}; order[#order + 1] = k end
    table.insert(groups[k], c.frame)
  end
  for _, k in ipairs(order) do
    if #groups[k] > 1 then
      app.activeLayer = l
      app.range:clear()
      app.range.layers = { l }
      app.range.frames = groups[k]
      app.command.LinkCels()
    end
  end
end
s:saveAs(s.filename)
print("linked")
