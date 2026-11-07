-- Adapted from TempleOS GodDoodle.HC:Adam/God/GodDoodle.HC:96-181.
export type Raster = IndexedBitmap
export type Random = (count: number) -> number
export type Operation = BitmapRasterOperation
export type Rasterize = (bitmap: Raster, operations: { Operation }) -> Raster
export type ModeFilter = (bitmap: Raster, options: BitmapFilterOptions) -> Raster

local raster = {}
local WIDTH, HEIGHT = 64, 48
local PIXEL_COUNT = WIDTH * HEIGHT
-- Index 0 is the pure black palette entry (#000000).
local BLACK, RED, LIGHT, DARK, WHITE = 0, 1, 2, 3, 4
local PALETTE = { "000000", "AA0000", "AAAAAA", "555555", "FFFFFF" }
local FILTER_PALETTE = { "#000000", "#AA0000", "#AAAAAA", "#555555", "#FFFFFF" }

local function smooth(image: Raster, mode_filter: ModeFilter)
	local bitmap: Raster = {
		width = image.width,
		height = image.height,
		palette = FILTER_PALETTE,
		pixels = image.pixels,
	}
	image.pixels = mode_filter(bitmap, { radius = 3, tie = "lowest" }).pixels
end

local function apply_operations(image: Raster, operations: { Operation }, rasterize: Rasterize): Raster
	local bitmap: Raster = {
		width = image.width,
		height = image.height,
		palette = FILTER_PALETTE,
		pixels = image.pixels,
	}
	local rendered = rasterize(bitmap, operations)
	rendered.palette = PALETTE
	return rendered
end

function raster.generate(
	random: Random,
	rasterize: Rasterize,
	mode_filter: ModeFilter
): Raster
	local image: Raster = { width = WIDTH, height = HEIGHT, palette = PALETTE,
		pixels = string.rep("4", PIXEL_COUNT) }
	for pass = 1, 3 do
			local operations: { Operation } = {}
			local operation_count = 0
		for _ = 1, 29 do
			local shape = random(3)
			local cx = (WIDTH - 1) * random(5) / 15.5 - WIDTH / 2
			local cy = (HEIGHT - 1) * random(5) / 15.5 - HEIGHT / 2
			local rx = (WIDTH - 1) * random(5) / 15.5
			local ry = (HEIGHT - 1) * random(5) / 15.5
			if shape == 0 then
					operation_count += 1
					operations[operation_count] = { kind = "ellipse_outline", cx = cx, cy = cy,
						rx = rx, ry = ry, inner_ratio_sq = 0.72, color = RED }
			elseif shape == 1 then
					operation_count += 1
					operations[operation_count] = { kind = "ellipse_outline", cx = cx, cy = cy,
						rx = rx, ry = rx, inner_ratio_sq = 0.72, color = RED }
			elseif shape == 2 then
				local left = (WIDTH - 1) * random(5) / 15.5 - WIDTH / 2
				local top = (HEIGHT - 1) * random(5) / 15.5 - HEIGHT / 2
				local right = (WIDTH - 1) * random(5) / 15.5
				local bottom = (HEIGHT - 1) * random(5) / 15.5
					local operation: Operation = { kind = "rectangle_border", x0 = left, y0 = top,
						x1 = right, y1 = bottom, color = RED }
					operation_count += 1
					operations[operation_count] = operation
			else
					local operation: Operation = { kind = "line",
						x0 = (WIDTH - 1) * random(4) / 15, y0 = (HEIGHT - 1) * random(4) / 15,
						x1 = (WIDTH - 1) * random(4) / 15, y1 = (HEIGHT - 1) * random(4) / 15, color = RED }
					operation_count += 1
					operations[operation_count] = operation
			end
		end
		for _ = 1, 6 do
				operation_count += 1
				operations[operation_count] = {
				kind = "flood_fill",
				start_index = random(12) % PIXEL_COUNT,
				color = ({ BLACK, DARK, LIGHT, WHITE })[random(2) + 1],
				}
		end
		image = apply_operations(image, operations, rasterize)
		smooth(image, mode_filter)
	end
	return image
end

return raster
