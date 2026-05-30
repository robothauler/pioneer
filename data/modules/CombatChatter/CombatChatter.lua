-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game = require 'Game'
local Event = require 'Event'
local Comms = require 'Comms'
local Engine = require 'Engine'
local Lang = require 'Lang'

local l = Lang.GetResource("module-combatchatter")

local CommodityType = require 'CommodityType'

local timestamp

local escape_pod = CommodityType.RegisterCommodity("escape_pod", {
	l10n_key = "ESCAPE_POD",
	l10n_resource = "module-combatchatter",
	price = 500,
	icon_name = "Default",
	model_name = "escape_pod",
	mass = 1,
	purchasable = false
})

local getNumberOfFlavours = function (str)
	local num = 1

	while l:get(str .. "_" .. num) do
		num = num + 1
	end
	return num - 1
end

local saySomething = function (ship, silence, probability)
	if ship == nil or not ship:isa('Ship') or ship:IsPlayer() then return end

	if Game.player:DistanceTo(ship) < 1e6 then
		if Game.time > timestamp + silence then
			timestamp = Game.time
			if Engine.rand:Number(1) < probability then
				return true
			end
		end
	end
end

local onShipFiring = function (ship)
	if saySomething(ship, Engine.rand:Integer(15, 30), 0.2) then
		Comms.ImportantMessage(l["OPPONENT_TAUNT_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_TAUNT"))], ship.label)
	end
end

local onShipHit = function (ship, attacker)
	if attacker == nil then return end

	if saySomething(ship, Engine.rand:Integer(15, 30), 0.3) then
		if ship:GetCurrentAICommand() ~= 'CMD_KILL' then
			Comms.ImportantMessage(l["OPPONENT_WARNING_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_WARNING"))], ship.label)
		elseif ship:GetHullPercent() < 100.0 then
			Comms.ImportantMessage(l["OPPONENT_GRIPE_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_GRIPE"))], ship.label)
		end
	end
end

local onShipDestroyed = function (ship, attacker)
	if saySomething(ship, Engine.rand:Integer(15, 30), 0.5) then
		Comms.ImportantMessage(l["OPPONENT_LASTWORDS_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_LASTWORDS"))], ship.label)
	end

	if saySomething(attacker, 0, 1) then -- Very rare. So it's worth noting!
		Comms.ImportantMessage(l["OPPONENT_DESTROYED_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_DESTROYED"))], attacker.label)
	end

	if ship and ship:isa('Ship') and not ship:IsPlayer() then
		ship:SpawnCargo(escape_pod, 60*60*24*7, Engine.rand:Integer(1, ship.maxCrew))
		print("Escape Pods spawned")
	end
end

local onGameStart = function ()
	timestamp = 0
end

Event.Register("onShipFiring", onShipFiring)
Event.Register("onShipHit", onShipHit)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onGameStart", onGameStart)
