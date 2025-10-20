local Lib = getgenv().hgLib
if not Lib then
	warn("! Huge Games Not Loaded !")
	return
end
local clientPlot = require(game:GetService("ReplicatedStorage").Library.Client.PlotCmds.ClientPlot)
local hPillarItems = require(game.ReplicatedStorage.Library.Directory.HPillarItems)

local myPlot = nil
function Plot()
	if not myPlot then myPlot = clientPlot.GetByPlayer(game.Players.LocalPlayer) end;return myPlot
end

function getPayoutPerSecond(Id, pt)
	local item = hPillarItems[Id]
	if not item then return 0 end
	local payout = item.BaseMoneyPerSecond
	if not payout then return 0 end

	if pt == 1 then payout = payout * 2 end
	if pt == 2 then payout = payout * 4 end
	return payout
end

local Slots = {
	Empty = function()
		for i = 1,10 do
			local Pillar = Plot().SaveVariables["Pillar_"..tostring(i)]
			if not Pillar then return i end
		end
	end,
	Lowest = function()
		local lowest, lowestam = 0, math.huge
		for i = 1,10 do
			local Pillar = Plot().SaveVariables["Pillar_"..tostring(i)]
			if Pillar and Pillar.Data and Pillar.Class~="EggHalloween" then
				local Payout = getPayoutPerSecond(Pillar.Data.id, Pillar.Data.pt or 0)
				if Payout < lowestam then
					lowestam = Payout
					lowest = i
				end
			end
		end
		if lowest>0 then
			return lowest, lowestam
		end		
	end,
};Slots.Get = function()
	local empty = Slots.Empty()
	if empty then return empty end
	local lowest, lowestam = Slots.Lowest()
	if lowest then return lowest end
end

function EquipBest()
	local highestid, highestpayout = "", 0
	table.foreach(Lib.Save.Get().Inventory.HPillar, function(Id, Data)
		local Payout = getPayoutPerSecond(Data.id, Data.pt or 0)
		if Payout > highestpayout then
			highestpayout = Payout
			highestid = Id
		end
	end)
	if highestid == "" then return end

	local empty = Slots.Empty()
	if empty then
		Lib.Network.Invoke("HalloweenWorld_PlacePet", empty, highestid)
		return
	end

	local lowest, lowestam = Slots.Lowest()
	if highestpayout > lowestam then
		Lib.Network.Invoke("HalloweenWorld_Claim", lowest)
		Lib.Network.Invoke("HalloweenWorld_PickUp", lowest)
		Lib.Network.Invoke("HalloweenWorld_PlacePet", lowest, highestid)
		return
	end
end


local lastClaim = tick()
function claimAllSlots()
	if not (tick() > lastClaim + 1) then return end
	for i = 1,10 do
		local Pillar = Plot().SaveVariables["Pillar_"..tostring(i)]
		if Pillar and Pillar.Data and Pillar.Class~="EggHalloween" then
			game:GetService("ReplicatedStorage").Network.HalloweenWorld_Claim:InvokeServer(i)
		end
	end
	lastClaim = tick()
end


function findEgg()
	local e = Lib.Save.Get().Inventory.EggHalloween
	for _,v in pairs(e) do
		if v.id then
			return v.id
		end
	end
end

function mainLoop()
	local Egg = findEgg()
	if Egg then
		local Slot, isempty = Slots.Empty()
		if Slot then
			if not isempty then
				Lib.Network.Invoke("HalloweenWorld_Claim", Slot)
				Lib.Network.Invoke("HalloweenWorld_PickUp", Slot)
			end
			Lib.Network.Invoke("HalloweenWorld_PlaceEgg", Slot, Egg)
		end
	else
		if getgenv().HalloweenConfig.EquipBest then setHighestItems() end
		if getgenv().HalloweenConfig.ClaimMoney then claimAllSlots() end
	end
end


local HalloweenEventLoop = game.HttpService:GenerateGUID(false)
getgenv().HalloweenEventLoop = HalloweenEventLoop

repeat task.wait()
	pcall(mainLoop)
until getgenv().HalloweenEventLoop~=HalloweenEventLoop
