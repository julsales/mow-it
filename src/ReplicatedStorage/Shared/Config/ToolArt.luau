--!strict
-- How every tool looks: which Blender base model it uses (art/tools/), its
-- two paint colours and optional extras. 15 base models cover all 48
-- tools; colour, extras and size make each upgrade look different.
--
-- Models[*].AssetId: the Model asset uploaded from art/tools/out/<name>.fbx
-- (owned by the game's group, so InsertService can load it). 0 = not
-- uploaded yet: the tool falls back to the Part-built look (ToolModels).
-- Center/Size: the model's bounding box as authored in Blender, in studs
-- (art/tools/out/meta.json); used to put the imported mesh back exactly
-- where it was authored, whatever unit scale the importer picked.
--
-- Moving pieces (ToolAnimations.client) are meshes named "…#Rig": SpinN /
-- Reel turn with the ground speed, Drum turns all the time, Rotor*/Head/Prop/Drill/Portal spin all
-- the time, Orbit circles the player, Buzz shakes and SnipL/SnipR/Lever
-- open and close around `Snip.Pivot` (authored coordinates) on each cut.

export type ModelDef = {
	AssetId: number,
	Center: Vector3,
	Size: Vector3,
	HoldLength: number?, -- hand tools: longest side in the hand (studs)
	RideLift: number?, -- riders: height of the deck the player stands on
	Handle: Vector3?, -- push/reel mowers: the game adds the fitted handle from (±X, Y, Z)
	Snip: { Pivot: Vector3, Axis: Vector3, Angle: number }?, -- blades/lever: hinge and how far they open (degrees)
	Seat: Vector3?, -- ride-ons the player SITS on: top-centre of the seat (authored); the game moves the seat under the player
}

export type ToolLook = {
	Model: string,
	Color: Color3, -- "Accent" pieces
	Color2: Color3, -- "Accent2" pieces (stripes, rims, trim)
	Extras: { string }?, -- optional pieces to keep ("Turbo", "Crown"…)
	Scale: number?, -- ground tools: size multiplier (default from the ladder)
	Finish: string?, -- "Golden" | "Rainbow" | "Void": special paint + effects (Finishes)
}

export type Finish = {
	Color: Color3, -- replaces the Accent paint
	Color2: Color3, -- Accent2 / Glow, always neon
	Material: Enum.Material,
	Rainbow: boolean?, -- Accent cycles through the rainbow (ToolAnimations.client)
	Particle: { Texture: string, Color: ColorSequence, Rate: number, Size: number, LightEmission: number },
	Light: Color3,
}

local rgb = Color3.fromRGB

local Models: { [string]: ModelDef } = {
	clipper = { AssetId = 125003935411772, Center = Vector3.new(0, 0.074, -0.796), Size = Vector3.new(0.66, 1.088, 2.882), HoldLength = 1.3, Snip = { Pivot = Vector3.new(0, 0.25, -1.55), Axis = Vector3.xAxis, Angle = 10 } },
	scissors_safety = { AssetId = 120638250934550, Center = Vector3.new(0, 0.002, -0.536), Size = Vector3.new(1.54, 0.195, 2.428), HoldLength = 1.8, Snip = { Pivot = Vector3.new(0, 0, -0.48), Axis = Vector3.yAxis, Angle = 18 } },
	scissors_kitchen = { AssetId = 124984095097638, Center = Vector3.new(-0.025, 0.007, -0.808), Size = Vector3.new(1.35, 0.187, 2.976), HoldLength = 2.1, Snip = { Pivot = Vector3.new(0, 0, -0.45), Axis = Vector3.yAxis, Angle = 16 } },
	shears = { AssetId = 111659672280353, Center = Vector3.new(0, 0, -0.58), Size = Vector3.new(1.063, 0.277, 3.689), HoldLength = 2.6, Snip = { Pivot = Vector3.new(0, 0, -0.8), Axis = Vector3.yAxis, Angle = 14 } },
	sickle = { AssetId = 93802071925746, Center = Vector3.new(0, 0.866, -0.925), Size = Vector3.new(0.329, 2.062, 3.05), HoldLength = 2.3 },
	grass_whip = { AssetId = 123278661581067, Center = Vector3.new(0, 0.207, -1.6), Size = Vector3.new(0.269, 0.813, 4.3), HoldLength = 3.2 },
	hedge = { AssetId = 72879795646218, Center = Vector3.new(0, 0.218, -1.55), Size = Vector3.new(0.9, 1.585, 4), HoldLength = 3.4 },
	string_trimmer = { AssetId = 90620380495865, Center = Vector3.new(0, -0.083, -1.55), Size = Vector3.new(1.2, 1.834, 5.8), HoldLength = 4.8 },
	reel = { AssetId = 78655685328069, Center = Vector3.new(0, 0.8, -2.789), Size = Vector3.new(3.02, 1.6, 2.021), Handle = Vector3.new(1.0, 1.0, -2.2) },
	push = { AssetId = 127384897680211, Center = Vector3.new(0, 1.25, -3.687), Size = Vector3.new(3.55, 2.5, 4.275), Handle = Vector3.new(0.9, 1.2, -2.4) },
	rider = { AssetId = 133849751211282, Center = Vector3.new(0, 1.793, -0.776), Size = Vector3.new(4.455, 3.814, 6.007), RideLift = 1.35, Seat = Vector3.new(0, 2.4, 0.6) },
	zeroturn = { AssetId = 108957789542568, Center = Vector3.new(-0.032, 2.3, -1.007), Size = Vector3.new(5.115, 4.869, 6.385), RideLift = 1.3, Seat = Vector3.new(0, 2.15, 0.4) },
	tractor = { AssetId = 82571445593930, Center = Vector3.new(0, 3.491, -2.23), Size = Vector3.new(6.05, 7.418, 10.14), RideLift = 2.25, Seat = Vector3.new(0, 3.075, 0.6) },
	combine = { AssetId = 139488875639096, Center = Vector3.new(-0.602, 3.595, 0.24), Size = Vector3.new(9.054, 7.611, 10.12), RideLift = 2.2, Seat = Vector3.new(0, 3.2, -0.2) },
	drone = { AssetId = 130688639158553, Center = Vector3.new(0, 2.502, -0.4), Size = Vector3.new(6.058, 4.865, 6.058), RideLift = 2.3 },
	mega_push = { AssetId = 121793856419832, Center = Vector3.new(0, 3.25, -5.622), Size = Vector3.new(9.23, 6.5, 13.645), RideLift = 2.2 },
	fortress = { AssetId = 77627639646586, Center = Vector3.new(-0.602, 4.395, 0.556), Size = Vector3.new(9.054, 9.211, 10.752), RideLift = 2.2, Seat = Vector3.new(0, 3.2, -0.2) },
	swarm = { AssetId = 81977994625587, Center = Vector3.new(0, 2.623, -1.678), Size = Vector3.new(9.906, 5.106, 8.838), RideLift = 2.3 },
	void = { AssetId = 139076317027769, Center = Vector3.new(0.325, 2.805, -1.714), Size = Vector3.new(6.521, 5.291, 9.011), RideLift = 2.2 },
	airship = { AssetId = 101949380235177, Center = Vector3.new(0, 6.325, 0.298), Size = Vector3.new(4.6, 11.75, 10.396), RideLift = 2.2 },
	drill = { AssetId = 76698397475352, Center = Vector3.new(0, 2.902, -2.05), Size = Vector3.new(5.815, 5.805, 9.1), RideLift = 3.15 },
	mowzilla = { AssetId = 98397533214522, Center = Vector3.new(0, 3.1, -1.215), Size = Vector3.new(7.412, 6.91, 10.069), RideLift = 3.9 },
}

-- Fixed colours/materials of the shared pieces (by mesh name).
local Pieces: { [string]: { Color: Color3, Material: Enum.Material, Transparency: number? } } = {
	Metal = { Color = rgb(186, 192, 202), Material = Enum.Material.Metal },
	Chrome = { Color = rgb(232, 236, 242), Material = Enum.Material.Metal },
	Dark = { Color = rgb(46, 46, 52), Material = Enum.Material.SmoothPlastic },
	Rubber = { Color = rgb(30, 30, 33), Material = Enum.Material.SmoothPlastic },
	Wood = { Color = rgb(156, 98, 56), Material = Enum.Material.Wood },
	Glass = { Color = rgb(170, 220, 240), Material = Enum.Material.Glass, Transparency = 0.45 },
	Light = { Color = rgb(255, 236, 140), Material = Enum.Material.Neon },
	Seat = { Color = rgb(70, 46, 34), Material = Enum.Material.SmoothPlastic },
	Eye = { Color = rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic },
	Teeth = { Color = rgb(250, 244, 222), Material = Enum.Material.SmoothPlastic },
	Gold = { Color = rgb(255, 196, 50), Material = Enum.Material.Metal },
	Fabric = { Color = rgb(92, 104, 70), Material = Enum.Material.Fabric },
	Battery = { Color = rgb(60, 200, 110), Material = Enum.Material.SmoothPlastic },
	Stone = { Color = rgb(150, 150, 160), Material = Enum.Material.Slate },
	HandleGrip = { Color = rgb(36, 36, 40), Material = Enum.Material.SmoothPlastic },
	SteeringWheel = { Color = rgb(30, 30, 34), Material = Enum.Material.SmoothPlastic },
}

local Tools: { [string]: ToolLook } = {
	-- Front Yard: hand tools
	nail_clipper = { Model = "clipper", Color = rgb(255, 120, 170), Color2 = rgb(255, 255, 255) },
	safety_scissors = { Model = "scissors_safety", Color = rgb(255, 150, 40), Color2 = rgb(255, 230, 120) },
	kitchen_scissors = { Model = "scissors_kitchen", Color = rgb(60, 170, 230), Color2 = rgb(255, 255, 255) },
	garden_shears = { Model = "shears", Color = rgb(220, 50, 45), Color2 = rgb(255, 220, 90) },
	hand_sickle = { Model = "sickle", Color = rgb(150, 80, 210), Color2 = rgb(255, 210, 80) },
	grass_whip = { Model = "grass_whip", Color = rgb(70, 190, 90), Color2 = rgb(255, 230, 120) },
	reel_mower = { Model = "reel", Color = rgb(60, 160, 70), Color2 = rgb(255, 210, 60) },
	turbo_reel = { Model = "reel", Color = rgb(230, 60, 40), Color2 = rgb(255, 200, 40), Extras = { "Turbo" } },
	-- Backyard: battery tools
	hedge_trimmer = { Model = "hedge", Color = rgb(255, 196, 40), Color2 = rgb(40, 40, 46) },
	cordless_shears = { Model = "hedge", Color = rgb(40, 130, 230), Color2 = rgb(255, 255, 255), Extras = { "Battery" } },
	string_trimmer = { Model = "string_trimmer", Color = rgb(250, 120, 30), Color2 = rgb(255, 230, 120) },
	mega_trimmer = { Model = "string_trimmer", Color = rgb(220, 40, 60), Color2 = rgb(255, 200, 60) },
	electric_reel = { Model = "reel", Color = rgb(40, 190, 200), Color2 = rgb(255, 255, 255), Extras = { "Battery" } },
	trimmer_pro = { Model = "string_trimmer", Color = rgb(40, 40, 50), Color2 = rgb(255, 120, 30) },
	garden_saw = { Model = "hedge", Color = rgb(250, 110, 20), Color2 = rgb(40, 40, 46), Extras = { "Saw", "Battery" } },
	volt_whacker = { Model = "string_trimmer", Color = rgb(130, 60, 230), Color2 = rgb(255, 230, 60), Extras = { "Bolt" } },
	-- Sunny Farm: gas push mowers
	push_mower = { Model = "push", Color = rgb(220, 45, 40), Color2 = rgb(255, 214, 70), Extras = { "Bag" } },
	power_mower = { Model = "push", Color = rgb(40, 150, 70), Color2 = rgb(255, 230, 60), Extras = { "Bag" } },
	wide_push = { Model = "push", Color = rgb(250, 160, 30), Color2 = rgb(40, 40, 46), Extras = { "Bag" }, Scale = 1.35 },
	farm_mower = { Model = "push", Color = rgb(40, 110, 200), Color2 = rgb(255, 255, 255) },
	mower_deluxe = { Model = "push", Color = rgb(170, 40, 60), Color2 = rgb(255, 210, 80), Extras = { "Bag", "Deluxe" } },
	tractor_jr = { Model = "tractor", Color = rgb(60, 170, 70), Color2 = rgb(255, 214, 60), Scale = 0.75 },
	field_hand = { Model = "push", Color = rgb(110, 160, 60), Color2 = rgb(250, 240, 210), Extras = { "Bag" }, Scale = 1.45 },
	harvest_hand = { Model = "push", Color = rgb(230, 120, 30), Color2 = rgb(255, 240, 200), Extras = { "Bag", "Deluxe" }, Scale = 1.5 },
	-- Big Ranch: riders
	riding_mower = { Model = "rider", Color = rgb(220, 45, 40), Color2 = rgb(255, 214, 70) },
	zero_turn = { Model = "zeroturn", Color = rgb(250, 140, 30), Color2 = rgb(40, 40, 46) },
	ranch_rider = { Model = "rider", Color = rgb(140, 90, 50), Color2 = rgb(250, 230, 180) },
	zero_turn_pro = { Model = "zeroturn", Color = rgb(40, 120, 220), Color2 = rgb(255, 255, 255), Extras = { "Rops" } },
	meadow_king = { Model = "rider", Color = rgb(60, 170, 80), Color2 = rgb(255, 214, 60) },
	longhorn = { Model = "tractor", Color = rgb(200, 60, 40), Color2 = rgb(250, 230, 190), Extras = { "Horns" } },
	prairie_boss = { Model = "rider", Color = rgb(230, 190, 60), Color2 = rgb(60, 40, 30) },
	stampede = { Model = "zeroturn", Color = rgb(160, 40, 40), Color2 = rgb(30, 30, 34), Extras = { "Rops" } },
	-- Golf Estate
	stand_on_mower = { Model = "zeroturn", Color = rgb(250, 220, 40), Color2 = rgb(40, 40, 46) },
	fairway_fleet = { Model = "zeroturn", Color = rgb(255, 255, 255), Color2 = rgb(50, 160, 80), Extras = { "Rops" } },
	tractor_mower = { Model = "tractor", Color = rgb(40, 140, 60), Color2 = rgb(255, 214, 40) },
	estate_comb = { Model = "combine", Color = rgb(60, 170, 90), Color2 = rgb(255, 230, 120) },
	greenkeeper = { Model = "tractor", Color = rgb(30, 110, 60), Color2 = rgb(255, 255, 255), Extras = { "Canopy" } },
	mansion_mower = { Model = "rider", Color = rgb(30, 40, 70), Color2 = rgb(255, 196, 50) },
	royal_tractor = { Model = "tractor", Color = rgb(120, 40, 170), Color2 = rgb(255, 196, 50), Extras = { "Canopy", "Crown" }, Finish = "Golden" },
	fairway_titan = { Model = "tractor", Color = rgb(240, 240, 240), Color2 = rgb(30, 130, 70), Extras = { "Canopy" }, Finish = "Golden" },
	-- Mega Fields: the special ones (themed, comically big, VOID)
	combine_harvester = { Model = "combine", Color = rgb(220, 50, 40), Color2 = rgb(255, 214, 70) },
	mega_mower = { Model = "mega_push", Color = rgb(230, 40, 40), Color2 = rgb(255, 214, 60), Extras = { "Bag", "Deluxe" }, Finish = "Rainbow" },
	field_fortress = { Model = "fortress", Color = rgb(70, 90, 170), Color2 = rgb(255, 210, 60), Finish = "Golden" },
	drone_swarm = { Model = "swarm", Color = rgb(40, 180, 230), Color2 = rgb(255, 255, 255), Finish = "Rainbow" },
	titan_harvester = { Model = "void", Color = rgb(36, 22, 58), Color2 = rgb(190, 90, 255), Scale = 1.3, Finish = "Void" },
	sky_mower = { Model = "airship", Color = rgb(70, 140, 230), Color2 = rgb(250, 248, 240), Finish = "Rainbow" },
	terra_mower = { Model = "drill", Color = rgb(150, 90, 50), Color2 = rgb(255, 130, 30) },
	mowzilla = { Model = "mowzilla", Color = rgb(200, 30, 40), Color2 = rgb(255, 200, 40), Scale = 1.35, Finish = "Void" },
}

-- Special finishes for the top tools. Particle textures are free Creator
-- Store images (docs/ASSETS.md): "star sparkle particle" by Vupatu (decal
-- 6490035158), "Rainbow Sparkle Particle" by Rokelium (9289210132),
-- "Dream Particle Void Outline" by redgodnior (4508781782).
local Finishes: { [string]: Finish } = {
	Golden = {
		Color = rgb(255, 190, 40),
		Color2 = rgb(255, 244, 180),
		Material = Enum.Material.Foil,
		Particle = { Texture = "rbxassetid://6490035152", Color = ColorSequence.new(rgb(255, 230, 120)), Rate = 10, Size = 0.6, LightEmission = 1 },
		Light = rgb(255, 210, 90),
	},
	Rainbow = {
		Color = rgb(255, 80, 80),
		Color2 = rgb(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		Rainbow = true,
		Particle = { Texture = "rbxassetid://9289210113", Color = ColorSequence.new(rgb(255, 255, 255)), Rate = 12, Size = 0.7, LightEmission = 0.6 },
		Light = rgb(200, 200, 255),
	},
	Void = {
		Color = rgb(24, 12, 40),
		Color2 = rgb(180, 80, 255),
		Material = Enum.Material.SmoothPlastic,
		Particle = { Texture = "rbxassetid://4508781776", Color = ColorSequence.new(rgb(190, 100, 255), rgb(60, 0, 120)), Rate = 14, Size = 1.1, LightEmission = 0.8 },
		Light = rgb(170, 70, 255),
	},
}

return { Models = Models, Pieces = Pieces, Tools = Tools, Finishes = Finishes }
