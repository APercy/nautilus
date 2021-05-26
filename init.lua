--
-- constants
--
local LONGIT_DRAG_FACTOR = 0.13*0.13
local LATER_DRAG_FACTOR = 2.0

minetest.register_lbm({                            -- this is to remove old bright water nodes after server crash etc
	name = "nautilus:delete_lights",
	run_at_every_load = true,
		nodenames = {"nautilus:water_light"},
		action = function(pos, node)
				minetest.set_node(pos, {name = "default:water_source"})
		end,
	})

nautilus={}
nautilus.gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.8
nautilus.fuel = {['biofuel:biofuel'] = 1,['biofuel:bottle_fuel'] = 1,['biofuel:phial_fuel'] = 0.25, ['biofuel:fuel_can'] = 10}

nautilus.colors ={
    black='#2b2b2b',
    blue='#0063b0',
    brown='#8c5922',
    cyan='#07B6BC',
    dark_green='#567a42',
    dark_grey='#6d6d6d',
    green='#4ee34c',
    grey='#9f9f9f',
    magenta='#ff0098',
    orange='#ff8b0e',
    pink='#ff62c6',
    red='#dc1818',
    violet='#a437ff',
    white='#FFFFFF',
    yellow='#ffe400',
}

function nautilus.clone_node(node_name)
	if not (node_name and type(node_name) == 'string') then
		return
	end

	local node = minetest.registered_nodes[node_name]
	return table.copy(node)
end

dofile(minetest.get_modpath("nautilus") .. DIR_DELIM .. "nautilus_control.lua")
dofile(minetest.get_modpath("nautilus") .. DIR_DELIM .. "nautilus_fuel_management.lua")
dofile(minetest.get_modpath("nautilus") .. DIR_DELIM .. "nautilus_custom_physics.lua")


--
-- helpers and co.
--

local creative_exists = minetest.global_exists("creative")

function nautilus.get_hipotenuse_value(point1, point2)
    return math.sqrt((point1.x - point2.x) ^ 2 + (point1.y - point2.y) ^ 2 + (point1.z - point2.z) ^ 2)
end

function nautilus.dot(v1,v2)
	return v1.x*v2.x+v1.y*v2.y+v1.z*v2.z
end

function nautilus.sign(n)
	return n>=0 and 1 or -1
end

function nautilus.minmax(v,m)
	return math.min(math.abs(v),m)*nautilus.sign(v)
end

-- lets control particle emission frequency
nautilus.last_light_particle_dtime = 0

--painting
function nautilus.paint(self, colstr)
    if colstr then
        self.color = colstr
        local l_textures = self.initial_properties.textures
        for _, texture in ipairs(l_textures) do
            local i,indx = texture:find('nautilus_painting.png')
            if indx then
                l_textures[_] = "nautilus_painting.png^[multiply:".. colstr
            end
        end
	    self.object:set_properties({textures=l_textures})
    end
end

-- destroy the boat
function nautilus.destroy(self)
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self.driver_name then
        -- detach the driver first (puncher must be driver)
        puncher:set_detach()
        puncher:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        player_api.player_attached[name] = nil
        -- player should stand again
        player_api.set_animation(puncher, "stand")
        self.driver_name = nil
    end

    local pos = self.object:get_pos()
    if self.pointer then self.pointer:remove() end

    self.object:remove()

    pos.y=pos.y+2
    --[[for i=1,7 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:steel_ingot')
    end

    for i=1,7 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:mese_crystal')
    end]]--

    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'nautilus:boat')
    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:diamond')

    --[[local total_biofuel = math.floor(self.energy) - 1
    for i=0,total_biofuel do
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'biofuel:biofuel')
    end]]--
end

-- attach player
function nautilus.attach(self, player)
    --self.object:set_properties({glow = 10})
    local name = player:get_player_name()
    self.driver_name = name
    self.engine_running = true
    player:set_breath(10)

    -- temporary------
    self.hp = 50 -- why? cause I can desist from destroy
    ------------------

    -- attach the driver
    player:set_attach(self.object, "", {x = 0, y = -7, z = -2}, {x = 0, y = 0, z = 0})
    player:set_eye_offset({x = 0, y = -12, z = 0}, {x = 0, y = -12, z = -5})
    player_api.player_attached[name] = true
    -- make the driver sit
    minetest.after(0.2, function()
        local player = minetest.get_player_by_name(name)
        if player then
	        player_api.set_animation(player, "sit")
        end
    end)
    -- disable gravity
    self.object:set_acceleration(vector.new())
end

--
-- entity
--

minetest.register_entity("nautilus:boat", {
	initial_properties = {
	    physical = true,
	    collisionbox = {-1, -1, -1, 1, 1, 1}, --{-1,0,-1, 1,0.3,1},
	    selectionbox = {-0.6,0.6,-0.6, 0.6,1,0.6},
	    visual = "mesh",
	    mesh = "nautilus.b3d",
        textures = {"nautilus_black.png", "nautilus_painting.png", "nautilus_glass.png", "nautilus_metal.png", "nautilus_metal.png", "nautilus_orange.png", "nautilus_painting.png", "nautilus_red.png", "nautilus_painting.png", "nautilus_helice.png", "nautilus_interior.png", "nautilus_panel.png"},
    },
    textures = {},
	driver_name = nil,
	sound_handle = nil,
    energy = 0.001,
    owner = "",
    static_save = true,
    infotext = "A nice submarine",
    lastvelocity = vector.new(),
    hp = 50,
    color = "#ffe400",
    rudder_angle = 0,
    timeout = 0;
    buoyancy = 0.98,
    max_hp = 50,
    engine_running = false,
    anchored = false,
    physics = nautilus.physics,
    --water_drag = 0,

    get_staticdata = function(self) -- unloaded/unloads ... is now saved
        return minetest.serialize({
            stored_energy = self.energy,
            stored_owner = self.owner,
            stored_hp = self.hp,
            stored_color = self.color,
            stored_anchor = self.anchored,
            stored_buoyancy = self.buoyancy,
            stored_driver_name = self.driver_name,
        })
    end,

	on_activate = function(self, staticdata, dtime_s)
        if staticdata ~= "" and staticdata ~= nil then
            local data = minetest.deserialize(staticdata) or {}
            self.energy = data.stored_energy
            self.owner = data.stored_owner
            self.hp = data.stored_hp
            self.color = data.stored_color
            self.anchored = data.stored_anchor
            self.buoyancy = data.stored_buoyancy
            self.driver_name = data.stored_driver_name
            --minetest.debug("loaded: ", self.energy)
            local properties = self.object:get_properties()
            properties.infotext = data.stored_owner .. " nice submarine"
            self.object:set_properties(properties)
        end

        nautilus.paint(self, self.color)
        local pos = self.object:get_pos()

        --animation load - stoped
        self.object:set_animation({x = 1, y = 5}, 0, 0, true);

	    local pointer=minetest.add_entity(pos,'nautilus:pointer')
        local energy_indicator_angle = nautilus.get_pointer_angle(self.energy)
	    pointer:set_attach(self.object,'',{x=0,y=-8.45,z=5.31},{x=0,y=0,z=energy_indicator_angle})
	    self.pointer = pointer

		self.object:set_armor_groups({immortal=1})

        mobkit.actfunc(self, staticdata, dtime_s)

	end,

	on_step = function(self, dtime)
        mobkit.stepfunc(self, dtime)
        
        local accel_y = self.object:get_acceleration().y
        local rotation = self.object:get_rotation()
        local yaw = rotation.y
		local newyaw=yaw
        local pitch = rotation.x
        local newpitch = pitch
		local roll = rotation.z
		local newroll=roll

        local hull_direction = minetest.yaw_to_dir(yaw)
        local nhdir = {x=hull_direction.z,y=0,z=-hull_direction.x}		-- lateral unit vector
        local velocity = self.object:get_velocity()

        local longit_speed = nautilus.dot(velocity,hull_direction)
        local longit_drag = vector.multiply(hull_direction,longit_speed*longit_speed*LONGIT_DRAG_FACTOR*-1*nautilus.sign(longit_speed))
		local later_speed = nautilus.dot(velocity,nhdir)
		local later_drag = vector.multiply(nhdir,later_speed*later_speed*LATER_DRAG_FACTOR*-1*nautilus.sign(later_speed))
        local accel = vector.add(longit_drag,later_drag)

        local vel = self.object:get_velocity()

        local is_attached = false
        if self.owner then
            local player = minetest.get_player_by_name(self.owner)
            
            if player then
                local player_attach = player:get_attach()
                if player_attach then
                    if player_attach == self.object then is_attached = true end
                end
            end
        end

		if is_attached then
            local impact = nautilus.get_hipotenuse_value(vel, self.last_vel)
            if impact > 1 then
                --self.damage = self.damage + impact --sum the impact value directly to damage meter
                local curr_pos = self.object:get_pos()
                minetest.sound_play("collision", {
                    to_player = self.driver_name,
	                --pos = curr_pos,
	                --max_hear_distance = 5,
	                gain = 1.0,
                    fade = 0.0,
                    pitch = 1.0,
                })
                --[[if self.damage > 100 then --if acumulated damage is greater than 100, adieu
                    nautilus.destroy(self)   
                end]]--
            end
            local player = minetest.get_player_by_name(self.owner)
            if player:get_breath() < 10 then
                player:set_breath(10)
            end
            --control
			accel = nautilus.nautilus_control(self, dtime, hull_direction, longit_speed, accel) or vel

            --light
            --local pos = obj:get_pos()
            --local node = minetest.get_node(pos)
            
        else
            -- for some engine error the player can be detached from the submarine, so lets set him attached again
            local can_stop = true
            if self.owner and self.driver_name then
                -- attach the driver again
                local player = minetest.get_player_by_name(self.owner)
                if player then
                    nautilus.attach(self, player)
                    can_stop = false
                end
            end

            if can_stop then
                --detach player
                if self.sound_handle ~= nil then
	                minetest.sound_stop(self.sound_handle)
	                self.sound_handle = nil
                end
            end
		end

		if math.abs(self.rudder_angle)>5 then 
            local turn_rate = math.rad(24)
			newyaw = yaw + self.dtime*(1 - 1 / (math.abs(longit_speed) + 1)) * self.rudder_angle / 30 * turn_rate * nautilus.sign(longit_speed)
		end

        -- calculate energy consumption --
        ----------------------------------
        if self.energy > 0 then
            local zero_reference = vector.new()
            local acceleration = nautilus.get_hipotenuse_value(accel, zero_reference)
            local consumed_power = acceleration/6000
            self.energy = self.energy - consumed_power;

            local energy_indicator_angle = nautilus.get_pointer_angle(self.energy)
            if self.pointer:get_luaentity() then
                self.pointer:set_attach(self.object,'',{x=0,y=-8.45,z=5.31},{x=0,y=0,z=energy_indicator_angle})
            else
                --in case it have lost the entity by some conflict
                self.pointer=minetest.add_entity({x=0,y=-8.45,z=5.31},'nautilus:pointer')
                self.pointer:set_attach(self.object,'',{x=0,y=-8.45,z=5.31},{x=0,y=0,z=energy_indicator_angle})
            end
        end
        if self.energy <= 0 then
            self.engine_running = false
            if self.sound_handle then minetest.sound_stop(self.sound_handle) end
		    self.object:set_animation_frame_speed(0)
        end
        ----------------------------
        -- end energy consumption --

        --roll adjust
        ---------------------------------
		local sdir = minetest.yaw_to_dir(newyaw)
		local snormal = {x=sdir.z,y=0,z=-sdir.x}	-- rightside, dot is negative
		local prsr = nautilus.dot(snormal,nhdir)
        local rollfactor = -10
        newroll = (prsr*math.rad(rollfactor))*later_speed
        --minetest.chat_send_all('newroll: '.. newroll)
        ---------------------------------
        -- end roll

		--local bob = nautilus.minmax(nautilus.dot(accel,hull_direction),0.8)	-- vertical bobbing

		if self.isinliquid then
			accel.y = accel_y -- + bob
			newpitch = velocity.y * math.rad(6)
			self.object:set_acceleration(accel)
		end

		if newyaw~=yaw or newpitch~=pitch or newroll~=roll then
            self.object:set_rotation({x=newpitch,y=newyaw,z=newroll})
        end

        --center steering
        local rudder_limit = 30
        if longit_speed > 0 then
            local factor = 1
            if self.rudder_angle > 0 then factor = -1 end
            local correction = (rudder_limit*(longit_speed/100)) * factor
            self.rudder_angle = self.rudder_angle + correction
        end

        --saves last velocy for collision detection (abrupt stop)
        self.last_vel = self.object:get_velocity()
	end,

	on_punch = function(self, puncher, ttime, toolcaps, dir, damage)
		if not puncher or not puncher:is_player() then
			return
		end
		local name = puncher:get_player_name()
        if self.owner and self.owner ~= name and self.owner ~= "" then return end
        if self.owner == nil then
            self.owner = name
        end
        	
        if self.driver_name and self.driver_name ~= name then
			-- do not allow other players to remove the object while there is a driver
			return
		end

        local touching_ground, liquid_below = nautilus.check_node_below(self.object)
        
        local is_attached = false
        if puncher:get_attach() == self.object then
            is_attached = true
        end

        local itmstck=puncher:get_wielded_item()
        local item_name = ""
        if itmstck then item_name = itmstck:get_name() end

        if is_attached == true then
            if item_name == "biofuel:biofuel" then
                --refuel
                nautilus_load_fuel(self, puncher:get_player_name())
                self.engine_running = true
            else
                --nautilus.put_light(self.object)
            end
        end

        if is_attached == false then

            -- deal with painting or destroying
		    if itmstck then
			    local _,indx = item_name:find('dye:')
			    if indx then

                    --lets paint!!!!
				    local color = item_name:sub(indx+1)
				    local colstr = nautilus.colors[color]
                    --minetest.chat_send_all(color ..' '.. dump(colstr))
				    if colstr then
                        nautilus.paint(self, colstr)
					    itmstck:set_count(itmstck:get_count()-1)
					    puncher:set_wielded_item(itmstck)
				    end
                    -- end painting

			    else -- deal damage
				    if not self.driver and toolcaps and toolcaps.damage_groups and toolcaps.damage_groups.fleshy then
					    --mobkit.hurt(self,toolcaps.damage_groups.fleshy - 1)
					    --mobkit.make_sound(self,'hit')
                        self.hp = self.hp - 10
                        minetest.sound_play("collision", {
	                        object = self.object,
	                        max_hear_distance = 5,
	                        gain = 1.0,
                            fade = 0.0,
                            pitch = 1.0,
                        })
				    end
			    end
            end

            if self.hp <= 0 then
                nautilus.destroy(self)
            end

        end
        
	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end

		local name = clicker:get_player_name()
        if self.owner and self.owner ~= name and self.owner ~= "" then return end
        if self.owner == "" then
            self.owner = name
        end

		if name == self.driver_name then
            self.engine_running = false

			-- driver clicked the object => driver gets off the vehicle
            --self.object:set_properties({glow = 0})
			self.driver_name = nil
            clicker:set_breath(10)
			-- sound and animation
            if self.sound_handle then
                minetest.sound_stop(self.sound_handle)
                self.sound_handle = nil
            end
			
			--self.engine:set_animation_frame_speed(0)

            -- detach the player
		    clicker:set_detach()
		    player_api.player_attached[name] = nil
		    clicker:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
		    player_api.set_animation(clicker, "stand")
		    self.driver = nil
            --self.object:set_acceleration(vector.multiply(nautilus.vector_up, -nautilus.gravity))
        
		elseif not self.driver_name then
            -- no driver => clicker is new driver
            nautilus.attach(self, clicker)
		end
	end,
})

-----------
-- light --
-----------

function nautilus.put_light(object, name)
	local pos = object:getpos()
	if not pos then
		return
	end

    local player = minetest.get_player_by_name(name)
    local dir = player:get_look_dir()
    pos = nautilus.find_collision(pos,dir)

    if pos then
	    local n = minetest.get_node_or_nil(pos)
        --minetest.chat_send_player(name, n.name)
        if n and n.name == 'default:water_source' then
		    minetest.set_node(pos, {name='nautilus:water_light'})
		    --local timer = minetest.get_node_timer(pos)
		    --timer:set(10, 0)
            minetest.after(10,function(pos)
			    local node = minetest.get_node_or_nil(pos)
			    if node and node.name == "nautilus:water_light" then
				    minetest.swap_node(pos, {name="default:water_source"})
			    end
			end, pos)
	    end
    end

	--[[
    local r = 6
    local count = 0
	for _ = 1, 3 do
		local fpos = {}
		fpos.x = pos.x + math.random(2 * r + 1) - r - 1
		fpos.y = pos.y + math.random(2 * r + 1) - r - 1
		fpos.z = pos.z + math.random(2 * r + 1) - r - 1
		local n = minetest.get_node_or_nil(fpos)
        if n and n.name == 'default:water_source' then
			minetest.set_node(fpos, {name='nautilus:water_light'})
			local timer = minetest.get_node_timer(fpos)
			timer:set(10, 0)
			count = count + 1
		end
	end

	return count]]--
end


nautilus_newnode = nautilus.clone_node('default:water_source')
nautilus_newnode.light_source = 14
nautilus_newnode.liquid_alternative_flowing = 'nautilus:water_light'
nautilus_newnode.liquid_alternative_source = 'nautilus:water_light'
nautilus_newnode.on_timer = function(pos)
	minetest.remove_node(pos)
end
minetest.register_node('nautilus:water_light', nautilus_newnode)

-- [[ from Gundul mod lightup ]]--
function nautilus.find_collision(pos1,dir)
	pos1 = mobkit.pos_shift(pos1,vector.multiply(dir,1))
    local distance = 20
	local pos2 = mobkit.pos_shift(pos1,vector.multiply(dir,distance))
	local ray = minetest.raycast(pos1, pos2, true, false)
			for pointed_thing in ray do
				if pointed_thing.type == "node" then
					local dist = math.floor(vector.distance(pos1,pointed_thing.under))
					pos2 = mobkit.pos_shift(pos1,vector.multiply(dir,dist-1))
					return pos2
				end
				if pointed_thing.type == "object" then
					local obj = pointed_thing.ref
					local objpos = obj:get_pos()
					return objpos
				end
			end
	return nil
end

-----------
-- items
-----------

-- blades
minetest.register_craftitem("nautilus:engine",{
	description = "Nautilus Engine",
	inventory_image = "nautilus_icon_engine.png",
})
-- cabin
minetest.register_craftitem("nautilus:cabin",{
	description = "Cabin for Nautilus",
	inventory_image = "nautilus_icon_cabin.png",
})

-- boat
minetest.register_craftitem("nautilus:boat", {
	description = "Nautilus",
	inventory_image = "nautilus_icon.png",
    liquids_pointable = true,

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
        
        local pointed_pos = pointed_thing.under
        local node_below = minetest.get_node(pointed_pos).name
        local nodedef = minetest.registered_nodes[node_below]
        if nodedef.liquidtype ~= "none" then
			pointed_pos.y=pointed_pos.y+0.2
			local boat = minetest.add_entity(pointed_pos, "nautilus:boat")
			if boat and placer then
                local ent = boat:get_luaentity()
                local owner = placer:get_player_name()
                ent.owner = owner
				boat:set_yaw(placer:get_look_horizontal())
				itemstack:take_item()

                local properties = ent.object:get_properties()
                properties.infotext = owner .. " nice submarine"
                ent.object:set_properties(properties)
			end
        end

		return itemstack
	end,
})

--
-- crafting
--

if minetest.get_modpath("default") then
	minetest.register_craft({
		output = "nautilus:boat",
		recipe = {
			{"",                "",               ""},
			{"nautilus:engine", "nautilus:cabin", "nautilus:engine"},
		}
	})
	minetest.register_craft({
		output = "nautilus:engine",
		recipe = {
			{"",                    "default:steel_ingot", ""},
			{"default:steel_ingot", "default:mese_crystal",  "default:steel_ingot"},
			{"",                    "default:steel_ingot", "default:diamond"},
		}
	})
	minetest.register_craft({
		output = "nautilus:cabin",
		recipe = {
			{"default:steel_ingot", "default:steelblock", "default:steel_ingot"},
			{"default:steelblock",  "default:glass",      "default:steelblock"},
			{"default:steel_ingot", "default:steelblock", "default:steel_ingot"},
		}
	})
end


