-- Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = require 'Engine'
local Lang = require 'Lang'
local Game = require 'Game'
local Space = require 'Space'
local Comms = require 'Comms'
local Event = require 'Event'
local Legal = require 'Legal'
local Serializer = require 'Serializer'
local Timer = require 'Timer'
local Commodities = require 'Commodities'
local PlayerState = require 'PlayerState'

local MissionUtils = require 'modules.MissionUtils'
local ShipBuilder  = require 'modules.MissionUtils.ShipBuilder'

local l = Lang.GetResource("module-policepatrol")
local l_ui_core = Lang.GetResource("ui-core")

-- Fine at which police will hunt down outlaw player
-- This is a copy from CrimeTracking.lua.
local maxFineTolerated = 300
--   The distance, in meters, at which the police patrol upholds the law
local lawEnforcedRange = 4000000

local getNumberOfFlavours = function (str)
	local num = 1

	while l:get(str .. "_" .. num) do
		num = num + 1
	end
	return num - 1
end

local hasIllegalGoods = function (cargo)
	local illegal = false

	for name in pairs(cargo) do
		if not Game.system:IsCommodityLegal(name) then
			illegal = true
			break
		end
	end
	return illegal
end


local patrol = {}
local showMercy = true
local piracy = false
local target = nil

local attackShip = function (ship)
	for i = 1, #patrol do
		patrol[i]:AIKill(ship)
	end
	target = ship
end

local onShipDestroyed = function (ship, attacker)
	if ship:IsPlayer() or attacker == nil then return end

	if ship == target then
		target = nil
	else
		for i = 1, #patrol do
			if patrol[i] == ship then
				table.remove(patrol, i)
				if attacker:isa("Ship") and attacker:IsPlayer() then
					showMercy = false
				end
				break
			elseif patrol[i] == attacker then
				Comms.ImportantMessage(l["TARGET_DESTROYED_" .. Engine.rand:Integer(1, getNumberOfFlavours("TARGET_DESTROYED"))], attacker.label)
				break
			end
		end
	end
end

local onShipHit = function (ship, attacker)
	if attacker == nil then return end
	if not attacker:isa('Ship') then return end

	-- Support all police, not only the patrol
	-- TODO: this should use a property set on the ship rather than checking for the shipid
	-- (what happens if the player is committing piracy in a police hull?)
	local policeId = Game.system.faction.policeShip
	if ship.shipId == policeId and attacker.shipId ~= policeId then
		piracy = true
		attackShip(attacker)
	end
end

local onShipFiring = function (ship)
	if piracy or target then return end

	local policeId = Game.system.faction.policeShip
	if ship.shipId ~= policeId then
		for i = 1, #patrol do
			if ship:DistanceTo(patrol[i]) <= lawEnforcedRange then
				Comms.ImportantMessage(string.interp(l_ui_core.X_CANNOT_BE_TOLERATED_HERE, { crime = l_ui_core.UNLAWFUL_WEAPONS_DISCHARGE }), patrol[i].label)
				attackShip(ship)
				break
			end
		end
	end
end

local onJettison = function (ship, cargo)
	if not ship:IsPlayer() or Game.system:IsCommodityLegal(cargo.name) then return end

	if #patrol > 0 and showMercy then
		local manifest = ship:GetComponent('CargoManager').commodities
		if not hasIllegalGoods(manifest) then
			Comms.ImportantMessage(l.TAKE_A_HIKE, patrol[1].label)
			for i = 1, #patrol do
				patrol[i]:CancelAI()
			end
			target = nil
		end
	end
end

local onEnterSystem = function (player)
	if not hasIllegalGoods(Commodities) then return end

	local system = assert(Game.system)
	if (1 - system.lawlessness) < Engine.rand:Number(4) then return end

	local crimes, fine = PlayerState.GetCrimeOutstanding()
	local ship
	local n = 1 + math.floor((1 - system.lawlessness) * (system.population / 3))

	local threat = 10.0 + Engine.rand:Number(10, 50) * system.lawlessness
	local template = MissionUtils.ShipTemplates.PolicePatrol:clone {
		shipId = system.faction.policeShip,
		label = system.faction.policeName
	}

	for i = 1, n do
		ship = ShipBuilder.MakeShipNear(player, template, threat, 50, 100)
		assert(ship)

		table.insert(patrol, ship)
	end

	if Engine.rand:Number(1) < system.lawlessness then
		-- You are lucky. They are busy, eating donuts ;-)
		Comms.ImportantMessage(string.interp(l["RESPECT_THE_LAW_" .. Engine.rand:Integer(1, getNumberOfFlavours("RESPECT_THE_LAW"))], { system = system.name }), ship.label)
	else
		if fine > maxFineTolerated then
			Comms.ImportantMessage(string.interp(l["OUTLAW_DETECTED_" .. Engine.rand:Integer(1, getNumberOfFlavours("OUTLAW_DETECTED"))], { ship_label = player.label }), ship.label)
			showMercy = false
			attackShip(player)
		else
			Comms.ImportantMessage(l["INITIATE_CARGO_SCAN_" .. Engine.rand:Integer(1, getNumberOfFlavours("INITIATE_CARGO_SCAN"))], ship.label)
			Timer:CallAt(Game.time + Engine.rand:Integer(3, 9), function ()
				if not Game.system then return end -- Shut up when the player is already in hyperspace

				local manifest = player:GetComponent('CargoManager').commodities
				if hasIllegalGoods(manifest) then
					Comms.ImportantMessage(l.ILLEGAL_GOODS_DETECTED, ship.label)
					attackShip(player)
					Comms.ImportantMessage(l["POLICE_TAUNT_" .. Engine.rand:Integer(1, getNumberOfFlavours("POLICE_TAUNT"))], ship.label)
				else
					Comms.ImportantMessage(l.NOTHING_DETECTED, ship.label)
				end
			end)
		end
	end

	local policeId = system.faction.policeShip
	Timer:CallEvery(15, function ()
		if not Game.system or #patrol == 0 then return true end
		if target then return false end

		local ships = Space.GetBodiesNear(patrol[1], lawEnforcedRange, "Ship")
		for _, enemy in ipairs(ships) do
			if enemy.shipId ~= policeId and enemy:GetCurrentAICommand() == "CMD_KILL" then
				if not piracy then
					Comms.ImportantMessage(string.interp(l_ui_core.X_CANNOT_BE_TOLERATED_HERE, { crime = l_ui_core.PIRACY }), patrol[1].label)
					Comms.ImportantMessage(string.interp(l["RESTRICTIONS_WITHDRAWN_" .. Engine.rand:Integer(1, getNumberOfFlavours("RESTRICTIONS_WITHDRAWN"))], { ship_label = player.label }), patrol[1].label)
					piracy = true
				end
				attackShip(enemy)
				break
			end
		end
		if piracy and not target then
			Comms.ImportantMessage(string.interp(l["RESTRICTIONS_ESTABLISHED_" .. Engine.rand:Integer(1, getNumberOfFlavours("RESTRICTIONS_ESTABLISHED"))], { ship_label = player.label }), patrol[1].label)
			piracy = false
		end
	end)
end

local onLeaveSystem = function (ship)
	patrol = {}
	showMercy = true
	piracy = false
	target = nil
end


local loaded_data

local onGameStart = function ()
	if loaded_data then
		patrol = loaded_data.patrol
		showMercy = loaded_data.showMercy
		piracy = loaded_data.piracy
		target = loaded_data.target
		loaded_data = nil
	end
end

local onGameEnd = function ()
	patrol = {}
	showMercy = true
	piracy = false
	target = nil
end

local serialize = function ()
	return { patrol = patrol, showMercy = showMercy, piracy = piracy, target = target }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onShipHit", onShipHit)
Event.Register("onShipFiring", onShipFiring)
Event.Register("onJettison", onJettison)
Event.Register("onGameStart", onGameStart)
Event.Register("onGameEnd", onGameEnd)

Serializer:Register("PolicePatrol", serialize, unserialize)
