-- luacheck: globals SERVER CLIENT util

local Tag = "grow"

do
	local ENT = {}
	ENT.PrintName = "Base Crop"
	ENT.Author = "26"
	ENT.Purpose = "Plant crop!"
	ENT.Base = "base_gmodentity"

	function ENT:SetupDataTables()
		self:NetworkVar("Float", 0, "Increment")
		self:NetworkVar("Float", 1, "RealModelScale")
		self:NetworkVar("Float", 2, "MaxModelScale")
		self:NetworkVar("Float", 3, "WateredGrowingScale")
		self:NetworkVar("Float", 4, "LastWater")

		self:NetworkVar("Int", 0, "TimeBetweenIncrement")
		self:NetworkVar("Int", 1, "Yield")

		self:NetworkVar("String", 0, "CropName")

		self:NetworkVar("Bool", 0, "IsDoneGrowing")
	end

	if SERVER then
		function ENT:PreInit()
			self:SetIncrement(0.01)
			self:SetRealModelScale(0.25)
			self:SetMaxModelScale(1.25)
			self:SetWateredGrowingScale(0.95)
			self:SetLastWater(SysTime() - 5)

			self:SetTimeBetweenIncrement(5)
			self:SetYield(math.random(2, 5))

			self:SetCropName("Pumpkin")

			self:SetIsDoneGrowing(false)
		end

		function ENT:Initialize()
			self:SetModel("models/props/CS_militia/fern01.mdl")
			self:SetMoveType(MOVETYPE_NONE)
			self:SetAngles(Angle(0, math.random(-180, 180), 0))
			--self:Activate()

			self:PreInit()
		end

		function ENT:ExtraThink()
		end

		local GROW_DIST = 100 ^ 2
		local GROW_FORWARD_DIST = 50 ^ 2
		function ENT:Think()
			self:SetModelScale(self:GetRealModelScale(), 0.5)

			if not self.LastIncrement then
				self.LastIncrement = SysTime()
			end

			local nextTime = self.LastIncrement + self:GetTimeBetweenIncrement()
			if SysTime() < self:GetLastWater() + 1 then
				nextTime = nextTime - (self:GetTimeBetweenIncrement() * self:GetWateredGrowingScale())
			end

			if SysTime() > nextTime and not self:GetIsDoneGrowing() then
				self.LastIncrement = SysTime()
				self:SetRealModelScale(self:GetRealModelScale() + self:GetIncrement())

				if self:GetRealModelScale() >= self:GetMaxModelScale() then
					self:SetIsDoneGrowing(true)
					if self.PostGrowFunction then
						self:PostGrowFunction()
					end
				end
			end

			-- are we being watered
			for k, v in pairs(ents.FindInSphere(self:GetPos(), GROW_DIST)) do
				if IsValid(v) and v:IsPlayer() then
					local wep = v:GetActiveWeapon()

					-- they're clicking
					if IsValid(wep) and wep:GetClass() == "weapon_squirtbottle" and v:KeyDown(IN_ATTACK) then
						local fpos = v:GetPos() + v:GetForward() * 20
						if fpos:DistToSqr(self:GetPos()) < GROW_FORWARD_DIST then
							self:SetLastWater(SysTime())
						end
					end
				end
			end

			self:ExtraThink()
		end

		function ENT:PostGrowFunction()
			Say(self, "Done Watering")
		end
		
		function ENT:AttemptSell(ent)
			--Say(self, "Sold", ent)
			self:Remove()
			ent.crops = ent.crops - 1
		end
	else
		function ENT:Draw()
			self:DrawModel()
		end
	end

	scripted_ents.Register(ENT, Tag .. "_base_crop")
end

-- a crop
do
	local ENT = {}

	ENT.Base = "base_gmodentity"

	function ENT:SetupDataTables()
		self:NetworkVar("String", 0, "CropName")

		self:NetworkVar("Int", 0, "CropPrice")
		self:NetworkVar("Int", 1, "LittleGrowTime")

		self:NetworkVar("Float", 0, "MaxModelScale")

		self:NetworkVar("Entity", 0, "COwner")
	end

	function ENT:Preinit()
		self:SetCropName("Watermelon")

		self:SetCropPrice(10)
		self:SetLittleGrowTime(7)

		self:SetMaxModelScale(0.75)
	end

	if SERVER then
		function ENT:Initialize()
			self:SetModel("models/props_junk/watermelon01.mdl")
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			--self:SetMoveType(MOVETYPE_NONE)

			local phys = self:GetPhysicsObject()
			if IsValid(phys) then
				phys:EnableMotion(false)
			end

			self:Preinit()
			self:SetModelScale(0)
			self:SetModelScale(self:GetMaxModelScale(), self:GetLittleGrowTime())
			self.Spawned = SysTime()

			timer.Simple(
				self:GetLittleGrowTime(),
				function()
					if not IsValid(self) then
						return
					end
					if not IsValid(self:GetCOwner()) then
						self:Remove()
						return
					end

					local phys = self:GetPhysicsObject()
					if IsValid(phys) then
						phys:EnableMotion(true)
						phys:Wake()
					end
				end
			)
		end

		function ENT:AttemptSell(ply)
			if ply ~= self:GetCOwner() then
				ply:ChatPrint("Not your crop!")
				return
			end

			self:Remove()
			ply:ChatPrint("Sold a " .. self:GetCropName() .. " for NOTHING.")
		end
	else
		function ENT:Draw()
			self:DrawModel()
		end
	end

	scripted_ents.Register(ENT, "grow_base_plant")
end

-- pumpkin
do
	local ENT = {}
	ENT.PrintName = "Pumpkin Crop"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_crop"

	function ENT:PostGrowFunction()
		for i = 1, self:GetYield() do
			local pumpkin = ents.Create("grow_plant_pumpkin")
			pumpkin:SetPos(self:GetPos() + Vector(math.random(-55, 55), math.random(-55, 55), math.random(5, 8)))
			pumpkin:SetAngles(Angle(math.random(-10, 10), math.random(-180, 180), 0))
			pumpkin:Spawn()
			pumpkin:SetCOwner(self:GetOwner())

			self:DeleteOnRemove(pumpkin)
		end
	end
	scripted_ents.Register(ENT, Tag .. "_crop_pumpkin")
	
	local ENT = {}
	ENT.PrintName = "Pumpkin"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_plant"
	
	function ENT:Preinit()
		self:SetCropName("Pumpkin")

		self:SetCropPrice(20)
		self:SetLittleGrowTime(10)

		self:SetMaxModelScale(0.65)
		
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(30)	
		end
		self:SetModel("models/props_halloween/pumpkin_01.mdl")
	end
	
	scripted_ents.Register(ENT, Tag .. "_plant_pumpkin")
end

-- watermelon
do
	local ENT = {}
	ENT.PrintName = "Melon Crop"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_crop"

	function ENT:PreInit()
		self:SetIncrement(0.01)
		self:SetRealModelScale(0.25)
		self:SetMaxModelScale(1.25)
		self:SetWateredGrowingScale(0.95)
		self:SetLastWater(SysTime() - 5)

		self:SetTimeBetweenIncrement(5)
		self:SetYield(math.random(2, 5))

		self:SetCropName("Melon")

		self:SetIsDoneGrowing(false)
	end

	function ENT:PostGrowFunction()
		for i = 1, self:GetYield() do
			local pumpkin = ents.Create("grow_plant_melon")
			pumpkin:SetPos(self:GetPos() + Vector(math.random(-55, 55), math.random(-55, 55), math.random(5, 8)))
			pumpkin:SetAngles(Angle(math.random(-10, 10), math.random(-180, 180), 0))
			pumpkin:Spawn()
			pumpkin:SetCOwner(self:GetOwner())

			local phys = pumpkin:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetMass(30)
			end

			self:DeleteOnRemove(pumpkin)
		end
	end
	scripted_ents.Register(ENT, Tag .. "_crop_melon")
	
	local ENT = {}
	ENT.PrintName = "Watermelon"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_plant"
	
	function ENT:Preinit()
		self:SetCropName("Watermelon")

		self:SetCropPrice(15)
		self:SetLittleGrowTime(7)

		self:SetMaxModelScale(0.75)
		
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(30)	
		end
	end
	
	scripted_ents.Register(ENT, Tag .. "_plant_melon")
end

-- cursed
do
	local ENT = {}
	ENT.PrintName = "Cursed Skull Crop"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_crop"

	function ENT:PreInit()
		self:SetIncrement(0.035)
		self:SetRealModelScale(0.25)
		self:SetMaxModelScale(2.25)
		self:SetWateredGrowingScale(0.95)
		self:SetLastWater(SysTime() - 5)

		self:SetTimeBetweenIncrement(5)
		self:SetYield(math.random(3, 7))

		self:SetCropName("Cursed Skull")

		self:SetIsDoneGrowing(false)
		self:SetColor(Color(255, 0, 0))
	end

	function ENT:ExtraThink()
		if not self:IsOnFire() then
			self:Ignite(2000)
		end
	end

	function ENT:PostGrowFunction()
		for i = 1, self:GetYield() do
			local pumpkin = ents.Create("grow_plant_skull")
			pumpkin:SetPos(self:GetPos() + Vector(math.random(-95, 95), math.random(-95, 95), math.random(5, 8)))
			pumpkin:SetAngles(Angle(math.random(-10, 10), math.random(-180, 180), 0))
			pumpkin:Spawn()
			pumpkin:SetCOwner(self:GetOwner())

			local phys = pumpkin:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetMass(30)
			end

			self:DeleteOnRemove(pumpkin)
		end
	end
	scripted_ents.Register(ENT, Tag .. "_crop_cursed")
	
	local ENT = {}
	ENT.PrintName = "Cursed Skull"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_plant"
	
	function ENT:Preinit()
		self:SetCropName("Cursed Skull")

		self:SetCropPrice(35)
		self:SetLittleGrowTime(10)

		self:SetMaxModelScale(2.5)
		
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(30)	
		end
		self:SetModel("models/Gibs/HGIBS.mdl")
		self:SetColor(Color(200, 0, 0))
	end
	
	scripted_ents.Register(ENT, Tag .. "_plant_skull")
end

-- shrooms, this is just meme crop i might work on it later
do
	local ENT = {}
	ENT.PrintName = "Mushroom"
	ENT.Author = "twentysix"
	ENT.Base = Tag .. "_base_crop"

	function ENT:PreInit()
		self:SetIncrement(0.05)
		self:SetRealModelScale(0.5)
		self:SetMaxModelScale(2.5)
		self:SetWateredGrowingScale(0.95)
		self:SetLastWater(SysTime() - 5)

		self:SetTimeBetweenIncrement(15)
		self:SetYield(1)

		self:SetCropName("Mushroom")

		self:SetIsDoneGrowing(false)
	end

	function ENT:Initialize()
		self:SetModel("models/props_swamp/shroom_ref_01_cluster.mdl")
		self:SetMoveType(MOVETYPE_NONE)
		self:SetAngles(Angle(0, math.random(-180, 180), 0))
		--self:Activate()

		self:PreInit()
	end

	function ENT:PostGrowFunction()
	end

	scripted_ents.Register(ENT, Tag .. "_crop_shrooms")
end


-- planter
do
	local SWEP = {Primary = {}, Secondary = {}}

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
	SWEP.Crops = {
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
		--print("HOLSTER",self)
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
						--print(x,y)
						
						local nameMarkup = markup.Parse("<font=TargetID><color=255,255,255>" .. (UndecorateNick(v:GetOwner():Nick())) .. "'s " .. colorToString(EasyChat.PastelizeNick(v:GetCropName())) .. v:GetCropName() .. " <color=255,255,255>crop")
						nameMarkup:Draw(x-nameMarkup.totalWidth/2,y)
						--[[local tw, th = surface.GetTextSize(v:GetCropName())
						surface.SetTextColor(EasyChat.PastelizeNick(v:GetCropName()))
						surface.SetTextPos(x-tw/2, y)
						surface.DrawText(v:GetCropName())]]
					end
					
					if v.Base == "grow_base_plant" and v:GetCOwner() and IsValid(v:GetCOwner()) then
						
						local t = v:GetPos():ToScreen()
						local x, y = t.x, t.y
						--print(x,y)
						
						local nameMarkup = markup.Parse("<font=TargetID><color=255,255,255>" .. (UndecorateNick(v:GetCOwner():Nick())) .. "'s " .. colorToString(EasyChat.PastelizeNick(v:GetCropName())) .. v:GetCropName())
						nameMarkup:Draw(x-nameMarkup.totalWidth/2,y)
						--[[local tw, th = surface.GetTextSize(v:GetCropName())
						surface.SetTextColor(EasyChat.PastelizeNick(v:GetCropName()))
						surface.SetTextPos(x-tw/2, y)
						surface.DrawText(v:GetCropName())]]
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
		--print(SysTime(),self:GetNextPrimaryFire())
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

	weapons.Register(SWEP, Tag .. "_planter")
end
--models/props_swamp/shroom_ref_01_cluster.mdl
-- net stuff
do
	if SERVER then
		util.AddNetworkString(Tag .. "_PlaceCrop")

		local planter = weapons.Get(Tag .. "_planter")
		net.Receive(
			Tag .. "_PlaceCrop",
			function(len, ply)
				if not (ply:GetActiveWeapon():GetClass() == Tag .. "_planter") then
					return
				end

				local crop = net.ReadUInt(16)
				local canGrow = net.ReadBit()
				if not (canGrow == 1) then
					return
				end
				local cropI = planter.Crops[crop]
				local ent = cropI[2]
				if not ent then
					return
				end

				if not ply.crops then
					ply.crops = 0
				end

				if ply.crops and ply.crops + 1 > 6 then
					ply:ChatPrint("You have too many crops. Harvest/sell a couple!")
					return
				end
				
				ply:Lock()
				--print(ply.crops, ply.crops + 1)
				
				--player/footsteps/dirt05.wav
				
				local tr = ply:GetEyeTrace()
				if not IsValid(ply) or not ply then return end
				local d = {3,6,5}
				ply:EmitSound(string.format("player/footsteps/dirt%s.wav", (table.Random(d))))
				timer.Simple(0.6 + math.random(0, 100) / 100, function()
					if not IsValid(ply) or not ply then return end
					ply:EmitSound("material/material_dirt_impact1.wav")
					ply:ChatPrint("You have planted a " .. cropI[1] .. "!")
					
					ent = ents.Create(ent)
					ent:SetPos(tr.HitPos + Vector(0, 0, 6))
					ent:SetOwner(ply)
					ent:Spawn()
					
					local ang = (tr.HitPos - ply:GetPos()):Angle()
					ang.p = 0
					ang.r = 0
					ang.y = ang.y + 90
					ent:SetAngles(ang)
					ply.crops = ply.crops + 1
					ply:UnLock()
				end)

			end
		)
	end
end
