local bit_source = require("@lib/strange_disk/bits")
local raster = require("@lib/strange_disk/raster")
local song = require("@lib/strange_disk/song")
local media_format = require("@lib/strange_disk/format")

export type Note = song.Note
export type Song = song.Song
export type Raster = raster.Raster
export type Rasterize = raster.Rasterize
export type ModeFilter = raster.ModeFilter
export type Presentation = media_format.Presentation
export type BitSource = bit_source.BitSource

local strange_disk = {}

function strange_disk.generate(
	draw_raster: (count: number) -> number,
	draw_song: (count: number) -> number,
	rasterize: Rasterize,
	mode_filter: ModeFilter
): Presentation
	local raster_source = bit_source.new(draw_raster)
	local song_source = bit_source.new(draw_song)
	local image = raster.generate(function(count: number): number return raster_source:read(count) end,
		rasterize, mode_filter)
	local generated_song = song.generate(function(count: number): number return song_source:read(count) end)
	return { width = image.width, height = image.height, palette = image.palette, pixels = image.pixels,
		song = generated_song }
end

strange_disk.serialize = media_format.serialize
strange_disk.parse = media_format.parse

return strange_disk
