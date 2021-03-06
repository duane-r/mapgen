-- Duane's mapgen planets.lua
-- Copyright Duane Robertson (duane@duanerobertson.com), 2019
-- Distributed under the LGPLv2.1 (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)


local layer_mod = mapgen
local mod = mapgen
local mod_name = 'mapgen'

local Geomorph = geomorph.Geomorph

local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_pi = math.pi
local math_sin = math.sin
local node = layer_mod.node
local VN = vector.new


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


do
	local newnode = layer_mod.clone_node('default:water_source')
	newnode.description = 'Water'
	newnode.drop = 'default:water_source'
	newnode.liquid_range = 0
	newnode.liquid_viscosity = 1
	newnode.liquid_renewable = false
	newnode.liquid_alternative_flowing = mod_name..':weightless_water'
	newnode.liquid_alternative_source = mod_name..':weightless_water'
	minetest.register_node(mod_name..':weightless_water', newnode)

	if bucket and bucket.liquids then
		bucket.liquids[mod_name..':weightless_water'] = {
			source = mod_name..':weightless_water',
			flowing = mod_name..':weightless_water',
			itemname = 'bucket:bucket_water',
		}
	end

	newnode = layer_mod.clone_node('default:lava_source')
	newnode.description = 'Lava'
	newnode.drop = 'default:lava_source'
	newnode.sunlight_propagates = true
	newnode.liquid_range = 0
	newnode.liquid_viscosity = 1
	newnode.liquid_renewable = false
	newnode.liquid_alternative_flowing = mod_name..':weightless_lava'
	newnode.liquid_alternative_source = mod_name..':weightless_lava'
	minetest.register_node(mod_name..':weightless_lava', newnode)

	if bucket and bucket.liquids then
		bucket.liquids[mod_name..':weightless_lava'] = {
			source = mod_name..':weightless_lava',
			flowing = mod_name..':weightless_lava',
			itemname = 'bucket:bucket_lava',
		}
	end
end


-----------------------------------------------
-- Planets_Mapgen class
-----------------------------------------------

local Planets_Mapgen = layer_mod.subclass_mapgen()


function Planets_Mapgen:_init()
	self.biomemap = {}
	self.heatmap = {}
	self.humiditymap = {}
end


-- check
function Planets_Mapgen:generate()
	-- Geomorph requires this.
	self.gpr = PcgRandom(self.seed + 4563)

	local minp, maxp = self.minp, self.maxp
	local water_level = self.water_level
	local height_max = self.share.height_max
	if self.share.disruptive or (height_max and math_max(water_level, height_max) > minp.y) then
		return
	end

	local ring_jump = 3

	local csize, area = self.csize, self.area
	local data, p2data = self.data, self.p2data
	local heightmap = self.heightmap
	local biomemap = self.biomemap
	local ystride = area.ystride
	local biomes = self.biomes
	local pr = self.gpr
	local sphere_count = pr:next(0, 1) + pr:next(0, 1)
	if sphere_count < 1 then
		return
	end
	local geo = Geomorph.new()
	local a, b, c, st

	local biome_name = planet_biomes[self.gpr:next(1, #planet_biomes)]
	local biome = biomes[biome_name] or {}
	self.biomes_here[biome.name] = true
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


-----------------------------------------------
-- Register the mapgen(s)
-----------------------------------------------


do
	local max_chunks = layer_mod.max_chunks

	layer_mod.register_map({
		name = 'planets',
		biomes = 'default',
		mapgen = Planets_Mapgen,
		mapgen_name = 'planets',
		map_minp = VN(-max_chunks, 2, -max_chunks),
		map_maxp = VN(max_chunks, 5, max_chunks),
		water_level = 1,
	})

	layer_mod.register_map({
		name = 'planets',
		biomes = 'default',
		mapgen = Planets_Mapgen,
		mapgen_name = 'planets',
		map_minp = VN(-max_chunks, 11, -max_chunks),
		map_maxp = VN(max_chunks, 40, max_chunks),
		water_level = 1,
	})

	layer_mod.register_map({
		name = 'planets',
		biomes = 'default',
		mapgen = Planets_Mapgen,
		mapgen_name = 'planets',
		map_minp = VN(-max_chunks, 70, -max_chunks),
		map_maxp = VN(max_chunks, 90, max_chunks),
		water_level = 2400,
	})
end
