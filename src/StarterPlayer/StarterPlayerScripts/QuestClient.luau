--!strict
-- Presentation state only. Discovery/acceptance/rewards are server-owned.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Quests = require(Shared.Config.Quests)
local World = require(Shared.QuestWorld)
local State = require(script.Parent:WaitForChild("ClientState"))
local Land = require(script.Parent:WaitForChild("LandState"))
local Guide = require(script.Parent:WaitForChild("WorldGuide"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local Interface = require(Shared.Config.Interface)
local Client = {}
local event = Instance.new("BindableEvent")
Client.Offered = event.Event
local focus: string? = nil
local autoStarted = false
local marker: BillboardGui? = nil
local markerRoot: BasePart? = nil
function Client.Eligible(id: string): boolean
	local def = Quests.ById[id]
	local profile = State.Get()
	return def ~= nil and profile ~= nil and profile.UnlockedZoneIds[def.ZoneId] == true and Land.IsUnlocked(def.ZoneId)
end
function Client.Contact(): string?
	if focus and Client.Eligible(focus) then return focus end
	for _, def in Quests.List do if Client.Eligible(def.Id) then return def.Id end end
	return nil
end
function Client.Near(id: string): boolean
	local npc = World.Find(id)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and npc ~= nil and (root.Position - npc.Position).Magnitude <= Quests.TalkDistance
end
function Client.Focus(id: string)
	if Client.Eligible(id) then focus = id end
end
function Client.Clear() focus = nil; Guide.Clear("Quest") end
function Client.Tracked(): string? return focus end
(Shared.Parent:WaitForChild("Remotes"):WaitForChild("QuestOffer") :: RemoteEvent).OnClientEvent:Connect(function(id)
	if not Quests.ById[id] then return end
	Client.Clear()
	event:Fire(id)
end)
task.spawn(function()
	while true do
		task.wait(Quests.ScanSeconds)
		local profile = State.Get()
		if profile and not autoStarted then
			for _, def in Quests.List do
				if Client.Eligible(def.Id) then
					autoStarted = true
					if not profile.KnownQuestContacts[def.Id] then focus = def.Id; break end
				end
			end
		end
		if focus and (not Client.Eligible(focus) or (workspace:GetAttribute("ContractId") or "") ~= "") then Client.Clear() end
		local npc, pad = World.Find(focus or "")
		if focus and pad and npc then Guide.Set("Quest", pad, 10, true) else Guide.Clear("Quest") end
		if markerRoot ~= npc then
			if marker then marker:Destroy(); marker = nil end
			markerRoot = npc
			if npc and focus then
				marker = Instance.new("BillboardGui")
				marker.Name = "QuestDestination"
				marker.Size = UDim2.fromOffset(150, 76)
				marker.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
				marker.AlwaysOnTop = true
				marker.MaxDistance = Quests.MarkerDistance
				marker.Adornee = npc
				local icon = Ui.Icon(marker, Interface.Images.Quests, 42)
				icon.Position = UDim2.new(0.5, -21, 0, 0)
				local label = Ui.OutlinedText(marker, Quests.ById[focus].NpcName, 15)
				label.AutomaticSize = Enum.AutomaticSize.None
				label.Position = UDim2.fromOffset(0, 42); label.Size = UDim2.new(1, 0, 0, 28)
				marker.Parent = Players.LocalPlayer.PlayerGui
			end
		end
	end
end)
return Client
