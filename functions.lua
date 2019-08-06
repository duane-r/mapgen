-- Duane's mapgen functions.lua
-- Copyright Duane Robertson (duane@duanerobertson.com), 2019
-- Distributed under the LGPLv2.1 (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)

-- Some of this code was inspired by, and hopefully is compatible
--  with, Donald Hines' Realms mod.


local mod = mapgen
local mod_name = 'mapgen'


mod.registered_biomes = {}
mod.registered_cave_biomes = {}
mod.registered_decorations = {}
mod.registered_mapfuncs = {}
mod.registered_mapgens = {}
mod.registered_noises = {}
mod.registered_spawns = {}
mod.rmf = mod.registered_mapfuncs


local axes = { 'x', 'y', 'z' }


-- This table looks up nodes that aren't already stored.
mod.node = setmetatable({}, {
	__index = function(t, k)
		if not (t and k and type(t) == 'table') then
			return
		end

		t[k] = minetest.get_content_id(k)
		return t[k]
	end
})
local node = mod.node


local fnv_offset = 2166136261
local fnv_prime = 16777619
function math.fnv1a(data)
	local hash = fnv_offset
	for _, b in pairs(data) do
		hash = math.xor(hash, b)
		hash = hash * fnv_prime
	end
	return hash
end


function math.xor(a, b)
	local r = 0
	for i = 0, 31 do
		local x = a / 2 + b / 2
		if x ~= math.floor(x) then
			r = r + 2^i
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
	end
	return r
end
assert(math.xor(60, 13) == 49)


function vector.contains(minp, maxp, q)
	for _, a in pairs(axes) do
		if minp[a] > q[a] or maxp[a] < q[a] then
			return
		end
	end

	return true
end


function vector.intersect_min(a, b)
	local out = {}
	for _, axis in pairs(axes) do
		if a[axis] < b[axis] then
			out[axis] = a[axis]
		else
			out[axis] = b[axis]
		end
	end
	return out
end


function vector.intersect_max(a, b)
	local out = {}
	for _, axis in pairs(axes) do
		if a[axis] > b[axis] then
			out[axis] = a[axis]
		else
			out[axis] = b[axis]
		end
	end
	return out
end


function vector.mod(v, m)
	local w = table.copy(v)
	for _, d in ipairs(axes) do
		if w[d] then
			w[d] = w[d] % m
		end
	end
	return w
end



-- These nodes will have their on_construct method called
--  when placed by the mapgen (to start timers).
mod.construct_nodes = {}
function mod.add_construct(node_name)
	mod.construct_nodes[node[node_name]] = true
end


-- Modify a node to add a group
function mod.add_group(node_name, groups)
	local def = minetest.registered_items[node_name]
	if not (node_name and def and groups and type(groups) == 'table') then
		return false
	end

	local def_groups = def.groups or {}
	for group, value in pairs(groups) do
		if value == 0 then
			def_groups[group] = nil
		else
			def_groups[group] = value
		end
	end

	minetest.override_item(node_name, {groups = def_groups})
	return true
end


function mod.clone_node(name)
	if not (name and type(name) == 'string') then
		return
	end
	if not minetest.registered_nodes[name] then
		return
	end

	local nod = minetest.registered_nodes[name]
	local node2 = table.copy(nod)
	return node2
end


function mod.cube_intersect(r1, r2)
	if not (
		vector.contains(r1.minp, r1.maxp, r2.minp)
		or vector.contains(r1.minp, r1.maxp, r2.maxp)
		or vector.contains(r2.minp, r2.maxp, r1.minp)
		or vector.contains(r2.minp, r2.maxp, r1.maxp)
	) then
		return
	end

	local minp, maxp = {}, {}
	for _, axis in pairs(axes) do
		minp[axis] = math.max(r1.minp[axis], r2.minp[axis])
		maxp[axis] = math.min(r1.maxp[axis], r2.maxp[axis])
	end
	return minp, maxp
end


function mod.get_noise2d(name, default, seed, default_seed, size, pos)
	if not (name and pos and size and type(name) == 'string'
	and type(pos) == 'table' and type(size) == 'table'
	and mod.registered_noises[name]) then
		return
	end

	if size.z then
		size.y = size.z
	end

	if pos.z then
		pos.y = pos.z
	end

	local def = table.copy(mod.registered_noises[name])
	if seed then
		def.seed = def.seed + seed
	end
	local noise = minetest.get_perlin_map(def, size)
	if not noise then
		return
	end

	return noise:get_2d_map_flat(pos)
end


function mod.get_noise3d(name, default, seed, default_seed, size, pos)
	if not (name and pos and size and type(name) == 'string'
	and type(pos) == 'table' and type(size) == 'table'
	and mod.registered_noises[name]) then
		return
	end

	local def = table.copy(mod.registered_noises[name])
	if seed then
		def.seed = def.seed + seed
	end
	local noise = minetest.get_perlin_map(def, size)
	if not noise then
		return
	end

	return noise:get_3d_map_flat(pos)
end


function mod.invert_table(t, use_node)
	local any
	local new_t = {}

	if type(t) == 'string' then
		t = {t}
	end

	for _, d in ipairs(t) do
		if type(d) == 'string' then
			local l = {}
			if use_node and d:find('^group:') then
				local gr = d:gsub('^group:', '')
				for n, v in pairs(minetest.registered_nodes) do
					if v.groups[gr] then
						l[#l+1] = n
					end
				end
			elseif use_node then
				l = {d}
			end

			if use_node then
				for _, v in pairs(l) do
					new_t[node[v]] = node[v]
				end
			else
				new_t[d] = d
			end
			any = true
		end
	end

	if any then
		return new_t
	end
end


-- memory issues?
function mod.node_string_or_table(n)
    if not n then
        return {}
    end

    local o
    if type(n) == 'string' then
        o = { n }
    elseif type(n) == 'table' then
        o = table.copy(n)
    else
        return {}
    end

    for i, v in pairs(o) do
        o[i] = node[v]
    end

    return o
end


function mod.register_biome(def, source)
	if not def.name then
		minetest.log(mod_name .. ': No-name biome: ' .. dump(def))
		return
	end

	local w = table.copy(def)

	w.node_top = node[w.node_top]
	w.node_filler = node[w.node_filler]
	w.node_riverbed = node[w.node_riverbed]
	w.node_stone = node[w.node_stone]
	w.node_water = node[w.node_water]
	w.node_water_top = node[w.node_water_top]
	w.node_dust = node[w.node_dust]

	w.source = source or w.source
	mod.registered_biomes[w.name] = w

	return w
end


local unknown_count = 0
function mod.register_decoration(def)
	local deco = table.copy(def)
	table.insert(mod.registered_decorations, deco)

	if not deco.name then
		local nname
		local dec = deco.decoration or deco.schematic
		if dec and type(dec) == 'string' then
			nname = dec:gsub('^.*[:/]([^%.]+)', '%1')
		else
			unknown_count = unknown_count + 1
			nname = 'unknown' .. unknown_count
		end
		deco.name = nname
	end

	if deco.place_on and type(deco.place_on) == 'table'
	and deco.place_on[1]:find('ethereal') then
		deco.source = 'ethereal'
	end

	if deco.flags and deco.flags ~= '' then
		for flag in deco.flags:gmatch('[^, ]+') do
			deco[flag] = deco[flag] or true
		end
	end

	if deco.place_on then
		deco.place_on_i = mod.invert_table(deco.place_on, true)
	end

	if deco.biomes then
		deco.biomes_i = mod.invert_table(deco.biomes)
	end

	for _, a in pairs(mod.aquatic_decorations or {}) do
		if deco.decoration == a or deco.schematic == a then
			deco.aquatic = true
		end
	end

	if deco.deco_type == 'schematic' then
		deco = mod.translate_schematic(deco)
	end

	return deco
end


function mod.translate_schematic(deco)
	if deco.deco_type ~= 'schematic' then
		return
	end

	if deco.schematic and type(deco.schematic) == 'string' then
		local s = deco.schematic
		local f = io.open(s, 'r')
		if f then
			f:close()
			local sch = minetest.serialize_schematic(s, 'lua', {})
			sch = minetest.deserialize('return {'..sch..'}')
			sch = sch.schematic
			deco.schematic_array = sch
		else
			print(mod_name .. ': ** Error opening: '..deco.schematic)
		end

		--print(dump(deco.schematic_array))
		if not deco.schematic_array then
			print(mod_name .. ': ** Error opening: '..deco.name)
		end
	end

	if not deco.schematic_array and deco.schematic and type(deco.schematic) == 'table' then
		deco.schematic_array = deco.schematic
	end

	if deco.schematic_array then
		-- Force air placement to 0 probability.
		-- This is usually correct.
		for _, v in pairs(deco.schematic_array.data) do
			if v.name == 'air' then
				v.prob = 0
				if v.param1 then
					v.param1 = 0
				end
			elseif v.name:find('leaves') or v.name:find('needles') then
				if v.prob and v.prob > 127 then
					v.prob = v.prob - 128
				end
			end
		end
	else
		print('FAILed to translate schematic: ' .. deco.name)
		deco.bad_schem = true
	end

	return deco
end


function mod.register_flower(name, source, desc, biomes, seed)
	local groups = { }
	groups.snappy = 3
	groups.flammable = 2
	groups.flower = 1
	groups.flora = 1
	groups.attached_node = 1
	local img = mod_name .. '_' .. name .. '.png'

	minetest.register_node(mod_name..':' .. name, {
		description = desc,
		drawtype = 'plantlike',
		waving = 1,
		tiles = { img },
		inventory_image = img,
		wield_image = img,
		sunlight_propagates = true,
		paramtype = 'light',
		walkable = false,
		buildable_to = true,
		stack_max = 99,
		groups = groups,
		sounds = default.node_sound_leaves_defaults(),
		selection_box = {
			type = 'fixed',
			fixed = { -0.5, -0.5, -0.5, 0.5, -5/16, 0.5 },
		}
	})

	local bi = { }
	if biomes then
		bi = { }
		for _, b in pairs(biomes) do
			bi[b] = true
		end
	end

	if bi['rainforest'] then
		minetest.register_decoration({
			deco_type = 'simple',
			place_on = { 'default:dirt_with_rainforest_litter' },
			sidelen = 16,
			noise_params = {
				offset = 0.015,
				scale = 0.025,
				spread = { x = 200, y = 200, z = 200 },
				seed = seed,
				octaves = 3,
				persist = 0.6
			},
			biomes = { 'rainforest', 'rainforest_swamp' },
			y_min = 1,
			y_max = 31000,
			decoration = mod_name..':'..name,
			name = name,
			flower = true,
			source = source,
		})
	end

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'default:dirt_with_grass', 'default:dirt_with_dry_grass', 'default:dirt_with_rainforest_litter' },
		sidelen = 16,
		noise_params = {
			offset = -0.015,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = seed,
			octaves = 3,
			persist = 0.6
		},
		biomes = biomes,
		y_min = 1,
		y_max = 31000,
		decoration = mod_name..':'..name,
		name = name,
		flower = true,
		source = source,
	})
end


function mod.register_mapfunc(name, func)
	if not (name and func and type(name) == 'string' and type(func) == 'function') then
		return
	end

	if mod.registered_mapfuncs[name] then
		minetest.log(mod_name .. ': * Overriding existing map function: ' .. name)
	end

	mod.registered_mapfuncs[name] = func
end


function mod.register_mapgen(name, func)
	if not (name and func and type(name) == 'string' and type(func) == 'function') then
		return
	end

	if mod.registered_mapgens[name] then
		minetest.log(mod_name .. ': * Overriding existing mapgen: ' .. name)
	end

	mod.registered_mapgens[name] = func
end


function mod.register_noise(name, def)
	if not (name and def and type(name) == 'string' and type(def) == 'table') then
		return
	end

	if mod.registered_noises[name] then
		minetest.log(mod_name .. ': * Overriding existing noise: ' .. name)
	end

	mod.registered_noises[name] = def
end


function mod.register_spawn(name, func)
	if not (name and func and type(name) == 'string' and type(func) == 'function') then
		return
	end

	if mod.registered_spawns[name] then
		minetest.log(mod_name .. ': * Overriding existing spawn: ' .. name)
	end

	mod.registered_spawns[name] = func
end


-- Create and initialize a table for a schematic.
function mod.schematic_array(width, height, depth)
	if not (
		width and height and depth
		and type(width) == 'number'
		and type(height) == 'number'
		and type(depth) == 'number'
	) then
		return
	end

	-- Dimensions of data array.
	local s = {size={x=width, y=height, z=depth}}
	s.data = {}

	for z = 0,depth-1 do
		for y = 0,height-1 do
			for x = 0,width-1 do
				local i = z*width*height + y*width + x + 1
				s.data[i] = {}
				s.data[i].name = "air"
				s.data[i].param1 = 000
			end
		end
	end

	s.yslice_prob = {}

	return s
end



minetest.register_privilege('mapgen', {
	description = 'allowed to alter the landscape',
	give_to_singleplayer = true,
	give_to_admin = true,
})


--[[
minetest.register_chatcommand('ether', {
	params = '',
	description = 'Teleport to ether',
	privs = { mapgen = true },
	func = function(player_name, param)
		if type(player_name) ~= 'string' or player_name == '' then
			return
		end

		local player = minetest.get_player_by_name(player_name)
		if not player then
			return
		end

		local pos = player:get_pos()
		local npos = table.copy(pos)

		if pos.y < -27000 then
			npos.x = math.floor(npos.x * 8 + 0.5)
			--npos.y = npos.y + 28800
			npos.y = math.floor((npos.y + 28400) * 8 + 0.5)
			npos.z = math.floor(npos.z * 8 + 0.5)
			player:set_pos(npos)
		else
			npos.x = math.floor(npos.x / 8 + 0.5)
			--npos.y = npos.y - 28800
			npos.y = math.floor((npos.y) / 8 + 0.5) - 28400 + 2
			npos.z = math.floor(npos.z / 8 + 0.5)
			player:set_pos(npos)
		end
	end,
})
--]]


minetest.register_chatcommand('chunk', {
	params = '',
	description = 'What chunk is this?',
	privs = { },
	func = function(player_name, param)
		if not player_name then
			return
		end

		local player = minetest.get_player_by_name(player_name)
		if not player then
			return
		end

		local pos = player:get_pos()
		if not pos then
			return
		end

		local chunksize = tonumber(minetest.settings:get('chunksize') or 5)
		local chunk_offset = math.floor(chunksize / 2) * 16;
		local csize = { x=chunksize * 16, y=chunksize * 16, z=chunksize * 16 }

		local chunk = vector.floor(vector.divide(vector.add(pos, chunk_offset), csize.z))
		minetest.chat_send_player(player_name, 'Chunk: ' .. chunk.x .. ',' .. chunk.y .. ',' .. chunk.z)
	end,
})


--[[
minetest.register_chatcommand('genesis', {
	params = '',
	description = 'Regenerate a chunk, destroying all existing nodes.',
	privs = { mapgen = true },
	func = function(player_name, param)
		if not player_name then
			return
		end

		local player = minetest.get_player_by_name(player_name)
		if not player then
			return
		end

		local pos = player:get_pos()
		if not pos then
			return
		end

		local chunksize = tonumber(minetest.settings:get('chunksize') or 5)
		local chunk_offset = math.floor(chunksize / 2) * 16;
		local csize = { x=chunksize * 16, y=chunksize * 16, z=chunksize * 16 }

		local chunk = vector.floor(vector.divide(vector.add(pos, chunk_offset), csize.z))
		local minp = vector.add(vector.multiply(chunk, csize.z), -chunk_offset)
		local maxp = vector.add(vector.add(minp, -1), csize.z)
		local vm = minetest.get_voxel_manip()
		if not vm then
			return
		end
		local emin, emax = vm:read_from_map(minp, maxp)

		if not (emin and emax) then
			return
		end

		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local data = vm:get_data()
		local p2data = vm:get_param2_data()
		local n_air = minetest.get_content_id('air')

		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				local ivm = area:index(minp.x, y, z)
				for x = minp.x, maxp.x do
					data[ivm] = n_air
					p2data[ivm] = 0
					ivm = ivm + 1
				end
			end
		end

		vm:set_data(data)
		vm:set_param2_data(p2data)
		vm:write_to_map()
		vm = nil

		local mg = mod.Mapgen(minp, maxp, nil)
		if not mg then
			return
		end
		mg.name = 'Mapgen'

		mg:generate_all(true)
	end,
})
--]]


do
	-- Catch any registered by other mods.
	local old_register_decoration = minetest.register_decoration
	minetest.register_decoration = function (def)
		mod.register_decoration(def)
		old_register_decoration(def)
	end


	local old_clear_registered_decorations = minetest.clear_registered_decorations
	minetest.clear_registered_decorations = function ()
		mod.decorations = {}
		old_clear_registered_decorations()
	end


	local old_register_biome = minetest.register_biome
	minetest.register_biome = function (def)
		mod.register_biome(def)
		old_register_biome(def)
	end


	local old_clear_registered_biomes = minetest.clear_registered_biomes
	minetest.clear_registered_biomes = function ()
		mod.biomes = {}
		old_clear_registered_biomes()
	end
end
