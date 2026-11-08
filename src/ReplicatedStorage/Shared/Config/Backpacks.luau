--!strict
-- Storage ladder. Grass fills your storage; when it is full you must sell
-- (or own an auto-sell automation). Capacity is in units of cut grass.

export type BackpackDef = {
	Id: string,
	DisplayName: string,
	Capacity: number,
	Price: number,
	RequiredZone: number,
}

local Backpacks: { BackpackDef } = {
	{ Id = "pocket", DisplayName = "Your Pocket", Capacity = 10, Price = 0, RequiredZone = 1 },
	{ Id = "plastic_bag", DisplayName = "Plastic Bag", Capacity = 50, Price = 100, RequiredZone = 1 },
	{ Id = "school_backpack", DisplayName = "School Backpack", Capacity = 150, Price = 400, RequiredZone = 1 },
	{ Id = "duffel_bag", DisplayName = "Duffel Bag", Capacity = 400, Price = 1_500, RequiredZone = 2 },
	{ Id = "trash_bin", DisplayName = "Trash Bin", Capacity = 1_000, Price = 5_000, RequiredZone = 2 },
	{ Id = "wheelbarrow", DisplayName = "Wheelbarrow", Capacity = 2_500, Price = 18_000, RequiredZone = 3 },
	{ Id = "pickup_bed", DisplayName = "Pickup Truck Bed", Capacity = 6_000, Price = 60_000, RequiredZone = 3 },
	{ Id = "hay_trailer", DisplayName = "Hay Trailer", Capacity = 15_000, Price = 200_000, RequiredZone = 4 },
	{ Id = "dump_truck", DisplayName = "Dump Truck", Capacity = 40_000, Price = 700_000, RequiredZone = 5 },
	{ Id = "vacuum_silo", DisplayName = "Vacuum Silo", Capacity = 120_000, Price = 2_500_000, RequiredZone = 5 },
	{ Id = "auto_conveyor", DisplayName = "Auto-Conveyor Rig", Capacity = 500_000, Price = 10_000_000, RequiredZone = 6 },
}

local byId: { [string]: BackpackDef } = {}
for _, pack in Backpacks do
	byId[pack.Id] = pack
end

return {
	List = Backpacks,
	ById = byId,
}
