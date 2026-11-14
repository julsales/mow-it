--!strict
-- Shared handling of the Blender art (art/tools, art/yard) once Roblox has
-- imported it: put a loaded model back where it was authored, read the
-- "Group.Extra#Rig" mesh names, paint pieces by group. Used by ToolModels
-- (tools) and Map/HayYard (the hay yard), so both treat the art the same.

local ArtModels = {}

export type Box = { Center: Vector3, Size: Vector3 }
export type Paint = { Color: Color3, Material: Enum.Material, Transparency: number?, Reflectance: number? }

local function largest(v: Vector3): number
	return math.max(v.X, v.Y, v.Z)
end

-- Scales and moves a freshly cloned art model so its authored origin is the
-- world origin again (the importer picks its own unit scale and pivot; the
-- authored bounding box from meta.json tells where everything was).
function ArtModels.Restore(copy: Model, def: Box)
	local _, size = copy:GetBoundingBox()
	copy:ScaleTo(copy:GetScale() * largest(def.Size) / largest(size))
	local box = copy:GetBoundingBox()
	copy:PivotTo(CFrame.new(def.Center) * box:ToObjectSpace(copy:GetPivot()))
end

-- "Group.Extra#Rig" -> group, extra?, rig?
function ArtModels.Split(name: string): (string, string?, string?)
	local base, rig = string.match(name, "^([^#]+)#(.+)$")
	local rest = base or name
	local group, extra = string.match(rest, "^([^%.]+)%.(.+)$")
	return group or rest, extra, rig
end

function ArtModels.Paint(piece: BasePart, paint: Paint)
	piece.Color = paint.Color
	piece.Material = paint.Material
	piece.Transparency = paint.Transparency or 0
	piece.Reflectance = paint.Reflectance or 0
end

-- The importer's texture/material would hide the paint.
function ArtModels.Strip(piece: BasePart)
	if piece:IsA("MeshPart") then
		piece.TextureID = ""
	end
	local appearance = piece:FindFirstChildOfClass("SurfaceAppearance")
	if appearance then
		appearance:Destroy()
	end
end

return ArtModels
