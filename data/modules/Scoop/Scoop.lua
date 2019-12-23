-- Copyright © 2008-2020 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game = require 'Game'
local Lang = require 'Lang'
local Ship = require 'Ship'
local Comms = require 'Comms'
local Event = require 'Event'
local Space = require 'Space'
local Timer = require 'Timer'
local Engine = require 'Engine'
local Format = require 'Format'
local Mission = require 'Mission'
local ShipDef = require 'ShipDef'
local Character = require 'Character'
local Equipment = require 'Equipment'
local Serializer = require 'Serializer'

local utils = require 'utils'

local InfoFace = import("ui/InfoFace")
local NavButton = import("ui/NavButton")

local l = Lang.GetResource("module-scoop")
local lc = Lang.GetResource("ui-core")

-- Get the UI class
local ui = Engine.ui

local AU = 149597870700.0
local LEGAL = 1
local ILLEGAL = 2

local mission_reputation = 1
local mission_time = 14*24*60*60
local max_dist = 30 * AU

local ads = {}
local missions = {}

local rescue_capsule = Equipment.EquipType.New({
	l10n_key = "RESCUE_CAPSULE",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = 500,
	icon_name = "Default",
	capabilities = { mass = 1, crew = 1 },
	purchasable = false
})

local rocket_launchers = Equipment.EquipType.New({
	l10n_key = "ROCKET_LAUNCHERS",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = 500,
	icon_name = "Default",
	capabilities = { mass = 1 },
	purchasable = false
})

local detonators = Equipment.EquipType.New({
	l10n_key = "DETONATORS",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = 250,
	icon_name = "Default",
	capabilities = { mass = 1 },
	purchasable = false
})

local nuclear_missile = Equipment.EquipType.New({
	l10n_key = "NUCLEAR_MISSILE",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = 1250,
	icon_name = "Default",
	model_name = "missile",
	capabilities = { mass = 1 },
	purchasable = false
})

-- Useless waste that the player has to sort out
local toxic_waste = Equipment.EquipType.New({
	l10n_key = "TOXIC_WASTE",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = -50,
	icon_name = "Default",
	capabilities = { mass = 1 },
	purchasable = false
})

local spoiled_food = Equipment.EquipType.New({
	l10n_key = "SPOILED_FOOD",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = -10,
	icon_name = "Default",
	capabilities = { mass = 1 },
	purchasable = false
})

local unknown = Equipment.EquipType.New({
	l10n_key = "UNKNOWN",
	l10n_resource = "module-scoop",
	slots = "cargo",
	price = -5,
	icon_name = "Default",
	capabilities = { mass = 1 },
	purchasable = false
})

local rescue_capsules = {
	rescue_capsule
}

local weapons = {
	rocket_launchers,
	detonators,
	nuclear_missile
}

local waste = {
	toxic_waste,
	spoiled_food,
	unknown,
	Equipment.cargo.radioactives,
	Equipment.cargo.rubbish
}

local flavours = {
	{
		id = "LEGAL_GOODS",
		cargo_type = nil,
		reward = -500,
		amount = 20,
		risk = 0,
	},
	{
		id = "ILLEGAL_GOODS",
		cargo_type = nil,
		reward = -1000,
		amount = 10,
		risk = 1,
	},
	{
		id = "RESCUE",
		cargo_type = rescue_capsules,
		reward = 1000,
		amount = 4,
		risk = 0,
		return_to_station = true,
	},
	{
		id = "ARMS_DEALER",
		cargo_type = weapons,
		reward = 750,
		amount = 1,
		risk = 0,
		deliver_to_ship = true,
	},
}

-- Sort goods, legal and illegal
local sortGoods = function (goods)
	local legal_goods = {}
	local illegal_goods = {}
	local system = Game.system

	for _, e in pairs(goods) do
		if e.purchasable and system:IsCommodityLegal(e) then
			table.insert(legal_goods, e)
		else
			table.insert(illegal_goods, e)
		end
	end

	return legal_goods, illegal_goods
end

-- Returns the number of flavours of the given string (assuming first flavour has suffix '_1').
local getNumberOfFlavours = function (str)
	local num = 1

	while l:get(str .. "_" .. num) do
		num = num + 1
	end

	return num - 1
end

-- Create a debris field in a random distance to a star
local spawnDebris = function (debris, amount, star, lifetime)
	local list = {}
	local cargo
	local min = math.max(1 * AU, star:GetSystemBody().radius * 2)
	local max = math.max(3 * AU, star:GetSystemBody().radius * 4)
	local body = Space.GetBody(star:GetSystemBody().index)

	for i = 1, Engine.rand:Integer(math.ceil(amount / 4), amount) do
		cargo = debris[Engine.rand:Integer(1, #debris)]
		body = Space.SpawnCargoNear(cargo, body, min, max, lifetime)
		table.insert(list, { cargo = cargo, body = body })
		min = 10
		max = 1000
	end

	-- add some useless waste
	for i = 1, Engine.rand:Integer(1, 9) do
		cargo = waste[Engine.rand:Integer(1, #waste)]
		body = Space.SpawnCargoNear(cargo, body, min, max, lifetime)
	end

	return list
end

-- Create a couple of police ships
local spawnPolice = function (station)
	local ship
	local police = {}
	local shipdef = ShipDef[Game.system.faction.policeShip]

	for i = 1, 2 do
		ship = Space.SpawnShipDocked(shipdef.id, station)
		ship:SetLabel(lc.POLICE)
		ship:AddEquip(Equipment.laser.pulsecannon_1mw)
		table.insert(police, ship)
		if station.type == "STARPORT_SURFACE" then
			ship:AIEnterLowOrbit(Space.GetBody(station:GetSystemBody().parent.index))
		end
	end

	Timer:CallAt(Game.time + 5, function ()
		for _, s in pairs(police) do
			s:AIKill(Game.player)
		end
	end)

	return police
end

-- Returns a random system close to the players location
local nearbySystem = function ()
	local dist = 5
	local systems = {}

	while #systems < 1 do
		systems = Game.system:GetNearbySystems(dist)
		dist = dist + 5
	end

	return systems[Engine.rand:Integer(1, #systems)].path
end

-- Create a pirate ship
local spawnPirate = function (star, pirate_label)
	local shipdefs = utils.build_array(utils.filter(
		function (k, def)
			return def.tag == "SHIP" and def.hyperdriveClass > 0 and def.equipSlotCapacity["scoop"] > 0
		end,
		pairs(ShipDef)))
	local shipdef = shipdefs[Engine.rand:Integer(1, #shipdefs)]

	local ship = Space.SpawnShipNear(shipdef.id,
		Space.GetBody(star:GetSystemBody().index),
		math.max(0.1 * AU/1000, star:GetSystemBody().radius/1000 * 2),
		math.max(0.3 * AU/1000, star:GetSystemBody().radius/1000 * 3))

	ship:SetLabel(pirate_label)
	ship:AddEquip(Equipment.hyperspace["hyperdrive_" .. shipdef.hyperdriveClass])
	ship:AddEquip(Equipment.laser.pulsecannon_2mw)
	ship:AddEquip(Equipment.misc.shield_generator)
	ship:AddEquip(Equipment.cargo.hydrogen, 10)
	ship:AddEquip(Equipment.cargo.battle_weapons)
	ship:AddEquip(Equipment.cargo.hand_weapons)
	ship:AddEquip(Equipment.cargo.narcotics)
	ship:AddEquip(Equipment.cargo.slaves)
	ship:AddEquip(Equipment.misc.cargo_scoop)

	ship:AIEnterHighOrbit(Space.GetBody(star:GetSystemBody().index))

	return ship
end

local removeMission = function (mission, ref)
	local oldReputation = Character.persistent.player.reputation
	local sender = mission.pirate and mission.pirate_label or mission.client.name

	if mission.status == "COMPLETED" then
		Character.persistent.player.reputation = oldReputation + mission_reputation
		Game.player:AddMoney(mission.reward)
		Comms.ImportantMessage(l["SUCCESS_MSG_" .. mission.id], sender)
	elseif mission.status == "FAILED" then
		Character.persistent.player.reputation = oldReputation - mission_reputation
		Comms.ImportantMessage(l["FAILURE_MSG_" .. mission.id], sender)
	end
	Event.Queue("onReputationChanged", oldReputation, Character.persistent.player.killcount,
		Character.persistent.player.reputation, Character.persistent.player.killcount)

	if ref == nil then
		for r, m in pairs(missions) do
			if m == mission then ref = r break end
		end
	end
	mission:Remove()
	missions[ref] = nil
end

-- Cargo transfer to a ship
local transferCargo = function (mission)
	Timer:CallEvery(3, function ()
		if not mission.pirate then return true end

		if Game.player:DistanceTo(mission.pirate) <= 50 then

			-- unload mission cargo
			for i, e in pairs(mission.debris) do
				if e.body == nil then
					if Game.player:RemoveEquip(e.cargo, 1, "cargo") == 1 then
						mission.pirate:AddEquip(e.cargo, 1, "cargo")
						mission.debris[i] = nil
					end
				end
			end

			if #mission.debris == 0 then
				mission.status = "COMPLETED"
			end
		end

		if mission.status == "COMPLETED" or mission.status == "FAILED" then
			local pirate = mission.pirate
			mission.pirate = nil
			removeMission(mission)
			pirate:HyperjumpTo(nearbySystem())
		end
	end)
end

local isQualifiedFor = function(reputation, ad)
	return reputation > (ad.reward/100) or false
end

local onDelete = function (ref)
	ads[ref] = nil
end

local isEnabled = function (ref)
	return ads[ref] ~= nil and isQualifiedFor(Character.persistent.player.reputation, ads[ref])
end

local onChat = function (form, ref, option)
	local ad = ads[ref]
	local player = Game.player
	local debris, ship

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	local qualified = isQualifiedFor(Character.persistent.player.reputation, ad)

	form:SetFace(ad.client)

	if not qualified then
		form:SetMessage(l["DENY_" .. Engine.rand:Integer(1, getNumberOfFlavours("DENY"))])
		return
	end

	if option == 0 then
		local introtext = string.interp(ad.introtext, {
			client = ad.client.name,
			shipid = ad.pirate_label,
			star   = ad.star:GetSystemBody().name,
			cash   = Format.Money(math.abs(ad.reward), false),
		})
		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(l["WHY_NOT_YOURSELF_" .. ad.id])

	elseif option == 2 then
		form:SetMessage(string.interp(l["HOW_MUCH_TIME_" .. ad.id], { star = ad.star:GetSystemBody().name, date = Format.Date(ad.due) }))

	elseif option == 3 then
		if ad.reward > 0 and player:CountEquip(Equipment.misc.cargo_scoop) == 0 and player:CountEquip(Equipment.misc.multi_scoop) == 0 then
			form:SetMessage(l.YOU_DO_NOT_HAVE_A_SCOOP)
			return
		end

		if ad.reward < 0 and player:GetMoney() < math.abs(ad.reward) then
			form:SetMessage(l.YOU_DO_NOT_HAVE_ENOUGH_MONEY)
			return
		end

		form:RemoveAdvertOnClose()
		ads[ref] = nil

		debris = spawnDebris(ad.debris_type, ad.amount, ad.star, ad.due - Game.time)

		if ad.reward < 0 then player:AddMoney(ad.reward) end
		if ad.deliver_to_ship then
			ship = spawnPirate(ad.star, ad.pirate_label)
		end

		local mission = {
			type              = "Scoop",
			location          = ad.location,
			introtext         = ad.introtext,
			client            = ad.client,
			star              = ad.star,
			id                = ad.id,
			debris            = debris,
			reward            = ad.reward,
			risk              = ad.risk,
			due               = ad.due,
			return_to_station = ad.return_to_station,
			deliver_to_ship   = ad.deliver_to_ship,
			pirate            = ship,
			pirate_label      = ad.pirate_label,
			destination       = debris[1].body
		}

		table.insert(missions, Mission.New(mission))
		form:SetMessage(l["ACCEPTED_" .. ad.id])
		return
	end

	form:AddOption(l.WHY_NOT_YOURSELF, 1)
	form:AddOption(l.HOW_MUCH_TIME, 2)
	form:AddOption(l.REPEAT_THE_REQUEST, 0)
	form:AddOption(l.OK_AGREED, 3)
end

local makeAdvert = function (station)
	local stars = Game.system:GetStars()
	local star = stars[Engine.rand:Integer(1, #stars)]
	local dist = station:DistanceTo(Space.GetBody(star.path:GetSystemBody().index))
	local flavour = flavours[Engine.rand:Integer(1, #flavours)]
	local due = Game.time + mission_time + dist / AU * 24*60*60 * Engine.rand:Number(0.9, 1.1)
	local debris_type, reward

	if flavours[LEGAL].cargo_type == nil then
		flavours[LEGAL].cargo_type, flavours[ILLEGAL].cargo_type = sortGoods(Equipment.cargo)
	end
	debris_type = flavour.cargo_type

	if flavour.reward < 0 then
		reward = flavour.reward * (1 - dist / AU / 10) * Engine.rand:Number(0.9, 1.1)
	else
		reward = flavour.reward * (1 + dist / AU / 10) * Engine.rand:Number(0.9, 1.1)
	end

	if #debris_type > 0 and dist < max_dist then
		local ad = {
			station           = station,
			location          = station.path,
			introtext         = l["INTROTEXT_" .. flavour.id],
			client            = Character.New(),
			star              = star.path,
			id                = flavour.id,
			debris_type       = debris_type,
			reward            = math.ceil(reward),
			amount            = flavour.amount,
			risk              = flavour.risk,
			due               = due,
			return_to_station = flavour.return_to_station,
			deliver_to_ship   = flavour.deliver_to_ship,
			pirate_label      = flavour.deliver_to_ship and Ship.MakeRandomLabel() or nil
		}

		ad.desc = string.interp(l["ADTEXT_" .. flavour.id], { cash = Format.Money(ad.reward, false) })

		local ref = station:AddAdvert({
			description = ad.desc,
			icon        = flavour.id == "RESCUE" and "searchrescue" or "haul",
			onChat      = onChat,
			onDelete    = onDelete,
			isEnabled   = isEnabled
		})
		ads[ref] = ad
	end
end

local onCreateBB = function (station)
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population * Game.system.lawlessness))
	for i = 1, num do
		makeAdvert(station)
	end
end

local onUpdateBB = function (station)
	for ref, ad in pairs(ads) do
		if ad.due < Game.time + 5*24*60*60 then -- five day timeout
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(4*24*60*60) < 60*60 then -- roughly once every four days
		makeAdvert(station)
	end
end

local onShipEquipmentChanged = function (ship, equipment)
	if not ship:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		if not mission.police and not Game.system:IsCommodityLegal(equipment) and mission.location:IsSameSystem(Game.system.path) then
			if (1 - Game.system.lawlessness) > Engine.rand:Number(4) then
				mission.police = spawnPolice(Space.GetBody(mission.location.bodyIndex))
			end
		end
	end
end

-- The attacker could be a ship or the star
-- If scooped or destroyed by self-destruction, attacker is nil
local onCargoDestroyed = function (body, attacker)
	for ref, mission in pairs(missions) do
		for i, e in pairs(mission.debris) do
			if body == e.body then
				e.body = nil
				if body == mission.destination then
					-- remove NavButton
					mission.destination = nil
				end
				if attacker and (mission.return_to_station or mission.deliver_to_ship) then
					mission.status = "FAILED"
				end
				if mission.destination == nil then
					for i, e in pairs(mission.debris) do
						if e.body ~= nil then
							-- set next target
							mission.destination = e.body
							break
						end
					end
				end
				break
			end
		end
	end
end

local onShipHit = function (ship, attacker)
	if ship:IsPlayer() then return end
	if attacker == nil or not attacker:isa('Ship') then return end

	for ref, mission in pairs(missions) do
		if mission.police then
			for _, s in pairs(mission.police) do
				if s == ship then
					ship:AIKill(attacker)
					break
				end
			end
		elseif mission.pirate == ship then
			ship:AIKill(attacker)
			break
		end
	end
end

local onShipDestroyed = function (ship, attacker)
	if ship:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		if mission.police then
			for i, s in pairs(mission.police) do
				if s == ship then
					table.remove(mission.police, i)
					break
				end
			end
		elseif mission.pirate == ship then
			mission.pirate = nil
			local msg = string.interp(l.SHIP_DESTROYED, {
				shipid  = mission.pirate_label,
				station = mission.location:GetSystemBody().name
			})
			Comms.ImportantMessage(msg, mission.client.name)
			break
		end
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		if mission.police then
			for _, s in pairs(mission.police) do
				if station.type == "STARPORT_SURFACE" then
					s:AIEnterLowOrbit(Space.GetBody(station:GetSystemBody().parent.index))
				else
					s:AIFlyTo(station)
				end
			end
		end

		if mission.return_to_station or mission.deliver_to_ship and not mission.pirate and mission.location == station.path then

			-- unload mission cargo
			for i, e in pairs(mission.debris) do
				if e.body == nil then
					if player:RemoveEquip(e.cargo, 1, "cargo") == 1 then
						mission.debris[i] = nil
					end
				end
			end
			if #mission.debris == 0 then mission.status = "COMPLETED" end

			if mission.status == "COMPLETED" or mission.status == "FAILED" then
				removeMission(mission, ref)
			end

		-- remove stale missions, if any
		elseif mission.deliver_to_ship and Game.time > mission.due then
			mission.status = "FAILED"
			removeMission(mission, ref)

		elseif mission.reward < 0 and Game.time > mission.due then
			mission:Remove()
			missions[ref] = nil
		end
	end
end

local onShipUndocked = function (player, station)
	if not player:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		if mission.police then
			for _, s in pairs(mission.police) do
				s:AIKill(player)
			end
		end

		if mission.deliver_to_ship and not mission.in_progess then
			mission.in_progress = true
			transferCargo(mission)
		end
	end
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() or Game.system.population == 0 then return end

	local stars = Game.system:GetStars()
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population * Game.system.lawlessness))

	flavours[LEGAL].cargo_type, flavours[ILLEGAL].cargo_type = sortGoods(Equipment.cargo)

	-- spawn random cargo (legal or illegal goods)
	for i = 1, num do
		local star = stars[Engine.rand:Integer(1, #stars)]
		local flavour = flavours[Engine.rand:Integer(1, 2)]
		local debris = flavour.cargo_type
		if #debris > 0 then
			spawnDebris(debris, flavour.amount, star.path, mission_time)
		end
	end
end

local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
		for ref, mission in pairs(missions) do
			mission.destination = nil
			mission.police = nil
			mission.pirate = nil
			for i, e in pairs(mission.debris) do
				e.body = nil
			end
		end
		flavours[LEGAL].cargo_type = nil
		flavours[ILLEGAL].cargo_type = nil
	end
end

local onReputationChanged = function (oldRep, oldKills, newRep, newKills)
	for ref, ad in pairs(ads) do
		local oldQualified = isQualifiedFor(oldRep, ad)
		if isQualifiedFor(newRep, ad) ~= oldQualified then
			Event.Queue("onAdvertChanged", ad.station, ref);
		end
	end
end

local onClick = function (mission)
	return ui:Grid(2,1)
		:SetColumn(0, {
			ui:VBox():PackEnd({
				ui:MultiLineText(
					mission.introtext:interp({
						client = mission.client.name,
						shipid = mission.pirate_label,
						star = mission.star:GetSystemBody().name,
						cash = Format.Money(math.abs(mission.reward), false)
					})
				),
				ui:Margin(5),
				mission.destination and NavButton.New(l.SET_AS_TARGET, mission.destination) or ui:Margin(0),
				ui:Margin(5),
				mission.pirate and ui:Grid(2,1)
					:SetColumn(0, {
						ui:VBox():PackEnd({
							ui:Label(l.SHIP)
						})
					})
					:SetColumn(1, {
						ui:VBox():PackEnd({
							ui:Label(mission.pirate.label)
						})
					})
				or ui:Margin(0),
				mission.pirate and NavButton.New(l.SET_AS_TARGET, mission.pirate) or ui:Margin(0),
				ui:Margin(5),
				ui:Grid(2,1)
					:SetColumn(0, {
						ui:VBox():PackEnd({
							ui:Label(l.CLIENT)
						})
					})
					:SetColumn(1, {
						ui:VBox():PackEnd({
							ui:Label(mission.client.name)
						})
					}),
				ui:Grid(2,1)
					:SetColumn(0, {
						ui:VBox():PackEnd({
							ui:Label(l.SPACEPORT)
						})
					})
					:SetColumn(1, {
						ui:VBox():PackEnd({
							ui:Label(mission.location:GetSystemBody().name)
						})
					}),
				ui:Grid(2,1)
					:SetColumn(0, {
						ui:VBox():PackEnd({
							ui:Label(l.DEADLINE)
						})
					})
					:SetColumn(1, {
						ui:VBox():PackEnd({
							ui:Label(Format.Date(mission.due))
						})
					}),
			})
		})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
end

local loaded_data

local onGameStart = function ()
	ads = {}
	missions = {}

	if loaded_data and loaded_data.ads then

		for k, ad in pairs(loaded_data.ads) do
			local ref = ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.id == "RESCUE" and "searchrescue" or "haul",
				onChat      = onChat,
				onDelete    = onDelete,
				isEnabled   = isEnabled
			})
			ads[ref] = ad
		end

		missions = loaded_data.missions

		loaded_data = nil

		for ref, mission in pairs(missions) do
			if mission.deliver_to_ship then
				mission.in_progress = true
				transferCargo(mission)
			end
		end
	end
end

local onGameEnd = function ()
	flavours[LEGAL].cargo_type = nil
	flavours[ILLEGAL].cargo_type = nil
end

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onShipEquipmentChanged", onShipEquipmentChanged)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onShipUndocked", onShipUndocked)
Event.Register("onShipHit", onShipHit)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onCargoDestroyed", onCargoDestroyed)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onGameStart", onGameStart)
Event.Register("onGameEnd", onGameEnd)
Event.Register("onReputationChanged", onReputationChanged)

Mission.RegisterType("Scoop", l.SCOOP, onClick)

Serializer:Register("Scoop", serialize, unserialize)

