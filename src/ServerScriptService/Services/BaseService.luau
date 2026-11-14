--!strict
-- Hands out the personal bases (Shared/Config/Bases.luau, built by
-- Map/Bases): every player gets a free one on joining and keeps it until
-- they leave. The owner spawns there, their name goes on its boards, and
-- its hay yard and jetty work for them alone (Shared/Bases tells whose a
-- base is; the attributes are set here and replicate to every client).
--
-- A server never has more players than bases (Config/Bases `Headings` is
-- the server size). Should it happen anyway, the extra player spawns on
-- the home island and their sell pads pay out directly.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Bases)
local Bases = require(Shared.Bases)

local Theme = Config.Tag

local BaseService = {}

local SPAWN_LIFT = 3.5 -- studs above the pad a character is put down
local STRAY = 40 -- a fresh character further than this from its pad is carried there

-- Writes on a base's boards who lives there (the board by the bridge and
-- the sign over the cabin's porch).
local function paint(base: Model, ownerName: string?)
	local texts = {
		OwnerSign = if ownerName then Config.OwnerText:format(ownerName) else Config.VacantText,
		ShopSign = if ownerName then Config.CabinText:format(ownerName) else Config.VacantText,
	}
	for _, d in base:GetDescendants() do
		local text = texts[d.Name]
		if text and d:IsA("BasePart") then
			local label = d:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				label.Text = text
			end
		end
	end
end

-- The owner's round picture with their name under it, floating over the
-- base (on its invisible "OwnerTag" part); nothing over a vacant base.
local function tag(base: Model, player: Player?)
	local anchor = base:FindFirstChild("OwnerTag")
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local old = anchor:FindFirstChild("Tag")
	if old then
		old:Destroy()
	end
	if not player then
		return
	end
	local spec = Config.Tag
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromScale(spec.Size.X, spec.Size.Y)
	gui.MaxDistance = spec.MaxDistance
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.AnchorPoint = Vector2.new(0.5, 0)
	photo.Position = UDim2.fromScale(0.5, 0)
	photo.Size = UDim2.fromScale(0.7, 0.7)
	photo.SizeConstraint = Enum.SizeConstraint.RelativeYY
	photo.BackgroundColor3 = Theme.Surface
	photo.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(math.max(player.UserId, 1))
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = photo
	local ring = Instance.new("UIStroke")
	ring.Color = Theme.Outline
	ring.Thickness = 4
	ring.Parent = photo
	photo.Parent = gui
	local name = Instance.new("TextLabel")
	name.Name = "OwnerName"
	name.Position = UDim2.fromScale(0, 0.74)
	name.Size = UDim2.fromScale(1, 0.26)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Theme.Text
	name.TextStrokeColor3 = Theme.Outline
	name.TextStrokeTransparency = 0
	name.Text = player.DisplayName
	name.Parent = gui
	gui.Parent = anchor
end

local function setOwner(base: Model, player: Player?)
	base:SetAttribute(Bases.OwnerAttribute, if player then player.UserId else 0)
	base:SetAttribute(Bases.OwnerNameAttribute, if player then player.DisplayName else "")
	paint(base, player and player.DisplayName)
	tag(base, player)
end

-- The player's base in this server, or nil.
function BaseService.Of(player: Player): Model?
	return Bases.Of(player.UserId)
end

-- Where the player's characters appear: their base's pad, or nil.
function BaseService.SpawnOf(player: Player): BasePart?
	local base = BaseService.Of(player)
	local pad = base and base:FindFirstChild("BaseSpawn")
	return if pad and pad:IsA("BasePart") then pad else nil
end

-- Puts the player's character on their base (spawning, quick travel, a
-- new franchise). False when they have no base or no character.
function BaseService.SendHome(player: Player): boolean
	local pad = BaseService.SpawnOf(player)
	local character = player.Character
	if not pad or not character then
		return false
	end
	character:PivotTo(pad.CFrame + Vector3.new(0, SPAWN_LIFT, 0))
	return true
end

local function onCharacter(player: Player, character: Model)
	-- RespawnLocation normally puts them on the pad; a character that
	-- loaded before the base was assigned is carried there.
	task.defer(function()
		local pad = BaseService.SpawnOf(player)
		local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if pad and root and character.Parent and (root.Position - pad.Position).Magnitude > STRAY then
			BaseService.SendHome(player)
		end
	end)
end

local function assign(player: Player)
	if BaseService.Of(player) then
		return
	end
	for _, base in Bases.All() do
		if base:GetAttribute(Bases.OwnerAttribute) == 0 then
			setOwner(base, player)
			local pad = base:FindFirstChild("BaseSpawn")
			if pad and pad:IsA("SpawnLocation") then
				player.RespawnLocation = pad
			end
			return
		end
	end
	warn(("[MowIt][Bases] No free base for %s."):format(player.Name))
end

function BaseService.Init()
	-- Whatever was saved in the place, every base starts vacant.
	for _, base in Bases.All() do
		setOwner(base, nil)
	end
	local function onPlayer(player: Player)
		assign(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local base = BaseService.Of(player)
		if base then
			setOwner(base, nil)
		end
	end)
end

return BaseService
