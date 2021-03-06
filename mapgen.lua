-- Duane's mapgen mapgen.lua
-- Copyright Duane Robertson (duane@duanerobertson.com), 2019
-- Distributed under the LGPLv2.1 (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)


local DEBUG
local mod = mapgen
local mod_name = 'mapgen'

local VN = vector.new
local chunksize = tonumber(minetest.settings:get('chunksize') or 5)


if minetest.get_modpath('realms') then
	return
end


local dir_to_yaw = minetest.dir_to_yaw
local dir_to_wallmounted = minetest.dir_to_wallmounted
local wallmounted_to_dir = minetest.wallmounted_to_dir
local yaw_to_dir = minetest.yaw_to_dir
local math_pi = math.pi
local wallmounted = mod.wallmounted

mod.buildable_to = {}
mod.grass_nodes = {}
mod.liquids = {}
mod.registered_realms = {}

local m_data = {}
local m_p2data = {}

-- blocks that are completely symmetrical
mod.no_rotate = {
	['default:cobble'] = true,
	['default:desert_stone_block'] = true,
	['default:desert_stonebrick'] = true,
	['default:lava_source'] = true,
	['default:mossycobble'] = true,
	['default:obsidian'] = true,
	['default:sandstone_block'] = true,
	['default:sandstonebrick'] = true,
	['default:stone_block'] = true,
	['default:stonebrick'] = true,
	['default:stone'] = true,
	['default:water_source'] = true,
	[mod_name .. ':ruined_carpet_1'] = true,
}
local no_rotate = mod.no_rotate

--------------------------------------------------------------
--Values range 0 - 23
--facedir / 4 = axis direction:
--0 = y+	1 = z+	2 = z-	3 = x+	4 = x-	5 = y-

-- tables of rotation values for rotating schematics
local drotn = {[0]=3, 0, 1, 2, 19, 16, 17, 18, 15, 12, 13, 14, 7, 4, 5, 6, 11, 8, 9, 10, 21, 22, 23, 20}

--facedir modulo 4 = rotation around that axis
local z_rots = {
	{[0] = 12, [7] = 4, [9] = 8, [12] = 0, [18] = 20 },
	{[0] = 20, [7] = 4, [9] = 8, [12] = 16, [18] = 12, },
	{[0] = 16, [7] = 4, [9] = 8, [12] = 0, [18] = 20 },
}

local rotated_schematics = {}
for _ = 1, 21 do
	table.insert(rotated_schematics, {})
end
--------------------------------------------------------------


mod.ores = {
	{ 'default:dirt', 0, },
	{ 'default:sand', 0, },
	{ 'default:gravel', 0, },
	{ 'default:clay', 1, },
	{ 'default:stone_with_coal', 1, },
	{ 'default:stone_with_iron', 2, },
	{ 'default:stone_with_gold', 3, },
	{ 'default:stone_with_diamond', 4, },
	{ 'default:stone_with_mese', 5, },
}

mod.default_ore_intersect = {
	'default:stone',
	'default:sandstone',
	'default:desert_stone',
	mod_name .. ':basalt',
	mod_name .. ':granite',
	mod_name .. ':stone_with_lichen',
	mod_name .. ':stone_with_algae',
	mod_name .. ':stone_with_moss',
	mod_name .. ':stone_with_salt',
	mod_name .. ':hot_rock',
	--mod_name .. ':sunny_stone',
}


-- table of node types to be dusted
mod.dusty_types = {
	normal = true,
	allfaces_optional = true,
	glasslike_framed_optional = true,
	glasslike = true,
	glasslike_framed = true,
	allfaces = true,
}


function mod.dust(params)
	local area, data, p2data = params.area, params.data, params.p2data
	local minp, maxp = params.chunk_minp, params.chunk_maxp
	local water_level = params.sealevel

	local n_ignore = mod.node['ignore']
	local n_air = mod.node['air']

	local index = 1
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local surface = params.share.surface[z][x]
			local height = surface.top or water_level or minp.y - 2
			local ivm = area:index(x, maxp.y - 1, z)

			local biome = params.share.biome or surface.biome or {}

			local n_dust
			if biome then
				n_dust = mod.node[biome.node_dust]
			end

			if n_dust and data[ivm] == n_air then
				local yc
				for y = maxp.y - 0, minp.y + 0, -1 do
					if y >= height and data[ivm] ~= n_air and data[ivm] ~= n_ignore then
						yc = y
						break
					end

					ivm = ivm - area.ystride
				end

				if yc then
					local name = minetest.get_name_from_content_id(data[ivm])
					local n = minetest.registered_nodes[name]
					if data[ivm] == n_ignore
					or (
						n and (not n.drawtype or mod.dusty_types[n.drawtype])
						and (n.walkable ~= false or (n.groups and n.groups.leaves))
					) then
						ivm = ivm + area.ystride
						data[ivm] = n_dust
						p2data[ivm] = 0
					end
				end
			end

			index = index + 1
		end
	end
end


-------------------------------------------------
-- Finds a place to put decorations with the all_floors,
--  all_ceilings, or liquid_surface flags.
-------------------------------------------------

local y_s = {}
function mod.find_break(params, x, z, flags, gpr)
	local minp, maxp = params.chunk_minp, params.chunk_maxp
	local data, area = params.data, params.area
	local ystride = params.area.ystride
	local buildable_to = mod.buildable_to

	local n_air = mod.node['air']

	for k in pairs(y_s) do
		y_s[k] = nil
	end

	if flags.liquid_surface then
		local ivm = area:index(x, maxp.y, z)
		for y = maxp.y, minp.y + 1, -1 do
			if data[ivm] ~= n_air then
				return
			end
			if mod.liquids[data[ivm - ystride]] then
				return (y - minp.y - 1)
			end
			ivm = ivm - ystride
		end
	end

	if flags.all_ceilings then
		local ivm = area:index(x, minp.y, z)
		for y = minp.y, maxp.y - 1 do
			if buildable_to[data[ivm]] and not buildable_to[data[ivm + ystride]] then
				if data[ivm] == n_air or flags.force_placement then
					table.insert(y_s, -(y - minp.y + 1))
				end
			end
			ivm = ivm + ystride
		end
	end

	if flags.all_floors then
		-- Don't check heightmap. It doesn't work in bubble caves.
		local ivm = area:index(x, maxp.y, z)
		for y = maxp.y, minp.y + 1, -1 do
			if buildable_to[data[ivm]] and not buildable_to[data[ivm - ystride]] then
				if data[ivm] == n_air or flags.force_placement then
					table.insert(y_s, y - minp.y - 1)
				end
			end
			ivm = ivm - ystride
		end
	end

	if #y_s > 0 then
		return y_s[gpr:next(1, #y_s)]
	end
end


function mod.generate_all(params)
	--mod.make_stone_layer_noise()  -- This isn't always needed.

	local realms = {}
	for _, realm in pairs(mod.registered_realms) do
		-- This won't necessarily find realms smaller than a chunk.
		local isect_minp, isect_maxp = mod.cube_intersect(
			{minp = params.chunk_minp, maxp = params.chunk_maxp},
			{minp = realm.realm_minp, maxp = realm.realm_maxp}
		)
		if isect_minp and isect_maxp then
			local r_copy = table.copy(realm)
			local fp = mod.mapgen_forced_params[realm.mapgen]
			if fp and fp['full_chunk'] then
				r_copy.isect_minp = params.chunk_minp
				r_copy.isect_maxp = params.chunk_maxp
			else
				r_copy.isect_minp = isect_minp
				r_copy.isect_maxp = isect_maxp
			end
			table.insert(realms, r_copy)
		end
	end

	if #realms < 1 then
		return
	end

	local vm, emin, emax
	if params.genesis_redo then
		vm = minetest.get_voxel_manip()
		emin, emax = vm:read_from_map(params.chunk_minp, params.chunk_maxp)
	else
		vm, emin, emax = minetest.get_mapgen_object('voxelmanip')
	end

	if not (vm and emin and emax) then
		--print(vm, emin, emax)
		return
	end

	params.area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	params.csize = vector.add(vector.subtract(params.chunk_maxp, params.chunk_minp), 1)
	params.data = vm:get_data(m_data)
	params.gpr = PcgRandom(params.chunk_seed + 772)
	params.metadata = {}
	params.node = mod.node
	params.p2data = vm:get_param2_data(m_p2data)
	params.schematics = {}
	params.share = {}
	params.share.propagate_shadow = false
	params.share.biomes_here = {}
	params.vmparam2 = params.p2data
	params.vm = vm

	-- This has to be done after the game starts.
	mod.populate_node_arrays()

	--params.biomemaps = {}
	local r_params_list = {}
	for _, realm in pairs(realms) do
		local t_terrain = os.clock()
		local r_params = realm
		table.insert(r_params_list, r_params)

		for k, v in pairs(params) do
			r_params[k] = v
		end

		----------------------------------------------------
		-- This fixes the mapgen v7 ridges bug, but it
		--  could cause serious problems.
		----------------------------------------------------
		-- Example:
		--  mapseed = jeffries
		--  static_spawnpoint = -1242,447,3677
		----------------------------------------------------
		r_params.overgen = realm.overgen or 0
		if vector.equals(r_params.isect_minp, params.chunk_minp) then
			r_params.isect_minp.y = r_params.isect_minp.y - r_params.overgen
		end
		if vector.equals(r_params.isect_maxp, params.chunk_maxp) then
			r_params.isect_maxp.y = r_params.isect_maxp.y + r_params.overgen
		end
		----------------------------------------------------

		r_params.csize = vector.add(vector.subtract(r_params.isect_maxp, r_params.isect_minp), 1)

		-----------------------------------------
		-- Fix this!
		-----------------------------------------
		r_params.realm_seed = r_params.map_seed
		-----------------------------------------

		mod.registered_mapgens[realm.mapgen](r_params)
		mod.time_terrain = mod.time_terrain + os.clock() - t_terrain
	end

	if not (params.share.no_biome or params.no_biome) then
		local called_bfuncs = {}
		local any_bfunc
		for _, r_params in pairs(r_params_list) do
			if r_params.biomefunc and not called_bfuncs[r_params.biomefunc] then
				local t_terrain = os.clock()
				mod.rmf[r_params.biomefunc](r_params)
				called_bfuncs[r_params.biomefunc] = true
				mod.time_terrain = mod.time_terrain + os.clock() - t_terrain
				any_bfunc = true
			end

			-- a special case to handle floaters' caves
			if not any_bfunc or r_params.cave_biomes then
				local nm = 'bm_fun_caves_biomes'
				if mod.rmf[nm] and not called_bfuncs[nm] then
					local t_terrain = os.clock()
					mod.rmf[nm](r_params)
					called_bfuncs[nm] = true
					mod.time_terrain = mod.time_terrain + os.clock() - t_terrain
				end
			end
		end

		if not params.no_decorations then
			mod.place_all_decorations(params)

			if not params.share.no_dust then
				mod.dust(params)
			end
		end
	end

	mod.save_map(params)
	mod.chunks = mod.chunks + 1
end


function mod.generate(minp, maxp, seed)
	if not (minp and maxp and seed) then
		minetest.log(mod_name..': generate did not receive minp, maxp, and seed. Aborting.')
		return
	end

	if not mod.map_seed then
		-- This is not the same mapseed minetest provides.
		-- See mod.generate_map_seed for details.
		mod.map_seed = mod.generate_map_seed()
		--minetest.log(mod_name..': starting with map_seed = 0x' .. string.format('%x', mod.map_seed))
	end

	-- This is not the same blockseed minetest provides. The
	-- latter is hard to duplicate in lua, so I just make my own.
	local blockseed = mod.generate_block_seed(minp)

	local params = {
		chunk_minp = minp,
		chunk_maxp = maxp,
		chunk_csize = vector.add(vector.subtract(maxp, minp), 1),
		chunk_seed = blockseed,
		real_chunk_seed = seed,
		map_seed = mod.map_seed,
	}
	mod.generate_all(params)

	local mem = math.floor(collectgarbage('count')/1024)
	if mem > 200 then
		minetest.log(mod_name .. ': Lua Memory: ' .. mem .. 'M')
	end
end


function mod.generate_block_seed(minp, map_seed)
	local seed = tonumber(map_seed or mod.map_seed)
	local data = {}

	while seed > 0 do
		table.insert(data, seed % 256)
		seed = math.floor(seed / 256)
	end

	for _, axis in pairs({'x', 'y', 'z'}) do
		table.insert(data, math.floor(minp[axis] + mod.max_height) % 256)
		table.insert(data, math.floor((minp[axis] + mod.max_height) / 256))
	end

	return math.fnv1a(data)
end


function mod.generate_map_seed()
	-- I use the fixed_map_seed by preference, since minetest 5.0.1
	--  gives the wrong seed to lua when a text map seed is used.
	-- By wrong, I mean that it doesn't match the seed used in the
	--  C code (the one displayed when you hit F5).

	local map_seed = minetest.get_mapgen_setting('fixed_map_seed')
	if map_seed == '' then
		return minetest.get_mapgen_setting('seed')
	else
		-- Just convert each letter into a byte of data.
		local bytes = {map_seed:byte(1, math.min(8, map_seed:len()))}
		local seed = 0
		local i = 1
		for _, v in pairs(bytes) do
			seed = seed + v * i
			i = i * 256
		end
		return seed
	end
end


function mod.get_ore(gpr, chunk_depth)
	local oren = 0
	for _, i in pairs(mod.ores) do
		if chunk_depth >= (i[2] or 0) then
			oren = oren + 1
		end
	end

	-- This assumes that the ores table is sorted.
	return mod.ores[gpr:next(1, oren)][1]
end


function mod.main()
	-- If on my system, it's ok to crash.
	local f = io.open(mod.path..'/duane', 'r')
	if f then
		minetest.log(mod_name .. ': Running without safety measures...')
	else
		mod.use_pcall = true
	end


	if mod.read_configuration_file() then
		if minetest.registered_on_generateds then
			-- This is unsupported. I haven't been able to think of an alternative.
			table.insert(minetest.registered_on_generateds, 1, mod.pgenerate)
		else
			minetest.register_on_generated(mod.pgenerate)
		end
	end
end


function mod.parse_configuration_file_line(line, lineno)
	if line:match('^#') then
		return
	end

	local fields = {}
	for f in line:gmatch('([^|]+)%|?') do
		local s = f:gsub('%s+', '')
		table.insert(fields, s)
	end
	local error_line = mod_name .. ': * bad realms.conf, line #' .. lineno .. ': ' .. line

	if #fields <= 1 then
		return
	elseif #fields < 8 then
		minetest.log(error_line)
		minetest.log(mod_name .. ':   missing items (should be 8+, separated by |)')
		return
	end

	if not mod.registered_mapgens[fields[1] ] then
		fields[1] = fields[1]:gsub('[^%a%d%_]+', '')
		local file_name = mod.path .. '/' .. fields[1] .. '.lua'
		local f = io.open(file_name, 'r')
		if f then
			f:close()
			dofile(file_name)
		end
	end

	if not mod.registered_mapgens[fields[1] ] then
		--minetest.log(error_line)
		minetest.log(mod_name .. ':   ' .. fields[1] .. ' is not a registered mapgen.')
		return
	end

	for i = 2, 8 do
		local s = fields[i]
		fields[i] = tonumber(fields[i])
		if not fields[i] then
			minetest.log(error_line)
			minetest.log(mod_name .. ':   ' .. s .. ' is not a number.')
			return
		end
	end

	if not mod.registered_mapfuncs[fields[9] ] then
		fields[9] = fields[9]:gsub('[^%a%d%_]+', '')
		local file_name = mod.path .. '/' .. fields[9] .. '.lua'
		local f = io.open(file_name, 'r')
		if f then
			f:close()
			dofile(file_name)
		end
	end

	if not mod.registered_mapfuncs[fields[9] ] then
		fields[9] = nil
	end

	for i = 10, #fields do
		local a, b = fields[i]:match('%s*([%a%d_]+)%s*=%s*([%a%d_]+)')
		if tonumber(b) then
			b = tonumber(b)
		end
		if a and b then
			fields[i] = { a, b }
		else
			local c = fields[i]:match('%s*([%a%d_]+)')
			if c then
				fields[i] = { c }
			end
		end
	end

	return fields
end


function mod.pgenerate(...)
	local status, err

	local t_all = os.clock()
	if mod.use_pcall then
		status, err = pcall(mod.generate, ...)
	else
		status = true
		mod.generate(...)
	end
	mod.time_all = mod.time_all + os.clock() - t_all

	if not status then
		minetest.log(mod_name .. ': Could not generate terrain:')
		minetest.log(dump(err))
		collectgarbage('collect')
	end
end


function mod.place_all_decorations(params, do_not_scan)
	local t_deco = os.clock()

	--local minp, maxp = params.isect_minp, params.isect_maxp
	local minp, maxp = params.chunk_minp, params.chunk_maxp
	local ps = PcgRandom(params.chunk_seed + 53)
	local biome = params.biome or params.share.biome
	local by = minp.y - (params.biome_height_offset or 0)

	for _, deco in pairs(mod.registered_decorations) do
		local b_check
		if deco.biomes then
			for b in pairs(deco.biomes_i) do
				if (biome and b == biome.name) or params.share.biomes_here[b] then
					b_check = true
					break
				end
			end
		else
			b_check = true
		end

		if b_check and not (
			deco.bad_schem
			or (deco.max_y and deco.max_y < by)
			or (deco.min_y and deco.min_y > by - minp.y + maxp.y)
		) then
			mod.place_deco(params, ps, deco, do_not_scan)
		end
	end

	mod.time_deco = mod.time_deco + os.clock() - t_deco
end


-- check
--function mod.place_deco(params, ps, deco, do_not_scan)
function mod.place_deco(params, ps, deco)
    local data, p2data, vm_area = params.data, params.p2data, params.area
    local minp, maxp = params.chunk_minp, params.chunk_maxp
    local schem = params.schematics
	--local biomemap = params.biomemap
	local ystride = vm_area.ystride
	local node = mod.node
	--local scan = not do_not_scan
	local cave_water_level = params.share.cave_water_level

    local csize = params.csize
    local sidelen = deco.sidelen or csize.x

    if csize.x % sidelen ~= 0 then
        sidelen = csize.x
    end

    local divlen = csize.x / sidelen
    local area = sidelen * sidelen

    for z0 = 0, divlen-1 do
        for x0 = 0, divlen-1 do
            local center = {
                x=math.floor(minp.x + sidelen / 2 + sidelen * x0),
                z=math.floor(minp.z + sidelen / 2 + sidelen * z0),
            }
            local min = {
                x=minp.x + sidelen * x0,
                z=minp.z + sidelen * z0,
            }
            local max = {
                x=minp.x + sidelen + sidelen * x0 - 1,
                z=minp.z + sidelen + sidelen * z0 - 1,
            }

            local nval = (
				deco.noise_params
				and minetest.get_perlin(deco.noise_params):get_2d({x=center.x, y=center.z})
				or deco.fill_ratio
			)

            local deco_count = area * nval
            if deco_count > 1 then
                deco_count = math.floor(deco_count)
            elseif deco_count > 0 then
                if ps:next(1, 1000) <= deco_count * 1000 then
                    deco_count = 1
                else
                    deco_count = 0
                end
            end

            for _ = 1, deco_count do
                local x = ps:next(min.x, max.x)
				local y
                local z = ps:next(min.z, max.z)
				local upside_down
				local surface = params.share.surface[z][x]
				local by = -33000

                if deco.liquid_surface or deco.all_floors or deco.all_ceilings then
					y = mod.find_break(params, x, z, deco, ps)
					if y then
						if y < 0 then
							y = math.abs(y)
							upside_down = true
						end
						y = y + minp.y
						by = y - (params.biome_height_offset or 0)
					end
                elseif surface then
                    local fy = surface.top
					if fy >= minp.y and fy < maxp.y then
						y = fy
						by = surface.biome_height or surface.top or by
					end
                end

				if y and surface.cave_floor and surface.cave_ceiling then
					local in_cave = (y >= surface.cave_floor - 2 and y <= surface.cave_ceiling + 2)
					if deco.underground and not in_cave then
						y = nil
					--elseif not deco.underground and in_cave then
					--	y = nil
					end
				elseif y and deco.underground and surface.top and y > surface.top - 2 then
					y = nil
				end

				if y then
					local biome

					if surface.top and y < surface.top then
						biome = params.share.cave_biome or params.share.biome
					end

					biome = biome or surface.biome

					if biome or not deco.biomes_i then
						local ivm = vm_area:index(x, y, z)
						if ((not deco.place_on_i) or deco.place_on_i[data[ivm]])
						and ((not deco.biomes_i) or deco.biomes_i[biome.name])
						and (not cave_water_level or deco.aquatic or y > cave_water_level)
						and (not deco.y_max or deco.y_max >= by)
						and (not deco.y_min or deco.y_min <= by) then
							if upside_down then
								ivm = ivm - ystride
							else
								ivm = ivm + ystride
							end

							if deco.deco_type == 'schematic' then
								local too_close
								local size_s = deco.size_offset and ((deco.size_offset.x + 1) * (deco.size_offset.z + 1)) or 9

								for _, s in ipairs(schem) do
									local dx, dz = s.x - x, s.z - z
									if dx * dx + dz * dz <= size_s then
										too_close = true
										break
									end
								end

								------------------------------
								-- Check for spawnby nodes.
								------------------------------

								if (deco.force_placement or mod.buildable_to[data[ivm]]) and not too_close then
									local rot = ps:next(0, 3)
									local sch = deco.schematic_array or deco.schematic
									if upside_down then
										y = y - (deco.place_offset_y or 0) - sch.size.y + 1
										mod.place_schematic(params, sch, VN(x, y, z), deco.flags, ps, rot, 2)
									else
										y = y + (deco.place_offset_y or 0)
										mod.place_schematic(params, sch, VN(x, y, z), deco.flags, ps, rot)
									end
									schem[#schem+1] = VN(x, y, z)
								end
							elseif deco.force_placement or mod.buildable_to[data[ivm]] then
								local ht = ps:next(1, (deco.height_max or 1))
								local inc = 1
								if upside_down then
									ht = -ht
									inc = -1
								end
								if deco.place_offset_y then
									if upside_down then
										ivm = ivm - deco.place_offset_y * ystride
									else
										ivm = ivm + deco.place_offset_y * ystride
									end
								end
								local first_node = data[ivm]
								for _ = y, y + ht - inc, inc do
									local d = deco.decoration
									if type(d) == 'table' then
										d = deco.decoration[ps:next(1, #d)]
									end

									if type(d) == 'string' and (deco.force_placement or mod.buildable_to[data[ivm]]) then
										local grass_p2 = 0
										if mod.grass_nodes[d] then
											grass_p2 = p2data[ivm - ystride]
										end
										data[ivm] = node[d]
										if deco.param2_max then
											p2data[ivm] = ps:next(deco.param2, deco.param2_max)
										else
											p2data[ivm] = deco.param2 or grass_p2 or 0
										end
										if deco.random_color_floor_ceiling then
											if upside_down then
												p2data[ivm] = 0 + ps:next(0, 7) * 32
											else
												p2data[ivm] = 1 + ps:next(0, 7) * 32
											end
										end
									end

									ivm = ivm + ystride * inc
									if not (deco.force_placement or data[ivm] == first_node) then
										break
									end
								end
							end
						end
					end
				end
            end
        end
    end
end


-- check
function mod.place_schematic(params, schem, pos, flags, ps, rot, rot_z)
	local area = params.area
	local data, p2data = params.data, params.p2data
	local color = ps:next(1, 8)
	local node = mod.node
	local eight_random_colors = mod.eight_random_colors

	rot_z = rot_z or 0
	rot = rot or 0

	if not (pos and schem and type(schem) == 'table') then
		return
	end

	local yslice_offset = 0
	local yslice = {}  -- true if the slice should be removed
	if schem.yslice_prob then
		for _, ys in pairs(schem.yslice_prob) do
			local prob = ys.prob or 254
			yslice[ys.ypos] = (prob < 254 and prob <= ps:next(1, 254))

			if rot_z == 2 and yslice[ys.ypos] then
				yslice_offset = yslice_offset + 1
			end
		end
	end

	local rotated_schem_1
	local rotated_schem_2
	if rotated_schematics[rot+1 + rot_z * 4][schem] then
		rotated_schem_1 = rotated_schematics[rot+1][schem]
	else
		if rot == 2 then
			rotated_schem_1 = mod.schematic_array(schem.size.x, schem.size.y, schem.size.z)
		elseif rot == 1 or rot == 3 then
			rotated_schem_1 = mod.schematic_array(schem.size.z, schem.size.y, schem.size.x)
		end

		if rot_z == 2 then
			rotated_schem_2 = mod.schematic_array(rotated_schem_1.size.x, rotated_schem_1.size.y, rotated_schem_1.size.z)
		elseif rot_z == 1 or rot_z == 3 then
			rotated_schem_2 = mod.schematic_array(rotated_schem_1.size.y, rotated_schem_1.size.x, rotated_schem_1.size.z)
		end

		if rot == 0 then
			rotated_schem_1 = schem
		else
			local ystride = schem.size.x
			local zstride = schem.size.y * schem.size.x
			local ystride_1 = rotated_schem_1.size.x
			local zstride_1 = rotated_schem_1.size.y * rotated_schem_1.size.x

			for z = 0, schem.size.z - 1 do
				for x = 0, schem.size.x - 1 do
					local x1, z1
					if rot == 1 then
						x1, z1 = schem.size.z - z - 1, x
					elseif rot == 2 then
						x1, z1 = schem.size.x - x - 1, schem.size.z - z - 1
					elseif rot == 3 then
						x1, z1 = z, schem.size.x - x - 1
					end

					for y = 0, schem.size.y-1 do
						local isch1 = z1 * zstride_1 + y * ystride_1 + x1 + 1
						local isch = z * zstride + y * ystride + x + 1
						rotated_schem_1.data[isch1] = schem.data[isch]
					end
				end
			end
		end

		rotated_schematics[rot+1][schem] = rotated_schem_1
	end

	if rot_z == 0 then
		rotated_schem_2 = rotated_schem_1
	else
		local ystride_1 = rotated_schem_1.size.x
		local zstride_1 = rotated_schem_1.size.y * rotated_schem_1.size.x
		local ystride_2 = rotated_schem_2.size.x
		local zstride_2 = rotated_schem_2.size.y * rotated_schem_2.size.x

		for y1 = 0, rotated_schem_1.size.y - 1 do
			for x1 = 0, rotated_schem_1.size.x - 1 do
				local x2, y2
				if rot_z == 1 then
					x2, y2 = rotated_schem_1.size.y - y1 - 1, x1
				elseif rot_z == 2 then
					x2, y2 = rotated_schem_1.size.x - x1 - 1, rotated_schem_1.size.y - y1 - 1
				elseif rot_z == 3 then
					x2, y2 = y1, rotated_schem_1.size.x - x1 - 1
				end

				for z = 0, rotated_schem_1.size.z-1 do
					local isch2 = z * zstride_2 + y2 * ystride_2 + x2 + 1
					local isch1 = z * zstride_1 + y1 * ystride_1 + x1 + 1
					rotated_schem_2.data[isch2] = rotated_schem_1.data[isch1]
				end
			end
		end
	end

	local place_center_x = flags and flags:find('place_center_x')
	local place_center_z = flags and flags:find('place_center_z')
	if rot_z == 0 then
		if flags and (
			((rot == 0 or rot == 2) and place_center_x)
			or ((rot == 1 or rot == 3) and place_center_z)
		) then
			pos.x = pos.x - math.floor(rotated_schem_2.size.x / 2)
		end

		if flags and (
			((rot == 0 or rot == 2) and place_center_z)
			or ((rot == 1 or rot == 3) and place_center_x)
		) then
			pos.z = pos.z - math.floor(rotated_schem_2.size.z / 2)
		end
	elseif rot_z == 2 then
		if flags and (((rot == 0 or rot == 2) and place_center_x) or ((rot == 1 or rot == 3) and place_center_z)) then
			pos.x = pos.x - math.floor(rotated_schem_2.size.x / 2)
		end

		if flags and (
			((rot == 0 or rot == 2) and place_center_z)
			or ((rot == 1 or rot == 3) and place_center_x)
		) then
			pos.z = pos.z - math.floor(rotated_schem_2.size.z / 2)
		end
	elseif rot_z == 1 or rot_z == 3 then
		if flags and place_center_z then
			pos.y = pos.y - math.floor(rotated_schem_2.size.y / 2)
		end

		if flags and place_center_x then
			pos.z = pos.z - math.floor(rotated_schem_2.size.z / 2)
		end
	end

	-- ?????
	if rot_z == 2 and flags and place_center_z then
		pos.y = pos.y - rotated_schem_2.size.y
	elseif rot_z == 1 and flags and place_center_z then
		pos.x = pos.x - rotated_schem_2.size.x
	end

	-- Place the rotated schematic on the data array.
	local ystride = area.ystride
	for z = 0, rotated_schem_2.size.z-1 do
		for x = 0, rotated_schem_2.size.x-1 do
			local sch_ystride = rotated_schem_2.size.x
			local ivm = area:index(pos.x + x, pos.y + yslice_offset, pos.z + z)
			local isch = z * rotated_schem_2.size.y * rotated_schem_2.size.x + x + 1

			for y = 0, rotated_schem_2.size.y-1 do
				if not yslice[y] then
					local rdi = rotated_schem_2.data[isch]
					local prob = rdi.prob or rdi.param1 or 255
					local force

					if prob > 127 then
						prob = prob - 128
						force = true
					end

					if (prob == 127 or prob >= ps:next(1, 126))
					and (force or mod.buildable_to[data[ivm]]) then
						local name = rdi.name
						data[ivm] = node[name]

						local param2 = rdi.param2 or 0
						if no_rotate[name] then
							param2 = 0
						elseif wallmounted[name] then
							local yaw = dir_to_yaw(wallmounted_to_dir(param2))
							for _ = 1, rot do
								yaw = yaw + math_pi / 2
							end
							param2 = dir_to_wallmounted(yaw_to_dir(yaw))
						else
							local fdir = param2 % 32
							local extra = param2 - fdir
							for _ = 1, rot do
								fdir = drotn[fdir]
							end
							if rot_z > 0 then
								fdir = z_rots[rot_z][fdir] or z_rots[rot_z][0]
							end
							if eight_random_colors[data[ivm]] then
								extra = color * 32
							end
							param2 = fdir + extra
						end
						p2data[ivm] = param2
					end

					ivm = ivm + ystride
				end
				isch = isch + sch_ystride
			end
		end
	end
end


function mod.populate_node_arrays()
	local node = mod.node

	if #mod.buildable_to < 1 then
		for n, v in pairs(minetest.registered_nodes) do
			if v.buildable_to then
				mod.buildable_to[node[n] ] = true
			end
		end
	end

	if #mod.grass_nodes < 1 then
		for n in pairs(minetest.registered_nodes) do
			if n:find('grass_') then
				mod.grass_nodes[n] = true
			end
		end
	end

	if #mod.liquids < 1 then
		for _, d in pairs(minetest.registered_nodes) do
			if d.groups and d.drawtype == 'liquid' then
				mod.liquids[node[d.name] ] = true
			end
		end
	end
end


function mod.read_configuration_file()
	local file_name = mod.path .. '/realms.conf'

	local file = io.open(file_name, 'r')
	if not file then
		return
	end

	local good
	local lineno = 0
	for line in file:lines() do
		lineno = lineno + 1
		local fields = mod.parse_configuration_file_line(line, lineno)
		if fields then
			local realm = {
				mapgen = fields[1],
				realm_minp = { x = fields[2], y = fields[3], z = fields[4] },
				realm_maxp = { x = fields[5], y = fields[6], z = fields[7] },
				sealevel = fields[8],
				biomefunc = fields[9],
			}
			for i = 10, #fields do
				if type(fields[i]) == 'table' then
					realm[fields[i][1]] = fields[i][2] or true
				end
			end
			table.insert(mod.registered_realms, realm)

			if realm.spawn and not mod.spawn_realm and mod.registered_spawns[realm.mapgen] then
				mod.spawn_realm = realm
			end

			good = true
		end
	end

	file:close()

	return good
end


function mod.spawnplayer(player)
	local realm = mod.spawn_realm
	if not realm then
		return
	end

	local range = realm.spawn_range or 10000

	local beds_here = (minetest.get_modpath('beds') and beds and beds.spawn)

	local player_name = player:get_player_name()
	if beds_here and beds.spawn[player_name] then
		return
	end

	if minetest.settings:get('static_spawnpoint') then
		return
	end

	local pos
	local center = vector.divide(vector.add(realm.realm_minp, realm.realm_maxp), 2)

	for _ = 1, 10000 do
		pos = table.copy(center)
		pos.x = pos.x + math.random(range) + math.random(range) - range
		pos.z = pos.z + math.random(range) + math.random(range) - range

		pos.y = mod.registered_spawns[realm.mapgen](realm, pos.x, pos.z)

		if pos.y then
			--minetest.log(ct..' spawns attempted')
			break
		end
	end

	if not pos.y then
		return
	end

	pos.y = pos.y + 2
	player:set_pos(pos)

	if beds_here and not beds.spawn[player_name] then
		beds.spawn[player_name] = pos
		beds.set_spawns()
	end

	return true
end


function mod.save_map(params)
	local t_over = os.clock()

	local area, data, node = params.area, params.data, mod.node

	local n_stone = node['default:stone']
	local n_placeholder_lining
	if minetest.registered_nodes[mod_name .. ':placeholder_lining'] then
		n_placeholder_lining = node[mod_name .. ':placeholder_lining']

		local screwed_up
		for i = 1, #data do
			if data[i] == n_placeholder_lining then
				data[i] = n_stone
				screwed_up = area:position(i)
			end
		end
		if screwed_up then
			print(mod_name .. ': Correcting for minetest voxelmanip bug at around (' .. screwed_up.x .. ',' .. screwed_up.y .. ',' .. screwed_up.z .. '). Biome data has been replaced with default nodes.')
		end
	end

	params.vm:set_data(params.data)
	params.vm:set_param2_data(params.p2data)

	if not params.genesis_redo then
		if DEBUG then
			params.vm:set_lighting({day = 10, night = 10})
		else
			params.vm:set_lighting({day = 5, night = 5})
		end
		params.vm:calc_lighting(nil, nil, params.share.propagate_shadow)
	end

	params.vm:update_liquids()
	params.vm:write_to_map()

	-- Save all meta data for chests, cabinets, etc.
	for _, t in ipairs(params.metadata) do
		local meta = minetest.get_meta({x=t.x, y=t.y, z=t.z})
		meta:from_table()
		meta:from_table(t.meta)
	end

	mod.do_on_constructs(params)

	do
		local ps = PcgRandom(os.time())
		for _, v in ipairs(params.share.treasure_chests or {}) do
			local n = minetest.get_node_or_nil(v)
			if n and dungeon_loot and dungeon_loot.populate_chest then
				if params.share.treasure_chest_handler then
					params.share.treasure_chest_handler(v)
				else
					local meta = minetest.get_meta(v)
					local inv = meta:get_inventory()
					local listsz = inv:get_size("main")
					if listsz > 0 then
						dungeon_loot.populate_chest(v, ps)
					end
				end
			end
		end
	end

	mod.time_overhead = mod.time_overhead + os.clock() - t_over
end


minetest.register_on_newplayer(mod.spawnplayer)
minetest.register_on_respawnplayer(mod.spawnplayer)


mod.main()
