--
-- air
--
nautilus.GAUGE_AIR_POSITION = {x=0,y=-8.45,z=5.31}
nautilus.MAX_AIR = minetest.settings:get("nautilus_max_air") or 1200
nautilus.REAIR_ON_AIR = minetest.settings:get("nautilus_reair_on_air") or 200
nautilus.OPEN_AIR_LOST = minetest.settings:get("nautilus_open_air_lost") or 20

minetest.register_entity('nautilus:pointer_air',{
initial_properties = {
	physical = false,
	collide_with_objects=false,
	pointable=false,
	visual = "mesh",
	mesh = "nautilus_pointer.b3d",
	textures = {"nautilus_interior.png^[multiply:#0000FF"},
	},
	
on_activate = function(self,std)
	self.sdata = minetest.deserialize(std) or {}
	if self.sdata.remove then self.object:remove() end
end,
	
get_staticdata=function(self)
  	
  self.sdata.remove=true
  return minetest.serialize(self.sdata)
end,
	
})

-- definedin fuel magament file
--function nautilus.contains(table, val)

function nautilus.load_air(self, player_name)
    local player = minetest.get_player_by_name(player_name)
    local inv = player:get_inventory()

    local itmstck=player:get_wielded_item()
    local item_name = ""
    if itmstck then item_name = itmstck:get_name() end

    --minetest.debug("air: ", item_name)
    local air = nautilus.contains(nautilus.air, item_name)
    if air then
        local stack = ItemStack(item_name .. " 1")
        
        if self.air < nautilus.MAX_AIR then
            inv:remove_item("main", stack)
            self.air = self.air + air.amount
            if self.air > nautilus.MAX_AIR then self.air = nautilus.MAX_AIR end
            
            if air.drop then
                local leftover = inv:add_item("main", air.drop)
                if leftover then
                    minetest.item_drop(leftover, player, player:get_pos())
                end
            end

            local air_indicator_angle = nautilus.get_pointer_angle(self.air, nautilus.MAX_AIR)
            self.pointer:set_attach(self.object,'',nautilus.GAUGE_AIR_POSITION,{x=0,y=0,z=air_indicator_angle})
        end
        
        return true
    end

    return false
end

