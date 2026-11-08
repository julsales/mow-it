--!strict
-- Tool ladder, 48 tools in 6 families (spec: openspec/specs/tools-and-vehicles).
-- Nail Clipper -> MOWZILLA. Rideable tools are driven and mow by contact;
-- FuelType ~= "None" tools consume fuel (manual / automation / Infinite Fuel pass).

export type ToolDef = { Id: string, DisplayName: string, Power: number, Radius: number, Cooldown: number, Price: number, RequiredZone: number, Rideable: boolean, FuelType: string }

local Tools: { ToolDef } = {
	{ Id = "nail_clipper", DisplayName = "Nail Clipper", Power = 1, Radius = 4.0, Cooldown = 0.45, Price = 0, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "safety_scissors", DisplayName = "Safety Scissors", Power = 4, Radius = 4.8, Cooldown = 0.44, Price = 70, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "kitchen_scissors", DisplayName = "Kitchen Scissors", Power = 8, Radius = 5.5, Cooldown = 0.43, Price = 110, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "garden_shears", DisplayName = "Garden Shears", Power = 13, Radius = 6.2, Cooldown = 0.43, Price = 150, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "hand_sickle", DisplayName = "Hand Sickle", Power = 20, Radius = 7.0, Cooldown = 0.42, Price = 220, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "grass_whip", DisplayName = "Grass Whip", Power = 28, Radius = 7.8, Cooldown = 0.41, Price = 320, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "reel_mower", DisplayName = "Manual Reel Mower", Power = 37, Radius = 8.5, Cooldown = 0.41, Price = 460, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "turbo_reel", DisplayName = "Turbo Reel Mower", Power = 47, Radius = 9.2, Cooldown = 0.40, Price = 670, RequiredZone = 1, Rideable = false, FuelType = "None" },
	{ Id = "hedge_trimmer", DisplayName = "Electric Hedge Trimmer", Power = 58, Radius = 10.0, Cooldown = 0.39, Price = 980, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "cordless_shears", DisplayName = "Cordless Power Shears", Power = 71, Radius = 10.8, Cooldown = 0.38, Price = 1420, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "string_trimmer", DisplayName = "String Trimmer", Power = 84, Radius = 11.5, Cooldown = 0.38, Price = 2050, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "mega_trimmer", DisplayName = "Mega String Trimmer", Power = 99, Radius = 12.2, Cooldown = 0.37, Price = 2980, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "electric_reel", DisplayName = "Electric Reel Mower", Power = 115, Radius = 13.0, Cooldown = 0.36, Price = 4320, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "trimmer_pro", DisplayName = "Trimmer Pro 3000", Power = 132, Radius = 13.8, Cooldown = 0.35, Price = 6260, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "garden_saw", DisplayName = "Power Garden Saw", Power = 150, Radius = 14.5, Cooldown = 0.35, Price = 9080, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "volt_whacker", DisplayName = "Volt Whacker X", Power = 169, Radius = 15.2, Cooldown = 0.34, Price = 13170, RequiredZone = 2, Rideable = false, FuelType = "Battery" },
	{ Id = "push_mower", DisplayName = "Push Mower", Power = 189, Radius = 16.0, Cooldown = 0.33, Price = 19090, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "power_mower", DisplayName = "Self-Propelled Mower", Power = 210, Radius = 16.8, Cooldown = 0.32, Price = 27680, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "wide_push", DisplayName = "Wide-Deck Push Mower", Power = 232, Radius = 17.5, Cooldown = 0.32, Price = 40140, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "farm_mower", DisplayName = "Farm Mower 500", Power = 255, Radius = 18.2, Cooldown = 0.31, Price = 58210, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "mower_deluxe", DisplayName = "Mower Deluxe", Power = 279, Radius = 19.0, Cooldown = 0.30, Price = 84400, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "tractor_jr", DisplayName = "Tractor Jr.", Power = 304, Radius = 19.8, Cooldown = 0.29, Price = 122380, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "field_hand", DisplayName = "Field Hand Mower", Power = 331, Radius = 20.5, Cooldown = 0.29, Price = 177450, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "harvest_hand", DisplayName = "Harvest Hand Pro", Power = 358, Radius = 21.2, Cooldown = 0.28, Price = 257300, RequiredZone = 3, Rideable = false, FuelType = "Gas" },
	{ Id = "riding_mower", DisplayName = "Riding Mower", Power = 386, Radius = 22.0, Cooldown = 0.27, Price = 373080, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "zero_turn", DisplayName = "Zero-Turn Mower", Power = 415, Radius = 22.8, Cooldown = 0.26, Price = 540970, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "ranch_rider", DisplayName = "Ranch Rider", Power = 445, Radius = 23.5, Cooldown = 0.26, Price = 784400, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "zero_turn_pro", DisplayName = "Zero-Turn Pro", Power = 476, Radius = 24.2, Cooldown = 0.25, Price = 1137380, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "meadow_king", DisplayName = "Meadow King Rider", Power = 508, Radius = 25.0, Cooldown = 0.24, Price = 1649200, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "longhorn", DisplayName = "Longhorn Tractor Mower", Power = 540, Radius = 25.8, Cooldown = 0.23, Price = 2391340, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "prairie_boss", DisplayName = "Prairie Boss", Power = 574, Radius = 26.5, Cooldown = 0.23, Price = 3467450, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "stampede", DisplayName = "Stampede Zero-Turn", Power = 609, Radius = 27.2, Cooldown = 0.22, Price = 5027800, RequiredZone = 4, Rideable = true, FuelType = "Gas" },
	{ Id = "stand_on_mower", DisplayName = "Commercial Stand-On Mower", Power = 645, Radius = 28.0, Cooldown = 0.21, Price = 7290310, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "fairway_fleet", DisplayName = "Fairway Fleet Mower", Power = 681, Radius = 28.8, Cooldown = 0.20, Price = 10570950, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "tractor_mower", DisplayName = "Tractor Mower", Power = 719, Radius = 29.5, Cooldown = 0.20, Price = 15327880, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "estate_comb", DisplayName = "Estate Combine Mower", Power = 757, Radius = 30.2, Cooldown = 0.19, Price = 22225430, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "greenkeeper", DisplayName = "Greenkeeper Supreme", Power = 796, Radius = 31.0, Cooldown = 0.18, Price = 32226870, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "mansion_mower", DisplayName = "Mansion Grounds Mower", Power = 837, Radius = 31.8, Cooldown = 0.17, Price = 46728960, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "royal_tractor", DisplayName = "Royal Estate Tractor", Power = 878, Radius = 32.5, Cooldown = 0.17, Price = 67756990, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "fairway_titan", DisplayName = "Fairway Titan", Power = 920, Radius = 33.2, Cooldown = 0.16, Price = 98247630, RequiredZone = 5, Rideable = true, FuelType = "Gas" },
	{ Id = "combine_harvester", DisplayName = "Combine Harvester", Power = 963, Radius = 34.0, Cooldown = 0.15, Price = 142459070, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "mega_mower", DisplayName = "Industrial Mega Mower", Power = 1007, Radius = 34.8, Cooldown = 0.14, Price = 206565650, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "field_fortress", DisplayName = "Field Fortress Harvester", Power = 1052, Radius = 35.5, Cooldown = 0.14, Price = 299520190, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "drone_swarm", DisplayName = "Mower Drone Swarm", Power = 1097, Radius = 36.2, Cooldown = 0.13, Price = 434304270, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "titan_harvester", DisplayName = "Titan Harvester", Power = 1144, Radius = 37.0, Cooldown = 0.12, Price = 629741190, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "sky_mower", DisplayName = "Sky Mower Carrier", Power = 1192, Radius = 37.8, Cooldown = 0.11, Price = 913124730, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "terra_mower", DisplayName = "Terra-Mower", Power = 1240, Radius = 38.5, Cooldown = 0.11, Price = 1324030860, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
	{ Id = "mowzilla", DisplayName = "MOWZILLA", Power = 1289, Radius = 39.2, Cooldown = 0.10, Price = 1919844750, RequiredZone = 6, Rideable = true, FuelType = "Gas" },
}

local byId: { [string]: ToolDef } = {}
for _, tool in Tools do byId[tool.Id] = tool end

return { List = Tools, ById = byId }
