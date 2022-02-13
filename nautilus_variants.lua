
-- wooden cabin
minetest.register_craftitem("nautilus:cabin_wooden",{
    description = "Wooden Cabin for Nautilus",
    inventory_image = "nautilus_icon_cabin.png",
})

-- wooden boat
minetest.register_tool("nautilus:boat_wooden", {
    description = "Wooden Nautilus",
    inventory_image = "nautilus_icon.png",
    liquids_pointable = true,
    stack_max = 1,
    
    hull_integrity = 50,
    deep_limit = 25,
    overload_drop = {"nautilus:engine", "default:bronze_ingot 3"},

    on_place = nautilus.on_place,
})

-- boat
minetest.override_item("nautilus:boat", {
    hull_integrity = 75,
    deep_limit = 100,
    overload_drop = {"nautilus:engine", "default:steel_ingot 3","default:steelblock 3"},
})

-- carbon steel cabin
minetest.register_craftitem("nautilus:cabin_carbon_steel",{
    description = "Carbon Steel Cabin for Nautilus",
    inventory_image = "nautilus_icon_cabin.png",
})

-- cabron teel boat
minetest.register_tool("nautilus:boat_carbon_steel", {
    description = "Carbon Steel Nautilus",
    inventory_image = "nautilus_icon.png",
    liquids_pointable = true,
    stack_max = 1,
    
    hull_integrity = 100,
    deep_limit = 300,
    overload_drop = {"nautilus:engine", "technic:carbon_steel_ingot 3","technic:carbon_steel_block 3"},

    on_place = nautilus.on_place,
})

-- stainless steel cabin
minetest.register_craftitem("nautilus:cabin_stainless_steel",{
    description = "Stainless Steel Cabin for Nautilus",
    inventory_image = "nautilus_icon_cabin.png",
})

-- stainless steel boat
minetest.register_tool("nautilus:boat_stainless_steel", {
    description = "Stainless Steel Nautilus",
    inventory_image = "nautilus_icon.png",
    liquids_pointable = true,
    stack_max = 1,
    
    hull_integrity = 200,
    deep_limit = 900,
    overload_drop = {"nautilus:engine", "technic:stainless_steel_ingot 3","technic:stainless_steel_block 3"},

    on_place = nautilus.on_place,
})

-- mithril cabin
minetest.register_craftitem("nautilus:cabin_mithril",{
    description = "Mithril Cabin for Nautilus",
    inventory_image = "nautilus_icon_cabin.png",
})

-- mithril boat
minetest.register_tool("nautilus:boat_mithril", {
    description = "Mithril Nautilus",
    inventory_image = "nautilus_icon.png",
    liquids_pointable = true,
    stack_max = 1,
    
    hull_integrity = 400,
    deep_limit = nil,
    overload_drop = {"nautilus:engine", "moreores:mithril_ingot 3","moreores:mithril_block 3"},

    on_place = nautilus.on_place,
})

if minetest.get_modpath("default") then
    local wood_name = "group:wood"
    if minetest.get_modpath("oak") then
      wood_name = "oak:wood"
    end
    
    minetest.register_craft({
        output = "nautilus:boat_wooden",
        recipe = {
            {"",                "",               ""},
            {"nautilus:engine", "nautilus:cabin_wooden", "nautilus:engine"},
        }
    })
    minetest.register_craft({
        output = "nautilus:cabin_wooden",
        recipe = {
            {"default:bronze_ingot", wood_name, "default:bronze_ingot"},
            {wood_name,  "default:glass",      wood_name},
            {"default:bronze_ingot", wood_name, "default:bronze_ingot"},
        }
    })
end

if minetest.get_modpath("technic") then
    minetest.register_craft({
        output = "nautilus:boat_carbon_steel",
        recipe = {
            {"",                "",               ""},
            {"nautilus:engine", "nautilus:cabin_carbon_steel", "nautilus:engine"},
        }
    })
    minetest.register_craft({
        output = "nautilus:cabin_carbon_steel",
        recipe = {
            {"technic:carbon_steel_ingot", "technic:carbon_steel_block", "technic:carbon_steel_ingot"},
            {"technic:carbon_steel_block",  "default:glass",      "technic:carbon_steel_block"},
            {"technic:carbon_steel_ingot", "technic:carbon_steel_block", "technic:carbon_steel_ingot"},
        }
    })
    
    minetest.register_craft({
        output = "nautilus:boat_stainless_steel",
        recipe = {
            {"",                "",               ""},
            {"nautilus:engine", "nautilus:cabin_stainless_steel", "nautilus:engine"},
        }
    })
    minetest.register_craft({
        output = "nautilus:cabin_stainless_steel",
        recipe = {
            {"technic:stainless_steel_ingot", "technic:stainless_steel_block", "technic:stainless_steel_ingot"},
            {"technic:stainless_steel_block",  "default:glass",      "technic:stainless_steel_block"},
            {"technic:stainless_steel_ingot", "technic:stainless_steel_block", "technic:stainless_steel_ingot"},
        }
    })
end

if minetest.get_modpath("moreores") then
    minetest.register_craft({
        output = "nautilus:boat_mithril",
        recipe = {
            {"",                "",               ""},
            {"nautilus:engine", "nautilus:cabin_mithril", "nautilus:engine"},
        }
    })
    minetest.register_craft({
        output = "nautilus:cabin_mithril",
        recipe = {
            {"moreores:mithril_ingot", "moreores:mithril_block", "moreores:mithril_ingot"},
            {"moreores:mithril_block", "default:glass", "moreores:mithril_block"},
            {"moreores:mithril_ingot", "moreores:mithril_block", "moreores:mithril_ingot"},
        }
    })
end

