--!strict
-- Tool evolution ladder: you start with a nail clipper and end with machines
-- so big they mow by themselves. Power = grass harvested per successful cut
-- (before zone/buff multipliers). Order in this array IS the upgrade path;
-- the shop only sells the next tools for zones the player has unlocked.
--
-- AssetId / model names are filled in during the Assets phase
-- (docs/ASSETS.md) — code never depends on a specific model existing.

export type ToolDef = {
	Id: string,
	DisplayName: string,
	Power: number,
	Radius: number, -- studs around the player that one swing can reach
	Cooldown: number, -- seconds between swings
	Price: number, -- Coins
	RequiredZone: number, -- zone index (1-based) that must be unlocked
	Flavor: string,
}

local Tools: { ToolDef } = {
	{ Id = "nail_clipper", DisplayName = "Nail Clipper", Power = 1, Radius = 4, Cooldown = 0.45, Price = 0, RequiredZone = 1, Flavor = "Everyone starts somewhere. Snip. Snip." },
	{ Id = "safety_scissors", DisplayName = "Safety Scissors", Power = 2, Radius = 5, Cooldown = 0.40, Price = 50, RequiredZone = 1, Flavor = "Rounded tips. Unrounded ambition." },
	{ Id = "kitchen_scissors", DisplayName = "Kitchen Scissors", Power = 4, Radius = 5, Cooldown = 0.38, Price = 200, RequiredZone = 1, Flavor = "Technically for poultry. Works on grass." },
	{ Id = "garden_shears", DisplayName = "Garden Shears", Power = 8, Radius = 6, Cooldown = 0.35, Price = 750, RequiredZone = 1, Flavor = "Now you look like a gardener." },
	{ Id = "hedge_trimmer", DisplayName = "Electric Hedge Trimmer", Power = 15, Radius = 7, Cooldown = 0.30, Price = 2_500, RequiredZone = 2, Flavor = "Batteries included. Lawn not included." },
	{ Id = "string_trimmer", DisplayName = "String Trimmer", Power = 28, Radius = 8, Cooldown = 0.28, Price = 8_000, RequiredZone = 2, Flavor = "Edge lord." },
	{ Id = "push_mower", DisplayName = "Push Mower", Power = 50, Radius = 9, Cooldown = 0.25, Price = 25_000, RequiredZone = 3, Flavor = "Your first real mower." },
	{ Id = "power_mower", DisplayName = "Self-Propelled Mower", Power = 90, Radius = 10, Cooldown = 0.22, Price = 75_000, RequiredZone = 3, Flavor = "It walks. You supervise." },
	{ Id = "riding_mower", DisplayName = "Riding Mower", Power = 160, Radius = 12, Cooldown = 0.20, Price = 220_000, RequiredZone = 4, Flavor = "Sit down on the job, legally." },
	{ Id = "zero_turn", DisplayName = "Zero-Turn Mower", Power = 300, Radius = 14, Cooldown = 0.18, Price = 650_000, RequiredZone = 4, Flavor = "Spins like it means it." },
	{ Id = "stand_on_mower", DisplayName = "Commercial Stand-On Mower", Power = 550, Radius = 16, Cooldown = 0.16, Price = 1_800_000, RequiredZone = 5, Flavor = "What the pros stand on." },
	{ Id = "tractor_mower", DisplayName = "Tractor Mower", Power = 1_000, Radius = 18, Cooldown = 0.15, Price = 5_000_000, RequiredZone = 5, Flavor = "Farm-certified grass removal." },
	{ Id = "combine_harvester", DisplayName = "Combine Harvester", Power = 1_900, Radius = 22, Cooldown = 0.14, Price = 15_000_000, RequiredZone = 6, Flavor = "The field ends where you say it ends." },
	{ Id = "mega_mower", DisplayName = "Industrial Mega Mower", Power = 3_500, Radius = 26, Cooldown = 0.13, Price = 45_000_000, RequiredZone = 6, Flavor = "Requires a permit in 12 countries." },
	{ Id = "drone_swarm", DisplayName = "Mower Drone Swarm", Power = 6_500, Radius = 32, Cooldown = 0.12, Price = 120_000_000, RequiredZone = 6, Flavor = "You don't mow anymore. You conduct." },
	{ Id = "mowzilla", DisplayName = "MOWZILLA", Power = 12_000, Radius = 40, Cooldown = 0.10, Price = 350_000_000, RequiredZone = 6, Flavor = "Gigantic. Efficient. Slightly terrifying." },
}

local byId: { [string]: ToolDef } = {}
for _, tool in Tools do
	byId[tool.Id] = tool
end

return {
	List = Tools,
	ById = byId,
}
