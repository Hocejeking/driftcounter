ESX = nil 
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
local UseGlobalScore = GetConvar("DriftC_useGlobalScore", "true") -- Allow user to have the same score as the one they had on another server
local usePayout = GetConvar("DriftC_usePayout", "true") -- wether or not to pay out drifts.
local useFramework = GetConvar("DriftC_useFramework", "ES") -- either 'ES' or 'Native', anyone who reads this, please add VRP support since i cannot be bothered working with that sad excuse of an API.

local SaveAtEndOfDrift = GetConvar("DriftC_SaveAtEndOfDrift", "true") -- Set to false if you only want to save every `x` ms
local SaveTime = GetConvar("DriftC_SaveTime", 60000) -- How often you want to save if SaveAtEndOfDrift is false (In ms!)

if UseGlobalScore == "true" then UseGlobalScore = true else UseGlobalScore = false end
if usePayout == "true" then usePayout = true else usePayout = false end
if SaveAtEndOfDrift == "true" then SaveAtEndOfDrift = true else SaveAtEndOfDrift = false end

Citizen.CreateThread(function()
    RegisterServerEvent("driftcounter:payDrift")
    AddEventHandler('driftcounter:payDrift', function(money)
        local xPlayer = ESX.GetPlayerFromId(source)
		
        xPlayer.addMoney(money)
    end)
end)

RegisterServerEvent('driftcounter:DriftFinished')
AddEventHandler('driftcounter:DriftFinished', function(previous)

    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchScalar('SELECT score FROM users WHERE identifier = @identifier ', {['@identifier'] = xPlayer.identifier}, function(oldScore)
        if previous > oldScore then
            MySQL.Async.execute('UPDATE users SET score = @score WHERE identifier = @identifier', {['@score'] = previous, ['@identifier'] = xPlayer.identifier})
        end
    end)
end)

local highScores = {}
Citizen.CreateThread(function()
	while true do
			
		MySQL.Async.fetchAll('SELECT * FROM users ORDER BY score DESC LIMIT 10', {['@race'] = race}, function(scores)
			highScores = {}
			for i=1, #scores, 1 do
				if scores[i].jmeno == "" then
					table.insert(highScores, {
						name = "Neznámý uživatel",
						score = scores[i].score,
					})
				elseif scores[i].jmeno == " " then
					table.insert(highScores, {
						name = "Neznámý uživatel",
						score = scores[i].score,
					})
				else
					table.insert(highScores, {
						name = scores[i].jmeno,
						score = scores[i].score,
					})
				end
			end
			TriggerClientEvent("RequestHighScores", -1, highScores)
    	end)
		Wait(60000)
	end
end)

RegisterServerEvent('RequestHighScores')
AddEventHandler('RequestHighScores', function()
	TriggerClientEvent("RequestHighScores", source, highScores)
end)
