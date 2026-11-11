--!strict
-- Central tuning for Mow It!
-- Fill in the real PlaceIds after creating the two places in Studio
-- (see README > Roblox setup). 0 = not configured yet (Studio testing).

local GameConfig = {
	GameName = "Mow It!",

	-- Places ---------------------------------------------------------------
	-- Lobby is the start place. Game is a sub-place teleported to with a
	-- ReservedServerId so a party of up to 4 plays alone together.
	LobbyPlaceId = 0,
	GamePlaceId = 0, -- legacy name; v2 calls this the Land place (see below)
	LandPlaceId = 0, -- v2: private land sessions run here (reserved servers)

	-- Lobby / match --------------------------------------------------------
	MaxPartySize = 4,
	QueueCountdownSeconds = 10, -- starts when the first player steps on the pad
	MinPlayersToStartEarly = 1, -- the pad can be started by stepping off/on in later versions

	-- Core loop ------------------------------------------------------------
	GrassRespawnSeconds = 6, -- average; each cell waits 0.7x..1.5x this so lawns regrow unevenly
	GrassCellSize = 4, -- studs; one Terrain voxel column per cell, so it must stay 4 (GrassService)
	GrassStripeCells = 2, -- mowed stripes alternate light/dark every N cells
	SellValuePerGrass = 1, -- multiplied by the zone's GrassValue
	StartingCoins = 0,
	StartingToolId = "nail_clipper",
	StartingBackpackId = "pocket",

	-- Data -----------------------------------------------------------------
	DataStoreName = "MowIt_Profile_v1",
	AutosaveSeconds = 120,

	-- Debug ----------------------------------------------------------------
	Verbose = true,
}

return GameConfig
