--!strict
-- Discovery and conversation are observed by the server, never granted by a UI.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Quests)
local World = require(Shared.QuestWorld)
local Profiles = require(script.Parent.ProfileService)
local Land = require(script.Parent.LandService)
local QuestService = {}
local remotes: Folder
local lastTalk = setmetatable({}, { __mode = "k" })

local function nearby(player: Player, id: string, distance: number): boolean
	local def = Config.ById[id]
	local profile = Profiles.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local npc = World.Find(id)
	return def ~= nil and profile ~= nil and profile.UnlockedZoneIds[def.ZoneId] == true
		and Land.IsUnlocked(def.ZoneId) and root ~= nil and humanoid ~= nil and humanoid.Health > 0
		and npc ~= nil and (root.Position - npc.Position).Magnitude <= distance
end
function QuestService.CanAccept(player: Player, id: string): boolean
	local profile = Profiles.Get(player)
	return profile ~= nil and profile.KnownQuestContacts[id] == true and nearby(player, id, Config.TalkDistance)
end
function QuestService.Talk(player: Player, id: string)
	if not nearby(player, id, Config.TalkDistance) then return end
	if os.clock() - (lastTalk[player] or -math.huge) < Config.ScanSeconds then return end
	lastTalk[player] = os.clock()
	local profile = Profiles.Get(player)
	profile.KnownQuestContacts[id] = true
	Profiles.NotifyChanged(player);
	(remotes.QuestOffer :: RemoteEvent):FireClient(player, id)
end
function QuestService.Scan()
	for _, def in Config.List do
		local root = World.Find(def.Id)
		if root and not root:FindFirstChild(Config.PromptName) then
			-- Replace only the procedural builder's generic label; custom baked
			-- names and geometry remain the map author's property.
			local tag = root.Parent:FindFirstChild("NameTag", true)
			local label = tag and tag:FindFirstChildOfClass("TextLabel")
			if label and label.Text == "Farmer Joe · Grass Buyer" then label.Text = def.NpcName .. " · Grass Buyer" end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = Config.PromptName
			prompt.ObjectText = def.NpcName
			prompt.ActionText = "Talk · Local jobs"
			prompt.MaxActivationDistance = Config.TalkDistance
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function(player) QuestService.Talk(player, def.Id) end)
			prompt.Parent = root
		end
		for _, player in Players:GetPlayers() do
			local profile = Profiles.Get(player)
			if profile and not profile.KnownQuestContacts[def.Id] and nearby(player, def.Id, Config.DiscoverDistance) then
				profile.KnownQuestContacts[def.Id] = true
				Profiles.NotifyChanged(player);
				(remotes.Notify :: RemoteEvent):FireClient(player, "You found " .. def.NpcName .. "! Talk to them for a local job.")
			end
		end
	end
end
function QuestService.Init(folder: Folder)
	remotes = folder
	task.spawn(function()
		while true do QuestService.Scan(); task.wait(Config.ScanSeconds) end
	end)
end
return QuestService
