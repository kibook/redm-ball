local Velocity = 20.0

local Animations = {
	idle = {dict = "mech_weapons_thrown@base", name = "grip_idle", flag = 25},
	idleWalking = {dict = "mech_weapons_thrown@base", name = "grip_walk", flag = 25},
	aimingLow = {dict = "mech_weapons_thrown@base", name = "aim_l", flag = 25},
	aimingMed = {dict = "mech_weapons_thrown@base", name = "aim_m", flag = 25},
	aimingHigh = {dict = "mech_weapons_thrown@base", name = "aim_h", flag = 25},
	aimingFullLow = {dict = "mech_weapons_thrown@base", name = "aimlive_l", flag = 25},
	aimingFullMed = {dict = "mech_weapons_thrown@base", name = "aimlive_m", flag = 25},
	aimingFullHigh = {dict = "mech_weapons_thrown@base", name = "aimlive_h", flag = 25},
	throwingLow = {dict = "mech_weapons_thrown@base", name = "throw_l_fb_stand", flag = 2},
	throwingMed = {dict = "mech_weapons_thrown@base", name = "throw_m_fb_stand", flag = 2},
	throwingHigh = {dict = "mech_weapons_thrown@base", name = "throw_h_fb_stand", flag = 2},
}

local BallModels = {
	["baseball"] = `s_baseball01x`,
	["bocceballgreen"] = `p_bocceballgreen01x`,
	["bocceballjack"] = `p_bocceballjack01x`,
	["bocceballred"] = `p_bocceballred01x`,
	["bone"] = `p_dogbone01x`,
	["cannonball"] = `p_cannonball01x`,
	["goatball"] = `mp004_p_goatball_02a`,
	["horseshoe"] = `p_horseshoe01x`,
	["jugglingball"] = `p_jugglingball01x`,
	["lightbulb"] = `p_lightbulb01x`,
	["shoe"] = `p_shoe01x`,
	["snowball"] = `p_cs_snowball01x`,
}

local EquippedBall
local CurrentAnimation
local ActiveProjectile
local KnockedDown

RegisterNetEvent("ball:hit")

function LoadModel(model)
	if not IsModelInCdimage(model) then
		print("Invalid model: " .. model)
		return false
	end

	RequestModel(model)

	while not HasModelLoaded(model) do
		Wait(0)
	end

	return true
end

function AttachBall(ball, ped)
	AttachEntityToEntity(ball, ped,
		GetEntityBoneIndexByName(ped, "SKEL_R_Finger33"),
		0.02, -0.02, -0.02,
		0.0, 180.0, 0.0,
		false,
		false,
		false,
		false,
		0,
		true,
		false,
		false)
end

function EquipBall(model)
	if EquippedBall then
		UnequipBall()
	end

	local ped = PlayerPedId()

	if not LoadModel(model) then
		return
	end

	local ball = CreateObject(model, 0.0, 0.0, 0.0, true, false, true, false, false)

	SetEntityLodDist(ball, 0xFFFF)

	AttachBall(ball, ped)

	EquippedBall = ball

	SetPlayerLockon(PlayerId(), false)
end

function UnequipBall()
	DeleteObject(EquippedBall)
	EquippedBall = nil

	if CurrentAnimation then
		StopAnimTask(PlayerPedId(), CurrentAnimation.dict, CurrentAnimation.name, 1.0)
	end

	SetPlayerLockon(PlayerId(), true)
end

function IsPlayingAnimation(ped, anim)
	return IsEntityPlayingAnim(ped, anim.dict, anim.name, anim.flag)
end

function PlayAnimation(ped, anim)
	if not DoesAnimDictExist(anim.dict) then
		print("Invalid animation dictionry: " .. anim.dict)
		return
	end

	RequestAnimDict(anim.dict)

	while not HasAnimDictLoaded(anim.dict) do
		Wait(0)
	end

	TaskPlayAnim(ped, anim.dict, anim.name, 4.0, 4.0, -1, anim.flag, 0, false, false, false, "", false)

	RemoveAnimDict(anim.dict)
end

local entityEnumerator = {
	__gc = function(enum)
		if enum.destructor and enum.handle then
			enum.destructor(enum.handle)
		end
		enum.destructor = nil
		enum.handle = nil
	end
}

function EnumerateEntities(firstFunc, nextFunc, endFunc)
	return coroutine.wrap(function()
		local iter, id = firstFunc()

		if not id or id == 0 then
			endFunc(iter)
			return
		end

		local enum = {handle = iter, destructor = endFunc}
		setmetatable(enum, entityEnumerator)

		local next = true
		repeat
			coroutine.yield(id)
			next, id = nextFunc(iter)
		until not next

		enum.destructor, enum.handle = nil, nil
		endFunc(iter)
	end)
end

function EnumeratePeds()
	return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

function GetBallModelNames()
	local names = {}

	for name, hash in pairs(BallModels) do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

function RequestControl(entity)
	NetworkRequestControlOfEntity(entity)

	local timeWaited = 0

	while not NetworkHasControlOfEntity(entity) and timeWaited <= 500 do
		Wait(1)
		timeWaited = timeWaited + 1
	end
end

function ApplyBallHit(ped, velocity)
	SetPedToRagdoll(ped, 3000, 3000, 0, 0, 0, 0)
	SetEntityVelocity(ped, velocity / 6.0)
end

function GetPlayerFromPed(ped)
	for _, player in ipairs(GetActivePlayers()) do
		if GetPlayerPed(player) == ped then
			return player
		end
	end
end

RegisterCommand("ball", function(source, args, raw)
	if #args < 1 then
		if EquippedBall then
			UnequipBall()
		else
			EquipBall(BallModels["baseball"])
		end
	else
		EquipBall(BallModels[args[1]])
	end
end)

AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() ~= resourceName then
		return
	end

	if EquippedBall then
		UnequipBall()
	end
end)

AddEventHandler("ball:hit", function(ped, velocity)
	if ped == -1 then
		if GetRelationshipBetweenGroups(`PLAYER`, `PLAYER`) == 5 then
			ApplyBallHit(PlayerPedId(), velocity)
			KnockedDown = GetSystemTime() + 3000
		end
	else
		ApplyBallHit(NetToPed(ped), velocity)
	end
end)

CreateThread(function()
	while true do
		if EquippedBall then
			DisableControlAction(0, `INPUT_MELEE_ATTACK`, true)
			DisableControlAction(0, `INPUT_MELEE_GRAPPLE`, true)
			DisableControlAction(0, `INPUT_MELEE_GRAPPLE_CHOKE`, true)
			DisableControlAction(0, `INPUT_INSPECT_ZOOM`, true)
			DisableControlAction(0, `INPUT_INTERACT_LOCKON`, true)
			DisableControlAction(0, `INPUT_CONTEXT_LT`, true)

			local _, wep = GetCurrentPedWeapon(ped)
			if wep ~= `WEAPON_UNARMED` then
				SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true, 0, false, false)
			end

			if IsControlJustPressed(0, `INPUT_OPEN_WHEEL_MENU`) or IsControlJustPressed(0, `INPUT_TOGGLE_HOLSTER`) or IsControlJustPressed(0, `INPUT_TWIRL_PISTOL`) then
				UnequipBall()
			end
		end

		Wait(0)
	end
end)

CreateThread(function()
	local timeStartedPressing

	while true do
		local ped = PlayerPedId()

		if EquippedBall and not KnockedDown then
			-- Re-attach ball if ped changes
			if not IsEntityAttachedToEntity(EquippedBall, ped) then
				AttachBall(EquippedBall, ped)
			end

			-- Restart animation if interrupted
			if CurrentAnimation then
				if not IsPlayingAnimation(ped, CurrentAnimation) then
					PlayAnimation(ped, CurrentAnimation)
				end
			end

			if IsControlPressed(0, `INPUT_AIM`) then
				-- Determine how long the attack button has been pressed
				local timePressed

				if timeStartedPressing then
					timePressed = GetSystemTime() - timeStartedPressing
				else
					timePressed = 0
				end

				-- Determine Z angle of throw
				local rot = GetGameplayCamRot(2)
				local zangle

				if rot.x < -20.0 then
					if timePressed > 1000 then
						CurrentAnimation = Animations.aimingFullLow
					else
						CurrentAnimation = Animations.aimingLow
					end

					zangle = 5.0
				elseif rot.x < 20.0 then
					if timePressed > 1000 then
						CurrentAnimation = Animations.aimingFullMed
					else
						CurrentAnimation = Animations.aimingMed
					end
					
					zangle = 10.0
				else
					if timePressed > 1000 then
						CurrentAnimation = Animations.aimingFullHigh
					else
						CurrentAnimation = Animations.aimingHigh
					end

					zangle = 15.0
				end

				if IsControlPressed(0, `INPUT_ATTACK`) then
					if not timeStartedPressing then
						timeStartedPressing = GetSystemTime()
					end
				elseif IsControlJustReleased(0, `INPUT_ATTACK`) then
					-- Determine intensity of throw based on length of button press
					local velocity
					local throwingAnim

					if timePressed > 1000 then
						velocity = Velocity * 5
						throwingAnim = Animations.throwingHigh
					elseif timePressed > 200 then
						velocity = Velocity * 3
						throwingAnim = Animations.throwingMed
					else
						velocity = Velocity
						throwingAnim = Animations.throwingLow
					end

					timeStartedPressing = nil

					-- Play throwing animation
					ClearPedTasksImmediately(ped)
					SetEntityHeading(ped, rot.z)
					PlayAnimation(ped, throwingAnim)

					Wait(500)

					-- Calculate trajectory
					local r = math.rad(-rot.z)
					local vx = velocity * math.sin(r)
					local vy = velocity * math.cos(r)
					local vz = rot.x + zangle

					-- Throw ball
					ClearPedTasks(ped)
					DetachEntity(EquippedBall)
					SetEntityCoords(EquippedBall, GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.2))
					SetEntityVelocity(EquippedBall, vx, vy, vz)
					ActiveProjectile = EquippedBall

					-- Clean up and spawn a new ball in hand
					local model = GetEntityModel(EquippedBall)
					SetObjectAsNoLongerNeeded(EquippedBall)
					EquippedBall = 0
					EquipBall(model)
				end
			else
				timeStartedPressing = nil

				if IsPedWalking(ped) then
					CurrentAnimation = Animations.idleWalking
				else
					CurrentAnimation = Animations.idle
				end
			end
		end

		Wait(0)
	end
end)

CreateThread(function()
	while true do
		if ActiveProjectile and HasEntityCollidedWithAnything(ActiveProjectile) then
			local velocity = GetEntityVelocity(ActiveProjectile)

			for ped in EnumeratePeds() do
				if IsEntityTouchingEntity(ActiveProjectile, ped) then
					if IsPedAPlayer(ped) then
						TriggerServerEvent("ball:hit", GetPlayerServerId(GetPlayerFromPed(ped)), -1, velocity)
					elseif NetworkGetEntityIsNetworked(ped) then
						if NetworkHasControlOfEntity(ped) then
							ApplyBallHit(ped, velocity)
						else
							TriggerServerEvent("ball:hit", -1, PedToNet(ped), velocity)
						end
					end
				end
			end

			local ball = ActiveProjectile
			SetTimeout(10000, function()
				RequestControl(ball)
				DeleteObject(ball)
			end)

			ActiveProjectile = nil
		end

		Wait(0)
	end
end)

CreateThread(function()
	while true do
		if KnockedDown and GetSystemTime() > KnockedDown then
			KnockedDown = nil
		end

		Wait(500)
	end
end)

CreateThread(function()
	TriggerEvent("chat:addSuggestion", "/ball", "Equip/Unequip a throwable ball", {
		{name = "type", help = table.concat(GetBallModelNames(), ", ")}
	})
end)
