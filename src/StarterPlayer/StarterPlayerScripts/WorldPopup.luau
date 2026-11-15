--!strict
-- Text that rises and fades over a spot in the world: "+25 Coins" where a
-- bale was sold, "+3" over the player who just cut grass. Defaults are
-- Config/Interface.Popup; callers override what differs.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Interface = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Interface)
local Defaults = Interface.Popup

export type Options = { Size: Vector2?, Seconds: number?, Lift: number?, Rise: number? }

local WorldPopup = {}

local folder: Folder? = nil
local function home(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "Popups (local)"
		made.Parent = Workspace
		folder = made
	end
	return folder :: Folder
end

function WorldPopup.Show(at: Vector3, message: string, color: Color3, options: Options?)
	local o: Options = options or {}
	local size = o.Size or Defaults.Size
	local seconds = o.Seconds or Defaults.Seconds
	local lift, rise = o.Lift or Defaults.Lift, o.Rise or Defaults.Rise

	local host = Instance.new("Part")
	host.Name = "Popup"
	host.Size = Vector3.one * 0.2
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Position = at
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = Defaults.MaxDistance
	gui.Adornee = host
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.Text = message
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Interface.Colors.Ink
	stroke.Thickness = 2.5
	stroke.Parent = text
	gui.Parent = host
	host.Parent = home()

	local started = os.clock()
	local step: RBXScriptConnection
	step = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - started) / seconds, 0, 1)
		gui.StudsOffsetWorldSpace = Vector3.new(0, lift + rise * (1 - (1 - a) ^ 2), 0)
		local fade = math.clamp((a - 0.6) / 0.4, 0, 1)
		text.TextTransparency = fade
		stroke.Transparency = fade
		if a >= 1 then
			step:Disconnect()
			host:Destroy()
		end
	end)
end

return WorldPopup
