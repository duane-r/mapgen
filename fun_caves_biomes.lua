-- Duane's mapgen fun_caves_biomes.lua
-- Copyright Duane Robertson (duane@duanerobertson.com), 2019
-- Distributed under the LGPLv2.1 (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)


local layer_mod = mapgen
local mod = mapgen
local mod_name = 'mapgen'

local clone_node = layer_mod.clone_node
local light_max = 10
local time_factor = 100 -- 1000
local newnode


do
	local def = {
        type = 'fixed',
        fixed = {},
	}

	local div = 9
	local hdiv = 5

	for z = 1, div do
		local dz = 1 - math.abs(z - hdiv) / hdiv
		for x = 1, div do
			local dx = 1 - math.abs(x - hdiv) / hdiv
			local c = math.abs(dx * dx + dz * dz)

			--if math_random(1, 3) ~= 1 then
			if c > 0.25 then
				table.insert(def.fixed, {
					(x - 1) / div - 0.5,
					-0.5,
					(z - 1) / div - 0.5,
					x / div - 0.5,
					math.max(dz, dx) * (math.random(1, 10) / 10) - 0.5,
					z / div - 0.5,
				})
			end
		end
	end

	minetest.register_node(mod_name .. ':placeholder_lining', {
		description = 'This should not be here.',
	})

	minetest.register_node(mod_name .. ':pretty_crystal', {
		description = 'Pretty Crystal',
		tiles = { 'mapgen_70_white.png' },
		use_texture_alpha = 'blend',
		light_source = 8,
		inventory_image = 'mapgen_pretty_crystal_inventory.png',
		drawtype = 'nodebox',
		node_box = def,
		-- Using an 8-pixel palette seems to force the game to use
		--  the highest three bits, rather than five.
		paramtype2 = 'colorwallmounted',
		--paramtype2 = 'colorfacedir',
		palette = 'mapgen_palette_crystals_2.png',
		is_ground_content = true,
		--groups = { cracky = 3, natural_stone = 1 },
		-- If they're in natural_stone, they end up stacked.
		groups = { cracky = 3, },
		sounds = default.node_sound_stone_defaults({
			footstep = { name = 'default_stone_footstep', gain = 0.25 },
		}),
	})
end


do
	minetest.register_node(mod_name .. ':basalt', {
		description = 'Basalt',
		tiles = { 'mapgen_basalt.png' },
		is_ground_content = true,
		groups = { cracky = 1, level = 2, natural_stone = 1 },
		sounds = default.node_sound_stone_defaults({
			footstep = { name = 'default_stone_footstep', gain = 0.25 },
		}),
	})

	minetest.register_node(mod_name .. ':granite', {
		description = 'Granite',
		tiles = { 'mapgen_granite.png' },
		is_ground_content = true,
		groups = { cracky = 1, level = 3, natural_stone = 1 },
		sounds = default.node_sound_stone_defaults({
			footstep = { name = 'default_stone_footstep', gain = 0.25 },
		}),
	})


	newnode = clone_node('default:stone')
	newnode.description = 'Etherstone'
	newnode.tiles = { 'mapgen_black_sand.png' }
	newnode.groups = { cracky = 3 }
	newnode.drop = nil
	minetest.register_node(mod_name .. ':etherstone', newnode)


	-- stone with lichen
	newnode = clone_node('default:stone')
	newnode.description = 'Cave Stone With Lichen'
	newnode.tiles = { 'default_stone.png^mapgen_lichen.png' }
	newnode.groups = { stone = 1, cracky = 3, crumbly = 3, natural_stone = 1 }
	newnode.sounds = default.node_sound_dirt_defaults({
		footstep = { name = 'default_grass_footstep', gain = 0.25 },
	})
	minetest.register_node(mod_name .. ':stone_with_lichen', newnode)

	-- stone with algae
	newnode = clone_node('default:stone')
	newnode.description = 'Cave Stone With Algae'
	newnode.tiles = { 'default_stone.png^mapgen_algae.png' }
	newnode.groups = { stone = 1, cracky = 3, crumbly = 3, natural_stone = 1 }
	newnode.sounds = default.node_sound_dirt_defaults({
		footstep = { name = 'default_grass_footstep', gain = 0.25 },
	})
	minetest.register_node(mod_name .. ':stone_with_algae', newnode)

	-- stone with moss
	newnode = clone_node('default:stone')
	newnode.description = 'Cave Stone With Moss'
	newnode.tiles = { 'default_stone.png^mapgen_moss.png' }
	newnode.groups = { stone = 1, cracky = 3, crumbly = 3, natural_stone = 1 }
	newnode.sounds = default.node_sound_dirt_defaults({
		footstep = { name = 'default_grass_footstep', gain = 0.25 },
	})
	minetest.register_node(mod_name .. ':stone_with_moss', newnode)

	-- salt
	minetest.register_node(mod_name .. ':stone_with_salt', {
		description = 'Cave Stone with Salt',
		tiles = { 'mapgen_salt.png' },
		paramtype = 'light',
		use_texture_alpha = 'blend',
		drawtype = 'glasslike',
		sunlight_propagates = false,
		is_ground_content = true,
		groups = { stone = 1, crumbly = 3, cracky = 3 },
		sounds = default.node_sound_glass_defaults(),
	})

	-- salt, radioactive ore
	newnode = clone_node(mod_name .. ':stone_with_salt')
	newnode.description = 'Salt With Radioactive Ore'
	newnode.tiles = { 'mapgen_radioactive_ore.png' }
	--newnode.light_source = 5
	minetest.register_node(mod_name .. ':radioactive_ore', newnode)

	minetest.register_node(mod_name .. ':glowing_fungal_stone', {
		description = 'Glowing Fungal Stone',
		tiles = { 'default_stone.png^mapgen_glowing_fungal.png', },
		is_ground_content = true,
		light_source = 5,
		groups = { cracky = 3, stone = 1 },
		drop = { items = { { items = { 'default:cobble' }, }, { items = { mod_name .. ':glowing_fungus', }, }, }, },
		sounds = default.node_sound_stone_defaults(),
	})

	minetest.register_node(mod_name .. ':glowing_gem', {
		description = 'Glowing gems',
		tiles = { 'mapgen_glowing_gem.png', },
		is_ground_content = true,
		paramtype = 'light',
		use_texture_alpha = 'blend',
		drawtype = 'glasslike',
		--light_source = 5,
		groups = { cracky = 3, stone = 1 },
		sounds = default.node_sound_stone_defaults(),
	})

	minetest.register_node(mod_name .. ':sand_gem_glass', {
		description = 'Sand Gem Glass',
		tiles = { 'mapgen_glowing_gem_glass.png', 'mapgen_glowing_gem_glass_detail.png', },
		is_ground_content = true,
		paramtype = 'light',
		--use_texture_alpha = 'blend',
		drawtype = 'glasslike_framed_optional',
		--light_source = 5,
		groups = { cracky = 3, stone = 1, oddly_breakable_by_hand = 1 },
		sunlight_propagates = true,
		sounds = default.node_sound_glass_defaults(),
	})

	minetest.register_craft({
		output = mod_name .. ':sand_gem_glass 2',
		type = 'shapeless',
		recipe = {
			mod_name .. ':glowing_gem',
			'default:glass',
		}
	})

	if minetest.get_modpath('doors') then
		print('register door')
		doors.register('door_sand_gem_glass', {
			tiles = {'mapgen_sand_gem_glass_door.png'},
			description = 'Sand Gem Glass Door',
			inventory_image = 'mapgen_sand_gem_glass_door.png',
			groups = {cracky=3},
			sounds = default.node_sound_glass_defaults(),
			sound_open = 'doors_glass_door_open',
			sound_close = 'doors_glass_door_close',
			recipe = {
				{'mapgen:sand_gem_glass', 'mapgen:sand_gem_glass'},
				{'mapgen:sand_gem_glass', 'mapgen:sand_gem_glass'},
				{'mapgen:sand_gem_glass', 'mapgen:sand_gem_glass'},
			},
		})
	end

	-- black (oily) sand
	newnode = clone_node('default:sand')
	newnode.description = 'Black Sand'
	newnode.tiles = { 'mapgen_black_sand.png' }
	newnode.groups['falling_node'] = 0
	minetest.register_node(mod_name .. ':black_sand', newnode)

	-- rocks, hot
	minetest.register_node(mod_name .. ':hot_rock', {
		description = 'Hot Rocks',
		--tiles = { 'mapgen_hot_rock.png' },
		tiles = { 'default_cobble.png^[colorize:#990000:100' },
		--tiles = { 'default_desert_stone.png^[colorize:#FF0000:50' },
		is_ground_content = true,
		groups = { crumbly = 2, surface_hot = 3 },
		light_source = 5,
		damage_per_second = 1,
		sounds = default.node_sound_stone_defaults({
			footstep = { name = 'default_stone_footstep', gain = 0.25 },
		}),
	})

	-- Glowing fungus grows underground.
	minetest.register_craftitem(mod_name .. ':glowing_fungus', {
		description = 'Glowing Fungus',
		drawtype = 'plantlike',
		paramtype = 'light',
		tiles = { 'mapgen_glowing_fungus.png' },
		inventory_image = 'mapgen_glowing_fungus.png',
		groups = { dig_immediate = 3 },
	})
end


do
	local giant_mushroom_cap_node_box = {
		type = 'fixed',
		fixed = {
			{ -0.3, -0.25, -0.3, 0.3, 0.5, 0.3 },
			{ -0.3, -0.25, -0.4, 0.3, 0.4, -0.3 },
			{ -0.3, -0.25, 0.3, 0.3, 0.4, 0.4 },
			{ -0.4, -0.25, -0.3, -0.3, 0.4, 0.3 },
			{ 0.3, -0.25, -0.3, 0.4, 0.4, 0.3 },
			{ -0.4, -0.5, -0.4, 0.4, -0.25, 0.4 },
			{ -0.5, -0.5, -0.4, -0.4, -0.25, 0.4 },
			{ 0.4, -0.5, -0.4, 0.5, -0.25, 0.4 },
			{ -0.4, -0.5, -0.5, 0.4, -0.25, -0.4 },
			{ -0.4, -0.5, 0.4, 0.4, -0.25, 0.5 },
		}
	}

	local huge_mushroom_cap_node_box = {
		type = 'fixed',
		fixed = {
			{ -0.5, -0.5, -0.33, 0.5, -0.33, 0.33 },
			{ -0.33, -0.5, 0.33, 0.33, -0.33, 0.5 },
			{ -0.33, -0.5, -0.33, 0.33, -0.33, -0.5 },
			{ -0.33, -0.33, -0.33, 0.33, -0.17, 0.33 },
		}
	}

	local giant_mushroom_stem_node_box = {
		type = 'fixed',
		fixed = {
			{ -0.25, -0.5, -0.25, 0.25, 0.5, 0.25 },
		}
	}

	minetest.register_craft({
		output = 'default:wood',
		recipe = {
			{mod_name .. ':giant_mushroom_stem'}
		}
	})

	local grow_into = {
		['air'] = true,
		['default:water_source'] = true,
		['default:water_flowing'] = true,
	}

	local function spread_spores(pos, elapsed, mushroom)
		local posu = {x=pos.x, y=pos.y+1, z=pos.z}
		if (minetest.get_node_light(posu, nil) or 15) == 15 then
			minetest.remove_node(pos)
			return
		end

		local node_down = minetest.get_node_or_nil({x=pos.x, y=pos.y-1, z=pos.z})
		if not node_down then
			return true
		end

		if node_down.name == 'air' then
			minetest.remove_node(pos)
			return
		end

		--if math.random(5) == 1 then
		--  local name = 'fun_caves:fungal_tree_leaves_' .. math.random(4)
		--  if minetest.registered_nodes[name] then
		--    minetest.set_node(pos, {name = name})
		--    return
		--  end
		--end

		local minp = vector.subtract(pos, 8)
		local maxp = vector.add(pos, 8)
		local dirt = minetest.find_nodes_in_area_under_air(minp, maxp, {'group:soil'})
		if dirt and #dirt > 0 then
			local p = dirt[math.random(#dirt)]
			--local crowd = minetest.find_nodes_in_area_under_air(minp, maxp, {'flowers:mushroom_red', 'flowers:mushroom_brown'})
			if mushroom then
				minetest.set_node({x=p.x, y=p.y+1, z=p.z}, {name=mushroom})
			elseif math.random(2) == 1 then
				minetest.set_node({x=p.x, y=p.y+1, z=p.z}, {name='flowers:mushroom_red'})
			else
				minetest.set_node({x=p.x, y=p.y+1, z=p.z}, {name='flowers:mushroom_brown'})
			end
		end

		return true
	end

	minetest.register_node(mod_name .. ':giant_mushroom_cap', {
		description = 'Giant Mushroom Cap',
		tiles = { 'mapgen_mushroom_giant_cap.png', 'mapgen_mushroom_giant_under.png', 'mapgen_mushroom_giant_cap.png' },
		is_ground_content = false,
		paramtype = 'light',
		drawtype = 'nodebox',
		node_box = giant_mushroom_cap_node_box,
		light_source = 5,
		groups = { fleshy=1, dig_immediate=3, flammable=2, plant=1 },
		on_timer = spread_spores,
		on_construct = function(pos)
			local timer = minetest.get_node_timer(pos)
			local max = 10 * (time_factor or 10)
			if timer then
				timer:set(max, max > 1 and math.random(max - 1) or 0)
			end
		end,
	})


	-- mushroom cap, huge
	minetest.register_node(mod_name .. ':huge_mushroom_cap', {
		description = 'Huge Mushroom Cap',
		tiles = { 'mapgen_mushroom_giant_cap.png', 'mapgen_mushroom_giant_under.png', 'mapgen_mushroom_giant_cap.png' },
		is_ground_content = false,
		paramtype = 'light',
		drawtype = 'nodebox',
		node_box = huge_mushroom_cap_node_box,
		light_source = 5,
		groups = { fleshy=1, dig_immediate=3, flammable=2, plant=1 },
	})

	-- mushroom stem, giant or huge
	minetest.register_node(mod_name .. ':giant_mushroom_stem', {
		description = 'Giant Mushroom Stem',
		tiles = { 'mapgen_mushroom_giant_stem.png', 'mapgen_mushroom_giant_stem.png', 'mapgen_mushroom_giant_stem.png' },
		is_ground_content = false,
		groups = { choppy=2, flammable=2,  plant=1, oddly_breakable_by_hand = 1 },
		sounds = default.node_sound_wood_defaults(),
		sunlight_propagates = true,
		paramtype = 'light',
		drawtype = 'nodebox',
		node_box = giant_mushroom_stem_node_box,
		on_timer = function(pos, elapsed)
			local posu = {x=pos.x, y=pos.y+1, z=pos.z}
			local dark = (minetest.get_node_light(posu, nil) or 15) <= (light_max - 4 or 10)
			local node_down = minetest.get_node_or_nil({x=pos.x, y=pos.y-1, z=pos.z})
			if not (node_down and dark) then
				return true
			end

			if node_down.name == 'air' then
				minetest.remove_node(pos)
				return
			end

			local posu2 = {x=pos.x, y=pos.y+2, z=pos.z}
			local node_up = minetest.get_node_or_nil(posu)
			local node_up2 = minetest.get_node_or_nil(posu2)
			if not (node_up and node_up2) then
				return true
			end

			if math.random(15) == 1
			and minetest.registered_nodes[node_down.name].groups
			and minetest.registered_nodes[node_down.name].groups.soil
			and (
				node_up.name == mod_name .. ':huge_mushroom_cap'
				or grow_into[node_up.name]
			) and grow_into[node_up2.name] then
				local n = mod_name .. ':giant_mushroom_stem'
				minetest.set_node(posu, { name = n })
				minetest.set_node(posu2, {name=mod_name .. ':giant_mushroom_cap'})
				return true
			end

			if not grow_into[node_up.name] then
				return true
			end

			if node_down.name == mod_name .. ':giant_mushroom_stem' then
				minetest.set_node(posu, {name=mod_name .. ':giant_mushroom_cap'})
			elseif minetest.registered_nodes[node_down.name].groups
			and minetest.registered_nodes[node_down.name].groups.soil then
				minetest.set_node(posu, {name=mod_name .. ':huge_mushroom_cap'})
			end

			return true
		end,
		on_construct = function(pos)
			local timer = minetest.get_node_timer(pos)
			local max = 50 * (time_factor or 10)
			if timer then
				timer:set(max, max > 1 and math.random(max - 1) or 0)
			end
		end,
	})


	for _, sh in pairs({'flowers:mushroom_red', 'flowers:mushroom_brown'}) do
		minetest.override_item(sh, {
			on_timer = function(pos, elapsed)
				local posu = {x=pos.x, y=pos.y+1, z=pos.z}
				local daylight = minetest.get_node_light(posu, 0.5) or 0
				local light = minetest.get_node_light(posu, nil) or 0
				local mushroom = minetest.get_node_or_nil(pos)
				if light == 15 then
					minetest.remove_node(pos)
					return
				elseif light > light_max - 4 then
					return true
				elseif daylight > light_max - 4 then
					return spread_spores(pos, elapsed, mushroom.name)
				end

				local node_down = minetest.get_node_or_nil({x=pos.x, y=pos.y-1, z=pos.z})
				if not node_down then
					return true
				end

				if node_down.name == 'air' then
					minetest.remove_node(pos)
					return
				end

				if math.random(50) ~= 1 then
					return true
				end

				local node_up = minetest.get_node_or_nil(posu)
				if not node_up then
					return true
				end

				if minetest.registered_nodes[node_down.name].groups
				and minetest.registered_nodes[node_down.name].groups.soil
				and grow_into[node_up.name] then
					local n = mod_name .. ':giant_mushroom_stem'
					minetest.set_node(pos, { name = n })
					minetest.set_node(posu, { name = mod_name .. ':huge_mushroom_cap' })
				end
			end,
			on_construct = function(pos)
				local timer = minetest.get_node_timer(pos)
				local max = 10 * (time_factor or 10)
				if timer then
					timer:set(max, max > 1 and math.random(max - 1) or 0)
				end
			end,
		})

		minetest.registered_items[sh].groups.timed = 1
	end


	layer_mod.add_construct(mod_name .. ':giant_mushroom_cap')
	layer_mod.add_construct(mod_name .. ':giant_mushroom_stem')
	layer_mod.add_construct('flowers:mushroom_red')
	layer_mod.add_construct('flowers:mushroom_brown')

	-- Caps can be cooked and eaten.
	minetest.register_craftitem(mod_name .. ':mushroom_steak', {
		description = 'Mushroom Steak',
		inventory_image = 'mushroom_steak.png',
		on_use = minetest.item_eat(4),
	})

	minetest.register_craft({
		type = 'cooking',
		output = mod_name .. ':mushroom_steak',
		recipe = mod_name .. ':huge_mushroom_cap',
		cooktime = 2,
	})

	minetest.register_craft({
		type = 'cooking',
		output = mod_name .. ':mushroom_steak 2',
		recipe = mod_name .. ':giant_mushroom_cap',
		cooktime = 2,
	})
end


do
	-- spikes, hot -- silicon-based life
	local spike_size = { 1.0, 1.2, 1.4, 1.6, 1.7 }
	local nodename
	mod.hot_spikes = { }

	for i in ipairs(spike_size) do
		if i == 1 then
			nodename = ':' .. mod_name .. ':hot_spike'
		else
			nodename = ':' .. mod_name .. ':hot_spike_' .. i
		end

		table.insert(mod.hot_spikes, nodename)

		local vs = spike_size[i]

		minetest.register_node(nodename, {
			description = 'Stone Spike',
			tiles = { 'mapgen_hot_spike.png' },
			is_ground_content = true,
			groups = { cracky = 3, oddly_breakable_by_hand = 1, surface_hot = 3 },
			damage_per_second = 1,
			sounds = default.node_sound_stone_defaults(),
			paramtype = 'light',
			drawtype = 'plantlike',
			walkable = false,
			light_source = i * 2 + 2,
			buildable_to = true,
			visual_scale = vs,
			selection_box = {
				type = 'fixed',
				fixed = { -0.5*vs, -0.5*vs, -0.5*vs, 0.5*vs, -5/16*vs, 0.5*vs },
			}
		})
	end

	mod.hot_spike = { }
	for i = 1, #mod.hot_spikes do
		mod.hot_spike[mod.hot_spikes[i] ] = i
	end


	--[[
	register_node_and_alias('will_o_wisp_glow', {
		description = 'Will-o-wisp',
		drawtype = 'plantlike',
		visual_scale = 0.75,
		tiles = { 'will_o_wisp.png' },
		paramtype = 'light',
		sunlight_propagates = true,
		light_source = 8,
		walkable = false,
		diggable = false,
		pointable = false,
		is_ground_content = false,
		on_construct = function(pos)
			local timer = minetest.get_node_timer(pos)
			local max = 30
			if timer then
				timer:set(max, math.random(max - 1))
			end
		end,
		on_timer = function(pos, elapsed)
			--local nod = minetest.get_node_or_nil(pos)
			minetest.set_node(pos, { name = mod_name .. ':will_o_wisp_dark' })
		end,
	})

	register_node_and_alias('will_o_wisp_dark', {
		description = 'Will-o-wisp',
		drawtype = 'plantlike',
		visual_scale = 0.75,
		tiles = { 'will_o_wisp.png' },
		paramtype = 'light',
		sunlight_propagates = true,
		walkable = false,
		diggable = false,
		pointable = false,
		is_ground_content = false,
		on_construct = function(pos)
			local timer = minetest.get_node_timer(pos)
			local max = 30
			if timer then
				timer:set(max, math.random(max - 1))
			end
		end,
		on_timer = function(pos, elapsed)
			--local nod = minetest.get_node_or_nil(pos)
			minetest.set_node(pos, { name = mod_name .. ':will_o_wisp_glow' })
		end,
	})

	--layer_mod.add_construct(mod_name .. ':will_o_wisp_glow')
	--layer_mod.add_construct(mod_name .. ':will_o_wisp_dark')



	newnode = clone_node('air')
	newnode.drowning = 1
	minetest.register_node(':' .. mod_name .. ':inert_gas', newnode)


	-- kelp-like water plant?
	minetest.register_node(':' .. mod_name .. ':wet_fungus', {
		description = 'Leaves',
		tiles = { 'wet_fungus.png' },
		light_source = 2,
		groups = { snappy = 3 },
		drop = '',
		sounds = default.node_sound_leaves_defaults(),
	})
	--]]
end


do
	-- What's a cave without speleothems?
	local spel = {
		{
			stalac = 'stalactite',
			stalag = 'stalagmite',
			tile = 'default_stone.png',
			place_on = { 'default:stone' },
			biomes = { 'stone' },
		},
		{
			stalac = 'stalactite_slimy',
			stalag = 'stalagmite_slimy',
			tile = 'default_stone.png^mapgen_algae.png',
			light = light_max-6,
			place_on = { mod_name .. ':stone_with_algae' },
			biomes = { 'algae' },
		},
		{
			stalac = 'stalactite_mossy',
			stalag = 'stalagmite_mossy',
			tile = 'default_stone.png^mapgen_moss.png',
			light = light_max-6,
			place_on = { mod_name .. ':stone_with_moss' },
			biomes = { 'mossy' },
		},
		{
			stalac = 'stalactite_lichen',
			stalag = 'stalagmite_lichen',
			tile = 'default_stone.png^mapgen_lichen.png',
			light = light_max-6,
			place_on = { mod_name .. ':stone_with_lichen' },
			biomes = { 'lichen' },
		},
		--[[
		{
			stalac = 'stalactite_crystal',
			stalag = 'stalagmite_crystal',
			tile = 'mapgen_radioactive_ore',
			light = light_max
		},
		--]]
		{
			stalac = 'icicle_down',
			stalag = 'icicle_up',
			desc = 'Icicle',
			tile = 'default_ice.png',
			drop = 'default:ice',
			place_on = { 'default:ice' },
			biomes = { 'ice', },
		},
	}

	for _, desc in pairs(spel) do
		minetest.register_node(mod_name .. ':' .. desc.stalac, {
			description = (desc.desc or 'Stalactite'),
			tiles = { desc.tile },
			is_ground_content = true,
			walkable = false,
			--light_source = desc.light,
			paramtype = 'light',
			drop = (desc.drop or mod_name .. ':stalactite'),
			drawtype = 'nodebox',
			node_box = { type = 'fixed',
			fixed = {
				{ -0.07, 0.0, -0.07, 0.07, 0.5, 0.07 },
				{ -0.04, -0.25, -0.04, 0.04, 0.0, 0.04 },
				{ -0.02, -0.5, -0.02, 0.02, 0.25, 0.02 },
			} },
			groups = { rock = 1, cracky = 3 },
			sounds = default.node_sound_stone_defaults(),
		})

		minetest.register_node(mod_name .. ':' .. desc.stalag, {
			description = (desc.desc or 'Stalagmite'),
			tiles = { desc.tile },
			is_ground_content = true,
			walkable = false,
			paramtype = 'light',
			--light_source = desc.light,
			drop = mod_name .. ':stalagmite',
			drawtype = 'nodebox',
			node_box = { type = 'fixed',
			fixed = {
				{ -0.07, -0.5, -0.07, 0.07, 0.0, 0.07 },
				{ -0.04, 0.0, -0.04, 0.04, 0.25, 0.04 },
				{ -0.02, 0.25, -0.02, 0.02, 0.5, 0.02 },
			} },
			groups = { rock = 1, cracky = 3 },
			sounds = default.node_sound_stone_defaults(),
		})

		minetest.register_decoration({
			deco_type = 'simple',
			place_on = desc.place_on,
			sidelen = 16,
			fill_ratio = 0.1,
			biomes = desc.biomes,
			decoration = mod_name .. ':' .. desc.stalac,
			name = desc.stalac,
			flags = 'all_ceilings, underground',
		})

		minetest.register_decoration({
			deco_type = 'simple',
			place_on = desc.place_on,
			sidelen = 16,
			fill_ratio = 0.1,
			biomes = desc.biomes,
			decoration = mod_name .. ':' .. desc.stalag,
			name = desc.stalag,
			flags = 'all_floors, underground',
		})
	end
	--[[


	minetest.register_node(mod_name .. ':bound_spirit', {
		description = 'Tormented Spirit',
		tiles = { 'spirit.png' },
		use_texture_alpha = 'blend',
		light_source = 1,
		paramtype2 = 'facedir',
		walkable = false,
		pointable = false,
		groups = { poison = 1 },
		drawtype = 'plantlike',
	})
	--]]
end


do
	local huge_mushroom_sch = {
		size = { x=1, y=3, z=1 },
		data = {
			{ name = 'default:dirt', force_place = true, },
			{ name = mod_name .. ':giant_mushroom_stem', },
			{ name = mod_name .. ':huge_mushroom_cap', },
		},
	}

	local giant_mushroom_sch = {
		size = { x=1, y=4, z=1 },
		data = {
			{ name = 'default:dirt', force_place = true, },
			{ name = mod_name .. ':giant_mushroom_stem', },
			{ name = mod_name .. ':giant_mushroom_stem', },
			{ name = mod_name .. ':giant_mushroom_cap', },
		},
	}

	minetest.register_decoration({
		deco_type = 'schematic',
		place_on = { 'group:natural_stone', },
		sidelen = 16,
		noise_params = {
			offset = 0.010,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = 30,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'stone', 'algae', 'lichen', },
		schematic = huge_mushroom_sch,
		name = 'huge_mushroom',
		flags = 'all_floors, underground',
	})

	minetest.register_decoration({
		deco_type = 'schematic',
		place_on = { 'group:natural_stone', },
		sidelen = 16,
		noise_params = {
			offset = 0.007,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = 20,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'stone', 'algae', 'lichen', },
		schematic = giant_mushroom_sch,
		name = 'giant_mushroom',
		flags = 'all_floors, underground',
	})

	minetest.register_node(mod_name .. ':glow_worm', {
		description = 'Glow worm',
		tiles = { 'mapgen_glow_worm.png' },
		selection_box = {
			type = 'fixed',
			fixed = {
				{ 0.1, -0.5, 0.1, -0.1, 0.5, -0.1, },
			},
		},
		color = '#DDEEFF',
		use_texture_alpha = 'blend',
		light_source = 6,
		paramtype2 = 'facedir',
		walkable = false,
		groups = { oddly_breakable_by_hand=1, dig_immediate=2 },
		drawtype = 'plantlike',
	})

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'group:natural_stone', },
		height_max = 6,
		sidelen = 16,
		noise_params = {
			offset = 0.015,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = 52,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'stone', 'algae', 'lichen', },
		decoration = mod_name .. ':glow_worm',
		name = 'glow_worm',
		flags = 'all_ceilings, underground',
	})

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'group:natural_stone', },
		sidelen = 16,
		noise_params = {
			offset = 0.015,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = -18,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'sea_cave', 'wet_stone', 'mossy', },
		decoration = mod_name .. ':glowing_fungal_stone',
		place_offset_y = -1,
		name = 'glowing_fungal_stone',
		flags = 'all_ceilings, all_floors',
	})

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'group:sand', },
		sidelen = 16,
		noise_params = {
			offset = 0.015,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = -17,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'sand', 'sandstone', },
		decoration = mod_name .. ':glowing_gem',
		name = 'glowing_gem',
		flags = 'all_floors',
	})

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'group:natural_stone', },
		sidelen = 16,
		noise_params = {
			offset = 0.025,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = -10,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'sea_cave', },
		decoration = mod_name .. ':glowing_fungal_stone',
		place_offset_y = -1,
		name = 'glowing_fungal_stone_wet',
		flags = 'all_ceilings, all_floors, force_placement',
	})

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { mod_name .. ':granite', mod_name .. ':basalt', },
		sidelen = 16,
		noise_params = {
			offset = -0.005,
			scale = 0.02,
			spread = { x = 200, y = 200, z = 200 },
			seed = -13,
			octaves = 3,
			persist = 0.6
		},
		--fill_ratio = 0.001,
		biomes = { 'granite_lava', 'basalt_lava', },
		decoration = 'default:lava_source',
		name = 'lava_flow',
		place_offset_y = -1,  -- This fails in C.
		flags = 'all_ceilings, force_placement, underground',
	})

	--[[
	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { mod_name .. ':granite', },
		sidelen = 16,
		fill_ratio = 0.003,
		place_offset_y = -1,
		biomes = { 'basalt_lava', },
		decoration = 'default:lava_source',
		name = 'lava_source',
		flags = 'all_ceilings, force_placement',
	})
	--]]

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { mod_name .. ':black_sand', },
		sidelen = 16,
		noise_params = {
			offset = 0.02,
			scale = 0.04,
			spread = { x = 200, y = 200, z = 200 },
			seed = -70,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'coal', },
		decoration = 'fire:permanent_flame',
		name = 'Gas Flame',
		flags = 'all_floors, underground',
	})

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { mod_name .. ':black_sand', },
		sidelen = 16,
		fill_ratio = 0.04,
		place_offset_y = -1,
		biomes = { 'coal', },
		decoration = 'default:coalblock',
		name = 'Coal Seam',
		flags = 'all_floors, all_ceilings',
	})

	-- Make these grow, eventually.
	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { mod_name .. ':hot_rock', },
		sidelen = 16,
		fill_ratio = 0.04,
		biomes = { 'hot', },
		decoration = {
			mod_name .. ':hot_spike',
			mod_name .. ':hot_spike_2',
			mod_name .. ':hot_spike_3',
			mod_name .. ':hot_spike_4',
			mod_name .. ':hot_spike_5',
		},
		name = 'Hot Spike',
		flags = 'all_floors, underground',
	})

	--[[
	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'group:natural_stone', },
		sidelen = 16,
		noise_params = {
			offset = 0.025,
			scale = 0.025,
			spread = { x = 200, y = 200, z = 200 },
			seed = -31,
			octaves = 3,
			persist = 0.6
		},
		biomes = { 'stone', 'wet_stone', 'lichen', 'sea_cave',
			'mossy', 'algae', 'salt', 'basalt', 'sand', 'coal' },
		decoration = mod_name .. ':pretty_crystal',
		name = 'Pretty Crystal',
		flags = 'all_ceilings, all_floors, random_color_floor_ceiling',
	})
	--]]

	minetest.register_decoration({
		deco_type = 'simple',
		place_on = { 'group:natural_stone', mod_name .. ':granite', mod_name .. ':hot_rock', },
		sidelen = 16,
		fill_ratio = 0.1,
		biomes = { 'granite_lava', 'hot' },
		decoration = mod_name .. ':pretty_crystal',
		name = 'Pretty Crystal',
		flags = 'all_ceilings, all_floors, random_color_floor_ceiling, underground',
	})
end


do
	newnode = clone_node('default:dirt')
	newnode.description = 'Mushroom Soil'
	newnode.tiles = { newnode.tiles[1]..'^[colorize:#000000:100' }
	newnode.on_timer = function(pos, elapsed)
		local posu = {x=pos.x, y=pos.y+1, z=pos.z}
		--local daylight = minetest.get_node_light(posu, 0.5) or 0
		local light = minetest.get_node_light(posu, nil) or 0
		if light > light_max then
			return true
		end

		local node_up = minetest.get_node_or_nil(posu)
		if not node_up then
			return true
		end

		if node_up.name == 'air' then
			minetest.set_node(posu, { name = 'flowers:mushroom_brown' })
			return true
		end
	end
	newnode.on_construct = function(pos)
		local timer = minetest.get_node_timer(pos)
		local max = 1200
		if timer then
			timer:set(max, max > 1 and math.random(max - 1) or 0)
		end
	end
	minetest.register_node(mod_name .. ':mushroom_soil', newnode)

	for _, n in pairs({
		'group:wood',
		'farming:straw',
		'group:flora',
	}) do
		minetest.register_craft({
			output = mod_name .. ':mushroom_soil',
			type = 'shapeless',
			recipe = { 'default:dirt', 'flowers:mushroom_brown', n, },
		})
	end
end


function mod.register_cave_biome(def)
	def.source = 'fun_caves'
	def.underground = true
	layer_mod.register_biome(def)
end

do
    mod.register_cave_biome({
        name = 'stone',
        heat_point = 30,
        humidity_point = 50,
    })

    mod.register_cave_biome({
        name = 'wet_stone',
        heat_point = 100,
        humidity_point = 100,
        node_cave_liquid = 'default:water_source',
    })

    mod.register_cave_biome({
        name = 'sea_cave',
        heat_point = 50,
        humidity_point = 115,
        node_cave_liquid = 'default:water_source',
        node_gas = 'default:water_source',
    })

    mod.register_cave_biome({
        name = 'lichen',
        heat_point = 15,
        humidity_point = 20,
        node_cave_liquid = 'default:water_source',
        node_lining = mod_name .. ':stone_with_lichen',
    })

    mod.register_cave_biome({
        name = 'algae',
        heat_point = 65,
        humidity_point = 75,
        node_lining = mod_name .. ':stone_with_algae',
        node_cave_liquid = 'default:water_source',
    })

    mod.register_cave_biome({
        name = 'mossy',
        heat_point = 25,
        humidity_point = 75,
        node_lining = mod_name .. ':stone_with_moss',
        node_cave_liquid = 'default:water_source',
    })

    mod.register_cave_biome({
        name = 'basalt_lava',
        heat_point = 105,
        humidity_point = 70,
        node_stone = mod_name .. ':basalt',
        node_cave_liquid = 'default:lava_source',
    })

    mod.register_cave_biome({
        name = 'salt',
        heat_point = 50,
        humidity_point = -5,
        node_lining = mod_name .. ':stone_with_salt',
        node_stone = 'default:sandstone',
		surface_depth = 2,
		--y_min = 0,
    })

    mod.register_cave_biome({
        name = 'granite',
        heat_point = 60,
        humidity_point = 50,
        node_stone = mod_name .. ':granite',
    })

    mod.register_cave_biome({
        name = 'sand',
        heat_point = 70,
        humidity_point = 25,
        node_floor = 'default:sand',
        node_stone = 'default:sandstone',
		surface_depth = 2,
    })

    mod.register_cave_biome({
        name = 'coal',
        heat_point = 110,
        humidity_point = 0,
        node_lining = mod_name .. ':black_sand',
		node_stone = mod_name .. ':basalt',
		surface_depth = 2,
    })

    mod.register_cave_biome({
        name = 'hot',
        heat_point = 120,
        humidity_point = 35,
        node_floor = mod_name .. ':hot_rock',
		node_stone = mod_name .. ':granite',
        node_cave_liquid = 'default:lava_source',
    })

    mod.register_cave_biome({
		--deco = mod_name .. ':will_o_wisp_glow',
        name = 'ice',
        heat_point = -15,
        humidity_point = 50,
		node_cave_liquid = 'default:ice',
		node_stone = 'default:ice',
		surface_depth = 4,
    })
end


--[[
minetest.register_lbm({
	name = mod_name .. ':mush_timers',
	nodenames = {
		mod_name .. ':giant_mushroom_cap',
		mod_name .. ':giant_mushroom_stem',
		'flowers:mushroom_red',
		'flowers:mushroom_brown',
	},
	action = function(pos, node)
		local n = node.name
		minetest.registered_nodes[n].on_construct(pos)
	end,
})
--]]


mod.registered_cave_biomes = true
