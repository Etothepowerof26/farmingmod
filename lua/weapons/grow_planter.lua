SWEP.PrintName = "Planter"

SWEP.BounceWeaponIcon = false
SWEP.DrawWeaponInfoBox = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true

SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.Spawnable = true
SWEP.Category = "Farming"

SWEP.HoldType = "melee2"

SWEP.Author = "TwentySix"
SWEP.Instructions = "Literally equip this weapon to know how to use it."

SWEP.Primary = {}
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = ")physics/concrete/concrete_impact_bullet%s.wav"
-- material/material_dirt_step1.wav
-- material/material_dirt_impact1.wav

SWEP.Secondary = {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Crop = nil
SWEP.Crops =
{
	{"Pumpkin", Tag .. "_crop_pumpkin"},
	{"Melon", Tag .. "_crop_melon"},
	{"Mushroom", Tag .. "_crop_shrooms"},
	{"Cursed Skulls", Tag .. "_crop_cursed"}
}
SWEP.CropIndex = 0
SWEP.LastReload = 0

function SWEP:Initialize()
	self:SetHoldType("melee")
end

if CLIENT then

	local brightPlants =
	{
		Pumpkin = true,
		Melon = true
	}
	local darkPlants =
	{
		Mushroom = true
	}

	local grassPlants =
	{
		Pumpkin = true,
		Melon = true,
		Mushroom = true
	}

	local function getLightLevel(pos)
		local light = render.GetLightColor(pos)
		return light.x + light.y + light.z
	end

	function SWEP:CanGrow(plant)
		-- base cases
		if not LocalPlayer() then
			return false, "Invalid player."
		end

		local tr = LocalPlayer():GetEyeTrace()

		-- cant place crops across the map
		if tr.HitPos:DistToSqr(tr.StartPos) > 35000 then
			return false, "Spot is too far away!"
		end

		-- crowding
		for k,v in pairs(ents.FindInSphere(tr.HitPos, 100)) do
			if v.Base == "grow_base_crop" then
				return false, "Too close to another crop!"
			end
		end

		-- plant specific cases
		local light = getLightLevel(tr.HitPos)
		--print(light)
		if brightPlants[plant] and light < 0.2 then
			return false, "Too dark!"
		end

		if darkPlants[plant] and light > 0.2 then
			return false, "Too bright!"
		end

		-- grass/sand, doesn't work on displacements
		if grassPlants[plant] and ((not tr.HitTexture:lower():find("sand")) and (not tr.HitTexture:lower():find("grass"))) then
			return false, "Can only be grown on sand/grass."
		end

		if landmark and landmark.nearest and tr and tr.HitPos then
			if plant == "Cursed Skulls" and not (landmark.nearest(tr.HitPos) == "hll") then
				return false, "Can only be grown in hell!"
			elseif plant ~= "Cursed Skulls" and (landmark.nearest(tr.HitPos) == "hll") then
				return false, "Too volatile of an area!"
			end
		end

		return true
	end

end

function SWEP:Reload()
	if SERVER then
		return
	end

	if not self.LastReload then
		self.LastReload = SysTime()
	end

	if SysTime() < self.LastReload + .25 then
		return
	end

	self.CropIndex = self.CropIndex + 1
	if self.CropIndex > table.Count(self.Crops) then
		self.CropIndex = 1
	end

	self.LastReload = SysTime()
	surface.PlaySound("UI/buttonrollover.wav")
end


function SWEP:CreateGhost( model, pos, angle )
	self.GhostEntity = ents.CreateClientProp( model )

	-- If there's too many entities we might not spawn..
	if (not self.GhostEntity:IsValid()) then
		self.GhostEntity = nil
		return false
	end

	self.GhostEntity:SetModel( model )
	self.GhostEntity:SetPos( pos )
	self.GhostEntity:SetAngles( angle )
	self.GhostEntity:Spawn()

	self.GhostEntity:SetSolid( SOLID_VPHYSICS );
	self.GhostEntity:SetMoveType( MOVETYPE_NONE )
	self.GhostEntity:SetNotSolid( true );
	self.GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )
	self.GhostEntity:SetColor( Color( 255, 255, 255, 200 ) )
	self.GhostEntity:SetModelScale( 0.5 )
	self.GhostEntity:DrawShadow( false )

	return self.GhostEntity
end

function SWEP:UpdateGhost(croptab)
	local ent = croptab[2]
	if not ent then return false end
	if not self.GhostEntity then return false end

	-- todo
	self.GhostEntity:SetModel("models/props/CS_militia/fern01.mdl")
end

function SWEP:Deploy()
	if self.GhostEntity and IsValid(self.GhostEntity) then
		self.GhostEntity:Remove()
		self.GhostEntity = nil
	end

	self.GhostActive = true
	--print("DEPLOY",self)

	return true
end

function SWEP:Holster()
	if self.GhostEntity and IsValid(self.GhostEntity) then
		self.GhostEntity:Remove()
		self.GhostEntity = nil
	end

	self.GhostActive = false
	return true
end

function SWEP:Equip()
	return self:Deploy()
end

if CLIENT then
	function SWEP:Think()
		if not IsFirstTimePredicted() then return end
		if not self.GhostActive then return end
		if not self.GhostEntity or not IsValid(self.GhostEntity) then
			self.GhostEntity = nil
			self:CreateGhost( "models/props/CS_militia/fern01.mdl", Vector(0, 0, 0), Angle() )
		end

		local tr = LocalPlayer():GetEyeTrace()
		self.GhostEntity:SetPos(tr.HitPos + Vector(0, 0, 6))

		local ang = (tr.HitPos - LocalPlayer():GetPos()):Angle()
		ang.p = 0
		ang.r = 0
		ang.y = ang.y + 90

		self.GhostEntity:SetAngles(ang)
	end
end



local distsdad = 850

local function colorToString(col)
	return string.format("<color=%s,%s,%s>", col.r, col.g, col.b)
end

local function getNearest(ent_s, filter, pos)
	local closest, closest_ent = math.huge, nil
	for i = 1, #(ent_s) do
		local ent = ent_s[i]

		if not (filter or function() end)(ent) then continue end

		if ent:GetPos():DistToSqr(pos) < closest then
			closest, closest_ent = ent:GetPos():DistToSqr(pos), ent
		end
	end

	return closest_ent, closest
end

if CLIENT then
	local grow_draw_cropinfo = CreateClientConVar("cl_grow_drawcropinfo", 1, true, false, "Draw names of crops/plants")

	local stringHash = function(text)
		local counter = 1
		local len = string.len(text)
		
		local fmod1 = 2 ^ 32 - 17
		local fmod2 = 2 ^ 24 - 1023
		local fmod3 = 2 ^ 23 - 16382
		local fmod4 = 2 ^ 22 - 262140
		
		local _fmod1 = 2 ^ 13 - 31
		local _fmod2 = 2 ^ 8
		
		for i = 1, len, 3 do
			counter = math.fmod(counter * _fmod1, fmod1) +
				(string.byte(text, i) * fmod2) +
				((string.byte(text, i + 1) or (len - i + _fmod2)) * fmod3) +
				((string.byte(text, i + 2) or (len - i + _fmod2)) * fmod4)
		end
		
		return math.fmod(counter, 4294967291)
	end

	local pastelize = function(str)
		local hue = string_hash(nick)
		local saturation, value = hue % 3 == 0, hue % 127 == 0

		-- thanks easychat
		local bad_col = HSVToColor(hue % 180 * 2, saturation and 0.3 or 0.6, value and 0.6 or 1)
		return Color(bad_col.r, bad_col.g, bad_col.b, bad_col.a)
	end

	function SWEP:DrawHUD()
		if not markup._Parse then
			markup.Cache = {}
			markup._Parse = markup.Parse

			markup.Parse = function(str)
				if not markup.Cache[str] then
					markup.Cache[str] = markup._Parse(str)
				end

				return markup.Cache[str]
			end
		end

		surface.SetTextPos(ScrW() / 2, ScrH() / 2)
		surface.SetFont("TargetID")

		surface.SetTextColor(255, 255, 0)
		surface.DrawText("Attack to attempt to plant a crop.")
		local th = ({surface.GetTextSize("A")})[2]

		surface.SetTextPos(ScrW() / 2, ScrH() / 2 + th)
		surface.SetTextColor(100, 255, 255)
		surface.DrawText("Reload to cycle through crops.")

		surface.SetTextPos(ScrW() / 2, ScrH() / 2 + th * 2)
		surface.SetTextColor(100, 255, 100)
		surface.DrawText("Right click to harvest the crop nearest to your cursor.")

		local tr = LocalPlayer():GetEyeTrace()
		if grow_draw_cropinfo:GetBool() then
			for k,v in pairs(ents.FindInSphere(tr.HitPos, distsdad)) do
				if v:GetClass():find("grow_crop_") and v:GetOwner() and IsValid(v:GetOwner()) then
					local t = v:GetPos():ToScreen()
					local x, y = t.x, t.y
					local nameMarkup = markup.Parse("<font=TargetID><color=255,255,255>" .. (UndecorateNick(v:GetOwner():Nick())) .. "'s " .. colorToString(pastelize(v:GetCropName())) .. v:GetCropName() .. " <color=255,255,255>crop")
					nameMarkup:Draw(x-nameMarkup.totalWidth/2,y)
				end

				if v.Base == "grow_base_plant" and v:GetCOwner() and IsValid(v:GetCOwner()) then
					local t = v:GetPos():ToScreen()
					local x, y = t.x, t.y
					local nameMarkup = markup.Parse("<font=TargetID><color=255,255,255>" .. (UndecorateNick(v:GetCOwner():Nick())) .. "'s " .. colorToString(pastelize(v:GetCropName())) .. v:GetCropName())
					nameMarkup:Draw(x-nameMarkup.totalWidth/2,y)
				end
			end
		end

		local closest_plant = getNearest(ents.FindInSphere(tr.HitPos, distsdad), function(ent)
			return ent.Base == "grow_base_plant" and ent:GetCOwner() == LocalPlayer()
		end, tr.HitPos)
		if closest_plant then
			cam.Start3D()
				render.DrawLine( tr.HitPos, closest_plant:GetPos(), Color( 100, 255, 255 ), false )
			cam.End3D()
		else
			local closest_plant = getNearest(ents.FindInSphere(tr.HitPos, distsdad), function(ent)
				return ent.Base == "grow_base_crop" and ent:GetOwner() == LocalPlayer()
			end, tr.HitPos)

			if closest_plant then
				cam.Start3D()
					render.DrawLine( tr.HitPos, closest_plant:GetPos(), Color( 100, 255, 255 ), false )
				cam.End3D()
			end
		end

		--local ent = cropdata[2] or nil
		local cropdata = (self.Crops[self.CropIndex] or {})
		local cropname = cropdata[1] or "Nothing"
		if cropname == "Nothing" then
			surface.SetTextPos(ScrW() / 2, ScrH() / 2 + th * 4)
			surface.SetTextColor(255, 255, 255)
			surface.DrawText("Current Crop: " .. cropname)
			return
		end

		local canGrow, reason
		if self.CanGrow then
			canGrow, reason = self:CanGrow(cropname)
		else
			canGrow, reason = false, "Invalid growth data."
		end

		if canGrow then
			surface.SetTextColor(100, 255, 100)
			if IsValid(self.GhostEntity) and self.GhostEntity then
				self.GhostEntity:SetColor( Color( 100, 255, 100, 200 ) )
			end
		else
			surface.SetTextColor(255, 100, 100)
			if IsValid(self.GhostEntity) and self.GhostEntity then
				self.GhostEntity:SetColor( Color( 255, 100, 100, 200 ) )
			end
		end
		surface.SetTextPos(ScrW() / 2, ScrH() / 2 + th * 4)

		surface.DrawText("Current Crop: " .. cropname)
		surface.SetTextPos(ScrW() / 2, ScrH() / 2 + th * 5)
		surface.DrawText("Can they grow on this spot? " .. (canGrow and "Yes!" or "No, ") .. (reason or ""))

		surface.SetFont("TargetIDSmall")
		surface.SetTextPos(ScrW() / 2, ScrH() / 2 + th * 7)
		surface.SetTextColor(255, 255, 100)
		surface.DrawText("I've heard that using a Spray Bottle makes the crops grow faster...")
	end
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not (owner:IsValid() and owner:IsPlayer()) then
		return
	end

	owner:SetAnimation(PLAYER_ATTACK1)
	if CLIENT then
		local cropdata = (self.Crops[self.CropIndex] or {})
		local ent = cropdata[2] or nil
		if ent and CurTime() > (self.LastFire or 0) then
			local entData = scripted_ents.Get(ent)

			local canGrow, reason
			if self.CanGrow then
				canGrow, reason = self:CanGrow(cropdata[1])
			else
				canGrow, reason = false, "Invalid growth data."
			end

			net.Start(Tag .. "_PlaceCrop")
			net.WriteUInt(self.CropIndex, 16)
			net.WriteBit(canGrow and 1 or 0)
			net.SendToServer()
			self.LastFire = CurTime() + 1
		end
	end

	self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()
	if not (owner:IsValid() and owner:IsPlayer()) then
		return
	end

	owner:SetAnimation(PLAYER_ATTACK1)
	if SERVER then
		if CurTime() > (self.LastFire or 0) then
			local tr = owner:GetEyeTrace()
			local closest_plant = getNearest(ents.FindInSphere(tr.HitPos, distsdad), function(ent)
				return ent.Base == "grow_base_plant" and ent:GetCOwner() == owner
			end, tr.HitPos)

			if closest_plant then
				closest_plant:AttemptSell(owner)
			else
				local closest_plant = getNearest(ents.FindInSphere(tr.HitPos, distsdad), function(ent)
					return ent.Base == "grow_base_crop" and ent:GetOwner() == owner
				end, tr.HitPos)

				if closest_plant then
					closest_plant:AttemptSell(owner)
				end
			end
			self.LastFire = CurTime() + 0.5
		end
	end

	self:SetNextSecondaryFire(CurTime() + 0.5)
end