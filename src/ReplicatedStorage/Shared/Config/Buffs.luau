--!strict
-- Buffs & automation. Small automations appear mid-game (auto-swing, a hired
-- helper, one drone); the final zone is ABOUT automation (robot crews,
-- auto-sell), so late buffs change how you play, not just your numbers.

export type BuffDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Price: number,
	RequiredZone: number,
	MaxStacks: number,
	Kind: "Stat" | "Automation",
}

local Buffs: { BuffDef } = {
	{ Id = "swift_boots", DisplayName = "Swift Boots", Description = "+10% walk speed per stack. Mow faster by walking faster.", Price = 300, RequiredZone = 1, MaxStacks = 5, Kind = "Stat" },
	{ Id = "grass_magnet", DisplayName = "Grass Magnet", Description = "+25% swing radius per stack.", Price = 900, RequiredZone = 2, MaxStacks = 4, Kind = "Stat" },
	{ Id = "golden_blades", DisplayName = "Golden Blades", Description = "+5% chance a cut is critical (x3 grass) per stack.", Price = 4_000, RequiredZone = 2, MaxStacks = 6, Kind = "Stat" },
	{ Id = "auto_swing", DisplayName = "Auto-Swing", Description = "Your tool swings by itself while you hold position. Small automation, big relief.", Price = 12_000, RequiredZone = 3, MaxStacks = 1, Kind = "Automation" },
	{ Id = "gardener_helper", DisplayName = "Hired Gardener", Description = "An NPC gardener slowly mows near you and shares the harvest.", Price = 60_000, RequiredZone = 3, MaxStacks = 3, Kind = "Automation" },
	{ Id = "mower_drone", DisplayName = "Mower Drone", Description = "A drone circles you, cutting grass on its own.", Price = 400_000, RequiredZone = 5, MaxStacks = 3, Kind = "Automation" },
	{ Id = "auto_sell", DisplayName = "Auto-Sell Conveyor", Description = "When storage is full, grass sells itself. No more trips to the pad.", Price = 3_000_000, RequiredZone = 6, MaxStacks = 1, Kind = "Automation" },
	{ Id = "robot_crew", DisplayName = "Robot Mower Crew", Description = "A robot mower roams your current zone and mows for you.", Price = 12_000_000, RequiredZone = 6, MaxStacks = 4, Kind = "Automation" },
}

local byId: { [string]: BuffDef } = {}
for _, buff in Buffs do
	byId[buff.Id] = buff
end

return {
	List = Buffs,
	ById = byId,
}
