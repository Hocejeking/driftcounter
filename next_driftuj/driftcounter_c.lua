local score = 0
local screenScore = 0
local tick
local idleTime
local driftTime
local tablemultiplier = {350,1400,4200,11200}
local mult = 0.1
local multx2 = 0.105
local multx3 = 0.12
local previous = 0
local total = 0
local curAlpha = 0
local breakPoints = false
local race = null
local tandemBonus = false 
local tandemBonusNumber = 1.5

local SaveAtEndOfDrift = nil
local SaveTime = nil

local pocetVozidel = {}


local highScores = {}

ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

function formatnumber(amount)
	local formatted = amount
	while true do  
	  formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
	  if (k==0) then
		break
	  end
	end
	return formatted
end

Citizen.CreateThread( function()
	
	-- Save/Load functions -- 
	TriggerServerEvent("RequestConfig")
	
	function SaveScore()
		_,PlayerScore = StatGetInt("MP0_DRIFT_SCORE", -1)
		TriggerServerEvent("SaveScore", PlayerScore)
		SetTimeout(SaveTime, SaveScore)
	end	
		
	RegisterNetEvent("RecieveConfig")
	AddEventHandler("RecieveConfig", function(SaveAtEndOfDriftS, SaveTimeS)
		SaveAtEndOfDrift = SaveAtEndOfDriftS
		SaveTime = SaveTimeS
		if not SaveAtEndOfDrift then
			SetTimeout(SaveTime, SaveScore)
		end
	end)
	
	RegisterNetEvent("LoadScore")
	AddEventHandler("LoadScore", function(PlayerSavedScore)
		StatSetInt("MP0_DRIFT_SCORE", PlayerSavedScore, true)
		data = {score = PlayerSavedScore}
		TriggerServerEvent("SaveScore", GetPlayerServerId(PlayerId()), data)
	end)	
	
	
	local FirstTime = true
	AddEventHandler("playerSpawned", function()
		if FirstTime then
			TriggerServerEvent("LoadScoreData")
			FirstTime = false
		end
	end)

	TriggerServerEvent("RequestHighScores")
	RegisterNetEvent("RequestHighScores")
	AddEventHandler("RequestHighScores", function(scores)
		highScores = scores
	end)
	
	
	-- PREP FUNCTIONS --
	
	function round(number)
		number = tonumber(number)
		number = math.floor(number)
		
		if number < 0.01 then
			number = 0
		elseif number > 999999999 then
			number = 999999999
		end
		return number
	end
	
	function calculateBonus(previous)
		local points = previous
		local points = round(points)
		return points or 0
	end
	function math.precentage(a,b)
		return (a*100)/b
	end
	
	function angle(veh)
		if not veh then return false end
		local vx,vy,vz = table.unpack(GetEntityVelocity(veh))
		local modV = math.sqrt(vx*vx + vy*vy)
		
		
		local rx,ry,rz = table.unpack(GetEntityRotation(veh,0))
		local sn,cs = -math.sin(math.rad(rz)), math.cos(math.rad(rz))
		
		if GetEntitySpeed(veh)* 3.6 < 30 or GetVehicleCurrentGear(veh) == 0 then return 0,modV end --speed over 30 km/h
		
		local cosX = (sn*vx + cs*vy)/modV
		if cosX > 0.966 or cosX < 0 then return 0,modV end
		return math.deg(math.acos(cosX))*0.5, modV
	end
	
	function DrawHudText(text,colour,coordsx,coordsy,scalex,scaley)
		SetTextFont(9)
		SetTextProportional(7)
		SetTextScale(scalex, scaley)
		local colourr,colourg,colourb,coloura = table.unpack(colour)
		SetTextColour(colourr,colourg,colourb, coloura)
		SetTextDropshadow(0, 0, 0, 0, coloura)
		SetTextEdge(1, 0, 0, 0, coloura)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		AddTextComponentString(text)
		EndTextCommandDisplayText(coordsx,coordsy)
	end
	
	function DrawHudText1(text,colour,coordsx,coordsy,scalex,scaley)
		SetTextFont(2)
		SetTextProportional(7)
		SetTextScale(scalex, scaley)
		local colourr,colourg,colourb,coloura = table.unpack(colour)
		SetTextColour(colourr,colourg,colourb, coloura)
		SetTextDropshadow(0, 0, 0, 0, coloura)
		SetTextEdge(1, 0, 0, 0, coloura)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		AddTextComponentString(text)
		EndTextCommandDisplayText(coordsx,coordsy)
	end

	function DrawHudText2(text,colour,coordsx,coordsy,scalex,scaley)
		SetTextFont(2)
		SetTextProportional(7)
		SetTextScale(scalex, scaley)
		local colourr,colourg,colourb,coloura = table.unpack(colour)
		SetTextColour(colourr,colourg,colourb, coloura)
		SetTextDropshadow(0, 0, 0, 0, coloura)
		SetTextEdge(1, 0, 0, 0, coloura)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		AddTextComponentString(text)
		EndTextCommandDisplayText(coordsx,coordsy)
		
	end

	 
	-- END PREP FUNCTIONS --
	
	RegisterNetEvent("SetPlayerNativeMoney")
	AddEventHandler("SetPlayerNativeMoney", function(money)
		local _,pm = StatGetInt( "MP0_WALLET_BALANCE", -1)
		StatSetInt("MP0_WALLET_BALANCE", pm+money, true)
	end)

	AddEventHandler("raceFinishedGetPoints", function(result)
		breakPoints = result
	end)
	
	while true do
		Citizen.Wait(1)--NEED TESTING #################################
		PlayerPed = PlayerPedId()
		tick = GetGameTimer()
		
		if not IsPedDeadOrDying(PlayerPed, 1) and GetVehiclePedIsUsing(PlayerPed) and GetPedInVehicleSeat(GetVehiclePedIsUsing(PlayerPed), -1) == PlayerPed and IsVehicleOnAllWheels(GetVehiclePedIsUsing(PlayerPed)) and not IsPedInFlyingVehicle(PlayerPed) then
			PlayerVeh = GetVehiclePedIsIn(PlayerPed,false)
			local angle,velocity = angle(PlayerVeh)
			local tempBool = tick - (idleTime or 0) < 1850
			
			if not tempBool and score ~= 0 or breakPoints then
				
				previous = (score)
				--zde byl Hoče <3
				previous = calculateBonus(previous)
				TriggerEvent("getDriftPointsDRIFT", previous,breakPoints)
				total = total+previous
				cash = previous/24
				cash = round(cash)
				TriggerServerEvent("driftcounter:payDrift", cash )
				TriggerServerEvent("driftcounter:DriftFinished", previous)
				_,oldScore = StatGetInt("MP0_DRIFT_SCORE",-1)
				StatSetInt("MP0_DRIFT_SCORE", oldScore+previous, true)
				_,newScore = StatGetInt("MP0_DRIFT_SCORE",-1)
				local data = {score = newScore}
				TriggerServerEvent("SaveScore", GetPlayerServerId(PlayerId()), data) 
				score = 0

				breakPoints = false
			end
			if angle ~= 0 then
				if score == 0 then
					drifting = true
					driftTime = tick
				elseif score >= 50000 and score <= 149999 then
					local closePlayer, closestPlayerDistance  = ESX.Game.GetClosestPlayer()

					if IsPedSittingInAnyVehicle(PlayerPed) and closePlayer ~= -1 and closestPlayerDistance < 15.0 then

						score = score + (math.floor(angle*velocity*(GetFrameTime()*100))*multx2) * tandemBonusNumber
						tandemBonus = true 
						
						
					else 
						score = score + math.floor(angle*velocity*(GetFrameTime()*100))*multx2
						tandemBonus = false 
				
					end
				elseif score >= 150000 and score <= 699999 then

					local closePlayer, closestPlayerDistance  = ESX.Game.GetClosestPlayer()

					if IsPedSittingInAnyVehicle(PlayerPed) and closePlayer ~= -1 and closestPlayerDistance < 15.0 then

						tandemBonus = true 
						score = score + (math.floor(angle*velocity*(GetFrameTime()*100))*multx3) * tandemBonusNumber
						
					else 
						score = score + math.floor(angle*velocity*(GetFrameTime()*100))*multx3
						tandemBonus = false
				
					end
				end
				if tempBool then

					local closePlayer, closestPlayerDistance  = ESX.Game.GetClosestPlayer()

					if IsPedSittingInAnyVehicle(PlayerPed) and closePlayer ~= -1 and closestPlayerDistance < 15.0 then
						tandemBonus = true 
						score = score + (math.floor(angle*velocity*(GetFrameTime()*100))*mult) * tandemBonusNumber
						
					else 
						score = score + math.floor(angle*velocity*(GetFrameTime()*100))*mult
						tandemBonus = false
				
					end
					
				else
					score = math.floor(angle*velocity*(GetFrameTime()*100))*mult
					tandemBonus = false
				end
				screenScore = calculateBonus(score)
				idleTime = tick
			end
		end
			
			

			 
			
			
			
			
		
		if tick - (idleTime or 0) < 3000 then
			if curAlpha < 255 and curAlpha+10 < 255 then
				curAlpha = curAlpha+10
			elseif curAlpha > 255 then
				curAlpha = 255
			elseif curAlpha == 255 then
				curAlpha = 255
			elseif curAlpha == 250 then
				curAlpha = 255
			end
		else
			if curAlpha > 0 and curAlpha-10 > 0 then
				curAlpha = curAlpha-10			elseif curAlpha < 0 then
				curAlpha = 0

			elseif curAlpha == 5 then
				curAlpha = 0
			end
		end
		if not screenScore then screenScore = 0 end

		DrawHudText(string.format("<u>\n%s</u>",tostring(screenScore)), {0,255,255,curAlpha},0.48,0.0,0.7,0.7)
		DrawHudText1(string.format("Body"), {0,255,255,curAlpha},0.50,0.09,0.7,0.4)
		
		if tandemBonus == true then

			DrawHudText2(string.format("Tandem bonus"),{0,255,255,curAlpha},0.47,0.02,0.7,0.4)
			print(tandemBonusNumber)

		end

		if screenScore >= 500000 and screenScore <= 999999 then
					DrawHudText1(string.format("\tDRIFT BONUS X2 DALSI NA 1M"), {255,0,0,curAlpha},0.43,0.03,0.7,0.4)
					tandemBonusNumber = 2.0
		elseif screenScore >= 1000000 then
					DrawHudText1(string.format("\t\tDRIFT BONUS X3"), {255,0,0,curAlpha},0.43,0.03,0.7,0.4)
					tandemBonusNumber = 2.5
		end

	end
end)

RegisterNetEvent('next_Driftcounter:client:openDriftMenu')
AddEventHandler('next_Driftcounter:client:openDriftMenu', function(...)
    openDriftMenu()
end)

function openDriftMenu()
    local elements2 = {}

	if highScores[1] ~= nil then
		for i=1, #highScores, 1 do
            if i == 1 then
                table.insert(elements2, {label = "<span style='color:yellow; font-weight:900;'>"..tostring(i) .. '</span> - ' .. highScores[i].name.. " - " .. highScores[i].score.." bodů"})
            elseif i == 2 then
                table.insert(elements2, {label = "<span style='color:silver; font-weight:900;'>"..tostring(i) .. '</span> - ' .. highScores[i].name.. " - " .. highScores[i].score.." bodů"})
            elseif i == 3 then
                table.insert(elements2, {label = "<span style='color:#cd7f32; font-weight:900;'>"..tostring(i) .. '</span> - ' .. highScores[i].name.. " - " .. highScores[i].score.." bodů"})
            else
                table.insert(elements2, {label = tostring(i) .. ' - ' .. highScores[i].name.. " - " .. highScores[i].score.." bodů"})
            end
        end
    end
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'DriftMenu', {
        title    = "Skóre - Drift",
        align    = 'right',
        elements = elements2
    }, function(data, menu)
    end, function(data, menu)
        menu.close()
    end)
end

