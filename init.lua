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
nautilus.fuel = {['biofuel:biofuel'] = {amount=1},['biofuel:bottle_fuel'] = {amount=1},
        ['biofuel:phial_fuel'] = {amount=0.25}, ['biofuel:fuel_can'] = {amount=10}}
nautilus.air = {['vacuum:air_bottle'] = {amount=100,drop="vessels:steel_bottle"},}

nautilus.have_air = false
if minetest.get_modpath("vacuum") then
    nautilus.have_air = true
end
nautilus.have_air = minetest.settings:get_bool("nautilus_air", nautilus.have_air)
nautilus.hull_deep_limit = minetest.settings:get_bool("nautilus_hull_deep_limit", true)
nautilus.allow_put_light = minetest.settings:get_bool("nautilus_allow_put_light", true)

local nautilus_attached = {}

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
dofile(minetest.get_modpath("nautilus") .. DIR_DELIM .. "nautilus_air_management.lua")
dofile(minetest.get_modpath("nautilus") .. DIR_DELIM .. "nautilus_custom_physics.lua")


--
-- helpers and co.
--

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
            local indx = texture:find('nautilus_painting.png')
            if indx then
                l_textures[_] = "nautilus_painting.png^[multiply:".. colstr
            end
        end
        self.object:set_properties({textures=l_textures})
    end
end

-- destroy the boat
function nautilus.destroy(self, overload)
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self.driver_name then
        local driver = minetest.get_player_by_name(self.driver_name)
        -- prevent error when submarine of unlogged driver is destroied by preasure
        if driver then
            driver:set_detach()
            driver:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
            -- player should stand again
            player_api.set_animation(driver, "stand")
        end
        player_api.player_attached[self.driver_name] = nil
        self.driver_name = nil
    end

    local pos = self.object:get_pos()
    if self.pointer then self.pointer:remove() end
    if self.pointer_air then self.pointer_air:remove() end

    self.object:remove()

    pos.y=pos.y+2
    --[[for i=1,7 do
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:steel_ingot')
    end

    for i=1,7 do
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:mese_crystal')
    end]]--

    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'nautilus:boat')
    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:diamond')

    --[[local total_biofuel = math.floor(self.energy) - 1
    for i=0,total_biofuel do
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'biofuel:biofuel')
    end]]--
    if overload then
        local stack = ItemStack(self.item)
        local item_def = stack:get_definition()
        
        if item_def.overload_drop then
            for _,item in pairs(item_def.overload_drop) do
                minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},item)
            end
            return
        end
    end
    local stack = ItemStack(self.item)
    local item_def = stack:get_definition()
    if self.hull_integrity then
        local boat_wear = math.floor(65535*(1-(self.hull_integrity/item_def.hull_integrity)))
        stack:set_wear(boat_wear)
    end
    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5}, stack)
end

--returns 0 for old, 1 for new
function nautilus.detect_player_api(player)
    local player_proterties = player:get_properties()
    local mesh = "character.b3d"
    if player_proterties.mesh == mesh then
        local models = player_api.registered_models
        local character = models[mesh]
        if character then
            if character.animations.sit.eye_height then
                return 1
            else
                return 0
            end
        end
    end

    return 0
end

-- attach player
function nautilus.attach(self, player)
    --self.object:set_properties({glow = 10})
    local name = player:get_player_name()
    self.driver_name = name
    self.engine_running = true
    if (nautilus.have_air==false) then
        player:set_breath(10)
    end
    nautilus_attached[name] = self.object

    -- temporary------
    self.hp = 50 -- why? cause I can desist from destroy
    ------------------

    -- attach the driver
    player:set_attach(self.object, "", {x = 0, y = -7, z = -2}, {x = 0, y = 0, z = 0})
    local eye_y = -12
    if nautilus.detect_player_api(player) == 1 then
        eye_y = -5.5
    end
    player:set_eye_offset({x = 0, y = eye_y, z = 0}, {x = 0, y = eye_y, z = -5})
    player_api.player_attached[name] = true
    -- make the driver sit
    minetest.after(0.2, function()
        player = minetest.get_player_by_name(name)
        if player then
            player_api.set_animation(player, "sit")
        end
    end)
    -- disable gravity
    self.object:set_acceleration(vector.new())
end

local function open_cover(self, player)
    local pos = self.object:get_pos()
    pos.y = pos.y + 1
    local node = minetest.get_node_or_nil(pos)
    if node then
        local node_def = minetest.registered_nodes[node.name]
        if (node_def.liquidtype=="none") and (node_def.drowning==0) then
            if (self.air < nautilus.REAIR_ON_AIR) then
                self.air = nautilus.REAIR_ON_AIR
                minetest.chat_send_player(player:get_player_name(), "Nautilus has been filled with fresh air.")
            end
        else
            self.air = self.air - nautilus.OPEN_AIR_LOST
            if (self.air<0) then
                self.air = 0
            end
        end
    end
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
        textures = {"nautilus_black.png", "nautilus_painting.png", "nautilus_glass.png",
                "nautilus_metal.png", "nautilus_metal.png", "nautilus_orange.png",
                "nautilus_painting.png", "nautilus_red.png", "nautilus_painting.png",
                "nautilus_helice.png", "nautilus_interior.png", "nautilus_panel.png"},
    },
    textures = {},
    driver_name = nil,
    sound_handle = nil,
    energy = 0.001,
    air = nautilus.REAIR_ON_AIR,
    breath_time = 0,
    drown_time = 0,
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
    surface_level = nil,
    deep_limit = nil,
    deep_time = 0,
    hull_integrity = nil,
    item = "nautilus:boat",

    get_staticdata = function(self) -- unloaded/unloads ... is now saved
        return minetest.serialize({
            stored_energy = self.energy,
            stored_air = self.air,
            stored_owner = self.owner,
            stored_hp = self.hp,
            stored_color = self.color,
            stored_anchor = self.anchored,
            stored_buoyancy = self.buoyancy,
            stored_driver_name = self.driver_name,
            stored_surface_level = self.surface_level,
            stored_deep_limit = self.deep_limit,
            stored_hull_integrity = self.hull_integrity,
            stored_item = self.item,
        })
    end,

    on_activate = function(self, staticdata, dtime_s)
        if staticdata ~= "" and staticdata ~= nil then
            local data = minetest.deserialize(staticdata) or {}
            self.energy = data.stored_energy
            self.air = data.stored_air
            self.owner = data.stored_owner
            self.hp = data.stored_hp
            self.surface_level = data.stored_surface_level
            self.deep_limit = data.stored_deep_limit
            self.color = data.stored_color
            self.anchored = data.stored_anchor
            self.buoyancy = data.stored_buoyancy
            self.driver_name = data.stored_driver_name
            self.surface_level = data.stored_surface_level
            self.deep_limit = data.stored_deep_limit
            self.hull_integrity = data.stored_hull_integrity
            self.item = data.stored_item
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
        local energy_indicator_angle = nautilus.get_pointer_angle(self.energy, nautilus.MAX_FUEL)
        pointer:set_attach(self.object,'',nautilus.GAUGE_FUEL_POSITION,{x=0,y=0,z=energy_indicator_angle})
        self.pointer = pointer
        if nautilus.have_air then
            local pointer_air=minetest.add_entity(pos,'nautilus:pointer_air')
            local air_indicator_angle = nautilus.get_pointer_angle(self.air, 200)
            pointer_air:set_attach(self.object,'',nautilus.GAUGE_AIR_POSITION,{x=0,y=0,z=air_indicator_angle})
            self.pointer_air = pointer_air
        end

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

        local hull_direction = minetest.yaw_to_dir(yaw)
        local nhdir = {x=hull_direction.z,y=0,z=-hull_direction.x}        -- lateral unit vector
        local velocity = self.object:get_velocity()

        local longit_speed = nautilus.dot(velocity,hull_direction)
        local longit_drag = vector.multiply(hull_direction,longit_speed*
                longit_speed*LONGIT_DRAG_FACTOR*-1*nautilus.sign(longit_speed))
        local later_speed = nautilus.dot(velocity,nhdir)
        local later_drag = vector.multiply(nhdir,later_speed*later_speed*
                LATER_DRAG_FACTOR*-1*nautilus.sign(later_speed))
        local accel = vector.add(longit_drag,later_drag)

        local vel = self.object:get_velocity()
        local curr_pos = self.object:get_pos()
        self.object:move_to(curr_pos)

        local is_attached = false
        local player = nil
        if self.owner then
            player = minetest.get_player_by_name(self.owner)
            
            if player then
                local player_attach = player:get_attach()
                if player_attach then
                    if player_attach == self.object then is_attached = true end
                end
            end
        end
        
        if self.deep_limit then
            local deep = self.surface_level - curr_pos.y
            if (deep>self.deep_limit) then
                self.deep_time = self.deep_time + dtime
                if (self.deep_time > 1) then
                    self.deep_time = self.deep_time - 1
                    deep = deep - self.deep_limit
                    --minetest.sound_play("nautilus_crushing", {
                    minetest.sound_play("collision", {
                        to_player = self.driver_name,
                        --pos = curr_pos,
                        --max_hear_distance = 5,
                        gain = 0.1*deep,
                        fade = 0.0,
                        pitch = 1.0,
                    })
                    if (self.hull_integrity~=nil) then
                        self.hull_integrity = self.hull_integrity - deep
                        if (self.hull_integrity <= 0) then
                            --minetest.sound_play("nautilus_hull_break", {
                            minetest.sound_play("default_break_glass", {
                                to_player = self.driver_name,
                                --pos = curr_pos,
                                --max_hear_distance = 5,
                                gain = 2,
                                fade = 0.0,
                                pitch = 1.0,
                            })
                            nautilus.destroy(self, true)
                            return
                        end
                    end
                end
            end
        end

        if is_attached then
            local impact = nautilus.get_hipotenuse_value(vel, self.last_vel)
            if impact > 1 then
                minetest.sound_play("collision", {
                    to_player = self.driver_name,
                    --pos = curr_pos,
                    --max_hear_distance = 5,
                    gain = 1.0,
                    fade = 0.0,
                    pitch = 1.0,
                })
                if self.hull_integrity then
                    self.hull_integrity = self.hull_integrity - impact
                    if (self.hull_integrity <= 0) then
                        --minetest.sound_play("nautilus_hull_break", {
                        minetest.sound_play("default_break_glass", {
                            to_player = self.driver_name,
                            --pos = curr_pos,
                            --max_hear_distance = 5,
                            gain = 2,
                            fade = 0.0,
                            pitch = 1.0,
                        })
                        nautilus.destroy(self, true)
                        return
                    end
                end
            end
            if (nautilus.have_air==false) then
                if player:get_breath() < 10 then
                    player:set_breath(10)
                end
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
            newyaw = yaw + self.dtime*(1 - 1 / (math.abs(longit_speed) + 1)) *
                self.rudder_angle / 30 * turn_rate * nautilus.sign(longit_speed)
        end

        -- calculate energy consumption --
        ----------------------------------
        if self.energy > 0 then
            local zero_reference = vector.new()
            local acceleration = nautilus.get_hipotenuse_value(accel, zero_reference)
            local consumed_power = acceleration/nautilus.FUEL_CONSUMPTION
            self.energy = self.energy - consumed_power;

            local energy_indicator_angle = nautilus.get_pointer_angle(self.energy, nautilus.MAX_FUEL)
            if self.pointer:get_luaentity() then
                self.pointer:set_attach(self.object,'',nautilus.GAUGE_FUEL_POSITION,{x=0,y=0,z=energy_indicator_angle})
            else
                --in case it have lost the entity by some conflict
                self.pointer=minetest.add_entity(nautilus.GAUGE_FUEL_POSITION,'nautilus:pointer')
                self.pointer:set_attach(self.object,'',nautilus.GAUGE_FUEL_POSITION,{x=0,y=0,z=energy_indicator_angle})
            end
        end
        if self.energy <= 0 then
            self.engine_running = false
            if self.sound_handle then minetest.sound_stop(self.sound_handle) end
            self.object:set_animation_frame_speed(0)
        end
        ----------------------------
        -- end energy consumption --
        
        -- air consumption
        if nautilus.have_air and is_attached then
            if (self.air > 0) then
                self.air = self.air - dtime;
                
                local air_indicator_angle = nautilus.get_pointer_angle(self.air, nautilus.MAX_AIR)
                if self.pointer_air:get_luaentity() then
                    self.pointer_air:set_attach(self.object,'',nautilus.GAUGE_AIR_POSITION,
                            {x=0,y=0,z=air_indicator_angle})
                else
                    --in case it have lost the entity by some conflict
                    self.pointer_air=minetest.add_entity(nautilus.GAUGE_AIR_POSITION,'nautilus:pointer_air')
                    self.pointer_air:set_attach(self.object,'',nautilus.GAUGE_AIR_POSITION,
                            {x=0,y=0,z=air_indicator_angle})
                end
                
                self.breath_time = self.breath_time + dtime
                if (self.breath_time>=0.5) then
                    local times = math.floor(self.breath_time/0.5)
                    local breath = player:get_breath() + 1*times
                    local max_breath = player:get_properties().breath_max
                    if (breath<=max_breath) then
                        player:set_breath(breath+1)
                    end
                    self.breath_time = self.breath_time - 0.5*times
                end
            else
                self.breath_time = self.breath_time + dtime
                self.drown_time = self.drown_time + dtime
                if (self.breath_time>=0.3) then
                    local times = math.floor(self.breath_time/0.3)
                    local pos = player:get_pos()
                    pos.y = pos.y + 1
                    local node = minetest.get_node_or_nil(pos)
                    if node then
                        node = minetest.registered_nodes[node.name]
                    end
                    local breath = player:get_breath()
                    if (node==nil) or (node.drowning==0) then
                        breath = breath - 1*times
                        if (breath<=0) then
                            breath = 0
                            if (self.drown_time>=2) then
                                self.drown_time = 0
                                print(self.drown_time)
                                local hp = player:get_hp()
                                hp = hp - 1
                                player:set_hp(hp, {type="drown"})
                            end
                        end
                        player:set_breath(breath)
                    end
                    self.breath_time = self.breath_time - 0.3*times
                end
            end
        end

        --roll adjust
        ---------------------------------
        local sdir = minetest.yaw_to_dir(newyaw)
        local snormal = {x=sdir.z,y=0,z=-sdir.x}    -- rightside, dot is negative
        local prsr = nautilus.dot(snormal,nhdir)
        local rollfactor = -10
        local newroll = (prsr*math.rad(rollfactor))*later_speed
        --minetest.chat_send_all('newroll: '.. newroll)
        ---------------------------------
        -- end roll

        --local bob = nautilus.minmax(nautilus.dot(accel,hull_direction),0.8)    -- vertical bobbing

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
        local is_admin = false
        is_admin = minetest.check_player_privs(puncher, {server=true})
		local name = puncher:get_player_name()
        if self.owner and self.owner ~= name and self.owner ~= "" then
            if is_admin == false then return end
        end
        if self.owner == nil then
            self.owner = name
        end
            
        if self.driver_name and self.driver_name ~= name then
            -- do not allow other players to remove the object while there is a driver
            return
        end
        
        local is_attached = false
        if puncher:get_attach() == self.object then
            is_attached = true
        end

        local itmstck=puncher:get_wielded_item()
        local item_name = ""
        if itmstck then item_name = itmstck:get_name() end

        if is_attached == true then
            --refuel
            nautilus.load_fuel(self, puncher:get_player_name())
            self.engine_running = true
            --reair
            if nautilus.have_air then
                nautilus.load_air(self, puncher:get_player_name())
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
                    if not self.driver_name and toolcaps and toolcaps.damage_groups and
                            toolcaps.damage_groups.fleshy then
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
                nautilus.destroy(self, false)
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
            if (nautilus.have_air==false) then
              clicker:set_breath(10)
            end
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
            self.driver_name = nil
            --self.object:set_acceleration(vector.multiply(nautilus.vector_up, -nautilus.gravity))
            if nautilus.have_air then
                open_cover(self, clicker)
            end
            
            -- move player up
            minetest.after(0.1, function(pos)
                pos.y = pos.y + 2
                clicker:set_pos(pos)
            end, clicker:get_pos())
        elseif not self.driver_name then
            -- no driver => clicker is new driver
            nautilus.attach(self, clicker)
            if nautilus.have_air then
                open_cover(self, clicker)
            end
        end
    end,
})

-- norespawn in submarine when death
minetest.register_on_dieplayer(function(player, reason)
        local name = player:get_player_name()
        local object = nautilus_attached[name]
        if object then
            local entity = object:get_luaentity()
            if (entity) then
                if (entity.name=="nautilus:boat") then
                    if (entity.driver_name == name) then
                        player:set_detach()
                        entity.driver_name = nil
                        nautilus_attached[player:get_player_name()] = nil
                        player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
                        player_api.player_attached[name] = nil
                        player_api.set_animation(player, "stand")
                    end
                end
            end
        end
    end)

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


nautilus_newnode = nautilus.clone_node('default:ice')
nautilus_newnode.light_source = 14
--nautilus_newnode.liquid_alternative_flowing = 'nautilus:water_light'
--nautilus_newnode.liquid_alternative_source = 'nautilus:water_light'
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

-- item submarine on_place
nautilus.on_place = function(itemstack, placer, pointed_thing)
    if pointed_thing.type ~= "node" then
        return
    end
    
    local pointed_pos = pointed_thing.under
    local node_below = minetest.get_node(pointed_pos).name
    local nodedef = minetest.registered_nodes[node_below]
    if nodedef.liquidtype ~= "none" then
        -- minimum water depth has to be 2, for place submarine
        pointed_pos.y = pointed_pos.y - 1;
        node_below = minetest.get_node(pointed_pos).name
        nodedef = minetest.registered_nodes[node_below]
        if nodedef.liquidtype == "none" then
            minetest.chat_send_player(placer:get_player_name(), "Nautilus have to be placed on deeper water.")
            return
        end
        -- submarine can be placed only on water surface
        pointed_pos.y = pointed_pos.y + 2;
        node_below = minetest.get_node(pointed_pos).name
        nodedef = minetest.registered_nodes[node_below]
        if (nodedef.liquidtype ~= "none") or (nodedef.buildable_to==false) then
            minetest.chat_send_player(placer:get_player_name(), "Nautilus have to be placed on open water surface")
            return
        end
        pointed_pos.y = pointed_pos.y + 0.2
        local boat = minetest.add_entity(pointed_pos, "nautilus:boat")
        if boat and placer then
            local ent = boat:get_luaentity()
            local owner = placer:get_player_name()
            local item_def = itemstack:get_definition()
            ent.owner = owner
            ent.surface_level = pointed_thing.under.y
            if nautilus.hull_deep_limit then
              ent.deep_limit = item_def.deep_limit
            end
            if item_def.hull_integrity then
              local wear = (65535-itemstack:get_wear())/65535
              ent.hull_integrity = item_def.hull_integrity*wear
            end
            ent.item = itemstack:to_string()
            boat:set_yaw(placer:get_look_horizontal())
            itemstack:take_item()

            local properties = ent.object:get_properties()
            properties.infotext = owner .. " nice submarine"
            ent.object:set_properties(properties)
        end
    end

    return itemstack
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
minetest.register_tool("nautilus:boat", {
    description = "Nautilus",
    inventory_image = "nautilus_icon.png",
    liquids_pointable = true,
    stack_max = 1,

    on_place = nautilus.on_place,
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

if minetest.settings:get_bool("nautilus_variants", true) then
    dofile(minetest.get_modpath("nautilus") .. DIR_DELIM .. "nautilus_variants.lua")
end

