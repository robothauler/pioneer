-- Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = require 'Engine'
local Lang = require 'Lang'
local Game = require 'Game'
local Event = require 'Event'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Equipment = require 'Equipment'
local Character = require 'Character'
local PlayerState = require 'PlayerState'

local utils = require 'utils'

local l = Lang.GetResource("module-secondhand")

-- average number of adverts per BBS and billion population
local N_equil = 0.1 -- [ads/(BBS*unit_population)]

-- inverse half life of an advert in (approximate) hours
local inv_tau = 1.0 / (4 * 24)

-- Maximum indeces for randomised messages; see data/lang/module-secondhand/en.json
-- Note: including the 0
local max_flavour_index = 5
local max_surprise_index = 2
local max_money_index = 3

local flavours = {}
for i = 0, max_flavour_index do
	table.insert(flavours, {
		adtitle = l["FLAVOUR_" .. i .. "_TITLE"],
		adtext  = l["FLAVOUR_" .. i .. "_TEXT"],
		adbody  = l["FLAVOUR_" .. i .. "_BODY"],
	})
end

local ads = {}

-- find a value in an array and return key
local onDelete = function(ref)
	ads[ref] = nil
end

-- Check if a piece of equipment can fit into the ship. Both the available space
-- and, for equipemnt which requires a slot, a free and compatible slot are
-- checked.
--
-- Returns a triple of:
--
--   ok      - whether the equipment can be installed
--
--   slot?   - if ok and the equipment requires a slot, the free slot into which
--             it can be installed
--
--   message - a message containing the reason why the equipment can't be installed
--
---@param e EquipType
---@return boolean ok
---@return Hullconfig.Slot? slot
---@return string error
local canFit = function(e)
	local equipSet = Game.player:GetComponent("EquipSet")
	local hasEnoughFreeVolume = equipSet:GetFreeVolume() >= e.volume

	if not e.slot then
		return hasEnoughFreeVolume, nil, l.EQUIPMENT_NO_SPACE
	end

	if not equipSet:HasCompatibleSlotForEquipment(e) then
		return false, nil, l.EQUIPMENT_NO_COMPATIBLE_SLOT
	end
	if not hasEnoughFreeVolume then
		return false, nil, l.EQUIPMENT_SLOT_NO_SPACE
	end
	local slot = equipSet:GetFreeSlotForEquip(e)
	return slot ~= nil, slot, l.EQUIPMENT_NO_FREE_SLOT
end

-- Check if the player can afford the equipment item for sale
local canAfford = function(ad)
	return PlayerState.GetMoney() >= ad.price
end

-- Return true if the ad should be enabled in the BBS
local isEnabled = function(ref)
	return ads[ref] ~= nil and canAfford(ads[ref]) and canFit(ads[ref].equipment)
end

local onChat = function(form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	form:SetFace(ad.character)

	local ok, slot, message_str = canFit(ad.equipment)
	if not ok then
		form:SetMessage(message_str)
		return
	end

	-- It is more performant to check the money first, but it is a better player
	-- experience to check for equipment compatibility first.
	if not canAfford(ad) then
		form:SetMessage(l["NOT_ENOUGH_MONEY_" .. Engine.rand:Integer(0, max_money_index)])
		return
	end

	if option == 0 then -- state offer
		local adbody = string.interp(flavours[ad.flavour].adbody, {
			name      = ad.character.name,
			equipment = ad.equipment:GetName(),
			price     = Format.Money(ad.price, false),
		})
		form:SetMessage(adbody)
		form:AddOption(l.HOW_DO_I_FITT_IT, 1);
	elseif option == 1 then -- "How do I fit it"?
		form:SetMessage(l.FITTING_IS_INCLUDED_IN_THE_PRICE)
		form:AddOption(l.REPEAT_OFFER, 0);
	elseif option == 2 then               --- "Buy"
		if Engine.rand:Integer(0, 99) == 0 then -- This is a one in a hundred event
			form:SetMessage(l["NO_LONGER_AVAILABLE_" .. Engine.rand:Integer(0, max_surprise_index)])
			form:RemoveAdvertOnClose()
			ads[ref] = nil
		end

		-- TEMP: clarify the size of items offered for secondhand purchase
		local equipmentName = (ad.equipment.slot and "S" .. ad.equipment.slot.size .. " " or "") ..
		ad.equipment:GetName()

		local buy_message = string.interp(l.HAS_BEEN_FITTED_TO_YOUR_SHIP, {
			equipment = equipmentName
		})

		form:SetMessage(buy_message)
		Game.player:GetComponent("EquipSet"):Install(ad.equipment, slot)
		PlayerState.AddMoney(-ad.price)
		form:RemoveAdvertOnClose()
		ads[ref] = nil

		return
	end

	form:AddOption(l.BUY, 2);
end


local postAdvert = function(station, ad)
	-- TEMP: clarify the size of items offered for secondhand purchase
	local equipmentName = (ad.equipment.slot and "S" .. ad.equipment.slot.size .. " " or "") .. ad.equipment:GetName()

	ad.desc = string.interp(flavours[ad.flavour].adtext, {
		equipment = equipmentName,
	})
	local ref = station:AddAdvert({
		title       = flavours[ad.flavour].adtitle,
		description = ad.desc,
		icon        = "second_hand",
		onChat      = onChat,
		onDelete    = onDelete,
		isEnabled   = isEnabled
	})
	ads[ref] = ad
end

local makeAdvert = function(station)
	local character = Character.New()
	local flavour = Engine.rand:Integer(1, #flavours)

	-- Get all non-cargo or engines
	local avail_equipment = {}
	for id, equip in pairs(Equipment.new) do
		-- Don't sell hyperdrives on the secondhand market
		-- Don't sell thrusters because their price depends on the thruster count
		if equip.slot and not equip.slot.type:match("^hyperdrive") and not equip.slot.type:match("^thruster") then
			if equip.purchasable then
				table.insert(avail_equipment, equip)
			end
		end
	end

	-- choose a random ship equipment
	local equipType = avail_equipment[Engine.rand:Integer(1, #avail_equipment)]

	-- make an instance of the equipment
	-- TODO: set equipment integrity/wear, etc.
	local equipment = equipType:Instance()

	-- buy back price in equipment market is 0.8, so make sure the value is higher
	local reduction = Engine.rand:Number(0.8, 0.9)

	local price = utils.round(station:GetEquipmentPrice(equipment) * reduction, 2)

	local ad = {
		character = character,
		faceseed = Engine.rand:Integer(),
		flavour = flavour,
		price = price,
		equipment = equipment,
		station = station,
	}

	postAdvert(station, ad)
end

-- Dynamics of adverts on the BBS --
------------------------------------
-- N(t) = Number of ads, lambda = decay constant:
--    d/dt N(t) = prod - lambda * N
-- and equilibrium:
--    dN/dt = 0 = prod - lambda * N_equil
-- and solution (if prod=0), with N_0 initial number:
--    N(t) = N_0 * exp(-lambda * t)
-- with tau = half life, i.e. N(tau) = 0.5*N_0 we get:
--    0.5*N_0 = N_0*exp(-lambda * tau)
-- else, with production:
--   N(t) = prod/lambda - N_0*exp(-lambda * t)
-- We want to have N_0 = N_equil, since BBS should spawn at equilibrium

local onCreateBB = function(station)
	-- instead of "for i = 1, Game.system.population do", get higher,
	-- and more consistent resolution
	local iter = 10

	-- create one ad for each unit of population with some probability
	for i = 1, iter do
		if Engine.rand:Number(0, 1) < N_equil * Game.system.population / iter then
			makeAdvert(station)
		end
	end
end

local onUpdateBB = function(station)
	local lambda = 0.693147 * inv_tau -- adv, del prob = ln(2) / tau
	local prod = N_equil * lambda  -- adv. add prob

	-- local add = 0 -- just to print statistics

	local inv_BBSnumber = 1.0 / #Game.system:GetStationPaths()

	-- remove with decay rate lambda. Call ONCE/hour for all adverts
	-- in system, thus normalize with #BBS, or we remove adverts with
	-- a probability a factor #BBS too high.
	for ref, ad in pairs(ads) do
		if Engine.rand:Number(0, 1) < lambda * inv_BBSnumber then
			ad.station:RemoveAdvert(ref)
		end
	end

	local iter = 10
	local inv_iter = 1.0 / iter

	-- spawn new adverts, call for each BBS
	for i = 1, iter do
		if Engine.rand:Number(0, 1) <= prod * Game.system.population * inv_iter then
			makeAdvert(station)
			-- add = add + 1
		end
	end

	if prod * Game.system.population * inv_iter >= 1 then
		print("Warning from Second Hand: too few ads spawning")
	end

	-- print(Game.time / (60*60*24), #utils.build_array(pairs(ads)),
	--		 Game.system.population, #Game.system:GetStationPaths(), add)
end


local loaded_data

local onGameStart = function()
	ads = {}

	if not loaded_data or not loaded_data.ads then return end

	for _, ad in pairs(loaded_data.ads) do
		postAdvert(ad.station, ad)
	end

	loaded_data = nil
end

local serialize = function()
	return { ads = ads }
end

local unserialize = function(data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)
Event.Register("onUpdateBB", onUpdateBB)

Serializer:Register("SecondHand", serialize, unserialize)
