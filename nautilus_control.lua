--global constants

nautilus.nautilus_last_time_command = 0
nautilus.vector_up = vector.new(0, 1, 0)

function nautilus.get_pointer_angle(value, maxvalue)
    local angle = value/maxvalue * 180
    angle = angle - 90
    angle = angle * -1
    return angle
end

function nautilus.check_node_below(obj)
	local pos_below = obj:get_pos()
	pos_below.y = pos_below.y - 0.1
	local node_below = minetest.get_node(pos_below).name
	local nodedef = minetest.registered_nodes[node_below]
	local touching_ground = not nodedef or -- unknown nodes are solid
			nodedef.walkable or false
	local liquid_below = not touching_ground and nodedef.liquidtype ~= "none"
	return touching_ground, liquid_below
end

function nautilus.nautilus_control(self, dtime, hull_direction, longit_speed, accel)
    nautilus.nautilus_last_time_command = nautilus.nautilus_last_time_command + dtime
    if nautilus.nautilus_last_time_command > 1 then nautilus.nautilus_last_time_command = 1 end
	local player = minetest.get_player_by_name(self.driver_name)
    local retval_accel = accel;
    
	-- player control
	if player then
		local ctrl = player:get_player_control()
		local max_speed_anchor = 0.2
        if ctrl.aux1 then
            if nautilus.nautilus_last_time_command > 0.3 and
                    longit_speed < max_speed_anchor and
                    longit_speed > -max_speed_anchor then
                nautilus.nautilus_last_time_command = 0
		        if self.anchored == false then
                    self.anchored = true
                    self.object:set_velocity(vector.new())
                    minetest.chat_send_player(self.driver_name, 'anchors away!')
                    self.buoyancy = 0.98
                else
                    self.anchored = false
                    minetest.chat_send_player(self.driver_name, 'weigh anchor!')
                end
            end
            self.rudder_angle = 0
        end
        if ctrl.up and ctrl.down and nautilus.nautilus_last_time_command > 0.3 and
                self.energy > 0 and nautilus.allow_put_light then
            nautilus.nautilus_last_time_command = 0
            nautilus.put_light(self.object, self.driver_name)
            self.energy = self.energy - 0.005
        end

        if self.anchored == false and self.engine_running == true then
	        local paddleacc
	        if longit_speed < 5.0 and ctrl.up then
		        paddleacc = 0.5
	        elseif longit_speed >  -1.0 and ctrl.down then
		        paddleacc = -0.5
	        end

            if ctrl.up then
                self.object:set_animation_frame_speed(40)
            elseif ctrl.down then
                self.object:set_animation_frame_speed(-40)
            else
                self.object:set_animation_frame_speed(0)
            end

	        if paddleacc then
                retval_accel=vector.add(accel,vector.multiply(hull_direction,paddleacc))
            end
            --minetest.chat_send_all('paddle: '.. paddleacc)
        end

		if ctrl.jump then
            self.buoyancy = 0.97
		elseif ctrl.sneak then
            self.buoyancy = 1.03
        else
            --check if its liquid above
            local pos_up = self.object:get_pos()
            pos_up.y = pos_up.y + 2
            local node_up = minetest.get_node(pos_up).name
            local nodedef = minetest.registered_nodes[node_up]
            local liquid_up = nodedef.liquidtype ~= "none"
            if not liquid_up then
                --if in surface
                self.buoyancy = 0.98
            else
                --if submerged
                self.buoyancy = 1
            end
		end

		-- rudder
        local rudder_limit = 30
		if ctrl.right then
			self.rudder_angle = math.max(self.rudder_angle-60*dtime,-rudder_limit)
		elseif ctrl.left then
			self.rudder_angle = math.min(self.rudder_angle+60*dtime,rudder_limit)
		end
	end
    return retval_accel
end



