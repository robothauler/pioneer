-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Lang = require 'Lang'
local Game = require 'Game'
local Comms = require 'Comms'
local Event = require 'Event'
local Format = require 'Format'
local PlayerState = require 'PlayerState'
local Serializer = require 'Serializer'
local Timer = require 'Timer'

local l = Lang.GetResource("module-stationrefuelling")

local minimum_fee = 1
local maximum_fee = 6

local day = 24*60*60

local due     -- when to pay the station fee
local counter -- increases when docking or undocking

local calculateFee = function ()
	local fee = math.ceil(Game.system.population * 3)
	return math.clamp(fee, minimum_fee, maximum_fee)
end

local deductStationFee = function ()
	local fee = calculateFee()
	Comms.Message("Daily station fee deducted!")
	PlayerState.AddMoney(-fee)
	due = due + day
end

local setupStationFeeTimer = function (c)
	Timer:CallEvery(day, function ()

		-- close the timer if the player has left the station
		if counter > c then return true end

		deductStationFee()
	end)
end


local onPlayerDocked = function(_, station)
	local fee = calculateFee()

	if PlayerState.GetMoney() < fee then
		if station.isGroundStation == true then
			Comms.Message(l.THIS_IS_STATION_YOU_DO_NOT_HAVE_ENOUGH_LANDING:interp({station = station.label,fee = Format.Money(fee)}))
		else
			Comms.Message(l.THIS_IS_STATION_YOU_DO_NOT_HAVE_ENOUGH_DOCKING:interp({station = station.label,fee = Format.Money(fee)}))
		end
		PlayerState.SetMoney(0)
	else
		if station.isGroundStation == true then
			Comms.Message(l.WELCOME_TO_STATION_FEE_DEDUCTED:interp({station = station.label,fee = Format.Money(fee)}))
		else
			Comms.Message(l.WELCOME_ABOARD_STATION_FEE_DEDUCTED:interp({station = station.label,fee = Format.Money(fee)}))
		end
		PlayerState.AddMoney(-fee)
	end

	due = Game.time + day
	counter = counter + 1

	local c = counter
	setupStationFeeTimer(c)
end

local onPlayerUndocked = function ()
	counter = counter + 1
end

local loaded_data

local onGameStart = function ()
	if loaded_data and loaded_data.due then
		due = loaded_data.due
		loaded_data = nil
	else
		due = Game.time + day
	end
	counter = 0

	if Game.player:GetDockedWith() then
		local c = counter
		Timer:CallAt(due, function ()
			if counter > c then return end

			deductStationFee()

			setupStationFeeTimer(c)
		end)
	end
end

local serialize = function ()
	return { due = due }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onPlayerDocked", onPlayerDocked)
Event.Register("onPlayerUndocked", onPlayerUndocked)
Event.Register("onGameStart", onGameStart)

Serializer:Register("StationRefuelling", serialize, unserialize)
