if (SERVER) then
	AddCSLuaFile("shared.lua")
end

if (CLIENT) then
	SWEP.PrintName = "Blowtorch"
	SWEP.Slot = 1
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
end

SWEP.Author = "Sweepyoface"
SWEP.Instructions = "Left click to temporarily fade a prop."
SWEP.Contact = "github@sweepy.pw"
SWEP.Purpose = ""

SWEP.ViewModel = Model("models/weapons/v_Pistol.mdl")
SWEP.WorldModel = Model("models/weapons/w_Pistol.mdl")

SWEP.Spawnable = false
SWEP.AdminSpawnable = true
SWEP.Category = "DarkRP (Utility)"

SWEP.FadingSound = Sound("buttons/blip1.wav")
SWEP.Sound = Sound("physics/wood/wood_box_impact_hard3.wav")
SWEP.FadeTime = 10 -- Time it takes to fade a prop
SWEP.Cooldown = 0 -- Cooldown applied ONLY if the prop is successfully faded
SWEP.FadeDuration = 60 -- Time a prop is faded

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.snd = false

function SWEP:SetupDataTables()
	self:DTVar("Bool", 1, "fading")
	self:DTVar("Bool", 2, "cancelled")
	self:DTVar("Entity", 1, "target")
	self:DTVar("Int", 1, "start")
	self:DTVar("Int", 2, "endt")
end

function SWEP:Initialize()
	self:SetWeaponHoldType("pistol")
	if (SERVER) then
		self.dt.fading = false
	end
end

function SWEP:Cancel()
	self.dt.cancelled = true
	self.dt.target = nil
	self.dt.fading = false
	self.dt.start = -1
	self.dt.endt = -1
	
	timer.Destroy("FadingStuff")
	
	return
end

function SWEP:Succeed(ply, trace)
--	DarkRP.notify(ply, 2, 5, "Prop faded for " .. self.FadeDuration .. " seconds.")

	self.Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	
	local owner = ply
	owner:SetAnimation(PLAYER_ATTACK1)
	owner:EmitSound(self.Sound)
	owner:ViewPunch(Angle(-10, math.random(-5, 5), 0))
	
	local target = self.dt.target
	--target:SetMaterial("sprites/heatwave")
	local col = target:GetColor()
	target:SetColor( Color( col.r, col.g, col.b, 222 ) )
	target:SetRenderMode(RENDERMODE_TRANSALPHA)
	--target:SetCollisionGroup(COLLISION_GROUP_WORLD)
	target:DrawShadow(false)
	target:SetNotSolid(true)
	target.faded = true
	timer.Simple(self.FadeDuration, function()
		if (target and target:IsValid()) then
			--target:SetMaterial("")
			target:SetColor( Color( col.r, col.g, col.b, 255 ) )
			target:SetRenderMode(RENDERMODE_NORMAL)
			target:DrawShadow(true)
			target:SetNotSolid(false)
			--target:SetCollisionGroup(COLLISION_GROUP_NONE)
			target.faded = nil
		end
	end)
	
	local effectdata = EffectData()
	effectdata:SetOrigin(ply:GetShootPos())
	effectdata:SetScale(5)
	util.Effect("ManhackSparks", effectdata)	
	
	self:SetNextPrimaryFire(CurTime() + self.Cooldown)
	
	self:Cancel()
	return
end

function SWEP:Think()
	if self.dt.target and IsValid(self.dt.target) then
		if SERVER then
			local owner = self:GetOwner()
			local target = self.dt.target
			local trace = owner:GetEyeTrace()

			if ((target:GetPos() - owner:GetPos()):LengthSqr() >= 15000) then
				self:Cancel()
				return
			elseif (!trace.HitNonWorld) or (trace.Entity ~= target) then
				self:Cancel()
				return
			end
			
			if (CurTime() >= self.dt.endt) then
				self:Succeed(owner, trace)
			end
		end
	elseif self.dt.fading then
		self:Cancel()
	end
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetNextPrimaryFire(CurTime() + self:GetOwner():GetViewModel():SequenceDuration())
end

function SWEP:Holster()
	self:Cancel()
	return true
end

function SWEP:PrimaryAttack()
	if (CLIENT) then return end
	
	local owner = self:GetOwner()
	local trace = util.TraceLine({start = owner:GetShootPos(), endpos = owner:GetShootPos() + (owner:GetAimVector() * 160), filter = owner})

	local ent = trace.Entity
	if (trace.HitNonWorld and ent and ent:GetClass() == "prop_physics" and (ent:GetPos() - owner:GetPos()):LengthSqr() <= 15000 and !ent.faded) then	
		self.dt.cancelled = false
		self.dt.fading = true
		self.dt.target = trace.Entity
		self.dt.start = CurTime()
		self.dt.endt = CurTime() + self.FadeTime
		
		timer.Create("FadingStuff", 0.5, 0, function()
			self.snd = !self.snd
			if (self.snd) then
				owner:EmitSound(self.FadingSound)
			end
		
			local effectdata = EffectData()
			effectdata:SetOrigin(trace.HitPos)
			effectdata:SetScale(5)
			util.Effect("ManhackSparks", effectdata)	
		end)
	end
	
	self:SetNextPrimaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
end

if (CLIENT) then
	function SWEP:DrawHUD()
		if (self.dt.fading == true) then
			local w = ScrW()
			local h = ScrH()
			local x, y, width, height = w / 2 - w / 10, h / 2, w / 5, h / 15
			
			draw.RoundedBox(8, x, y, width, height, Color(10, 10, 10,120))
			
			local time = self.dt.endt - self.dt.start
			local curtime = CurTime() - self.dt.start
			local status = curtime / time
			local BarWidth = status * (width - 16) + 8

			draw.RoundedBox(8, x + 8, y + 8, BarWidth, height - 16, Color(255 - (status * 255), 0 + (status * 255), 0, 255))
			draw.SimpleText("Attempting to fade..", "Trebuchet24", w / 2, h / 2 + height / 2, Color(255, 255, 255, 255), 1, 1)
			
			// debug info
			-- draw.SimpleText(tostring(self.dt.fading), "Trebuchet24", 100, 50, Color(255, 255, 255, 255), 1, 1)
			-- draw.SimpleText(self.dt.start, "Trebuchet24", 100, 75, Color(255, 255, 255, 255), 1, 1)
			-- draw.SimpleText(self.dt.endt, "Trebuchet24", 100, 100, Color(255, 255, 255, 255), 1, 1)
			-- draw.SimpleText(CurTime(), "Trebuchet24", 100, 125, Color(255, 255, 255, 255), 1, 1)
			-- draw.SimpleText(tostring(self.dt.target:IsValid()), "Trebuchet24", 100, 150, Color(255, 255, 255, 255), 1, 1)
		end
	end
end
