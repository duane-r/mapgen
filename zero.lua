-- Duane's mapgen zero.lua
-- Copyright Duane Robertson (duane@duanerobertson.com), 2019
-- Distributed under the LGPLv2.1 (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)


local layer_mod = mapgen
local mod = mapgen
local mod_name = 'mapgen'

local Geomorph = geomorph.Geomorph

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local node = layer_mod.node
local os_clock = os.clock
local VN = vector.new

local water_diff = 8

local altitude_cutoff_high = 30
local altitude_cutoff_low = -10
local altitude_cutoff_low_2 = 63
local cave_underground = 5
local make_roads = true
local make_tracks = false

local n_air = node['air']
local n_ignore = node['ignore']
local n_stone = node['default:stone']


-----------------------------------------------
-- DFlat_Mapgen class
-----------------------------------------------

function dflat_mapgen(base_class)
	if not base_class then
		return
	end

	local new_class = {}
	local new_mt = { __index = new_class, }

	function new_class:new(mg, params)
		local new_inst = {}
		for k, v in pairs(mg) do
			new_inst[k] = v
		end
		for k, v in pairs(params) do
			new_inst[k] = v
		end

		new_inst.puzzle_boxes = {}

		setmetatable(new_inst, new_mt)
		return new_inst
	end

	setmetatable(new_class, { __index = base_class })

	return new_class
end

local DFlat_Mapgen = dflat_mapgen(layer_mod.Mapgen)


function DFlat_Mapgen:after_decorations()
	-- nop
end


function DFlat_Mapgen:after_terrain()
	local minp, maxp = self.minp, self.maxp
	local chunk_offset = self.chunk_offset
	local water_level = self.water_level
	local ground = (maxp.y >= water_level and minp.y <= water_level)
	local decorate = true

	local do_ore = true
	if ground and self.flattened and self.gpr:next(1, 5) == 1 then
		local sr = self.gpr:next(1, 3)
		if sr == 1 then
			self:geomorph('pyramid_temple')
		elseif sr == 2 then
			self:geomorph('pyramid')
		else
			self:simple_ruin()
		end
		do_ore = false
	else
		if math_max(water_level, self.height_max) - chunk_offset + 10 <= minp.y then
			self:planets()
		end
		if ground then
			self:houses()
		end
	end

	if self.height_max >= minp.y
	and self.height_min > minp.y + cave_underground then
		local t_cave = os_clock()
		self:simple_caves()
		mod.time_caves = mod.time_caves + os_clock() - t_cave
	end

	if do_ore then
		local t_ore = os_clock()
		self:simple_ore()
		mod.time_ore = mod.time_ore + os_clock() - t_ore
	end

	if #self.puzzle_boxes > 0 then
		self:place_puzzles()
	end
end


-- The houses function takes very little cpu time.
-- check
local house_materials = {'sandstonebrick', 'desert_stonebrick', 'stonebrick', 'brick', 'wood', 'junglewood'}
function DFlat_Mapgen:houses()
	local csize = self.csize
	local plots = self.plots
	local pr = self.gpr
	local heightmap = self.heightmap
	local base_level = self.base_level

	for _, box in pairs(plots) do
		local pos = vector.add(box.pos, -2)
		local size = vector.add(box.size, 4)
		local good = true

		for z = pos.z, pos.z + size.z do
			for x = pos.x, pos.x + size.x do
				local index = z * csize.x + x + 1
				if not heightmap[index] or heightmap[index] < base_level - 1 or heightmap[index] > base_level + 1 then
					good = false
					break
				end
			end
			if not good then
				break
			end
		end

		if good then
			local walls, roof
			while walls == roof do
				walls = (house_materials)[pr:next(1, #house_materials)]
				roof = (house_materials)[pr:next(1, #house_materials)]
			end
			local walls1 = 'default:'..walls
			local roof1 = 'default:'..roof
			local geo = Geomorph.new()
			local lev = pr:next(1, 4) - 2
			if #self.puzzle_boxes == 0 and lev == 0 and box.size.x >= 7 and box.size.z >= 7 then
				local width = 7
				table.insert(self.puzzle_boxes, {
					pos = table.copy(pos),
					size = VN(width, width, width),
				})
			else
				lev = math_max(1, lev)

				-- foundation
				pos = table.copy(box.pos)
				pos.y = pos.y - 1
				size = table.copy(box.size)
				size.y = 1
				geo:add({
					action = 'cube',
					node = 'default:cobble',
					location = pos,
					size = size,
				})

				pos = table.copy(box.pos)
				pos.y = pos.y + lev * 5
				size = table.copy(box.size)
				if pr:next(1, 3) == 1 then
					size.y = 1
					geo:add({
						action = 'cube',
						node = roof1,
						location = pos,
						size = size,
					})
				elseif box.size.x <= box.size.z then
					size.x = math_floor(size.x / 2)

					local pos2 = table.copy(pos)
					pos2.x = pos2.x + size.x
					pos2.y = pos2.y + size.x - 1

					pos = table.copy(pos)
					pos.x = pos.x + box.size.x - size.x
				else
					size.z = math_floor(size.z / 2)

					local pos2 = table.copy(pos)
					pos2.z = pos2.z + size.z
					pos2.y = pos2.y + size.z - 1

					pos = table.copy(pos)
					pos.z = pos.z + box.size.z - size.z
				end
				pos = table.copy(box.pos)
				pos.y = box.pos.y
				size = table.copy(box.size)
				size.y = lev * 5
				geo:add({
					action = 'cube',
					node = walls1,
					location = pos,
					size = size,
				})
				for y = 0, lev - 1 do
					local pos2 = vector.add(pos, 1)
					local sz2 = vector.add(size, -2)
					pos2.y = box.pos.y + y * 5 + 1
					sz2.y = 4
					geo:add({
						action = 'cube',
						node = 'air',
						location = pos2,
						size = sz2,
					})
				end

				for y = 0, lev - 1 do
					for z = box.pos.z + 2, box.pos.z + box.size.z, 4 do
						geo:add({
							action = 'cube',
							node = 'air',
							location = VN(box.pos.x, box.pos.y + y * 5 + 2, z),
							size = VN(box.size.x, 2, 2),
						})
					end
					for x = box.pos.x + 2, box.pos.x + box.size.x, 4 do
						geo:add({
							action = 'cube',
							node = 'air',
							location = VN(x, box.pos.y + y * 5 + 2, box.pos.z),
							size = VN(2, 2, box.size.z),
						})
					end
				end

				do
					local l = math_max(box.size.x, box.size.z)
					local f = pr:next(0, 2)
					pos = vector.round(vector.add(box.pos, vector.divide(box.size, 2)))
					pos = vector.subtract(pos, math_floor(l / 2 + 0.5) - f)
					pos.y = pos.y + lev * 5
					geo:add({
						action = 'sphere',
						node = 'air',
						intersect = {walls1, roof1},
						location = pos,
						size = VN(l - 2 * f, 20, l - 2 * f),
					})

					for _ = 1, 3 do
						local pos2 = table.copy(pos)
						pos2.x = pos2.x + pr:next(0, box.size.x) - math_floor(box.size.x / 2)
						pos2.z = pos2.z + pr:next(0, box.size.z) - math_floor(box.size.z / 2)

						geo:add({
							action = 'sphere',
							node = 'air',
							intersect = {walls1, roof1},
							location = pos2,
							size = VN(l, 20, l),
						})
					end
				end
			end

			do
				local ff_alt = math_max(0, pr:next(1, 3) + pr:next(1, 3) - 4)
				local ore = self:get_ore(ff_alt)
				pos = table.copy(box.pos)
				size = table.copy(box.size)

				geo:add({
					action = 'cube',
					node = ore,
					intersect = {walls1, roof1},
					location = pos,
					size = size,
					random = 100,
				})
			end

			do
				local index = pos.z * csize.x + pos.x
				local height = self.heightmap[index]
				local biome = self.biomemap[index]
				local dirt = biome and biome.node_top or 'default:dirt'

				pos = table.copy(box.pos)
				pos.y = height
				local ivm = self.area:indexp(vector.add(self.minp, pos))
				local p2 = self.p2data[ivm]

				pos = table.copy(box.pos)
				size = table.copy(box.size)
				size.y = 1
				geo:add({
					action = 'cube',
					node = dirt,
					location = pos,
					intersect = 'air',
					param2 = p2,
					size = size,
				})
			end

			geo:write_to_map(self, 0)
		end
	end
end


--[[
function DFlat_Mapgen:map_height()
	local minp, maxp = self.minp, self.maxp
	local ground_noise_map = self.noise['ground'].map
	local heightmap = self.heightmap
	local base_level = self.base_level
	local div = self.div

	local height_min = mod.max_height
	local height_max = -mod.max_height

	-----------------------------------------
	-- Fix this.
	-----------------------------------------
	if div then
		ground_noise_map = self.noise['ground_ether'].map
	end
	-----------------------------------------

	local index = 1
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			-- terrain height calculations
			local ground_1 = ground_noise_map[index]
			local height = base_level
			if ground_1 > altitude_cutoff_high then
				height = height + (ground_1 - altitude_cutoff_high) / (div or 1)
			elseif ground_1 < altitude_cutoff_low then
				local g = altitude_cutoff_low - ground_1
				if g < altitude_cutoff_low_2 then
					g = g * g * 0.01
				else
					g = (g - altitude_cutoff_low_2) * 0.5 + 40
				end
				height = height - g / (div or 1)
			end

			height = math_floor(height + 0.5)
			heightmap[index] = height
			height_max = math_max(ground_1, height_max)
			height_min = math_min(ground_1, height_min)

			index = index + 1
		end
	end

	self.height_min = height_min
	self.height_max = height_max

	if (math_max(altitude_cutoff_high, height_max) - altitude_cutoff_high)
	- (math_min(altitude_cutoff_low, height_min) - altitude_cutoff_low) < 3 then
		self.flattened = true
	end
end
--]]


-- check
local road_w = 3
function DFlat_Mapgen:map_roads()
	local csize = self.csize
	local roads = {}
	local tracks = {}
	local has_roads = false

	local index
	local road_ws = road_w * road_w
	for x = -road_w, csize.x + road_w - 1 do
		index = x + road_w + 1
		local l_road = self.noise['road_1'].map[index]
		for z = -road_w, csize.z + road_w - 1 do
			local road_1 = self.noise['road_1'].map[index]
			if (l_road < 0) ~= (road_1 < 0) then
				local index2 = z * csize.x + x + 1
				if make_tracks then
					tracks[index2] = true
				end
				for zo = -road_w, road_w do
					local zos = zo * zo
					for xo = -road_w, road_w do
						if x + xo >= 0 and x + xo < csize.x
						and z + zo >= 0 and z + zo < csize.z then
							if xo * xo + zos < road_ws then
								roads[index2 + zo * csize.x + xo] = true
								has_roads = true
							end
						end
					end
				end
			end
			l_road = road_1
			index = index + csize.x + road_w * 2
		end
	end

	-- Mark the road locations.
	index = 1
	for z = -road_w, csize.z + road_w - 1 do
		local l_road = self.noise['road_1'].map[index]
		for x = -road_w, csize.x + road_w - 1 do
			local road_1 = self.noise['road_1'].map[index]
			if (l_road < 0) ~= (road_1 < 0) then
				local index2 = z * csize.x + x + 1
				if make_tracks then
					tracks[index2] = true
				end
				for zo = -road_w, road_w do
					local zos = zo * zo
					for xo = -road_w, road_w do
						if x + xo >= 0 and x + xo < csize.x and z + zo >= 0 and z + zo < csize.z then
							if xo * xo + zos < road_ws then
								roads[index2 + zo * csize.x + xo] = true
								has_roads = true
							end
						end
					end
				end
			end
			l_road = road_1
			index = index + 1
		end
	end

	if make_tracks then
		for z = -1, csize.z + 1 do
			for x = -1, csize.x + 1 do
				index = z * csize.x + x + 1
				if tracks[index] then
					for zo = -1, 1 do
						for xo = -1, 1 do
							local index2 = (z + zo) * csize.x + (x + xo) + 1
							if tracks[index2] then
								if xo == 0 and zo == 0 then
									-- nop
								elseif math_abs(xo) == math_abs(zo) then
									local index3 = (z + 0) * csize.x + (x + xo) + 1
									local index4 = (z + zo) * csize.x + (x + 0) + 1
									if tracks[index3] or tracks[index4] then
										-- nop
									else
										tracks[index3] = true
									end
								end
							end
						end
					end
				end
			end
		end
	end

	self.has_roads = has_roads
	self.roads = roads
	self.tracks = tracks
end


function DFlat_Mapgen:mark_plots()
	local csize = self.csize
	local base_level = self.base_level  -- Figure from height?
	local plots = {}
	local roads = self.roads

	-- Generate plots for constructions.
	for _ = 1, 15 do
		local scale = self.gpr:next(1, 2) * 4
		local size = VN(self.gpr:next(1, 2), 1, self.gpr:next(1, 2))
		size.x = size.x * scale + 9
		size.y = size.y * 8
		size.z = size.z * scale + 9

		for _ = 1, 10 do
			local pos = VN(self.gpr:next(2, csize.x - size.x - 3), base_level, self.gpr:next(2, csize.z - size.z - 3))
			local good = true
			for _, box in pairs(plots) do
				if box.pos.x + box.size.x < pos.x
				or pos.x + size.x < box.pos.x
				or box.pos.z + box.size.z < pos.z
				or pos.z + size.z < box.pos.z then
					-- nop
				else
					good = false
					break
				end
			end
			for z = pos.z, pos.z + size.z do
				for x = pos.x, pos.x + size.x do
					local index = z * csize.x + x + 1
					if roads[index] then
						good = false
						break
					end
				end
				if not good then
					break
				end
			end
			if good then
				pos.y = pos.y - 2
				table.insert(plots, {
					pos = vector.add(pos, 2),
					size = vector.add(size, -4)
				})
				break
			end
		end
	end

	self.plots = plots
end


function DFlat_Mapgen:place_puzzles()
	local width = 7
	local geo = Geomorph.new()

	for _, puz in pairs(self.puzzle_boxes) do
		local pos = vector.add(puz.pos, -1)
		pos.y = pos.y + 4
		local size = vector.add(puz.size, 2)
		geo:add({
			action = 'cube',
			node = 'air',
			clear_up = 13,
			location = pos,
			size = size,
		})

		pos = table.copy(puz.pos)
		pos.y = pos.y + 4
		geo:add({
			action = 'puzzle',
			chance = 1,
			clear_up = 13,
			location = pos,
			size = VN(width, width, width),
		})

		-- Only the first.
		--break
	end
	geo:write_to_map(self, 0)
end


local planet_biomes = {
	'taiga',
	'icesheet',
	'desert',
	'rainforest',
	'snowy_grassland',
	'savanna',
	'coniferous_forest',
	'cold_desert',
	'deciduous_forest',
	'sandstone_desert',
	'grassland',
}

local stone_types = {
	{'default:cobble', 'default:stonebrick', 'default:stone', 'default:stoneblock'},
	{'default:desert_cobble', 'default:desert_stonebrick', 'default:desert_stone', 'default:desert_stone_block'},
	{'default:sandstonebrick', 'default:sandstonebrick', 'default:sandstone', 'default:sandstone_block'},
	{'default:desert_sandstone_brick', 'default:desert_sandstone_brick', 'default:desert_sandstone', 'default:desert_sandstone_block'},
	{'default:silver_sandstone_brick', 'default:silver_sandstone_brick', 'default:silver_sandstone', 'default:silver_sandstone_block'},
}

-- check
function DFlat_Mapgen:planets()
	local ring_jump = 3

	local minp, maxp = self.minp, self.maxp
	local csize, area = self.csize, self.area
	local data, p2data = self.data, self.p2data
	local heightmap = self.heightmap
	local biomemap = self.biomemap
	local ystride = area.ystride
	local biomes = mod.biomes
	local pr = self.gpr
	local sphere_count = pr:next(0, 1) + pr:next(0, 1)
	if sphere_count < 1 then
		return
	end
	local geo = Geomorph.new()
	local a, b, c, st

	local biome_name = planet_biomes[self.gpr:next(1, #planet_biomes)]
	local biome = biomes[biome_name] or {}
	self.biome = biome
	local b_stone = biome.node_stone or 'default:stone'

	for _ = 1, sphere_count do
		local sphere_size = pr:next(3, 10) + pr:next(3, 10)
		a = pr:next(0, csize.x-sphere_size-1)
		b = pr:next(0, csize.y-sphere_size-1)
		c = pr:next(0, csize.z-sphere_size-1)
		st = pr:next(0, 5)

		if st == 0 or st == 4 then
			a = pr:next(9, csize.x-sphere_size-10)
			b = pr:next(9, csize.y-sphere_size-10)
			c = pr:next(9, csize.z-sphere_size-10)
			local ring_size = math_floor(16 / 5)

			for i = ring_size, 0, -1 do
				local stone = stone_types[pr:next(1, 5)][3]
				geo:add({
					action = 'cylinder',
					node = stone,
					location = VN(a - ring_jump - i,
						b + math_floor(sphere_size / 2),
						c - ring_jump - i),
					size = VN(sphere_size + ring_jump * 2 + 2 * i,
						1, sphere_size + ring_jump * 2 + 2 * i),
					axis = 'y',
				})
			end

			geo:add({
				action = 'cylinder',
				node = 'air',
				location = VN(a - ring_jump + 1,
					b + math_floor(sphere_size / 2),
					c - ring_jump + 1),
				size = VN(sphere_size + 2 * (ring_jump - 1),
					1, sphere_size + 2 * (ring_jump - 1)),
				axis = 'y',
			})
		end

		if st < 4 then
			if biome.node_filler then
				geo:add({
					action = 'sphere',
					node = biome.node_filler,
					location = VN(a, b, c),
					size = VN(sphere_size, sphere_size, sphere_size),
				})
			end
			geo:add({
				action = 'sphere',
				node = b_stone,
				location = VN(a+2, b, c+2),
				size = VN(sphere_size-4, sphere_size-4, sphere_size-4)
			})
		elseif st == 4 then
			geo:add({
				action = 'sphere',
				node = mod_name..':weightless_water',
				location = VN(a, b, c),
				size = VN(sphere_size, sphere_size, sphere_size)
			})
		elseif st == 5 then
			sphere_size = math_floor((sphere_size + 4) / 2)
			geo:add({
				action = 'sphere',
				node = mod_name..':weightless_lava',
				location = VN(a, b, c),
				size = VN(sphere_size, sphere_size, sphere_size)
			})
		end
	end

	geo:write_to_map(self)

	local n_top = node[biome.node_top or 'default:dirt_with_grass']
	local n_filler = node[biome.node_filler or 'default:dirt']

	local index = 1
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			biomemap[index] = biome
			self.biomes_here[biome.name] = true
			local ivm = area:index(x, maxp.y, z)
			local found_top

			for y = maxp.y, minp.y, -1 do
				if not found_top and data[ivm] == n_filler then
					if y - minp.y < 60 then
						heightmap[index] = y
					end
					data[ivm] = n_top
					p2data[ivm] = 0
					found_top = true
				end

				ivm = ivm - ystride
			end

			index = index + 1
		end
	end
end


function DFlat_Mapgen:prepare()
	local minp, maxp = self.minp, self.maxp
	local chunk_offset = self.chunk_offset
	local water_level = self.water_level

	self.gpr = PcgRandom(self.seed + 5107)

	if self.div then
		self.biome = mod.biomes['ether']
	else
		self.biome = nil
	end

	local base_level = self.water_level + water_diff
	if self.div then
		base_level = self.water_level + 1
	end
	self.base_level = base_level

	local base_heat = 20 + math_abs(70 - ((((minp.z + chunk_offset + 1000) / 6000) * 140) % 140))
	self.base_heat = base_heat

	---------------------------------------
	-- Separate mapgen?
	---------------------------------------
	local ground = (maxp.y >= water_level and minp.y <= water_level)
	if ground then
		self:map_roads()
		self:mark_plots()
	end
	---------------------------------------
end


-- check
function DFlat_Mapgen:simple_ruin()
	if not self.flattened then
		return
	end

	local csize = self.csize
	local heightmap = self.heightmap
	local base_level = self.base_level
	local boxes = {}

	for _ = 1, 15 do
		local scale = self.gpr:next(2, 3) * 4
		local size = VN(self.gpr:next(1, 3), 1, self.gpr:next(1, 3))
		size.x = size.x * scale + 5
		size.y = size.y * 8
		size.z = size.z * scale + 5

		for _ = 1, 10 do
			local pos = VN(self.gpr:next(1, csize.x - size.x - 2), base_level, self.gpr:next(1, csize.z - size.z - 2))
			local good = true
			for _, box in pairs(boxes) do
				if box.pos.x + box.size.x < pos.x or pos.x + size.x < box.pos.x
				or box.pos.z + box.size.z < pos.z or pos.z + size.z < box.pos.z then
					-- nop
				else
					good = false
					break
				end
			end
			if good then
				table.insert(boxes, { pos = pos, size = size })
				break
			end
		end
	end
	local geo = Geomorph.new()
	local stone = 'default:sandstone'
	for _, box in pairs(boxes) do
		local pos = table.copy(box.pos)
		local size = table.copy(box.size)

		for z = pos.z, pos.z + size.z do
			local index = z * csize.x + pos.x + 1
			for _ = pos.x, pos.x + size.x do
				heightmap[index] = base_level
				index = index + 1
			end
		end

		-- foundation
		pos.y = pos.y - 2
		size.y = 3
		geo:add({
			action = 'cube',
			node = stone,
			location = pos,
			size = size,
		})

		pos = table.copy(pos)
		pos.y = pos.y + 3
		size = table.copy(size)
		size.y = 1
		geo:add({
			action = 'cube',
			node = 'air',
			location = pos,
			size = size,
		})

		box.pos.x = box.pos.x + 2
		box.pos.z = box.pos.z + 2
		box.size.x = box.size.x - 4
		box.size.z = box.size.z - 4

		pos = table.copy(box.pos)
		pos.y = pos.y + 8
		size = table.copy(box.size)
		size.y = 1
		geo:add({
			action = 'cube',
			node = stone,
			location = pos,
			size = size,
		})
		pos = vector.add(box.pos, 1)
		pos.y = pos.y + 8
		size = vector.add(box.size, -2)
		size.y = 1
		geo:add({
			action = 'cube',
			node = stone,
			location = pos,
			size = size,
		})
		pos = table.copy(pos)
		pos.y = pos.y - 1
		geo:add({
			action = 'cube',
			node = 'air',
			location = pos,
			size = size,
		})
		local pool = 14
		if box.size.x > pool and box.size.z > pool then
			pos = vector.add(box.pos, (pool / 2) - 1)
			pos.y = box.pos.y + 1
			size = vector.add(box.size, -(pool - 2))
			size.y = 1
			geo:add({
				action = 'cube',
				node = stone,
				location = pos,
				size = size,
			})
			pos = vector.add(box.pos, pool / 2)
			pos.y = box.pos.y + 1
			size = vector.add(box.size, -pool)
			size.y = 1
			geo:add({
				action = 'cube',
				node = 'default:water_source',
				location = pos,
				size = size,
			})
		end

		for z = box.pos.z, box.pos.z + box.size.z, 4 do
			for x = box.pos.x, box.pos.x + box.size.x, 4 do
				if x == box.pos.x or x == box.pos.x + box.size.x - 1
				or z == box.pos.z or z == box.pos.z + box.size.z - 1 then
					geo:add({
						action = 'cube',
						node = stone,
						location = VN(x, box.pos.y, z),
						size = VN(1, box.size.y, 1),
					})
				end
			end
		end
	end
	geo:write_to_map(self)

	return true
end


-----------------------------------------------
-- Register the mapgen(s)
-----------------------------------------------


do
	local terrain_scale = 100

	local ether_div = 8
	local max_chunks = layer_mod.max_chunks
	local max_chunks_ether = math_floor(layer_mod.max_chunks / ether_div)

	local noises = {
		['ground'] = { def = {offset = 0, scale = terrain_scale, seed = 4382, spread = {x = 320, y = 320, z = 320}, octaves = 6, persist = 0.5, lacunarity = 2.0} },
		['ground_ether'] = { def = {offset = 0, scale = terrain_scale, seed = 4382, spread = {x = 40, y = 40, z = 40}, octaves = 6, persist = 0.5, lacunarity = 2.0} },
		['road_1'] = { def = {offset = 0, scale = terrain_scale, seed = 4382, spread = {x = 320, y = 320, z = 320}, octaves = 3, persist = 0.5, lacunarity = 2.0} },
		['heat_2'] = { def = {offset = 0, scale = 4, seed = 5349, spread = {x = 10, y = 10, z = 10}, octaves = 3, persist = 0.5, lacunarity = 2} },
		['humidity_1'] = { def = {offset = 50, scale = 50, seed = 842, spread = {x = 1000, y = 1000, z = 1000}, octaves = 3, persist = 0.5, lacunarity = 2} },
		['humidity_2'] = { def = {offset = 0, scale = 1.5, seed = 90003, spread = {x = 8, y = 8, z = 8}, octaves = 2, persist = 1.0, lacunarity = 2} },
		['erosion'] = { def = {offset = 0, scale = 1.5, seed = -47383, spread = {x = 8, y = 8, z = 8}, octaves = 2, persist = 1.0, lacunarity = 2} },
		['flat_cave_1'] = { def = {offset = 0, scale = 10, seed = 6386, spread = {x = 23, y = 23, z = 23}, octaves = 3, persist = 0.7, lacunarity = 1.8} },
		['cave_heat'] = { def = {offset = 50, scale = 50, seed = 1578, spread = {x = 200, y = 200, z = 200}, octaves = 3, persist = 0.5, lacunarity = 2} },
	}

	local e_noises = table.copy(noises)
	e_noises.ground.def.spread = vector.divide(e_noises.ground.def.spread, ether_div)


	layer_mod.register_map({
		name = 'zero',
		biomes = 'default',
		mapgen = DFlat_Mapgen,
		mapgen_name = 'dflat',
		minp = VN(-max_chunks, -20, -max_chunks),
		maxp = VN(max_chunks, 15, max_chunks),
		noises = noises,
		params = {},
		water_level = 1,
	})

	layer_mod.register_map({
		name = 'ether',
		biomes = 'ether',
		mapgen = DFlat_Mapgen,
		mapgen_name = 'dflat',
		minp = VN(-max_chunks_ether, -360, -max_chunks_ether),
		maxp = VN(max_chunks_ether, -350, max_chunks_ether),
		noises = e_noises,
		params = { div = ether_div },
		water_level = -28400,
	})
end
