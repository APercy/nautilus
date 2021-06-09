--
-- fuel
--
nautilus.GAUGE_FUEL_POSITION = {x=0,y=-8.45,z=5.31}
nautilus.MAX_FUEL = minetest.settings:get("nautilus_max_fuel") or 10
nautilus.FUEL_CONSUMPTION = minetest.settings:get("nautilus_fuel_consumption") or 6000

minetest.register_entity('nautilus:pointer',{
initial_properties = {
	physical = false,
	collide_with_objects=false,
	pointable=false,
	visual = "mesh",
	mesh = "pointer.b3d",
	textures = {"nautilus_interior.png"},
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

function nautilus.contains(table, val)
    for k,v in pairs(table) do
        if k == val then
            return v
        end
    end
    return false
end

function nautilus.load_fuel(self, player_name)
    local player = minetest.get_player_by_name(player_name)
    local inv = player:get_inventory()

    local itmstck=player:get_wielded_item()
    local item_name = ""
    if itmstck then item_name = itmstck:get_name() end

    --minetest.debug("fuel: ", item_name)
    local fuel = nautilus.contains(nautilus.fuel, item_name)
    if fuel then
        local stack = ItemStack(item_name .. " 1")

        if self.energy < nautilus.MAX_FUEL then
            inv:remove_item("main", stack)
            self.energy = self.energy + fuel.amount
            if self.energy > nautilus.MAX_FUEL then self.energy = nautilus.MAX_FUEL end
            
            if fuel.drop then
                local leftover = inv:add_item("main", fuel.drop)
                if leftover then
                    minetest.item_drop(leftover, player, player:get_pos())
                end
            end

            local energy_indicator_angle = nautilus.get_pointer_angle(self.energy, nautilus.MAX_FUEL)
            self.pointer:set_attach(self.object,'',nautilus.GAUGE_FUEL_POSITION,{x=0,y=0,z=energy_indicator_angle})
        end
        
        return true
    end

    return false
end

