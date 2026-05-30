-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game = require 'Game'
local Event = require 'Event'
local Comms = require 'Comms'
local Engine = require 'Engine'
local Lang = require 'Lang'

local l = Lang.GetResource("module-chatter")

local CommodityType = require 'CommodityType'

local timestamp

local escape_pod = CommodityType.RegisterCommodity("escape_pod", {
	l10n_key = "ESCAPE_POD",
	l10n_resource = "module-chatter",
	price = 500,
	icon_name = "Default",
	model_name = "escape_pod",
	mass = 1,
	purchasable = false
})

local setTimestamp = function ()
	timestamp = Game.time + 90
end

local resetTimestamp = function ()
	timestamp = 0
end

local getNumberOfFlavours = function (str)
	local num = 1

	while l:get(str .. "_" .. num) do
		num = num + 1
	end
	return num - 1
end

local saySomething = function (ship)
	if ship == nil or not ship:isa('Ship') or ship:IsPlayer() then return end

	if Game.time > timestamp and Engine.rand:Number(1) > 0.75 and Game.player:DistanceTo(ship) < 1.5e9 then
		return true
	end
end

local onShipFiring = function (ship)
	if saySomething(ship) then
		setTimestamp()
		Comms.ImportantMessage(l["OPPONENT_TAUNT_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_TAUNT"))], ship.label)
	end
end

local onShipHit = function (ship, attacker)
	if attacker == nil then return end

	if saySomething(ship) then
		setTimestamp()
		if ship:GetHullPercent() < 100.0 then
			Comms.ImportantMessage(l["OPPONENT_GRIPE_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_GRIPE"))], ship.label)
		elseif ship:GetCurrentAICommand() ~= 'CMD_KILL' then
			Comms.ImportantMessage(l["OPPONENT_WARNING_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_WARNING"))], ship.label)
		end
	end
end

local onShipDestroyed = function (ship, attacker)
	ship:SpawnCargo(escape_pod, 60*60*24*7, Engine.rand:Integer(1, ship.maxCrew))
	if saySomething(ship) then
		Comms.ImportantMessage(l["OPPONENT_LASTWORDS_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_LASTWORDS"))], ship.label)
	elseif saySomething(attacker) then
		Comms.ImportantMessage(l["OPPONENT_DESTROYED_" .. Engine.rand:Integer(1, getNumberOfFlavours("OPPONENT_DESTROYED"))], attacker.label)
	end
end

Event.Register("onShipFiring", onShipFiring)
Event.Register("onShipHit", onShipHit)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onGameStart", resetTimestamp)
