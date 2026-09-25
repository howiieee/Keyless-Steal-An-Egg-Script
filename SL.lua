local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure HTTP Requests are enabled in Game Settings -> Security
local towerRemote = ReplicatedStorage:WaitForChild("TowerEntered")

-- Replace this with your own secure logging API or webhook URL
local LOGGING_URL = "https://your-custom-logging-server.com/api/logs"

towerRemote.OnServerEvent:Connect(function(player, action)
    -- 1. Format the data you want to extract
    local logData = {
        playerName = player.Name,
        userId = player.UserId,
        remoteFired = "TowerEntered",
        actionData = action,
        timestamp = os.time()
    }

    -- 2. Convert the Lua table to a JSON string
    local jsonData = HttpService:JSONEncode(logData)

    -- 3. Send the POST request to your external server
    -- Wrapped in a pcall (protected call) so it doesn't break the script if the external server is down
    local success, errorMessage = pcall(function()
        HttpService:PostAsync(LOGGING_URL, jsonData, Enum.HttpContentType.ApplicationJson)
    end)

    if success then
        print("Successfully exported remote log for " .. player.Name)
    else
        warn("Failed to export log: " .. errorMessage)
    end
end)
