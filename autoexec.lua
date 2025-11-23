


local function copytable(tbl)
    local copy = {}
    for i, v in pairs(tbl) do
        copy[i] = v
    end
    return copy
end 
local sandbox_env = copytable(getfenv())
setmetatable(sandbox_env,{
    __index = function(self, i)
        if rawget(sandbox_env, i) then
            return rawget(sandbox_env, i)
        elseif getfenv()[i] then
            return getfenv()[i]
        end
    end
})
sandbox_env.game = nil
setfenv(loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")), sandbox_env)()
getgenv().infyield = sandbox_env
print("iy loaded")

local loggingEnabled = false 
FunctionTiming = {}

function logFunctionExecution(functionName, elapsedTime)
    if not loggingEnabled then return end
    if not FunctionTiming[functionName] then
        FunctionTiming[functionName] = { Count = 0, TotalTime = 0 }
    end
    FunctionTiming[functionName].Count = FunctionTiming[functionName].Count + 1
    FunctionTiming[functionName].TotalTime = FunctionTiming[functionName].TotalTime + elapsedTime
end

function printFunctionLogs()
    for name, data in pairs(FunctionTiming) do
        local avgTime = data.TotalTime / data.Count
        print(string.format("%s: Called %d times, Average Time: %.4f seconds", name, data.Count, avgTime))
    end
end

HttpService = game:GetService("HttpService")
SaveFilename = "whitelistBlacklist.json"

function readDataFile()
    if readfile and isfile and isfile(SaveFilename) then
        local contents = readfile(SaveFilename)
        local success, data = pcall(function()
            return HttpService:JSONDecode(contents)
        end)
        if success and type(data) == "table" then
            return data
        end
    end
    return {}
end

function writeDataFile(t)
    if writefile then
        local jsonStr = HttpService:JSONEncode(t)
        writefile(SaveFilename, jsonStr)
    end
end

local returnToTrashcanEnabled = false
local trashcanConnection
local trashcanHeartbeatStart, trashcanHeartbeatEnd

function disableTrashcanReturn()
    returnToTrashcanEnabled = false
    if trashcanConnection then
        trashcanConnection:Disconnect()
        trashcanConnection = nil
    end
end

function setAllTrashCansCollide(isCollidable)
    local map = workspace:FindFirstChild("Map")
    if not map then return end
    local trashFolder = map:FindFirstChild("Trash")
    if not trashFolder then return end

    for _, obj in pairs(trashFolder:GetChildren()) do
        if obj.Name == "Trashcan" and obj:GetAttribute("Broken") ~= true then
            local nestedCan = obj:FindFirstChild("Trashcan")
            if nestedCan and nestedCan:IsA("BasePart") then
                nestedCan.CanCollide = isCollidable
            end
        end
    end
end

autoTrashGrabEnabled = false

function onTrashAnimationPlayed(animationTrack)
    local anim = animationTrack.Animation
    if not anim or not anim:IsA("Animation") or not anim.AnimationId then
        return  -- Safely exit; do nothing if the track has no valid Animation/AnimationId
    end

    -- Now you can safely compare anim.AnimationId:
    if anim.AnimationId == trashcanPickupAnimId then
        setAllTrashCansCollide(true)
        disableTrashcanReturn()
        print("Auto Trash Grab DISABLED due to animation")
    end
end

-- Services
Players = game:GetService("Players")
RunService = game:GetService("RunService")
MarketplaceService = game:GetService("MarketplaceService")
UserInputService = game:GetService("UserInputService")

-- Variables
player = Players.LocalPlayer
if not player then
    warn("LocalPlayer not found. Ensure this script is a LocalScript.")
    return
end

-- CHANGED: Moved aimAssistEnabled to top and track user toggling.
local aimAssistEnabled = true
local userAimAssistToggledOff = false -- Tracks if user toggled off aim assist via Fluent

-- Gravity and Density Changer Variables and Defaults
enableGravityChanger = true
increasedGravityValue = 350
originalGravity = workspace.Gravity
increasedDensityValue = 7
qResetTime = 1

isSpecificAnimationPlaying = false

originalProperties = {}

function saveOriginalProperties(part)
    if part:IsA("BasePart") then
        originalProperties[part] = part.CustomPhysicalProperties or part:GetMass()
    end
end

function increaseMass(part)
    if part:IsA("BasePart") then
        local customProperties = PhysicalProperties.new(increasedDensityValue, 0.5, 0.5, 0.5, 0.5)
        part.CustomPhysicalProperties = customProperties
    end
end

function resetMass(part)
    if part:IsA("BasePart") and originalProperties[part] then
        if typeof(originalProperties[part]) == "PhysicalProperties" then
            part.CustomPhysicalProperties = originalProperties[part]
        else
            part.CustomPhysicalProperties = PhysicalProperties.new(originalProperties[part] / part.Size.Magnitude, 0.5, 0.5, 0.5, 0.5)
        end
    end
end

function applyIncreasedMass(character)
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            increaseMass(part)
        end
    end
end

function resetCharacterMass(character)
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            resetMass(part)
        end
    end
end

-- Table to track spawn times for each player
local spawnTimes = {}

function handlePlayerSpawn(plr)
    -- If the player's character attribute equals "Bald", do not set spawn protection.
    if plr:GetAttribute("Character") == "Bald" then
        print("Spawn protection skipped for Bald player:", plr.Name)
        return
    end
    -- Prevent stacking: if already present, do not re-add
    if spawnTimes[plr.UserId] then return end

    spawnTimes[plr.UserId] = tick() -- Using tick() for game time
    print("Spawn protection activated for player:", plr.Name)

    task.delay(4, function()
        spawnTimes[plr.UserId] = nil
        print("Spawn protection removed for player:", plr.Name)
    end)
end

function setupPlayerSpawnProtection(targetPlayer)
    targetPlayer.CharacterAdded:Connect(function(character)
        handlePlayerSpawn(targetPlayer)
    end)

    if targetPlayer.Character then
        handlePlayerSpawn(targetPlayer)
    end
end
-- Set up spawn protection for all existing players except the local player
for _, otherPlayer in ipairs(Players:GetPlayers()) do
    if otherPlayer ~= player then
        setupPlayerSpawnProtection(otherPlayer)
    end
end

-- Connect to new players joining the game
Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= player then
        setupPlayerSpawnProtection(newPlayer)
    end
end)

function isultedactiveforothers(checkPlayer)
    local liveFolder = workspace:FindFirstChild("Live")
    if liveFolder then
        local playerFolder = liveFolder:FindFirstChild(checkPlayer.Name)
        if playerFolder and playerFolder:GetAttribute("Ulted") then
            return true
        end
    end
    return false
end

-- Function to get the player's Character attribute from the Live folder
local function getPlayerCharacterAttribute()
    local liveFolder = workspace:FindFirstChild("Live")
    if liveFolder then
        local playerFolder = liveFolder:FindFirstChild(player.Name)
        if playerFolder then
            return playerFolder:GetAttribute("Character")
        end
    end
    return nil
end

local isTeleportAnimationActive = false

-- Constants
BASEPLATE_SIZE = Vector3.new(2048, 4, 2048) -- Size of the baseplate
BASEPLATE_Y_DEFAULT = -496 -- Default Y position of the baseplate
BASEPLATE_Y_TELEPORT = -501 -- Y position during teleport to baseplate
TELEPORT_ANIMATION_ID = "rbxassetid://11343250001" -- Animation ID to trigger teleport
SECONDARY_ANIMATION_ID = "rbxassetid://11343318134" -- Secondary Animation ID
REPLACEMENT_ANIMATION_ID = "rbxassetid://18231574269" -- Replacement Animation ID

TELEPORT_HEIGHT_OFFSET = 4.25 -- Height above baseplate when teleporting 
MAX_TELEPORT_DURATION = 5 -- Maximum duration for teleport loop in seconds
BACK_TELEPORT_RADIUS = 50 -- Radius to detect nearby players

-- Detection Intervals (Set to 0 for immediate detection per frame)
NORMAL_DETECTION_INTERVAL = 0 -- Fast detection interval in seconds
TELEPORT_DETECTION_INTERVAL = 0.1

-- Constants
TOGGLE_KEY = Enum.KeyCode.C -- Key to toggle the animation lock
LOCK_ANIMATION_ID = "rbxassetid://18231574269" -- The specific animation to play when locked

-- Omni Constants
OMNI_ANIMATION_ID = "rbxassetid://13927612951" -- Omni Animation ID
REPLACEMENT_OMNI_ANIMATION_ID = "rbxassetid://18231574269" -- Replacement Omni Animation ID
TOOL_PLAY_DURATION = 2 -- Duration in seconds for Omni Tool animation
EQUIPPED_TOOL_NAME = "OmniTool" -- Name of the Omni Tool
isOmniToolEquipped = false
isPlayingOmniAnimViaTool = false -- Tracks if OmniAnim is being played via the tool

-- Additional Animation Constants
TABLE_FLIP_ANIMATION_ID = "rbxassetid://11365563255" -- Table Flip Animation ID
REPLACEMENT_TABLE_FLIP_ANIMATION_ID = "rbxassetid://18231574269" -- Replacement Animation ID for Table Flip

-- FixCam Animation
FIXCAM_ANIMATION_ID = "rbxassetid://12983333733" -- FixCam Animation ID

-- Variables
animationsLocked = false -- Tracks whether the animation lock mode is active
lockAnimation = Instance.new("Animation")
lockAnimation.AnimationId = LOCK_ANIMATION_ID
lockAnimationTrack = nil -- Reference to the currently playing lock animation

-- Clone variables
cloneCharacter = nil
-- Wait for the character to load
local character = player.Character or player.CharacterAdded:Wait()

-- Find the Humanoid within the character
local humanoid = character:FindFirstChild("Humanoid")


local function isRagdollPresent()
    local liveFolder = workspace:FindFirstChild("Live")
    if liveFolder then
        -- Use local player's name to find the corresponding folder
        local playerFolder = liveFolder:FindFirstChild(player.Name)
        if playerFolder and playerFolder:FindFirstChild("Ragdoll") then
            return true
        end
    end
    return false
end

infiniteJumpEnabled = true
tpwalkEnabled = true

character = player.Character or player.CharacterAdded:Wait()
humanoid = character:WaitForChild("Humanoid")
humanoidRootPart = character:WaitForChild("HumanoidRootPart")
baseplate = nil
teleported = false
originalCFrame = nil
isTeleporting = false -- Flag to control baseplate position updates

local teleportReason = nil -- Variable to track the reason for teleportation


local function log(message, level)
    if not loggingEnabled then return end

    level = level or "info"
    if level == "info" then
        print("[INFO]", message)
    elseif level == "warn" then
        warn("[WARN]", message)
    elseif level == "error" then
        error("[ERROR]", message)
    end
end

-- Safe Find Function
local function safeFind(parent, childName, timeout)
    timeout = timeout or 2
    local startTime = tick()
    local child = parent:FindFirstChild(childName)
    while not child and tick() - startTime < timeout do
        RunService.Heartbeat:Wait()
        child = parent:FindFirstChild(childName)
    end
    if not child then
        log("Could not find " .. childName .. " in " .. parent:GetFullName() .. " after " .. timeout .. "s", "warn")
    end
    return child
end


local  overrideConnection
local velocityMultipliers = {}
--[[
    ["rbxassetid://17889080495"] = 8,
    ["rbxassetid://17278415853"] = 6,
    ["rbxassetid://16737255386"] = 6,
    ["rbxassetid://16571461202"] = 3,
    ["rbxassetid://17838006839"] = 2.3,
}
]]
local playerMoveConnection
local playerLastTime = tick()
local otherPlayerAnimConnections = {}

-- This helper waits for an Animator to appear in a character
local function waitForAnimator(character, timeout)
    timeout = timeout or 1
    local startTime = tick()
    local animator = character:FindFirstChildOfClass("Animator")
    while not animator and tick() - startTime < timeout do
        task.wait(0.1)
        animator = character:FindFirstChildOfClass("Animator")
    end
    return animator
end

-- Declare a variable to store the connection
local lockAnimationStoppedConnection

-- Forward-declare functions to handle scope issues
local toggleAnimationLock
local executeUnbangCommand
local createClone
local controlClone
local restoreCamera
local anyPlayersNearby
local isAnyRelevantAnimationPlaying
local detectSpecificAnimations
local monitorNearbyAnimations
local handleLocalPlayerAnimation
local SpecialOnAnimationPlayed
local onAnimationPlayed
local createOmniTool
local onCharacterAdded
local handleDetectedAnimation
local monitorPlayerForDuration -- Added forward declaration
local getDetectionRoot -- Added for Detection Root Update

-- Variables for locking the original character
local lockOriginalEnabled = false
local lockConnection = nil

-- Variables for handling detected animations
isHandlingDetectedAnimation = false

-- Variable to track if teleport animation is playing
isTeleportAnimationPlaying = false

getDetectionRoot = function()
    if cloneCharacter then
        -- prefer HumanoidRootPart, else PrimaryPart, else first BasePart
        local root = cloneCharacter:FindFirstChild("HumanoidRootPart")
                    or cloneCharacter.PrimaryPart
                    or cloneCharacter:FindFirstChildWhichIsA("BasePart")
        if root then return root end
    end
    return humanoidRootPart      -- fall-back to original only if clone really empty
end



-- Function to toggle Animation Lock Mode
toggleAnimationLock = function()
    animationsLocked = not animationsLocked
    if animationsLocked then
        print("Animation Lock Mode Activated")

        -- Stop all currently playing animations except the lock animation and the specific animation
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animId = track.Animation.AnimationId
            if animId ~= LOCK_ANIMATION_ID and animId ~= "rbxassetid://10491993682" then
                track:Stop()
                print("Stopped Animation:", animId)
            end
        end

        -- Play the lock animation with looping
        lockAnimationTrack = animator:LoadAnimation(lockAnimation)
        lockAnimationTrack.Looped = true
        lockAnimationTrack.Priority = Enum.AnimationPriority.Action
        lockAnimationTrack:Play()
        print("Playing Lock Animation:", LOCK_ANIMATION_ID)

        -- Connect the Stopped event
        if lockAnimationTrack then
            lockAnimationStoppedConnection = lockAnimationTrack.Stopped:Connect(function()
                if animationsLocked then
                    lockAnimationTrack:Play()
                    print("Lock Animation restarted.")
                end
            end)
        end
    else
        print("Animation Lock Mode Deactivated")

        -- Stop the lock animation if it's playing
        if lockAnimationTrack and lockAnimationTrack.IsPlaying then
            lockAnimationTrack:Stop()
            print("Stopped Lock Animation")
            lockAnimationTrack = nil
        end

        -- Disconnect the Stopped event
        if lockAnimationStoppedConnection then
            lockAnimationStoppedConnection:Disconnect()
            lockAnimationStoppedConnection = nil
        end

    end
end

function executeUnbangCommand()
    if infyield and infyield.execCmd then
        print("Executing unbang command.")
        infyield.execCmd('unbang')
    else
        warn("infyield.execCmd is not available!")
    end
end

-- Connect the toggle function to the key press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- Ignore input if it's already processed by the game

    if input.KeyCode == TOGGLE_KEY then
        toggleAnimationLock()
    end
end)




local liveFolder = workspace:FindFirstChild("Live")

local playerFolder = liveFolder:FindFirstChild(player.Name)

local hasTrashCan = playerFolder and playerFolder:FindFirstChild("Trash Can")

local DetectedAnimations = {
    -- tatsu grab
--[[
    ["rbxassetid://17275150809"] = {
        DetectionRadius = 40,
        CharacterRequirement = "All", 
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected Animation 17275150809 on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
]]
    [SECONDARY_ANIMATION_ID] = {
        DetectionRadius = 40,
        CharacterRequirement = "All", 
        UltedRequirement = "Both",
        Action = function(otherPlayer, animator)
            if animator then
                hasTrashCan = true
                returnToTrashcanEnabled = false
                local animationTrack = animator:LoadAnimation(TELEPORT_ANIMATION_ID)
                
                -- Loop the animation for 0.5 seconds
                local duration = 0.5
                local startTime = tick()
                while tick() - startTime < duration do
                    animationTrack:Play()
                    task.wait(0.1)
                end
            end
        end
    },

    [OMNI_ANIMATION_ID] = {
        DetectionRadius = 70,
        CharacterRequirement = "All",
        UltedRequirement = "On",
        Action = function(otherPlayer)
            print("Detected Omni Animation on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

	[TABLE_FLIP_ANIMATION_ID] = {
		DetectionRadius = 350,                -- max range you care about
		CharacterRequirement = "Bald",
		UltedRequirement = "Both",
		Action = function(otherPlayer)
			local otherHRP = otherPlayer.Character
						and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not otherHRP then return end

			local rootPos  = getDetectionRoot().Position
			local distance = (otherHRP.Position - rootPos).Magnitude

			local shouldDetect = false
			if distance <= 10 then                                 -- point-blank
				shouldDetect = true
			elseif distance <= 350 then                            -- within arc
				local look        = otherHRP.CFrame.LookVector
				local toPlayerDir = (rootPos - otherHRP.Position).Unit
				local angleDeg    = math.deg(math.acos(
								math.clamp(look:Dot(toPlayerDir), -1, 1)))
				shouldDetect = angleDeg <= 50
			end

			if shouldDetect then
				print("Detected Table Flip on", otherPlayer.Name,
					"at", math.floor(distance), "studs.")
				executeUnbangCommand()
				handleDetectedAnimation()
			end
		end
	},



	-- FIX CAM / “serious punch”
	[FIXCAM_ANIMATION_ID] = {
		DetectionRadius = 350,                -- same cone logic
		CharacterRequirement = "All",
		UltedRequirement = "On",
		Action = function(otherPlayer)
			local otherHRP = otherPlayer.Character
						and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not otherHRP then return end

			local rootPos  = getDetectionRoot().Position
			local distance = (otherHRP.Position - rootPos).Magnitude

			local shouldDetect = false
			if distance <= 10 then
				shouldDetect = true
			elseif distance <= 350 then
				local look        = otherHRP.CFrame.LookVector
				local toPlayerDir = (rootPos - otherHRP.Position).Unit
				local angleDeg    = math.deg(math.acos(
								math.clamp(look:Dot(toPlayerDir), -1, 1)))
				shouldDetect = angleDeg <= 50
			end

			if shouldDetect then
				print("Detected FixCam on", otherPlayer.Name,
					"at", math.floor(distance), "studs.")
				executeUnbangCommand()
				handleDetectedAnimation()
			end
		end
	},

    -- earth strike
    ["rbxassetid://18897119503"] = {
        DetectionRadius = 80,
        CharacterRequirement = "Purple",
        UltedRequirement = "On",
        Action = function(otherPlayer)
            print("Detected Animation 18897119503 on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
--[[
    -- death hit drag
    ["rbxassetid://14900168720"] = {
        DetectionRadius = 20,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected death hit drag (14900168720) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
]]

    -- death blow
    ["rbxassetid://15134211820"] = {
        DetectionRadius = 100,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected death blow (15134211820) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    ["rbxassetid://15128849047"] = {
        DetectionRadius = 100,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected death blow (15128849047) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

--[[
    -- garou run
    ["rbxassetid://13630786846"] = {
        DetectionRadius = 35,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected garou run (13630786846) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- garou run finisher
    ["rbxassetid://13813099821"] = {
        DetectionRadius = 50,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected garou run finisher (13813099821) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
]]
    -- garou stomp
    ["rbxassetid://12463072679"] = {
        DetectionRadius = 20,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected garou stomp (12463072679) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
    -- thekick
    ["rbxassetid://75502010126640"] = {
        DetectionRadius = 100,
        CharacterRequirement = "Purple",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected thekick (75502010126640) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- thekick startup
    ["rbxassetid://106755459092436"] = {
        DetectionRadius = 60,
        CharacterRequirement = "Purple",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected thekick startup on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- thekick run
    ["rbxassetid://95575238948327"] = {
        DetectionRadius = 120,
        CharacterRequirement = "Purple",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected thekick startup on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
--[[
    -- garou stomp super slam
    ["rbxassetid://12467789963"] = {
        DetectionRadius = 100,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected garou stomp super slam (12467789963) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- garou water slaps
    ["rbxassetid://14057231976"] = {
        DetectionRadius = 10,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected garou water slaps (14057231976) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- garou punches
    ["rbxassetid://12460977270"] = {
        DetectionRadius = 10,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected garou punches (12460977270) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- tatsu explode
    ["rbxassetid://16597912086"] = {
        DetectionRadius = 10,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected Animation 16597912086 on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- WallCast
    ["rbxassetid://129651400898906"] = {
        DetectionRadius = 50,
        CharacterRequirement = "Purple",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected WallCast (129651400898906) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- TWINFANGS
    ["rbxassetid://18896229321"] = {
        DetectionRadius = 10,
        CharacterRequirement = "Purple",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected TWINFANGS (18896229321) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- robotbomb
    ["rbxassetid://113166426814229"] = {
        DetectionRadius = 10,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected robotbomb (113166426814229) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- robotheavygrab
    ["rbxassetid://77509627104305"] = {
        DetectionRadius = 8,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected robotheavygrab (77509627104305) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- robotgrab
    ["rbxassetid://94395585475029"] = {
        DetectionRadius = 6,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected robotgrab (94395585475029) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- freezingpath
    ["rbxassetid://112620365240235"] = {
        DetectionRadius = 10,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected freezingpath (112620365240235) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- judgementchain
    ["rbxassetid://75547590335774"] = {
        DetectionRadius = 25,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected judgementchain (75547590335774) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- ravagemiss
    ["rbxassetid://16945573694"] = {
        DetectionRadius = 10,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected ravagemiss (16945573694) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- stoicbomb
    ["rbxassetid://17141153099"] = {
        DetectionRadius = 130,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected stoicbomb (17141153099) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- dropkick
    ["rbxassetid://17420452843"] = {
        DetectionRadius = 100,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected dropkick (17420452843) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- fiveseasons
    ["rbxassetid://18462894593"] = {
        DetectionRadius = 500,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected fiveseasons (18462894593) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },

    -- collateralruin
    ["rbxassetid://17325254223"] = {
        DetectionRadius = 35,
        CharacterRequirement = "All",
        UltedRequirement = "Both",
        Action = function(otherPlayer)
            print("Detected collateralruin (17325254223) on", otherPlayer.Name)
            executeUnbangCommand()
            handleDetectedAnimation()
        end
    },
]]
}
-- Function to restore camera to player
restoreCamera = function()
    -- Disconnect override so no loops remain
    if overrideConnection then
        overrideConnection:Disconnect()
        overrideConnection = nil
    end

    -- Save current camera CFrame
    local oldCam = Workspace.CurrentCamera
    local savedCF = oldCam and oldCam.CFrame

    -- Destroy existing “Camera” instance
    local existingCam = Workspace:FindFirstChild("Camera")
    if existingCam then
        existingCam:Destroy()
    end

    -- Create new Camera for the player
    local cam = Instance.new("Camera")
    cam.Name       = "Camera"
    cam.CameraType = Enum.CameraType.Custom
    cam.Parent     = Workspace

    -- Apply saved orientation/position
    if savedCF then
        cam.CFrame = savedCF
    end

    Workspace.CurrentCamera = cam

    -- Point camera back to player
    local char     = player.Character
    local targetHum  = char and char:FindFirstChildOfClass("Humanoid")
    local targetPart = char and char:FindFirstChild("HumanoidRootPart")
    local target     = targetHum or targetPart
    if not target then
        warn("Cannot restore camera: humanoid or HumanoidRootPart missing.")
        return
    end
    cam.CameraSubject = target

    print("Camera restored to player character.")
end

-- Function to check if any players are nearby using the original HumanoidRootPart
anyPlayersNearby = function()

    local root = getDetectionRoot()                -- clone HRP when it exists
    if not root then return false end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            local otherHRP = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
            if otherChar and otherHRP then
                -- Use original humanoidRootPart instead of getDetectionRoot()
                local distance = (otherHRP.Position - humanoidRootPart.Position).Magnitude
                if distance <= BACK_TELEPORT_RADIUS then
                    return true
                end
              
            end
        end
    end
    return false
end


local function teleportOriginalToBaseplate()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        -- Use TELEPORT_HEIGHT_OFFSET for the Y-axis
        local newPosition = baseplate.Position + Vector3.new(0, TELEPORT_HEIGHT_OFFSET, 0)
        player.Character.HumanoidRootPart.CFrame = CFrame.new(newPosition)
    else
        warn("Cannot teleport original character: HumanoidRootPart not found.")
    end
end

local function startLockOriginalCharacter()
    if lockConnection then return end -- Prevent multiple connections
    lockOriginalEnabled = true
    lockConnection = RunService.Heartbeat:Connect(function()
        if lockOriginalEnabled then
            teleportOriginalToBaseplate()
        else
            lockConnection:Disconnect()
            lockConnection = nil
        end
    end)
end

local function stopLockOriginalCharacter()
    lockOriginalEnabled = false
    if lockConnection then
        lockConnection:Disconnect()
        lockConnection = nil
    end
end

local function immobilizeOriginalCharacter()
    if not player.Character then return end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
end

local function restoreOriginalCharacter()
    if not player.Character then return end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

    -- Restore humanoid properties
    if humanoid then
        humanoid.WalkSpeed = 16 -- Default walk speed
        humanoid.JumpPower = 50 -- Default jump power
    end

    -- Enable collision only for Head and Torso
    for _, partName in ipairs({"Head", "Torso"}) do
        local part = player.Character:FindFirstChild(partName)
        if part then
            part.CanCollide = true -- Enable collision
            part.Anchored = false -- Ensure it's not anchored
        end
    end
end

local function lockOriginal()
    teleportOriginalToBaseplate()
    startLockOriginalCharacter()
    immobilizeOriginalCharacter()
end

local function unlockOriginal()
    restoreOriginalCharacter()
    stopLockOriginalCharacter()
end


-- Table to store connections for each clone
local cloneConnections = {}

local function cleanupClone(clone)
    if clone and cloneConnections[clone] then
        cloneConnections[clone]:Disconnect()
        print("Cleaned up clone connection for")
        cloneConnections[clone] = nil
    end
    if clone then
        clone:Destroy()
        print("Destroyed clone")
    end
    cloneCharacter = nil
end



-- Function to create a clone of the original character
local function createClone(originalCharacter)
    --------------------------------------------------------------------------
    -- 1   Duplicate and parent
    --------------------------------------------------------------------------
    local clone = originalCharacter:Clone()
    clone.Parent = workspace                                    -- keep it separate

    --------------------------------------------------------------------------
    -- 2   Establish an immediate root for getDetectionRoot()
    --------------------------------------------------------------------------
    local rootPart = clone:FindFirstChild("HumanoidRootPart")   -- R15
                  or clone.PrimaryPart                           -- already set
                  or clone:FindFirstChildWhichIsA("BasePart")    -- R6 “Torso” fallback

    if not rootPart then
        warn("Clone has no BasePart to use as root.")
        return clone                                            -- still return for safety
    end
    clone.PrimaryPart = rootPart
    clone:SetPrimaryPartCFrame(originalCharacter.PrimaryPart.CFrame)

    --------------------------------------------------------------------------
    -- 3   Visual + physics tweaks
    --------------------------------------------------------------------------
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 0.5
            part.CanCollide   = false
            part.Anchored     = false
            part.Velocity     = Vector3.zero
            part.RotVelocity  = Vector3.zero
        end
    end

    --------------------------------------------------------------------------
    -- 4   Remove constraints that could freeze it
    --------------------------------------------------------------------------
    for _, child in ipairs(clone:GetDescendants()) do
        if child:IsA("Constraint") or child.Name == "RagdollConstraints" then
            child:Destroy()
        end
    end

    --------------------------------------------------------------------------
    -- 5   Match humanoid properties and clean body‐movers
    --------------------------------------------------------------------------
    local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
    if cloneHumanoid and humanoid then
        cloneHumanoid.WalkSpeed  = 30
        cloneHumanoid.JumpPower  = humanoid.JumpPower
        cloneHumanoid.AutoRotate = true
        cloneHumanoid.Health     = cloneHumanoid.MaxHealth

        local cloneAnimator = cloneHumanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", cloneHumanoid)

        -- stop any auto-started tracks
        for _, track in ipairs(cloneAnimator:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
        cloneHumanoid:ChangeState(Enum.HumanoidStateType.Running)

        for _, bm in ipairs(cloneHumanoid:GetChildren()) do
            if bm:IsA("BodyMover") or bm:IsA("BodyGyro") or bm:IsA("BodyVelocity") then
                -- bm:Destroy()
            end
        end
    else
        if not cloneHumanoid then warn("Clone missing Humanoid.") end
        if not humanoid      then warn("Original Humanoid missing.") end
    end

    --------------------------------------------------------------------------
    -- 6   Allow space-bar jumping control
    --------------------------------------------------------------------------
    local function onJumpInput(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.Space and not gameProcessed then
            while UserInputService:IsKeyDown(Enum.KeyCode.Space) do
                if cloneHumanoid then
                    cloneHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                task.wait()
            end
        end
    end
    UserInputService.InputBegan:Connect(onJumpInput)

    --------------------------------------------------------------------------
    -- 7   Expose to the rest of the script
    --------------------------------------------------------------------------
    cloneCharacter = clone      -- critical for getDetectionRoot()

    return clone
end



-- Helper function to check if a value is a number
function isNumber(value)
    return type(value) == "number" or (type(value) == "string" and tonumber(value) ~= nil)
end
local scale = 10
-- Function to control the clone's movement by syncing with the player's inputs
local function controlClone(clone, args)
    cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
    cloneRoot = clone.PrimaryPart
    if not cloneHumanoid or not cloneRoot then return end

    -- Define a scaling factor; default is 10 if not provided

    if args and args[1] and isNumber(args[1]) then
        scale = tonumber(args[1])
    end

    -- Disconnect any existing connection for this clone
    if cloneConnections[clone] then
        cloneConnections[clone]:Disconnect()
    end

    -- Connect to Heartbeat to update movement each frame
    cloneConnections[clone] = RunService.Heartbeat:Connect(function(deltaTime)
        -- Get the local player and their humanoid
        local player = Players.LocalPlayer
        if not player then return end

        local character = player.Character
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            -- Calculate the movement vector
            local movementVector = moveDir * scale * deltaTime

            -- Translate the clone by the movement vector
            clone:TranslateBy(movementVector)
        end
    end)
end



-- Camera control fixed!

local function setupCamera(clone)
    if not clone then
        warn("Cannot setup camera: clone is nil.")
        return
    end

    -- Disconnect previous override (if any)
    if overrideConnection then
        overrideConnection:Disconnect()
        overrideConnection = nil
    end

    -- Save current camera CFrame
    local oldCam = Workspace.CurrentCamera
    local savedCF = oldCam and oldCam.CFrame

    -- Destroy existing “Camera” instance
    local existingCam = Workspace:FindFirstChild("Camera")
    if existingCam then
        existingCam:Destroy()
    end

    -- Create new Camera
    local cam = Instance.new("Camera")
    cam.Name       = "Camera"
    cam.CameraType = Enum.CameraType.Custom
    cam.Parent     = Workspace

    -- Apply saved orientation/position
    if savedCF then
        cam.CFrame = savedCF
    end

    Workspace.CurrentCamera = cam

    -- Point it at clone’s Humanoid or HumanoidRootPart
    local targetHum  = clone:FindFirstChildOfClass("Humanoid")
    local targetPart = targetHum or clone:FindFirstChild("HumanoidRootPart")
    if not targetPart then
        warn("Cannot setup camera: no Humanoid or HumanoidRootPart on clone.")
        return
    end
    cam.CameraSubject = targetPart

    -- Override any external CameraSubject changes
    overrideConnection = cam:GetPropertyChangedSignal("CameraSubject"):Connect(function()
        if cam.CameraSubject ~= targetPart then
            cam.CameraType    = Enum.CameraType.Custom
            cam.CameraSubject = targetPart
        end
    end)

    print("Camera set to follow clone.")
end

local Y_THRESHOLD = 422 -- Desired Y-coordinate threshold

local function isAboveY(position, yThreshold)
    return position.Y > yThreshold
end

local function stabilizeClone(clone)
    local humanoidRootPart = clone:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        warn("HumanoidRootPart not found in clone.")
        return
    end

    -- Disable collisions if needed
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Ensure no BodyVelocity is applied
    local bodyVelocity = humanoidRootPart:FindFirstChildOfClass("BodyVelocity")
    if bodyVelocity then
        -- bodyVelocity:Destroy()
	print()
    end
end

local function syncAnimations(originalCharacter, clone)
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")

    if not originalHumanoid or not cloneHumanoid then return end

    local originalAnimator = originalHumanoid:FindFirstChildOfClass("Animator")
    local cloneAnimator = cloneHumanoid:FindFirstChildOfClass("Animator")

    if not originalAnimator or not cloneAnimator then return end

    -- Store animation tracks to manage them later
    local animationTracks = {}

    -- Copy any currently playing animations
    for _, track in ipairs(originalHumanoid:GetPlayingAnimationTracks()) do
        local animation = track.Animation
        if animation then
            local success, cloneAnimationTrack = pcall(function()
                return cloneAnimator:LoadAnimation(animation)
            end)
            if success and cloneAnimationTrack then
                cloneAnimationTrack.Priority = track.Priority
                cloneAnimationTrack:Play(track.TimePosition, track.WeightCurrent, track.Speed)
                animationTracks[track] = cloneAnimationTrack
                print("Synchronized animation:", animation.AnimationId)
            else
                warn("Failed to load animation:", animation.AnimationId, "on clone.")
            end
        end
    end

    -- Track active animations and sync them
    local animationPlayedConn = originalAnimator.AnimationPlayed:Connect(function(animationTrack)
        local animation = animationTrack.Animation
        if animation then
            local success, cloneAnimationTrack = pcall(function()
                return cloneAnimator:LoadAnimation(animation)
            end)
            if success and cloneAnimationTrack then
                cloneAnimationTrack.Priority = animationTrack.Priority
                cloneAnimationTrack:Play()
                print("Synchronized new animation:", animation.AnimationId)

                -- Keep track of the clone's animation track
                animationTracks[animationTrack] = cloneAnimationTrack

                -- Stop the animation on the clone when it stops on the original
                local stoppedConn
                stoppedConn = animationTrack.Stopped:Connect(function()
                    if cloneAnimationTrack and cloneAnimationTrack.IsPlaying then
                        cloneAnimationTrack:Stop()
                        print("Stopped synchronized animation:", animation.AnimationId)
                    end
                    if stoppedConn then
                        stoppedConn:Disconnect()
                        stoppedConn = nil
                    end
                    animationTracks[animationTrack] = nil
                end)
            else
                warn("Failed to load new animation:", animation.AnimationId, "on clone.")
            end
        end
    end)

    -- Return the connection and tracks to disconnect later
    return animationPlayedConn, animationTracks
end

local MINIMUM_TELEPORT_DURATION = 3 -- Minimum time in seconds
--==========================================================
local function movePlayerToTrashcan(trashcan)
    -- Ensure the player has a character and HRP exists
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local canPosition = trashcan:FindFirstChild("Trashcan")
        if canPosition and canPosition:IsA("BasePart") then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(canPosition.Position + Vector3.new(0, -4.5, 0)) 
        end
    else
        print("Player's character or HRP is missing.")
    end
end
local getFarthestTrashCan

local function enableTrashcanReturn()
    if trashcanConnection then return end -- Prevent multiple connections
    returnToTrashcanEnabled = true
    trashcanConnection = RunService.Heartbeat:Connect(function()
        trashcanHeartbeatStart = tick() -- Start tracking time
        if returnToTrashcanEnabled then
            -- Find the last picked trashcan to teleport back to
            local currentTrashcan = getFarthestTrashCan()
            if currentTrashcan then
                print('h')
            end
        else
            trashcanConnection:Disconnect()
            trashcanConnection = nil
        end
        trashcanHeartbeatEnd = tick()
    end)
end
--=======================================================================
handleDetectedAnimation = function(specialMode)
    if isHandlingDetectedAnimation then return end
    isHandlingDetectedAnimation = true

    -- NEW: Remember if trashcan/auto-click loops were on, then turn them off
    wasAutoTrashOn = autoTrashGrabEnabled
    wasTrashcanReturnOn = returnToTrashcanEnabled
    if wasAutoTrashOn then
        autoTrashGrabEnabled = false
        setAllTrashCansCollide(true)  -- Ensure trash cans are collidable again
    end
    if wasTrashcanReturnOn then
        disableTrashcanReturn()
    end


    teleportStartTime = tick()


    character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        character = player.CharacterAdded:Wait()
        character:WaitForChild("HumanoidRootPart")
    end
    humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

    -- ★ CHANGE: Use getDetectionRoot() so that if cloneCharacter exists, its HRP is used.
    while not isAboveY(getDetectionRoot().Position, BASEPLATE_Y_DEFAULT + TELEPORT_HEIGHT_OFFSET) do
        print("Player not above Y threshold (using detection root), retrying...")
        wait(0.01)
    end

    print("Proceeding with teleport.")

    aimAssistEnabled = false
    print("Aim assistance disabled.")

    cloneCharacter = createClone(character)
    print("Clone created.")

    isTeleporting = true
    lockOriginal()
    stabilizeClone(cloneCharacter)
    print("Clone controlled and original locked.")

    local cloneHumanoid = cloneCharacter:FindFirstChildOfClass("Humanoid")
    local cloneHRP = cloneCharacter:FindFirstChild("HumanoidRootPart")

    -- Remove controlClone call and use proper humanoid movement
    cloneHumanoid.WalkSpeed = scale -- Ensure proper movement speed
    cloneHumanoid.JumpPower = 100

    -- Connect input directly to clone humanoid
    local moveConnection
    moveConnection = RunService.RenderStepped:Connect(function()
        if cloneHumanoid and humanoid then
            cloneHumanoid:Move(humanoid.MoveDirection * 50) -- Boost movement if needed
            cloneHumanoid.Jump = humanoid.Jump
        end
    end)

    local success, animationPlayedConn = pcall(function()
        return syncAnimations(character, cloneCharacter)
    end)

    local connectionsToDisconnect = {animationPlayedConn}

    setupCamera(cloneCharacter)

    if not specialMode then
        local teleportRenderSteppedConnection
        local function onRenderStepped()
            local timeSinceTeleport = tick() - teleportStartTime
            if timeSinceTeleport >= MINIMUM_TELEPORT_DURATION then
                if not anyPlayersNearby() and not isAnyRelevantAnimationPlaying() then
                    -- Return actions
                    unlockOriginal()

                    if cloneCharacter and cloneCharacter:FindFirstChild("HumanoidRootPart") and character and character.PrimaryPart then
                        local cloneCFrame = cloneCharacter.HumanoidRootPart.CFrame
                        character:SetPrimaryPartCFrame(cloneCFrame)
                        print("Original character moved to clone's position.")
                    end

                    restoreCamera()
                    print("Camera restored.")

                    for _, conn in ipairs(connectionsToDisconnect) do
                        if conn and conn.Disconnect then
                            conn:Disconnect()
                            print("Disconnected a connection.")
                        end
                    end

                    if cloneCharacter then
                        print("Clone destroyed.")
                        cleanupClone(cloneCharacter)
                    end

                    isTeleporting = false
                    print("isTeleporting set to false.")

                    if not userAimAssistToggledOff then
                        aimAssistEnabled = true  -- CHANGED: wrapped in condition
                        print("Aim assistance re‐enabled.")
                    end

                    -- NEW: If loops were on, turn them back on now
                    if wasAutoTrashOn then
                        autoTrashGrabEnabled = true
                        setAllTrashCansCollide(false)
                    end
                    if wasTrashcanReturnOn then
                        enableTrashcanReturn()
                    end

                    isHandlingDetectedAnimation = false

                    -- Disconnect the RenderStepped connection
                    if teleportRenderSteppedConnection then
                        teleportRenderSteppedConnection:Disconnect()
                        teleportRenderSteppedConnection = nil
                    end
                end
            end
        end

        teleportRenderSteppedConnection = RunService.RenderStepped:Connect(onRenderStepped)
    end
end

isAnyRelevantAnimationPlaying = function()
    local rootPos = getDetectionRoot().Position
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and not spawnTimes[other.UserId] then
            local oHRP = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
            local anims = other.Character and other.Character:FindFirstChild("Humanoid"):GetPlayingAnimationTracks()
            if oHRP and anims then
                local dist = (oHRP.Position - rootPos).Magnitude
                for _, track in ipairs(anims) do
                    local cfg = DetectedAnimations[track.Animation.AnimationId]
                    if cfg and dist <= cfg.DetectionRadius then
                        return true
                    end
                end
            end
        end
    end
    return false
end


function createBaseplate()
    if baseplate and baseplate.Parent then
        baseplate:Destroy()
    end

    baseplate = Instance.new("Part")
    baseplate.Size = BASEPLATE_SIZE
    baseplate.Anchored = true
    baseplate.CanCollide = true
    baseplate.Transparency = 0
    baseplate.Name = "CustomBaseplate"
    baseplate.Color = Color3.fromRGB(100, 100, 255)
    baseplate.Material = Enum.Material.SmoothPlastic

    local sizeY = BASEPLATE_SIZE.Y
    -- Center at top surface - half thickness
    baseplate.Position = Vector3.new(
        humanoidRootPart.Position.X,
        BASEPLATE_Y_DEFAULT - (sizeY / 2),
        humanoidRootPart.Position.Z
    )

    baseplate.Parent = workspace
end

-- Function to update the baseplate's position to follow the player's X and Z
function updateBaseplatePosition()
    if baseplate and getDetectionRoot() and not isTeleporting then
        local playerPosition = getDetectionRoot().Position
        local targetY = teleported and BASEPLATE_Y_TELEPORT or BASEPLATE_Y_DEFAULT
        baseplate.Position = Vector3.new(playerPosition.X, targetY, playerPosition.Z)
    end
end

function syncAnimations(originalCharacter, clone)
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")

    if not originalHumanoid or not cloneHumanoid then return end

    local originalAnimator = originalHumanoid:FindFirstChildOfClass("Animator")
    local cloneAnimator = cloneHumanoid:FindFirstChildOfClass("Animator")

    if not originalAnimator or not cloneAnimator then return end

    -- Store animation tracks to manage them later
    local animationTracks = {}

    -- Copy any currently playing animations
    for _, track in ipairs(originalHumanoid:GetPlayingAnimationTracks()) do
        local animation = track.Animation
        if animation then
            local success, cloneAnimationTrack = pcall(function()
                return cloneAnimator:LoadAnimation(animation)
            end)
            if success and cloneAnimationTrack then
                cloneAnimationTrack.Priority = track.Priority
                cloneAnimationTrack:Play(track.TimePosition, track.WeightCurrent, track.Speed)
                animationTracks[track] = cloneAnimationTrack
            else
                warn("Failed to load animation:", animation.AnimationId, "on clone.")
            end
        end
    end

    -- Track active animations and sync them
    local animationPlayedConn = originalAnimator.AnimationPlayed:Connect(function(animationTrack)
        local animation = animationTrack.Animation
        if animation then
            local success, cloneAnimationTrack = pcall(function()
                return cloneAnimator:LoadAnimation(animation)
            end)
            if success and cloneAnimationTrack then
                cloneAnimationTrack.Priority = animationTrack.Priority
                cloneAnimationTrack:Play()

                -- Keep track of the clone's animation track
                animationTracks[animationTrack] = cloneAnimationTrack

                -- Stop the animation on the clone when it stops on the original
                local stoppedConn
                stoppedConn = animationTrack.Stopped:Connect(function()
                    if cloneAnimationTrack and cloneAnimationTrack.IsPlaying then
                        cloneAnimationTrack:Stop()
                        print("Stopped synchronized animation:", animation.AnimationId)
                    end
                    if stoppedConn then
                        stoppedConn:Disconnect()
                        stoppedConn = nil
                    end
                    animationTracks[animationTrack] = nil
                end)
            else
                warn("Failed to load new animation:", animation.AnimationId, "on clone.")
            end
        end
    end)

    -- Return the connection and tracks to disconnect later
    return animationPlayedConn, animationTracks
end

function detectSpecificAnimations()
    if isHandlingDetectedAnimation then return end

    detectedPlayers = {}

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and not spawnTimes[otherPlayer.UserId] then
            if otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local otherHumanoid = otherPlayer.Character:FindFirstChild("Humanoid")
                if otherHumanoid and otherHumanoid.Health > 0 then
                    local animator = otherHumanoid:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local animId = track.Animation.AnimationId
                            local detectedAnim = DetectedAnimations[animId]  -- <== added here
                            if detectedAnim then
                                local detectionRoot = getDetectionRoot()
                                local otherHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                                local distance = (otherPlayer.Character.HumanoidRootPart.Position - getDetectionRoot().Position).Magnitude
                                local shouldDetect = true

                                if animId == TABLE_FLIP_ANIMATION_ID or animId == FIXCAM_ANIMATION_ID then
                                    if distance <= 10 then
                                        shouldDetect = true -- Always detect if very close
                                    elseif distance <= 350 then
                                        local otherHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                                        local lookVector = otherHRP.CFrame.LookVector
                                        local toPlayerVector = (detectionRoot.Position - otherHRP.Position).Unit
                                        local angle = math.deg(math.acos(math.clamp(lookVector:Dot(toPlayerVector), -1, 1)))
                                        shouldDetect = angle <= 50
                                    end
                                else
                                    if distance > detectedAnim.DetectionRadius then
                                        shouldDetect = false
                                    end
                                end

                                -- Additional requirement checks here
                                if shouldDetect then
                                    -- Character Requirement
                                    local otherPlayerCharacterAttribute = otherPlayer.Character:GetAttribute("Character")
                                    if detectedAnim.CharacterRequirement ~= "All" and otherPlayerCharacterAttribute ~= detectedAnim.CharacterRequirement then
                                        shouldDetect = false
                                    end

                                    -- Ulted Requirement
                                    local playerIsUlted = isultedactiveforothers(otherPlayer)
                                    local ultedReq = detectedAnim.UltedRequirement
                                    local ultMatches = false

                                    if ultedReq == "On" then
                                        ultMatches = (playerIsUlted == true)
                                    elseif ultedReq == "Off" then
                                        ultMatches = (playerIsUlted == false)
                                    elseif ultedReq == "Both" then
                                        ultMatches = true
                                    end

                                    if not ultMatches then
                                        shouldDetect = false
                                    end

                                    if shouldDetect then
                                        if not detectedPlayers[otherPlayer.UserId] then
                                            detectedPlayers[otherPlayer.UserId] = {}
                                        end
                                        table.insert(detectedPlayers[otherPlayer.UserId], animId)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Process all detections
    for userId, animIds in pairs(detectedPlayers) do
        local otherPlayer = Players:GetPlayerByUserId(userId)
        for _, animId in ipairs(animIds) do
            if DetectedAnimations[animId] then
                DetectedAnimations[animId].Action(otherPlayer)
            end
        end
    end
end

-- Function to monitor and remove BodyGyro
function monitorBodyGyro()
    humanoidRootPart.ChildAdded:Connect(function(child)
        if child:IsA("BodyGyro") then
	    child:Destroy()
            print("BodyGyro detected on HumanoidRootPart. Deleting...")
        end
    end)

    -- In case BodyGyro already exists
    for _, child in ipairs(humanoidRootPart:GetChildren()) do
        if child:IsA("BodyGyro") then
	    child:Destroy()
            print("Existing BodyGyro found on HumanoidRootPart. Deleting...")
        end
    end
end

-- Call the monitor function
monitorBodyGyro()

-- Handle character respawn
player.CharacterAdded:Connect(function(char)
    character = char
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    monitorBodyGyro()
end)

handleLocalPlayerAnimation = function(animationTrack, animationId)


    function getAnimationNumericID(animId)
        return animId:match("rbxassetid://(%d+)") or animId:match("id=(%d+)")
    end



    local hb = RunService.Heartbeat
    -- Inside your handleLocalPlayerAnimation function:
    rawAnimId = animationTrack.Animation.AnimationId


    local numID = getAnimationNumericID(rawAnimId)


    local lookupKey = "rbxassetid://" .. numID


    local velocityMult = velocityMultipliers[lookupKey]


    if velocityMult then
        print("Velocity multiplier applied for animation:", lookupKey)
        if lookupKey == "rbxassetid://17838006839" then
            local movementConn
            movementConn = RunService.Heartbeat:Connect(function(delta)
                if humanoid.MoveDirection.Magnitude > 0 then
                    -- This multiplication will now work because velocityMult is a valid number.
                    character:TranslateBy(humanoid.MoveDirection * velocityMult * delta * 10)
	            else
		            character:TranslateBy(humanoid.MoveDirection * delta * 10)
                end
            end)
            local stoppedConn
            stoppedConn = animationTrack.Stopped:Connect(function()
                if movementConn then
                    movementConn:Disconnect()
                    movementConn = nil
                    print("Velocity multiplier removed after animation:", lookupKey)
                end
                stoppedConn:Disconnect()
            end)
        else
            -- Handle other animations:
            print("Lookup Key:", lookupKey, "Velocity Multiplier:", velocityMult)
            print("Command:", 'fly ' .. velocityMult)
            
            -- Set a global flag to signal that fly mode is active.
            _G.flyActive = true
            
            
            local Players = game:GetService("Players")
            local player = Players.LocalPlayer

            spawn(function()
                while _G.flyActive do
                    -- Get the player model under workspace.Live
                    local playerModel = workspace.Live:FindFirstChild(player.Name)
                    
                    if playerModel then
                        -- Delete BodyGyroBind from the player if it exists
                        local bodyGyroBind = playerModel:FindFirstChild("BodyGyroBind")
                        if bodyGyroBind then
                            bodyGyroBind:Destroy()
                        end
                        local Freeze = playerModel:FindFirstChild("Freeze")
                        if Freeze then
                            Freeze:Destroy()
                        end
                        -- Delete unwanted objects from the HumanoidRootPart if it exists
                        local hrp = playerModel:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            for _, objName in ipairs({"moveme", "BODYGYRO", "VelForwardBv"}) do
                                local obj = hrp:FindFirstChild(objName)
                                if obj then
                                    obj:Destroy()
                                end
                            end
                        end
                    end
                    
                    wait()  -- Adjust the wait time as needed
                end
            end)

            -- Execute the fly command.
            infyield.execCmd('fly ' .. velocityMult)
            
            -- When the animation stops, turn off fly mode and execute unfly.
            local stoppedConn
            stoppedConn = animationTrack.Stopped:Connect(function()
                _G.flyActive = false  -- This stops the loop above.
                infyield.execCmd('unfly')
                print("Unfly executed after animation:", lookupKey)
                stoppedConn:Disconnect()
            end)
        end
    end

    if animationId == "rbxassetid://17889080495" then
        isSpecificAnimationPlaying = true
        print("Specific Animation (17889080495) started playing.")

        -- When the animation stops, reset the flag
        animationTrack.Stopped:Connect(function()
            isSpecificAnimationPlaying = false
            print("Specific Animation (17889080495) stopped playing.")
        end)
    end

    if animationId == TELEPORT_ANIMATION_ID then
        print("Teleport Animation Detected")
        executeUnbangCommand()
	isTeleportAnimationActive = true
        wait(.05)
        handleDetectedAnimation()
        -- Stop the current animation
        animationTrack:Stop()

        -- Play the replacement animation
        local replacementAnimation = Instance.new("Animation")
        replacementAnimation.AnimationId = REPLACEMENT_ANIMATION_ID

        local success, replacementTrack = pcall(function()
            return humanoid:LoadAnimation(replacementAnimation)
        end)

        if success and replacementTrack then
            replacementTrack:Play()
            print("Replacement Animation for Teleport played successfully.")
        else
            warn("Failed to load Replacement Animation for Teleport.")
        end
	isTeleportAnimationActive = false
        infyield.execCmd('fixcam')
    end



--[[
    if animationId == OMNI_ANIMATION_ID then
        -- Handle Omni Animation Replacement
        if isPlayingOmniAnimViaTool then
            print("Omni Animation played via OmniTool. No replacement.")
            -- Do not replace
        elseif not isOmniToolEquipped then
            print("Omni Animation Detected without Tool Equipped:", animationId)
            
            -- Stop the original Omni animation
            animationTrack:Stop()
            print("Original Omni Animation Stopped.")
            
            -- Play the replacement Omni animation
            local replacementOmniAnimation = Instance.new("Animation")
            replacementOmniAnimation.AnimationId = REPLACEMENT_OMNI_ANIMATION_ID
            local success, replacementOmniTrack = pcall(function()
                return humanoid:LoadAnimation(replacementOmniAnimation)
            end)
            
            if success and replacementOmniTrack then
                replacementOmniTrack.Priority = Enum.AnimationPriority.Action
                replacementOmniTrack:Play()
                print("Played Replacement Omni Animation:", REPLACEMENT_OMNI_ANIMATION_ID)
            else
                warn("Failed to load Replacement Omni Animation.")
            end
        else
            print("Omni Tool is equipped. No replacement needed.")
        end
    end
]]

    -- Handle secondary animation replacement
    if animationId == SECONDARY_ANIMATION_ID then
        print("Secondary Animation Detected")
        executeUnbangCommand()

        -- Stop the current animation
        animationTrack:Stop()

        -- Play the replacement animation
        local replacementAnimation = Instance.new("Animation")
        replacementAnimation.AnimationId = REPLACEMENT_ANIMATION_ID

        local success, replacementTrack = pcall(function()
            return humanoid:LoadAnimation(replacementAnimation)
        end)

        if success and replacementTrack then
            replacementTrack:Play()
            print("Replacement Animation for Secondary played successfully.")
        else
            warn("Failed to load Replacement Animation for Secondary.")
        end
    end

end

-- Function to handle AnimationPlayed event
SpecialOnAnimationPlayed = function(animationTrack)
    local animationId = animationTrack.Animation.AnimationId
    handleLocalPlayerAnimation(animationTrack, animationId)
end

-- Function to create Omni Tool
createOmniTool = function()
    local backpack = player:WaitForChild("Backpack")
    if backpack:FindFirstChild(EQUIPPED_TOOL_NAME) then
        print("OmniTool already exists in backpack.")
        return -- Tool already exists
    end

    -- Create Omni Tool
    local tool = Instance.new("Tool")
    tool.Name = EQUIPPED_TOOL_NAME
    tool.RequiresHandle = false
    tool.CanBeDropped = false

    -- Connect to tool's Equipped and Unequipped events
    tool.Equipped:Connect(function()
        isOmniToolEquipped = true
        print("OmniTool has been equipped via Equipped event.")
    end)

    tool.Unequipped:Connect(function()
        isOmniToolEquipped = false
        print("OmniTool has been unequipped via Unequipped event.")
    end)

    -- Attach animation to tool activation
    tool.Activated:Connect(function()
        print("Omni Tool activated. Preparing to play Omni Animation.")
        isPlayingOmniAnimViaTool = true

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            local animation = Instance.new("Animation")
            animation.AnimationId = OMNI_ANIMATION_ID
            local track = animator:LoadAnimation(animation)
            track:Play()
            print("Omni Tool activated. Animation playing.")

            task.delay(TOOL_PLAY_DURATION, function()
                if track and track.IsPlaying then
                    track:Stop()
                    print("Omni Animation stopped after duration.")
                end
                isPlayingOmniAnimViaTool = false
                print("isPlayingOmniAnimViaTool set to false.")
            end)
        else
            warn("Animator not found on Humanoid for Omni Tool activation.")
            isPlayingOmniAnimViaTool = false
        end
    end)

    tool.Parent = backpack
    print("OmniTool created and added to backpack.")
end

local connections = {}

local function onCharacterAdded(char)
    print("Character added for:", char.Name)

    -- Initialize character variables
    character = char

    humanoid = safeFind(character, "Humanoid")
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 2)
        if not humanoid then
            warn("Humanoid not found for character:", character)
            return
        end
    end

    humanoidRootPart = safeFind(character, "HumanoidRootPart")
    if not humanoidRootPart then
        humanoidRootPart = character:WaitForChild("HumanoidRootPart", 2)
        if not humanoidRootPart then
            warn("HumanoidRootPart not found for character:", character)
            return
        end
    end

    -- Reassign the animator for the new humanoid
    animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = waitForAnimator(humanoid, 1) -- Wait up to 1 second for Animator
        if not animator then
            warn("Animator not found for humanoid after waiting.")
            return
        end
    end

    teleported = false
    originalCFrame = nil
    isTeleporting = false
    teleportReason = nil
    createBaseplate()
    if connections.AnimationPlayedConn then
        connections.AnimationPlayedConn:Disconnect()
    end
    connections.AnimationPlayedConn = humanoid.AnimationPlayed:Connect(SpecialOnAnimationPlayed)

    if connections.TrashPickupConn then
        connections.TrashPickupConn:Disconnect()
    end
    connections.TrashPickupConn = humanoid.AnimationPlayed:Connect(onTrashAnimationPlayed)
end

-- Connect the onCharacterAdded function to the CharacterAdded event
player.CharacterAdded:Connect(onCharacterAdded)

-- Initialize the baseplate and connections for the current character if already present
if player.Character then
    onCharacterAdded(player.Character)
end

-- Continuously update the baseplate's position every frame
RunService.Heartbeat:Connect(updateBaseplatePosition)

-- enforce slot 5 = OmniTool (handles missing Base or ToolName)
local function enforceSlot5()
    local hotbar = player.PlayerGui:FindFirstChild("Hotbar")
                   and player.PlayerGui.Hotbar:FindFirstChild("Backpack")
                   and player.PlayerGui.Hotbar.Backpack:FindFirstChild("Hotbar")
    if not hotbar then return end

    -- wait until slots 1-4 have names loaded
    for i = 1, 4 do
        local slot = hotbar:FindFirstChild(tostring(i))
        if slot then
            local base = slot:FindFirstChild("Base") or slot:WaitForChild("Base", 1)
            if base then
                local tn = base:FindFirstChild("ToolName")
                if tn then
                    repeat wait() until tn.Text and tn.Text ~= ""
                else
                    repeat wait() until base.ToolName and base.ToolName ~= ""
                end
            end
        end
    end

    local slot5  = hotbar:FindFirstChild("5")
    if not slot5 then return end

    local base5 = slot5:FindFirstChild("Base")
    if not base5 then return end

    -- read current tool name safely
    local tn5     = base5:FindFirstChild("ToolName")
    local current = (tn5 and tn5.Text) or (base5.ToolName or "")

    if current ~= "OmniTool" then
        -- clear any other numeric slots showing OmniTool
        for i = 1, 5 do
            if i ~= 5 then
                local slot = hotbar:FindFirstChild(tostring(i))
                if slot then
                    local b = slot:FindFirstChild("Base")
                    if b then
                        local tn = b:FindFirstChild("ToolName")
                        local name = (tn and tn.Text) or (b.ToolName or "")
                        if name == "OmniTool" then
                            if tn then
                                tn.Text = ""
                            else
                                b.ToolName = ""
                            end
                        end
                    end
                end
            end
        end

        -- destroy any existing OmniTool instances
        if player:FindFirstChild("Backpack") then
            local t = player.Backpack:FindFirstChild("OmniTool")
            if t then t:Destroy() end
        end
        if player.Character then
            local t = player.Character:FindFirstChild("OmniTool")
            if t then t:Destroy() end
        end

        -- spawn a fresh OmniTool
        createOmniTool()

        -- force slot 5 GUI
        if tn5 then
            tn5.Text = "OmniTool"
        else
            base5.ToolName = "OmniTool"
        end
    end
end



-- initial check + keep it locked every frame
enforceSlot5()
RunService.Heartbeat:Connect(enforceSlot5)



local function monitorNearbyAnimations()
    while true do
        if not isSpecificAnimationPlaying then
            detectSpecificAnimations()
        end

        if isTeleporting then
            wait(TELEPORT_DETECTION_INTERVAL)
        else
            RunService.RenderStepped:Wait()
        end
    end
end
spawn(monitorNearbyAnimations)


--------------------------------------------------------------------------------
-- BEGIN UPDATED SCRIPT
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

trashcanPickupAnimId = "rbxassetid://13814919604"  -- Animation ID for picking up trashcan
humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")



-- Connect the animation played event to the function
if humanoid then
    humanoid.AnimationPlayed:Connect(onTrashAnimationPlayed)
end



--------------------------------------------------------------------------------
-- TRASHCAN LOGIC (RENAMED FUNCTIONS)
--------------------------------------------------------------------------------
--[[
local function movePlayerToTrashcan(trashcan)
    -- Ensure the player has a character and HRP exists
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local canPosition = trashcan:FindFirstChild("Trashcan")
        if canPosition and canPosition:IsA("BasePart") then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(canPosition.Position + Vector3.new(0, 0.5, 0)) -- Centered and 0.5 studs up
        end
    else
        print("Player's character or HRP is missing.")
    end
end


function enableTrashcanReturn()
    if trashcanConnection then return end -- Prevent multiple connections
    returnToTrashcanEnabled = true
    trashcanConnection = RunService.Heartbeat:Connect(function()
        trashcanHeartbeatStart = tick() -- Start tracking time
        if returnToTrashcanEnabled then
            -- Find the last picked trashcan to teleport back to
            local currentTrashcan = getFarthestTrashCan()
            if currentTrashcan then
                movePlayerToTrashcan(currentTrashcan)
            end
        else
            trashcanConnection:Disconnect()
            trashcanConnection = nil
        end
        trashcanHeartbeatEnd = tick()
    end)
end
]]

-- Remove Freeze and CanWalk if they exist when the trashcan-grab loop is toggled on
local function removeFreezeAndCanWalkIfExists()
    liveFolder = workspace:FindFirstChild("Live")
    if not liveFolder then return end

    local playerFolder = liveFolder:FindFirstChild(player.Name)
    if not playerFolder then return end

    local freezeObj = playerFolder:FindFirstChild("Freeze")
    if freezeObj then
        freezeObj:Destroy()
    else
        print("freezenotfound")
    end

    local canWalkObj = playerFolder:FindFirstChild("CanWalk")
    if canWalkObj then
        canWalkObj:Destroy()
    else
        print("canwalknotfound")
    end
end

-- Find a trashcan that is “farthest from all players”
getFarthestTrashCan = function()
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end

    local trashFolder = map:FindFirstChild("Trash")
    if not trashFolder then return nil end

    local bestCan, bestDist = nil, -1
    for _, obj in pairs(trashFolder:GetChildren()) do
        if obj.Name == "Trashcan" and obj:GetAttribute("Broken") ~= true then
            local nestedCan = obj:FindFirstChild("Trashcan")
            if nestedCan and nestedCan:IsA("BasePart") then
                local minDistToPlayers = math.huge
                for _, plr in ipairs(Players:GetPlayers()) do
                    local char = plr.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dist = (hrp.Position - nestedCan.Position).Magnitude
                        if dist < minDistToPlayers then
                            minDistToPlayers = dist
                        end
                    end
                end
                if minDistToPlayers > bestDist then
                    bestDist = minDistToPlayers
                    bestCan = obj
                end
            end
        end
    end
    return bestCan
end

--------------------------------------------------------------------------------
-- CLICK-SPAM UNTIL PICKED UP, WITH A 1-SECOND TIMEOUT
--------------------------------------------------------------------------------

local function spamClickUntilPickedUp(trashCan)
    local liveFolder = workspace:FindFirstChild("Live")
    local startTime = tick()
    
    while true do
        local timeElapsed = tick() - startTime
        if timeElapsed >= 2.2 then
            -- Timed out, did NOT pick up
            return false
        end

        -- Check if the trash grab is disabled and stop if it is
        if not autoTrashGrabEnabled then
            print("Auto Trash Grab is disabled, stopping click spam.")
            return false
        end

        -- Check if the player has already picked up the trashcan
        local playerFolder = liveFolder and liveFolder:FindFirstChild(player.Name)
        if playerFolder and playerFolder:FindFirstChild("Trash Can") then
            print("Successfully picked up the trashcan.")
            return true
        end

        -- Simulate a click
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        RunService.Heartbeat:Wait()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        RunService.Heartbeat:Wait()
        wait(0.4)
    end
end

--------------------------------------------------------------------------------
-- MAIN PICK-UP LOGIC (HRP IN CENTER, 0.5 STUDS UP)
--------------------------------------------------------------------------------
-- Only modified per user request (no original position revert, clone starts at same HRP,
-- main char set to clone’s HRP after pick-up, and loop teleport).
--------------------------------------------------------------------------------
-- Mirrors BodyGyro/BodyVelocity from sourceHRP -> destHRP.
-- When NO forces exist on source: clone behaves like a normal humanoid (Running).
local function mirrorFlyForces(sourceHRP, destHRP)
    if not (sourceHRP and destHRP) then return function() end end

    local hum = destHRP.Parent and destHRP.Parent:FindFirstChildOfClass("Humanoid")
    local savedPS = hum and hum.PlatformStand or nil

    local dBG, dBV

    local function applyForces(sBG, sBV)
        -- BodyGyro
        if sBG then
            if not dBG then
                dBG = Instance.new("BodyGyro")
                dBG.Name = "FlyMirrorBodyGyro"
                dBG.Parent = destHRP
            end
            dBG.P = sBG.P
            dBG.D = sBG.D
            dBG.MaxTorque = sBG.MaxTorque or sBG.maxTorque
            local cf = sBG.CFrame or sBG.cframe
            if cf then dBG.CFrame = cf end
        elseif dBG then
            dBG:Destroy(); dBG = nil
        end

        -- BodyVelocity
        if sBV then
            if not dBV then
                dBV = Instance.new("BodyVelocity")
                dBV.Name = "FlyMirrorBodyVelocity"
                dBV.Parent = destHRP
            end
            dBV.P = sBV.P
            dBV.MaxForce = sBV.MaxForce or sBV.maxForce
            dBV.Velocity = sBV.Velocity or sBV.velocity
            -- let BV actually move the clone like the source
            destHRP.AssemblyLinearVelocity = sourceHRP.AssemblyLinearVelocity
        elseif dBV then
            dBV:Destroy(); dBV = nil
        end

        if hum and hum.PlatformStand ~= true then hum.PlatformStand = true end
    end

    local function releaseForces()
        if dBG then dBG:Destroy(); dBG = nil end
        if dBV then dBV:Destroy(); dBV = nil end
        if hum then
            if hum.PlatformStand == true then hum.PlatformStand = false end
            hum:ChangeState(Enum.HumanoidStateType.Running)
            -- Leave the clone alone otherwise: no CFrame/velocity/orientation overrides.
        end
    end

    -- Initialize once based on current source state
    do
        local sBG = sourceHRP:FindFirstChildOfClass("BodyGyro")
        local sBV = sourceHRP:FindFirstChildOfClass("BodyVelocity")
        if sBG or sBV then applyForces(sBG, sBV) else releaseForces() end
    end

    local hbConn = RunService.Heartbeat:Connect(function()
        if not (sourceHRP.Parent and destHRP.Parent) then return end
        local sBG = sourceHRP:FindFirstChildOfClass("BodyGyro")
        local sBV = sourceHRP:FindFirstChildOfClass("BodyVelocity")

        if sBG or sBV then
            applyForces(sBG, sBV)
        else
            releaseForces()
        end
    end)

    return function()
        if hbConn then hbConn:Disconnect() end
        if dBG then dBG:Destroy() end
        if dBV then dBV:Destroy() end
        if hum and savedPS ~= nil then hum.PlatformStand = savedPS end
    end
end


local function pickUpTrashCan(trashCan)
    local originalChar = player.Character
    if not originalChar or not originalChar.PrimaryPart then return end

    local srcHRP = originalChar:FindFirstChild("HumanoidRootPart")
    if not srcHRP then return end

    -- ✅ Save the MODEL pivot (more robust than HRP CFrame)
    local savedPivot = originalChar:GetPivot()

    if aimAssistEnabled then aimAssistEnabled = false end

    -- Create clone at the exact saved pivot
    local clone = createClone(originalChar)
    if not clone or not clone.PrimaryPart then
        warn("Clone failed to create in pickUpTrashCan"); return
    end
    stabilizeClone(clone)

    -- Force placement by model pivot (prevents HRP-vs-pivot mismatch)
    clone:PivotTo(savedPivot)

    -- Make sure its Humanoid isn't sitting or platform-standing initially
    local ch = clone:FindFirstChildOfClass("Humanoid")
	controlClone(clone)
    setupCamera(clone)
    pcall(function() syncAnimations(originalChar, clone) end)

    -- Now start moving the MAIN character; we delayed this until after clone is placed
    local canConnection = RunService.Heartbeat:Connect(function()
        movePlayerToTrashcan(trashCan)
    end)

    -- Mirror sFLY forces (or fall back to normal running per the fix above)
    local stopMirroring = mirrorFlyForces(srcHRP, clone:FindFirstChild("HumanoidRootPart"))

    local pickedUp = spamClickUntilPickedUp(trashCan)

    -- Cleanup
    if canConnection then canConnection:Disconnect() end
    if stopMirroring then stopMirroring() end

    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and clone:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = clone.HumanoidRootPart.CFrame
    end

    if cloneConnections[clone] then
        cloneConnections[clone]:Disconnect()
        cloneConnections[clone] = nil
    end
    clone:Destroy()

    restoreCamera()
    if not userAimAssistToggledOff then aimAssistEnabled = true end

    return pickedUp
end




--------------------------------------------------------------------------------
-- TOGGLE ON/OFF WITH “N” KEY
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.N then
        autoTrashGrabEnabled = not autoTrashGrabEnabled
        if autoTrashGrabEnabled then
            print("Auto Trash Grab ENABLED")
            setAllTrashCansCollide(false)
            enableTrashcanReturn() 
        else
            print("Auto Trash Grab DISABLED")
            setAllTrashCansCollide(true)
            disableTrashcanReturn()
        end
    end
end)

--== E  ⇒  teleport current clone to mouse pointer
local teleportKey = Enum.KeyCode.E
local mouse       = Players.LocalPlayer:GetMouse()

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or input.KeyCode ~= teleportKey then return end
    if cloneCharacter and cloneCharacter.PrimaryPart then
        local target = mouse.Hit                   -- 3-D point under cursor
        local root   = cloneCharacter.PrimaryPart  -- usually HumanoidRootPart

        -- keep clone’s facing; only move position
        root.CFrame = CFrame.new(
            target.X, target.Y + 3, target.Z,      -- +3 studs so it doesn’t clip
            select(4, root.CFrame:components())    -- orientation columns (4-12)
        )
    end
end)



--------------------------------------------------------------------------------
-- CONTINUOUS LOOK FOR TRASHCANS
--------------------------------------------------------------------------------

spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if autoTrashGrabEnabled then
            removeFreezeAndCanWalkIfExists()

            local liveFolder = workspace:FindFirstChild("Live")
            local playerFolder = liveFolder and liveFolder:FindFirstChild(player.Name)
            local hasTrashCan = playerFolder and playerFolder:FindFirstChild("Trash Can")

            if not hasTrashCan then
                local candidateCan = getFarthestTrashCan()
                if candidateCan then
                    local success = pickUpTrashCan(candidateCan)
                end
            end
        end
    end
end)








function extractAssetId(animId)
    return animId:match("rbxassetid://(%d+)")
end



-- === Load Fluent UI Libraries ===
Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()


local httpService = game:GetService("HttpService")
local animConfigFile = "FluentAimAssist_AnimConfig.json"
local animConfig = {}

-- Load existing config if it exists
if isfile and readfile and writefile then
    if isfile(animConfigFile) then
        local success, result = pcall(function()
            return httpService:JSONDecode(readfile(animConfigFile))
        end)
        if success and type(result) == "table" then
            animConfig = result
        else
            animConfig = {}
        end
    else
        -- Config file does not exist, use default empty table
        animConfig = {}
    end
else
    warn("File operations not supported. Animations config won't load or save.")
end

local function saveAnimConfig()
    if writefile then
        writefile(animConfigFile, httpService:JSONEncode(animConfig))
    end
end

animConfig.animations = animConfig.animations or {}

-- Ensure this code runs after your animConfig is loaded and execCmd is defined somewhere accessible.
-- Also ensure 'AnimationPlayed' is connected to 'Humanoid.AnimationPlayed' in onCharacterAdded or similar function.

local function AnimationPlayed(animationTrack)
    local animationId = animationTrack.Animation and animationTrack.Animation.AnimationId
    if not animationId then return end

    -- Extract the numeric asset ID
    local assetId = animationId:match("rbxassetid://(%d+)")
    if not assetId then return end

    -- Check if we have configuration for this animation
    local data = animConfig.animations and animConfig.animations[assetId]
    if not data then return end

    -- On Start command
    if data.onStart and data.onStart ~= "" then
        print("[Animation] Starting anim ID:", assetId, "Running onStart command:", data.onStart)
        execCmd(data.onStart)
    end

    -- When the animation stops, run the onEnd command if present
    animationTrack.Stopped:Connect(function()
        if data.onEnd and data.onEnd ~= "" then
            print("[Animation] Ending anim ID:", assetId, "Running onEnd command:", data.onEnd)
            execCmd(data.onEnd)
        end
    end)
end

player.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Disconnect previous connection if exists
    if animationPlayedConn then
        animationPlayedConn:Disconnect()
    end
    
    animationPlayedConn = humanoid.AnimationPlayed:Connect(AnimationPlayed)
end)

-- If character already exists
if player.Character and player.Character:FindFirstChild("Humanoid") then
    player.Character:FindFirstChild("Humanoid").AnimationPlayed:Connect(AnimationPlayed)
end



-- === Create Fluent Window ===
local Window = Fluent:CreateWindow({
    Title = "Fluent " .. Fluent.Version,
    SubTitle = "by dawid",
    TabWidth = 130,
    Size = UDim2.fromOffset(800, 600),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Define Tabs with Icons (AutoClicker tab removed)
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "crosshair" }),
    Prediction = Window:AddTab({ Title = "Prediction", Icon = "navigation" }),
    PullIn = Window:AddTab({ Title = "Pull-In", Icon = "arrow-down" }),
    Keybinds = Window:AddTab({ Title = "Keybinds", Icon = "keyboard" }),
    TempRotation = Window:AddTab({ Title = "Temp Rotation", Icon = "rotate-ccw" }),
    UltimateTemp = Window:AddTab({ Title = "Ultimate Temp", Icon = "star" }), 
    FOverride = Window:AddTab({ Title = "F Override", Icon = "shield" }),
    Animations = Window:AddTab({ Title = "Animations", Icon = "person-standing" }),
    VelocityLimiter = Window:AddTab({ Title = "Velocity Limiter", Icon = "gauge" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Waypoint = Window:AddTab({ Title = "Waypoint", Icon = "map-pin" }),
    Gravity = Window:AddTab({ Title = "Gravity", Icon = "arrow-down-to-line" })
}

local Options = Fluent.Options

-- === Initialize Services and Variables ===
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = Workspace.CurrentCamera

local Character = nil
local RootPart = nil
local Humanoid = nil

-- === Forward Declarations ===
local onToolEquipped
local activateTempRotationForSlot
local activateUltimateTempRotationForSlot
local deactivateFOverride
local deactivatePullIn
local AnimationPlayed
local updateAutoRotate
local getHotbarToolNames
local monitorHotbarChanges
local setDropdownValue
local ensureRotationMethod
local applyUltimateTempRotationForEquippedTool
local animationPlayedConn

local cooldownPresent = { [1] = false, [2] = false, [3] = false, [4] = false }


-- === Prediction Settings ===
local predictionSettings = {
    RegularAimXY = { reactionTime = 0.1, dampingFactor = 50, strength = 2 },
    RegularAimX = { reactionTime = 0.1, dampingFactor = 50, strength = 2 },
    FOverride = { 
        reactionTime = 0.1, 
        dampingFactor = 2, 
        strength = 1,
        inverseDampingEnabled = true
    }
}

-- === AutoRotate Settings ===
local regularAimAssistAutoRotateEnabled = true
local fOverrideAutoRotateEnabled = false

-- === F Override Variables ===
local fOverrideEnabled = true
local fOverrideRotationMethod = "X-Axis" -- "X-Axis" or "XY-Axis"
local fOverrideTargetingMethod = "closestToTorso" -- "closestToMouse" or "closestToTorso"
local fOverrideOnlyOnRightClick = false
local fOverrideOffOnRightClick = false
local noRotateOnRightClickForFOverride = false
local isFHeld = false -- Flag to track if F key is held down

local isFOverrideActive = false
local originalTargetingMethod = targetingMethod -- Initialize with current targeting method
local originalRotationMethod = rotationMethod -- Initialize with current rotation method

-- CHANGED: Keep track if the detected animation was TELEPORT_ANIMATION_ID
local detectedTeleportFromAnim = false

-- AutoSwitchRadius for conditional targeting
local autoSwitchRadius = 10 -- default value, configurable later via Fluent


-- === Temporary Rotation Handling via Number Keys ===
local keyRotationEnabled = { [1] = false, [2] = false, [3] = false, [4] = false }
local temporaryRotationKey = nil

-- === Temporary Rotation Settings (Per Toggle) ===
local tempRotationSettings = {
    [1] = {
        minTime = 2,
        maxTime = 5,
        addTime = 0.5,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 45,
        maxCFrameYAngleReverse = 45,
        rotationMethod = "X-Axis" -- Default rotation method for Key 1
    },
    [2] = {
        minTime = 2,
        maxTime = 5,
        addTime = 0.5,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 45,
        maxCFrameYAngleReverse = 45,
        rotationMethod = "X-Axis" -- Default rotation method for Key 2
    },
    [3] = {
        minTime = 2,
        maxTime = 5,
        addTime = 0.5,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 45,
        maxCFrameYAngleReverse = 45,
        rotationMethod = "X-Axis" -- Default rotation method for Key 3
    },
    [4] = {
        minTime = 2,
        maxTime = 5,
        addTime = 0.5,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 45,
        maxCFrameYAngleReverse = 45,
        rotationMethod = "X-Axis" -- Default rotation method for Key 4
    }
}

-- === Ultimate Temporary Rotation Settings (Per Toggle) ===
local ultimateTempRotationSettings = {
    [1] = {
        minTime = 3, -- Example settings, adjust as needed
        maxTime = 6,
        addTime = 0.7,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 60,
        maxCFrameYAngleReverse = 60,
        rotationMethod = "XY-Axis" -- Example rotation method for Ultimate Temp Key 1
    },
    [2] = {
        minTime = 3,
        maxTime = 6,
        addTime = 0.7,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 60,
        maxCFrameYAngleReverse = 60,
        rotationMethod = "XY-Axis"
    },
    [3] = {
        minTime = 3,
        maxTime = 6,
        addTime = 0.7,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 60,
        maxCFrameYAngleReverse = 60,
        rotationMethod = "XY-Axis"
    },
    [4] = {
        minTime = 3,
        maxTime = 6,
        addTime = 0.7,
        timer = 0,
        active = false,
        maxCFrameYAngleForward = 60,
        maxCFrameYAngleReverse = 60,
        rotationMethod = "XY-Axis"
    }
}

-- Table to keep track of equipped tools in Ultimate Mode
local ultimateEquippedTools = {}

-- === Main Tab Angle Limit Settings ===
maxCFrameYAngleForward = 45 -- degrees
maxCFrameYAngleReverse = 45 -- degrees
angleLimitDistance = 20 -- studs

-- === Right Click AutoRotate Variables ===
local rightClickHeld = false
local noRotateOnRightClick = false

-- === Pull-In Feature Variables ===
pullInEnabled = true
pullVelocity = 2
pullDistanceRange = 50

-- === Pull-In Configuration Variables ===
pullInStartTime = 1
pullInEndTime = 2
pullStoppingDistance = 1

-- === Velocity Limiter Variables ===
closeRangeLimitDistance = 10
closeRangeVelocityLimit = 30
overallPullInVelocityLimiter = 50

-- === Pull-In State Variables ===
activePullIns = {}
pullInActive = false

-- === Pull-In Direction Method ===
local pullDirectionMethod = "XY" -- "XY" or "X"
local pullTargetingMethod = "closestToMouse" -- Default value matching the dropdown's default

-- === Waypoint Variables ===
waypointPosition = Vector3.new(1173, 2532, -458)
returnToWaypointEnabled = false
local waypointConnection = nil

-- === Aim Assist Settings ===
local targetingMethod = "closestToMouse" -- "closestToMouse" or "closestToTorso"
local rotationMethod = "XY-Axis" -- "X-Axis" or "XY-Axis"
local baseRotationMethod = rotationMethod -- New variable to track the user's set rotation method
keybindsEnabled = true
aimAssistOnlyOnRightClick = false
aimAssistOffOnRightClick = false
local targetDeadPlayers = false

local animIds = {}

-- === Excluded Animation IDs ===
local excludedAnimIds = {
    ["507768375"] = true,
    ["180435571"] = true,
    ["14516273501"] = true, -- Newly added Animation ID to exclude
    -- Add more Animation IDs here as needed
}

-- === Clipboard Utility Functions ===
function copyToClipboard(txt)
    if everyClipboard then
        everyClipboard(tostring(txt))
        notify("Clipboard", "Copied to clipboard")
    else
        notify("Clipboard", "Your exploit doesn't have the ability to use the clipboard")
    end
end

-- Attempt to assign the available clipboard function
everyClipboard = setclipboard or copyToClipboard or set_clipboard or (Clipboard and Clipboard.set)


function copyanimidfrombutton()
    local player = game.Players.LocalPlayer
    if not player.Character then
        notify("Animations", "Character not found.")
        return
    end

    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        notify("Animations", "Humanoid not found.")
        return
    end

    animIds = {} -- Clear before collecting
    local playingAnims = humanoid:GetPlayingAnimationTracks()

    for _, animTrack in ipairs(playingAnims) do
        if animTrack and animTrack.Animation and animTrack.Animation.AnimationId then
            local animationId = animTrack.Animation.AnimationId
            local assetId = animationId:match("rbxassetid://(%d+)")

            if assetId and not excludedAnimIds[assetId] then
                table.insert(animIds, assetId)
            end
        end
    end

    if #animIds > 0 then
        local textToCopy = table.concat(animIds, "")
        copyToClipboard(textToCopy)
    else
        notify("Animations", "No animations to copy")
    end
end

-- Function to get the keys of a table
local function table_keys(tbl)
    local keyset = {}
    for k, _ in pairs(tbl) do
        table.insert(keyset, k)
    end
    return keyset
end

-- Function to get the Live folder
local function getLiveFolder()
    return Workspace:FindFirstChild("Live")
end

-- Function to get the player's folder within Live
local function getPlayerFolder(liveFolder)
    if liveFolder then
        return liveFolder:FindFirstChild(player.Name)
    end
    return nil
end

local function isUltimateModeActive()
    local liveFolder = workspace:FindFirstChild("Live")
    if liveFolder then
        local playerFolder = liveFolder:FindFirstChild(game.Players.LocalPlayer.Name)
        if playerFolder and playerFolder:GetAttribute("Ulted") then
            return true
        end
    end
    return false
end



-- Keep track of UI elements for each animation
local animationSections = {}

local function refreshAnimationsDropdown()
    local animationIds = {}
    for animId, _ in pairs(animConfig.animations) do
        table.insert(animationIds, animId)
    end
    Options.AnimationsDropdown:SetValues(animationIds)
    Options.AnimationsDropdown:SetValue(nil) -- Reset selected value
end

local function addAnimationSettingsInputs(animId)
    -- Create a new section for this animation's settings
    local section = Tabs.Animations:AddSection("Settings for Animation ID: " .. animId)

    local currentData = animConfig.animations[animId] or {onStart = "", onEnd = ""}

    local StartCommandInput = Tabs.Animations:AddInput("StartCommand_" .. animId, {
        Title = "Start Command for " .. animId,
        Description = "Command to run at animation start",
        Default = currentData.onStart,
        Placeholder = "e.g., tpwalk 10",
        Numeric = false,
        Finished = true
    })

    StartCommandInput:OnChanged(function(value)
        if animConfig.animations[animId] then
            animConfig.animations[animId].onStart = value
            saveAnimConfig()
        end
    end)

    local EndCommandInput = Tabs.Animations:AddInput("EndCommand_" .. animId, {
        Title = "End Command for " .. animId,
        Description = "Command to run at animation end",
        Default = currentData.onEnd,
        Placeholder = "e.g., tpstop",
        Numeric = false,
        Finished = true
    })

    EndCommandInput:OnChanged(function(value)
        if animConfig.animations[animId] then
            animConfig.animations[animId].onEnd = value
            saveAnimConfig()
        end
    end)

    animationSections[animId] = {
        Section = section,
        StartInput = StartCommandInput,
        EndInput = EndCommandInput
    }
end

local function removeAnimationSettingsInputs(animId)
    local inputs = animationSections[animId]
    if inputs then
        if inputs.StartInput then
            inputs.StartInput:Destroy()
        end
        if inputs.EndInput then
            inputs.EndInput:Destroy()
        end
        if inputs.Section then
            Section.Root:Destroy() 
            Section = nil
        end
        animationSections[animId] = nil
    end
end



-- === Update AutoRotate Function ===
local function updateAutoRotate()
    if not Character or not Humanoid then return end

    if Humanoid:GetState() == Enum.HumanoidStateType.FallingDown or isRagdollPresent() then
        Humanoid.AutoRotate = false
        return
    end

    -- === Priority 2: Handle F Override and F Held Conditions ===
    if isFOverrideActive and isFHeld then
        if fOverrideOnlyOnRightClick then
            if not rightClickHeld then
                Humanoid.AutoRotate = true
            else
                -- Disable AutoRotate when both F and Right Click are held
                Humanoid.AutoRotate = false
            end
        else
            -- Disable AutoRotate when F is held (if not only on Right Click)
            Humanoid.AutoRotate = false
        end

        -- === New: Handle F Override Off On Right Click ===
        if fOverrideOffOnRightClick and rightClickHeld then
            -- Disable all regular aim assist
            Humanoid.AutoRotate = true
            return
        end

        return
    end

    -- === Priority 3: Aim Assist Off On Right Click ===
    if aimAssistOffOnRightClick and rightClickHeld then
        Humanoid.AutoRotate = true
        return
    end

    -- === Priority 4: Aim Assist Only On Right Click ===
    if aimAssistOnlyOnRightClick then
        if rightClickHeld then
            Humanoid.AutoRotate = false
        else
            Humanoid.AutoRotate = true
        end
        return
    end

    -- === Priority 5: No Rotate On Right Click ===
    if noRotateOnRightClick and rightClickHeld then
        Humanoid.AutoRotate = false
        return
    end

    -- === Priority 6: Aim Assist Enabled ===
    if aimAssistEnabled and regularAimAssistAutoRotateEnabled then
        Humanoid.AutoRotate = false
        return
    end

    -- === Fallback: Enable AutoRotate if none of the above conditions are met ===
    Humanoid.AutoRotate = true
end



local activeDisableAnims = {} -- Table to track active animations disabling aim assist

-- === Turn-Off Animations Table ===
local turnoffanims = {
    {
        AnimationId = "rbxassetid://14542032218", -- Existing animation
        Mode = "end", -- Options: "time" or "end"
        Character = "all"
        -- Duration = 9, -- Duration in seconds (only for Mode "time")
    }, 
    {
        AnimationId = "rbxassetid://10470104242", -- New animation ID
        Mode = "end", -- Choose "time" if you want a duration-based action
        Character = "all"
        -- Duration = 5, -- Uncomment and set this if Mode = "time"
    },
    {
        AnimationId = "rbxassetid://12309835105", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://13501296372", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://134494086123052", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://17799224866", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://76530443909428", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://105811521074269", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://18440406788", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://18182425133", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://71060716968719", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://96865367566704", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://81827172076105", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
--[[
    {
        AnimationId = "rbxassetid://77727115892579", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
]]
    {
        AnimationId = "rbxassetid://94395585475029", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "Hunter"
    },
    {
        AnimationId = "rbxassetid://17278415853", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "all"
    },
    {
        AnimationId = "rbxassetid://17889080495", -- Only if Character == "Hunter"
        Mode = "end",
        Character = "all"
    },
    -- Add more animations as needed
    -- {
    --     AnimationId = "rbxassetid://17278415853",
    --     Mode = "end",
    --     Character = "all" or "Hunter"
    -- },
}



-- Function to get the player's Character attribute from the Live folder
local function getPlayerCharacterAttribute()
    local liveFolder = workspace:FindFirstChild("Live")
    if liveFolder then
        local playerFolder = liveFolder:FindFirstChild(player.Name)
        if playerFolder then
            return playerFolder:GetAttribute("Character")
        end
    end
    return nil
end

local playerCharacterValue = getPlayerCharacterAttribute()
print("Player Character Attribute:", playerCharacterValue)

local function monitorUltedAttribute()
    local function checkForUlted()
        local liveFolder = workspace:FindFirstChild("Live")
        if liveFolder then
            local playerFolder = liveFolder:FindFirstChild(game.Players.LocalPlayer.Name)
            if playerFolder then
                if playerFolder:GetAttribute("Ulted") then
                    log("Ultimate Mode Activated", "info")
                    updateAutoRotate() -- Your existing function to update aim assist
                    return true
                end
            end
        end
        return false
    end
end




-- Initial Setup: Monitor existing Live and Player folders
local liveFolder = getLiveFolder()
if liveFolder then
    local playerFolder = getPlayerFolder(liveFolder)
    if playerFolder then
        monitorUltedAttribute()
    end
end

-- Handle cases where Live folder is added after script starts
Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Live" and child:IsA("Folder") then
        print("[ToolMonitor] Live folder added to workspace.")
        local newLiveFolder = child
        local playerFolder = getPlayerFolder(newLiveFolder)
        if playerFolder then
            monitorUltedAttribute()
        end
    end
end)

-- Handle cases where Player folder is added within Live after Live exists
if liveFolder then
    liveFolder.ChildAdded:Connect(function(child)
        if child.Name == player.Name and child:IsA("Folder") then
            print("[ToolMonitor] Player folder added within Live.")
            monitorUltedAttribute()
        end
    end)
end

-- Function to teleport player to Waypoint
local function teleportToWaypoint()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = CFrame.new(waypointPosition)
    end
end

-- Function to start returning to Waypoint
local function startReturningToWaypoint()
    if waypointConnection then return end -- Prevent multiple connections
    returnToWaypointEnabled = true
    waypointConnection = RunService.Heartbeat:Connect(function()
        WPTheartbeatStart = tick() -- Start tracking time
        if returnToWaypointEnabled then
            teleportToWaypoint()
        else
            waypointConnection:Disconnect()
            waypointConnection = nil
        end
        WPTheartbeatEnd = tick()
        logFunctionExecution("wptconnection", WPTheartbeatEnd - WPTheartbeatStart)
    end)
end

local function stopReturningToWaypoint()
    returnToWaypointEnabled = false
    if waypointConnection then
        waypointConnection:Disconnect()
        waypointConnection = nil
    end
end

-- Calculate Direction Based on Method
local function CalculateDirection(targetPosition, playerPosition, method)
    local directionVector = targetPosition - playerPosition
    if method == "XY" then
        return directionVector.Unit
    elseif method == "X" then
        return Vector3.new(directionVector.X, 0, directionVector.Z).Unit
    else
        log("Invalid Pull Direction Method. Defaulting to XY.", "warn")
        return directionVector.Unit
    end
end

-- Calculate Force Magnitude Based on Humanoid RigType
local function CalculateForceMagnitude(pullVelocity, humanoid)
    local rigType = humanoid.RigType
    local multiplier = (rigType == Enum.HumanoidRigType.R6) and 400 or 800
    return pullVelocity * humanoid.WalkSpeed * multiplier
end

-- Apply Pull-In Force with BodyMover
local function ApplyPullInForce(pullIn, direction, forceMagnitude)
    local bodyMover = pullIn.BodyMover
    if not bodyMover then
        bodyMover = Instance.new("BodyForce")
        bodyMover.Name = "BodyForce"
        bodyMover.Parent = RootPart
        pullIn.BodyMover = bodyMover
    end
    bodyMover.Force = direction * forceMagnitude
end

-- Limit Velocity Towards Target
local function LimitVelocity(direction, currentVelocity, limiter)
    local velocityTowards = direction:Dot(currentVelocity)
    if velocityTowards > limiter then
        return currentVelocity - direction * (velocityTowards - limiter)
    end
    return currentVelocity
end

-- Ensure Rotation Method Consistency
local function ensureRotationMethod()
    log("Rotation Method has been updated to: " .. rotationMethod)
end


local liveFolder = getLiveFolder()
local playerFolder = getPlayerFolder(liveFolder)

local function isAnyTempRotationActive()
    for i = 1, 4 do
        if tempRotationSettings[i].active or ultimateTempRotationSettings[i].active then
            return true
        end
    end
    return false
end

local uiUpdatesEnabled = false

-- Set Dropdown Value Safely with Global UI Update Control
local function setDropdownValue(option, value, validValues, updateUI)
    if not uiUpdatesEnabled then return end -- Exit early if UI updates are disabled

    if table.find(validValues, value) then
        if updateUI ~= false then
            Options[option]:SetValue(value)
        end
        log(option .. " set to: " .. value)
    else
        if updateUI ~= false then
            Options[option]:SetValue(validValues[1])
        end
        log("Invalid " .. option .. " selected. Reverting to default: " .. validValues[1], "warn")
    end
end


if playerFolder then
    local lastCombo = playerFolder:GetAttribute("Combo")

    playerFolder:GetAttributeChangedSignal("Combo"):Connect(function()
        local currentCombo = playerFolder:GetAttribute("Combo")

        -- Check if Combo changed from 3 to 4
        if lastCombo == 2 and currentCombo == 3 then
            -- Proceed only if no other temp rotation is active
            if not isAnyTempRotationActive() then
                -- Temporarily set rotationMethod to "X-Axis"
                rotationMethod = "X-Axis"
                setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
                updateAutoRotate()
                log("Temporary rotation method set to X-Axis due to Combo change to 4.", "info")

                local restored = false
                local restoreConnection

                -- Listen for Combo changes to 1 or 5 to restore early
                restoreConnection = playerFolder:GetAttributeChangedSignal("Combo"):Connect(function()
                    local newCombo = playerFolder:GetAttribute("Combo")
                    if newCombo == 1 then
                        -- Restore to baseRotationMethod
                        rotationMethod = baseRotationMethod
                        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
                        updateAutoRotate()
                        log("Rotation method reverted to baseRotationMethod due to Combo change to " .. newCombo, "info")

                        restored = true
                        if restoreConnection then
                            restoreConnection:Disconnect()
                        end
                    end
                end)

                -- Restore after 1 second if not restored early
                delay(2, function()
                    if not restored then
                        rotationMethod = baseRotationMethod
                        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
                        updateAutoRotate()
                        log("Rotation method reverted to baseRotationMethod after 1 second.", "info")
                    end
                    if restoreConnection then
                        restoreConnection:Disconnect()
                    end
                end)
            else
                log("Combo change to 4 ignored due to active temporary rotation.", "warn")
            end
        end

        -- Update lastCombo for next comparison
        lastCombo = currentCombo
    end)
else
    warn("PlayerFolder not found. Cannot detect Combo changes.")
end


-- Global Flags





local activeHotbarSlot = nil
local lastEquippedSlot = nil -- To track the last equipped slot
local existingChildAddedConnection -- Variable to hold the existing ChildAdded connection

-- Configurable max time for detection (in seconds)
local maxDetectionTime = 0.35 -- Change this value to set your desired detection time


local function WaitForChildWithTimeout(parent, childName, timeout)
    local child = parent:FindFirstChild(childName)
    local startTime = tick()
    while not child do
        if tick() - startTime > timeout then
            return nil -- Timeout occurred
        end
        child = parent:FindFirstChild(childName)
    end
    return child
end


local function isOnScreen(playerToCheck)
    local character = playerToCheck.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if character and rootPart and ((humanoid and humanoid.Health > 0) or targetDeadPlayers) then
        local screenPoint, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(rootPart.Position)
        return onScreen and screenPoint.Z > 0
    end
    return false
end


local function getClosestPlayerToMouse()
    local closestPlayer
    local shortestDistance = math.huge
    local mouseLocation = UserInputService:GetMouseLocation()

    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherCharacter = otherPlayer.Character
            local otherHumanoid = otherCharacter and otherCharacter:FindFirstChild("Humanoid")
            local otherRootPart = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")

            if otherCharacter and otherRootPart and ((otherHumanoid and otherHumanoid.Health > 0) or targetDeadPlayers) then
                if isOnScreen(otherPlayer) then
                    local screenPoint, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(otherRootPart.Position)
                    local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mouseLocation).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = otherPlayer
                    end
                end
            end
        end
    end

    return closestPlayer
end


local function getClosestPlayerToTorsoUnlimited()
    local closestPlayer
    local shortestDistance = math.huge

    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherCharacter = otherPlayer.Character
            local otherHumanoid = otherCharacter and otherCharacter:FindFirstChild("Humanoid")
            local otherRootPart = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")

            if otherCharacter and otherRootPart and ((otherHumanoid and otherHumanoid.Health > 0) or targetDeadPlayers) then
                local distance = (otherRootPart.Position - RootPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = otherPlayer
                end
            end
        end
    end

    return closestPlayer
end

local function getClosestPlayerToTorsoLimited()
    local closestPlayer
    local shortestDistance = math.huge

    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherCharacter = otherPlayer.Character
            local otherHumanoid = otherCharacter and otherCharacter:FindFirstChild("Humanoid")
            local otherRootPart = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")

            if otherCharacter and otherRootPart and ((otherHumanoid and otherHumanoid.Health > 0) or targetDeadPlayers) then
                local distance = (otherRootPart.Position - RootPart.Position).Magnitude
                if distance < shortestDistance and distance <= pullDistanceRange then
                    shortestDistance = distance
                    closestPlayer = otherPlayer
                end
            end
        end
    end

    return closestPlayer
end


-- Check if Player is Allowed to Turn
local function isPlayerAllowedToTurn()
    if not Character or not Humanoid then return false end
    local state = Humanoid:GetState()
    return state == Enum.HumanoidStateType.Running or
           state == Enum.HumanoidStateType.Freefall or
           state == Enum.HumanoidStateType.Jumping
end


-- === Prediction Function ===
local function PredictPosition(targetPosition, targetVelocity, reactionTime, dampingFactor, strength)
    local directionVector = targetVelocity * reactionTime * strength
    local dampingMultiplier = 1

    local playerPosition = RootPart.Position
    local distance = (playerPosition - targetPosition).Magnitude

    if distance < dampingFactor and dampingFactor > 0 then
        dampingMultiplier = distance / dampingFactor
    end

    return targetPosition + (directionVector * dampingMultiplier)
end

local function PredictPositionFOverride(targetPosition, targetVelocity, reactionTime, dampingFactor, strength, inverseDampingEnabled)
    local directionVector = targetVelocity * reactionTime * strength
    local dampingMultiplier = 1

    local playerPosition = RootPart.Position
    local distance = (playerPosition - targetPosition).Magnitude

    if inverseDampingEnabled then
        if distance < dampingFactor then
            dampingMultiplier = 1 + ((dampingFactor - distance) / dampingFactor) -- Amplify for closer targets
        else
            dampingMultiplier = 1 / ((distance / dampingFactor) + 1) -- Reduce for farther targets
        end
    else
        if distance < dampingFactor and dampingFactor > 0 then
            dampingMultiplier = distance / dampingFactor
            log("Standard Damping Applied. Damping Multiplier = " .. dampingMultiplier, "info")
        end
    end

    return targetPosition + (directionVector * dampingMultiplier)
end

activateTempRotationForSlot = function(slot)
    log("Attempting to activate Temp Rotation for slot " .. slot, "info")
    if keyRotationEnabled[slot] then
        log("Key Rotation Enabled for slot " .. slot, "info")
    else
        print("Key Rotation Disabled for slot " .. slot .. "; Temp Rotation will not activate.", "warn")
        return
    end

    if not tempRotationSettings[slot].active then
        tempRotationSettings[slot].active = true
        log("Temp Rotation set to active for slot " .. slot, "info")
        
        rotationMethod = tempRotationSettings[slot].rotationMethod
        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
        tempRotationSettings[slot].timer = tempRotationSettings[slot].minTime
        print("Temp Rotation activated for hotbar slot " .. slot .. " with method: " .. rotationMethod, "info")
        updateAutoRotate()
    else
        print("Temp Rotation already active for slot " .. slot, "info")
    end
end

deactivateTempRotationForSlot = function(slot)
    if tempRotationSettings[slot].active then
        tempRotationSettings[slot].active = false
        log("Temp Rotation deactivated for slot " .. slot, "info")

        -- Revert to baseRotationMethod
        rotationMethod = baseRotationMethod
        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
        log("Restored Rotation Method to base: " .. rotationMethod, "info")

        updateAutoRotate()
    else
        log("Temp Rotation not active for slot " .. slot, "warn")
    end
end



activateUltimateTempRotationForSlot = function(slot)
    if keyRotationEnabled[slot] and not ultimateTempRotationSettings[slot].active then
        ultimateTempRotationSettings[slot].active = true
        log("Ultimate Temp Rotation set to active for slot " .. slot .. " with method: " .. ultimateTempRotationSettings[slot].rotationMethod, "info")

        rotationMethod = ultimateTempRotationSettings[slot].rotationMethod
        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
        ultimateTempRotationSettings[slot].timer = ultimateTempRotationSettings[slot].minTime
        log("Ultimate Temp Rotation activated for hotbar slot " .. slot .. " with method: " .. rotationMethod, "info")
        updateAutoRotate()
    else
        log("Ultimate Temp Rotation already active or key rotation disabled for slot " .. slot .. ".", "info")
    end
end

deactivateUltimateTempRotationForSlot = function(slot)
    if ultimateTempRotationSettings[slot].active then
        ultimateTempRotationSettings[slot].active = false
        log("Ultimate Temp Rotation deactivated for slot " .. slot .. ".", "info")

        -- Revert to baseRotationMethod
        rotationMethod = baseRotationMethod
        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
        log("Restored Rotation Method to base: " .. rotationMethod, "info")

        updateAutoRotate()
    else
        log("Ultimate Temp Rotation not active for slot " .. slot .. ".", "warn")
    end
end




-- Call this function during Initial Setup
if liveFolder then
    local playerFolder = getPlayerFolder(liveFolder)
    if playerFolder then
        monitorUltedAttribute()
    end
end

local cooldownMonitorInitialized = false

local function monitorCooldownFrames()
    if cooldownMonitorInitialized then
        return
    end
    cooldownMonitorInitialized = true

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        warn("[CooldownMonitor] PlayerGui not found.")
        return
    end

    local hotbar = playerGui:FindFirstChild("Hotbar")
    if not hotbar then
        warn("[CooldownMonitor] Hotbar not found in PlayerGui.")
        return
    end

    local backpack = hotbar:FindFirstChild("Backpack")
    if not backpack then
        warn("[CooldownMonitor] Backpack not found in Hotbar.")
        return
    end

    local hotbarFolder = backpack:FindFirstChild("Hotbar")
    if not hotbarFolder then
        warn("[CooldownMonitor] Hotbar folder not found within Backpack.")
        return
    end

    -- Iterate through each slot (1-4)
    for i = 1, 4 do
        local slotName = tostring(i)
        local slotFolder = hotbarFolder:FindFirstChild(slotName)
        if slotFolder then
            local baseFolder = slotFolder:FindFirstChild("Base")
            if baseFolder then
                -- Function to handle Cooldown addition
                local function onCooldownAdded(child)
                    if child.Name == "Cooldown" then
                        print("Cooldown detected in hotbar slot " .. i, "info")
                        activateTempRotationForSlot(i)

                        if isUltimateModeActive() then
                            activateUltimateTempRotationForSlot(i)
                        end
                    end
                end

                -- Function to handle Cooldown removal (optional)
                local function onCooldownRemoved(child)
                    if child.Name == "Cooldown" then
                        log("Cooldown removed from hotbar slot " .. i, "info")
                        cooldownPresent[i] = false
                        -- No re-activation here, just marking slot available for future activations when cooldown reappears
                    end
                end

                -- Connect ChildAdded and ChildRemoved events
                baseFolder.ChildAdded:Connect(onCooldownAdded)
                baseFolder.ChildRemoved:Connect(onCooldownRemoved)

                -- Check if Cooldown already exists at script start
                local existingCooldown = baseFolder:FindFirstChild("Cooldown")
                if existingCooldown then
                    if not cooldownPresent[i] then
                        cooldownPresent[i] = true
                        log("Existing Cooldown found in hotbar slot " .. i .. " at start", "info")
                        activateTempRotationForSlot(i)

                        if isUltimateModeActive() then
                            activateUltimateTempRotationForSlot(i)
                        end
                    else
                        log("Existing Cooldown found in slot " .. i .. " but cooldownPresent is already true, no re-activation.", "info")
                    end
                end
            else
                warn("[CooldownMonitor] Base folder not found in hotbar slot " .. i)
            end
        else
            warn("[CooldownMonitor] Hotbar slot " .. i .. " not found in Hotbar.")
        end
    end
end

-- Add Cooldown frame monitoring
monitorCooldownFrames()

-- === Aim Stabilizer Functions ===

local function AimStabilizerXY(targetHumanoidRoot, reactionTime, dampingFactor, strength, tempKey)
    if Humanoid:GetState() == Enum.HumanoidStateType.FallingDown or isRagdollPresent() then return end

    local targetCharacter = targetHumanoidRoot.Parent
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")

    if not (targetCharacter and targetHumanoidRoot and ((targetHumanoid and targetHumanoid.Health > 0) or targetDeadPlayers)) then
        return
    end

    local targetPosition = targetHumanoidRoot.Position
    local targetVelocity = targetHumanoidRoot.Velocity

    -- Determine which prediction function to use
    local predictedPosition
    if isFOverrideActive and predictionSettings.FOverride.strength > 0 then
        predictedPosition = PredictPositionFOverride(
            targetPosition,
            targetVelocity,
            predictionSettings.FOverride.reactionTime,
            predictionSettings.FOverride.dampingFactor,
            predictionSettings.FOverride.strength,
            predictionSettings.FOverride.inverseDampingEnabled
        )
    else
        predictedPosition = PredictPosition(targetPosition, targetVelocity, reactionTime, dampingFactor, strength)
    end

    local playerPosition = RootPart.Position
    local directionVector = predictedPosition - playerPosition
    local distance = directionVector.Magnitude

    if distance == 0 then return end

    local direction = directionVector.Unit

    -- Apply angle limits only if F Override is NOT active
    if not isFOverrideActive then
        local maxForward = tempKey and tempRotationSettings[tempKey].maxCFrameYAngleForward or maxCFrameYAngleForward
        local maxReverse = tempKey and tempRotationSettings[tempKey].maxCFrameYAngleReverse or maxCFrameYAngleReverse

        local applyAngleLimit = tempKey and tempRotationSettings[tempKey].active or (distance <= angleLimitDistance)
        if applyAngleLimit then
            local angle = math.deg(math.asin(direction.Y))
            angle = math.clamp(angle, -maxReverse, maxForward)
            direction = Vector3.new(direction.X, math.sin(math.rad(angle)), direction.Z).Unit
        end
    end

    -- Update CFrame efficiently
    RootPart.CFrame = CFrame.new(playerPosition, playerPosition + direction)
end

local function AimStabilizerX(targetHumanoidRoot, reactionTime, dampingFactor, strength, tempKey)
    -- 1) Basic validation
    if Humanoid:GetState() == Enum.HumanoidStateType.FallingDown or isRagdollPresent() then return end
    if not (targetHumanoidRoot and RootPart) then return end
    
    local targetCharacter = targetHumanoidRoot.Parent
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
    if not (targetCharacter and targetHumanoid and (targetHumanoid.Health > 0 or targetDeadPlayers)) then
        return
    end

    -- 2) Calculate predicted target position (same logic you had before)
    local targetPosition = targetHumanoidRoot.Position
    local targetVelocity = targetHumanoidRoot.Velocity
    local predictedPosition
    if isFOverrideActive and predictionSettings.FOverride.strength > 0 then
        predictedPosition = PredictPositionFOverride(
            targetPosition,
            targetVelocity,
            predictionSettings.FOverride.reactionTime,
            predictionSettings.FOverride.dampingFactor,
            predictionSettings.FOverride.strength,
            predictionSettings.FOverride.inverseDampingEnabled
        )
    else
        predictedPosition = PredictPosition(targetPosition, targetVelocity, reactionTime, dampingFactor, strength)
    end

    -- 3) Get our current position and LookVector
    local playerPosition = RootPart.Position
    local oldLook = RootPart.CFrame.LookVector

    -- 4) Extract the old pitch from current LookVector
    --    pitch = arcsin(Y)   (range ~ -π/2 to +π/2)
    local oldPitch = math.asin(oldLook.Y)

    -- 5) Compute the new horizontal (XZ) direction toward the predicted target
    local targetXZ = Vector3.new(predictedPosition.X, playerPosition.Y, predictedPosition.Z) 
        -- Force same Y-level as player
    local dirXZ = targetXZ - playerPosition
    if dirXZ.Magnitude < 0.001 then
        return -- Already on top of the target
    end
    dirXZ = dirXZ.Unit

    -- 6) Rebuild a final direction vector that keeps our old pitch but uses new yaw
    local cosPitch = math.cos(oldPitch)
    local finalDir = Vector3.new(
        dirXZ.X * cosPitch,   -- X
        math.sin(oldPitch),   -- Y
        dirXZ.Z * cosPitch    -- Z
    )

    -- 7) Use CFrame.lookAt to avoid Euler flips
    RootPart.CFrame = CFrame.lookAt(playerPosition, playerPosition + finalDir)
end




-- === Pull-In Activation and Deactivation Functions ===

-- Activate Pull-In for a Target
activatePullIn = function(target)
    local targetCharacter = target and target.Character
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
    local targetHumanoidRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

    if targetCharacter and targetHumanoid and targetHumanoidRoot and targetHumanoid.Health > 0 then
        -- Proceed to activate pull-in
        -- Create a new pull-in instance
        local pullIn = {
            Target = target,
            ActivationTime = tick(),
            StartTime = pullInStartTime or 1,
            EndTime = pullInEndTime or 2,
            Started = false,
            BodyMover = Instance.new("BodyForce")
        }
        pullIn.BodyMover.Parent = RootPart
        pullIn.BodyMover.Force = Vector3.new(0, 0, 0)

        table.insert(activePullIns, pullIn)
        pullInActive = true
        log("Pull-In activated towards: " .. target.Name)
    else
        log("Cannot activate Pull-In; Target is invalid or dead.", "warn")
    end
end

-- Deactivate Pull-In for a Target
deactivatePullIn = function(pullIn)
    if pullIn and pullIn.BodyMover then
        pullIn.BodyMover:Destroy()
        pullIn.BodyMover = nil
    end
    -- Remove pull-in from activePullIns
    for index, p in ipairs(activePullIns) do
        if p == pullIn then
            table.remove(activePullIns, index)
            break
        end
    end
    log("Pull-In deactivated for target: " .. (pullIn.Target and pullIn.Target.Name or "Unknown"))
end

-- === F Override Activation Functions ===


activateFOverride = function()
    if isFOverrideActive then return end
    isFOverrideActive = true
    
    -- Save the current rotationMethod if not already saved
    originalRotationMethod = rotationMethod
    
    rotationMethod = fOverrideRotationMethod
    setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"}, false)
    log("F Override activated with rotation method: " .. rotationMethod, "info")
    updateAutoRotate()
end

deactivateFOverride = function()
    if not isFOverrideActive then return end
    isFOverrideActive = false
    
    -- Revert to baseRotationMethod
    rotationMethod = baseRotationMethod
    log("F Override deactivated. Restored Rotation Method to base: " .. rotationMethod, "info")
    
    setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"}, false)
    updateAutoRotate()
end

-- === Main SaveManager and InterfaceManager Setup ===
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Set the folder where main configs will be saved
InterfaceManager:SetFolder("FluentAimAssist/config")
SaveManager:SetFolder("FluentAimAssist/config")

-- Build the main interface and config sections
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- === Setup Fluent UI Controls ===
do
    -- === Main Tab Controls ===
    -- CHANGED: Add AimAssist toggle callback that sets userAimAssistToggledOff
    Tabs.Main:AddToggle("AimAssistEnabled", {
        Title = "Aim Assist",
        Default = aimAssistEnabled,
        Description = "Enable or disable aim assist."
    }):OnChanged(function(value)
        aimAssistEnabled = value
        
        -- CHANGED: If user sets this to false, we remember that the user specifically wants it off.
        if not value then
            userAimAssistToggledOff = true  -- CHANGED: once off, we mark the user’s preference as OFF
        else
            userAimAssistToggledOff = false
            -- CHANGED: Removed the old code which automatically re‐enabled aimAssist if animations ended. 
            -- Now, if user toggles ON, we set aimAssistEnabled=true right away. If user toggles OFF, we don't forcibly turn it back on later.
        end

        updateAutoRotate()
    end)

    -- CHANGED: Add Input for autoSwitchRadius
    Tabs.Main:AddInput("AutoSwitchRadius", {
        Title = "Auto Switch Radius",
        Default = tostring(autoSwitchRadius),
        Placeholder = "20",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            autoSwitchRadius = num
        else
            autoSwitchRadius = 20
            Options.AutoSwitchRadius:SetValue("20")
        end
    end)

    Tabs.Main:AddDropdown("TargetingMethod", {
        Title = "Targeting Method",
        Values = {"Closest to Mouse", "Closest to Torso"},
        Multi = false,
        Default = "Closest to Mouse"
    }):OnChanged(function(value)
        if value == "Closest to Mouse" then
            targetingMethod = "closestToMouse"
        elseif value == "Closest to Torso" then
            targetingMethod = "closestToTorso"
        else
            targetingMethod = "closestToMouse"
            log("Invalid Targeting Method selected. Reverting to default.", "warn")
        end
        -- No need to call updateAutoRotate() here as it doesn't affect AutoRotate directly
    end)

    Tabs.Main:AddDropdown("RotationMethod", {
        Title = "Rotation Method",
        Values = {"X-Axis", "XY-Axis"},
        Multi = false,
        Default = baseRotationMethod,
    }):OnChanged(function(value)
        if value == "X-Axis" then
            rotationMethod = "X-Axis"
            baseRotationMethod = "X-Axis"
        elseif value == "XY-Axis" then
            rotationMethod = "XY-Axis"
            baseRotationMethod = "XY-Axis"
        else
            rotationMethod = "X-Axis"
            baseRotationMethod = "X-Axis"
            log("Invalid Rotation Method selected. Reverting to default.", "warn")
        end
        ensureRotationMethod()
    end)

    Tabs.Main:AddToggle("NoRotateOnRightClick", {
        Title = "No Rotate on Right Click",
        Default = noRotateOnRightClick,
        Description = "Keep automatic rotation enabled unless right-clicking."
    }):OnChanged(function(value)
        noRotateOnRightClick = value
        updateAutoRotate()
    end)

    Tabs.Main:AddToggle("AimAssistOnlyOnRightClick", {
        Title = "Aim Assist Only On Right Click",
        Default = aimAssistOnlyOnRightClick,
        Description = "Aim assist only active when holding right click."
    }):OnChanged(function(value)
        aimAssistOnlyOnRightClick = value
        updateAutoRotate()
    end)

    Tabs.Main:AddToggle("AimAssistOffOnRightClick", {
        Title = "Aim Assist Off On Right Click",
        Default = aimAssistOffOnRightClick,
        Description = "Disable aim assist when holding right click."
    }):OnChanged(function(value)
        aimAssistOffOnRightClick = value
        updateAutoRotate()
    end)

    Tabs.Main:AddToggle("TargetDeadPlayers", {
        Title = "Target Dead Players",
        Default = targetDeadPlayers,
        Description = "Enable targeting of players with 0 health."
    }):OnChanged(function(value)
        targetDeadPlayers = value
    end)


    -- === Main Tab Angle Limit Controls ===
    Tabs.Main:AddInput("MaxCFrameYAngleForward", {
        Title = "Max CFrame Y Angle Forward (degrees)",
        Description = "Maximum downward rotation angle when within angle limit distance.",
        Default = tostring(maxCFrameYAngleForward),
        Placeholder = "45",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num >= 0 and num <= 90 then
            maxCFrameYAngleForward = num
        else
            maxCFrameYAngleForward = 45
            Options.MaxCFrameYAngleForward:SetValue("45")
            log("Invalid Max CFrame Y Angle Forward input. Reverting to default value: 45", "warn")
        end
    end)

    Tabs.Main:AddInput("MaxCFrameYAngleReverse", {
        Title = "Max CFrame Y Angle Reverse (degrees)",
        Description = "Maximum upward rotation angle when within angle limit distance.",
        Default = tostring(maxCFrameYAngleReverse),
        Placeholder = "45",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num >= 0 and num <= 90 then
            maxCFrameYAngleReverse = num
        else
            maxCFrameYAngleReverse = 45
            Options.MaxCFrameYAngleReverse:SetValue("45")
            log("Invalid Max CFrame Y Angle Reverse input. Reverting to default value: 45", "warn")
        end
    end)

    Tabs.Main:AddInput("AngleLimitDistance", {
        Title = "Angle Limit Distance (studs)",
        Description = "Distance from target to apply Y angle limits.",
        Default = tostring(angleLimitDistance),
        Placeholder = "20",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            angleLimitDistance = num
        else
            angleLimitDistance = 20
            Options.AngleLimitDistance:SetValue("20")
            log("Invalid Angle Limit Distance input. Reverting to default value: 20", "warn")
        end
    end)

    -- === Prediction Tab Controls ===
    -- Regular Aim XY Prediction Settings
    Tabs.Prediction:AddInput("RegularAimXYReactionTime", {
        Title = "Regular Aim XY Reaction Time (sec)",
        Description = "Enter the reaction time for Regular Aim XY (any positive value).",
        Default = tostring(predictionSettings.RegularAimXY.reactionTime),
        Placeholder = "0.1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            predictionSettings.RegularAimXY.reactionTime = num
        else
            predictionSettings.RegularAimXY.reactionTime = 0.1
            Options.RegularAimXYReactionTime:SetValue("0.1")
            log("Invalid Regular Aim XY Reaction Time input. Reverting to default value: 0.1", "warn")
        end
    end)

    Tabs.Prediction:AddInput("RegularAimXYDampingFactor", {
        Title = "Regular Aim XY Damping Factor",
        Description = "Enter the damping factor for Regular Aim XY (any positive value).",
        Default = tostring(predictionSettings.RegularAimXY.dampingFactor),
        Placeholder = "50",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            predictionSettings.RegularAimXY.dampingFactor = num
        else
            predictionSettings.RegularAimXY.dampingFactor = 50
            Options.RegularAimXYDampingFactor:SetValue("50")
            log("Invalid Regular Aim XY Damping Factor input. Reverting to default value: 50", "warn")
        end
    end)

    Tabs.Prediction:AddInput("RegularAimXYStrength", {
        Title = "Regular Aim XY Strength",
        Description = "Enter the strength for Regular Aim XY (0 to disable, any positive value).",
        Default = tostring(predictionSettings.RegularAimXY.strength),
        Placeholder = "1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            predictionSettings.RegularAimXY.strength = num
        else
            predictionSettings.RegularAimXY.strength = 1
            Options.RegularAimXYStrength:SetValue("1")
            log("Invalid Regular Aim XY Strength input. Reverting to default value: 1", "warn")
        end
    end)

    -- Regular Aim X Prediction Settings
    Tabs.Prediction:AddInput("RegularAimXReactionTime", {
        Title = "Regular Aim X Reaction Time (sec)",
        Description = "Enter the reaction time for Regular Aim X (any positive value).",
        Default = tostring(predictionSettings.RegularAimX.reactionTime),
        Placeholder = "0.1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            predictionSettings.RegularAimX.reactionTime = num
        else
            predictionSettings.RegularAimX.reactionTime = 0.1
            Options.RegularAimXReactionTime:SetValue("0.1")
            log("Invalid Regular Aim X Reaction Time input. Reverting to default value: 0.1", "warn")
        end
    end)

    Tabs.Prediction:AddInput("RegularAimXDampingFactor", {
        Title = "Regular Aim X Damping Factor",
        Description = "Enter the damping factor for Regular Aim X (any positive value).",
        Default = tostring(predictionSettings.RegularAimX.dampingFactor),
        Placeholder = "50",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            predictionSettings.RegularAimX.dampingFactor = num
        else
            predictionSettings.RegularAimX.dampingFactor = 50
            Options.RegularAimXDampingFactor:SetValue("50")
            log("Invalid Regular Aim X Damping Factor input. Reverting to default value: 50", "warn")
        end
    end)

    Tabs.Prediction:AddInput("RegularAimXStrength", {
        Title = "Regular Aim X Strength",
        Description = "Enter the strength for Regular Aim X (0 to disable, any positive value).",
        Default = tostring(predictionSettings.RegularAimX.strength),
        Placeholder = "1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            predictionSettings.RegularAimX.strength = num
        else
            predictionSettings.RegularAimX.strength = 1
            Options.RegularAimXStrength:SetValue("1")
            log("Invalid Regular Aim X Strength input. Reverting to default value: 1", "warn")
        end
    end)

    -- F-Override Prediction Settings
    Tabs.Prediction:AddInput("FOverrideReactionTime", {
        Title = "F-Override Reaction Time (sec)",
        Description = "Enter the reaction time for F-Override (any positive value).",
        Default = tostring(predictionSettings.FOverride.reactionTime),
        Placeholder = "0.1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            predictionSettings.FOverride.reactionTime = num
        else
            predictionSettings.FOverride.reactionTime = 0.1
            Options.FOverrideReactionTime:SetValue("0.1")
            log("Invalid F-Override Reaction Time input. Reverting to default value: 0.1", "warn")
        end
    end)

    Tabs.Prediction:AddInput("FOverrideDampingFactor", {
        Title = "F-Override Damping Factor",
        Description = "Enter the damping factor for F-Override (any positive value).",
        Default = tostring(predictionSettings.FOverride.dampingFactor),
        Placeholder = "50",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            predictionSettings.FOverride.dampingFactor = num
        else
            predictionSettings.FOverride.dampingFactor = 50
            Options.FOverrideDampingFactor:SetValue("50")
            log("Invalid F-Override Damping Factor input. Reverting to default value: 50", "warn")
        end
    end)

    Tabs.Prediction:AddInput("FOverrideStrength", {
        Title = "F-Override Strength",
        Description = "Enter the strength for F-Override (0 to disable, any positive value).",
        Default = tostring(predictionSettings.FOverride.strength),
        Placeholder = "1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            predictionSettings.FOverride.strength = num
        else
            predictionSettings.FOverride.strength = 1
            Options.FOverrideStrength:SetValue("1")
            log("Invalid F-Override Strength input. Reverting to default value: 1", "warn")
        end
    end)

    -- === Pull-In Tab Controls ===
    Tabs.PullIn:AddToggle("PullInEnabled", {
        Title = "Pull-In Feature",
        Default = pullInEnabled,
        Description = "Enable or disable the pull-in feature."
    }):OnChanged(function(value)
        pullInEnabled = value
    end)

    Tabs.PullIn:AddInput("PullInStartTime", {
        Title = "Pull-In Start Time (sec)",
        Description = "Time before pull-in starts.",
        Default = tostring(pullInStartTime),
        Placeholder = "1",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            pullInStartTime = num
        else
            pullInStartTime = 1
            Options.PullInStartTime:SetValue("1")
            log("Invalid Pull-In Start Time input. Reverting to default value: 1", "warn")
        end
    end)

    Tabs.PullIn:AddInput("PullInEndTime", {
        Title = "Pull-In End Time (sec)",
        Description = "Duration of pull-in.",
        Default = tostring(pullInEndTime),
        Placeholder = "2",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            pullInEndTime = num
        else
            pullInEndTime = 2
            Options.PullInEndTime:SetValue("2")
            log("Invalid Pull-In End Time input. Reverting to default value: 2", "warn")
        end
    end)

    Tabs.PullIn:AddInput("PullVelocity", {
        Title = "Pull Velocity",
        Description = "Multiplier for pull velocity.",
        Default = tostring(pullVelocity),
        Placeholder = "2",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            pullVelocity = num
        else
            pullVelocity = 2
            Options.PullVelocity:SetValue("2")
            log("Invalid Pull Velocity input. Reverting to default value: 2", "warn")
        end
    end)

    -- Pull-In Targeting Method Dropdown
    Tabs.PullIn:AddDropdown("PullTargetingMethod", {
        Title = "Pull-In Targeting Method",
        Values = {"Closest to Mouse", "Closest to Torso"},
        Multi = false,
        Default = "Closest to Mouse"
    }):OnChanged(function(value)
        if value == "Closest to Mouse" then
            pullTargetingMethod = "closestToMouse"
        elseif value == "Closest to Torso" then
            pullTargetingMethod = "closestToTorso"
        else
            pullTargetingMethod = "closestToMouse"
            log("Invalid Pull-In Targeting Method selected. Reverting to default.", "warn")
        end
    end)

    -- Pull-In Distance Range Input
    Tabs.PullIn:AddInput("PullDistanceRange", {
        Title = "Pull-In Distance Range (studs)",
        Description = "Maximum distance to consider for pull-in.",
        Default = tostring(pullDistanceRange),
        Placeholder = "50",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            pullDistanceRange = num
        else
            pullDistanceRange = 50
            Options.PullDistanceRange:SetValue("50")
            log("Invalid Pull-In Distance Range input. Reverting to default value: 50", "warn")
        end
    end)

    -- Pull Direction Dropdown
    Tabs.PullIn:AddDropdown("PullDirectionMethod", {
        Title = "Pull Direction",
        Values = {"XY", "X"},
        Multi = false,
        Default = "XY"
    }):OnChanged(function(value)
        if value == "XY" then
            pullDirectionMethod = "XY"
        elseif value == "X" then
            pullDirectionMethod = "X"
        else
            pullDirectionMethod = "XY"
            log("Invalid Pull Direction Method selected. Reverting to default.", "warn")
        end
    end)

    -- === Keybinds Tab Controls ===
    -- Aim Assist Toggle Key
    local AimAssistToggleKey = Tabs.Keybinds:AddKeybind("AimAssistToggleKey", {
        Title = "Aim Assist Toggle Key",
        Mode = "Toggle",
        Default = "M",
        Description = "Press to toggle aim assist."
    })

    AimAssistToggleKey:OnClick(function()
        log("Aim Assist Toggle Key clicked: " .. tostring(AimAssistToggleKey:GetState()))
    end)

    AimAssistToggleKey:OnChanged(function(New)
        if typeof(New) == "EnumItem" then
            Options.AimAssistToggleKey.Value = New.Name
            log("Aim Assist Toggle Key changed to: " .. New.Name)
        elseif typeof(New) == "string" then
            local enumKey = Enum.KeyCode[New]
            if enumKey then
                Options.AimAssistToggleKey.Value = enumKey.Name
                log("Aim Assist Toggle Key changed to: " .. enumKey.Name)
            else
                Options.AimAssistToggleKey.Value = "M"
                log("Invalid keybind assigned to Aim Assist Toggle Key. Reverting to default: M", "warn")
            end
        else
            Options.AimAssistToggleKey.Value = "M"
            log("Invalid keybind type assigned to Aim Assist Toggle Key. Reverting to default: M", "warn")
        end
    end)

    -- Change Target Method Key
    local ChangeTargetMethodKey = Tabs.Keybinds:AddKeybind("ChangeTargetMethodKey", {
        Title = "Change Target Method Key",
        Mode = "Toggle",
        Default = "K",
        Description = "Press to change targeting method."
    })

    ChangeTargetMethodKey:OnClick(function()
        log("Change Target Method Key clicked: " .. tostring(ChangeTargetMethodKey:GetState()))
    end)

    ChangeTargetMethodKey:OnChanged(function(New)
        if typeof(New) == "EnumItem" then
            Options.ChangeTargetMethodKey.Value = New.Name
            log("Change Target Method Key changed to: " .. New.Name)
        elseif typeof(New) == "string" then
            local enumKey = Enum.KeyCode[New]
            if enumKey then
                Options.ChangeTargetMethodKey.Value = enumKey.Name
                log("Change Target Method Key changed to: " .. enumKey.Name)
            else
                Options.ChangeTargetMethodKey.Value = "K"
                log("Invalid keybind assigned to Change Target Method Key. Reverting to default: K", "warn")
            end
        else
            Options.ChangeTargetMethodKey.Value = "K"
            log("Invalid keybind type assigned to Change Target Method Key. Reverting to default: K", "warn")
        end
    end)

    -- Change Rotation Method Key
    local ChangeRotationMethodKey = Tabs.Keybinds:AddKeybind("ChangeRotationMethodKey", {
        Title = "Change Rotation Method Key",
        Mode = "Toggle",
        Default = "L",
        Description = "Press to change rotation method."
    })

    ChangeRotationMethodKey:OnClick(function()
        log("Change Rotation Method Key clicked: " .. tostring(ChangeRotationMethodKey:GetState()))
    end)

    ChangeRotationMethodKey:OnChanged(function(New)
        if typeof(New) == "EnumItem" then
            Options.ChangeRotationMethodKey.Value = New.Name
            log("Change Rotation Method Key changed to: " .. New.Name)
        elseif typeof(New) == "string" then
            local enumKey = Enum.KeyCode[New]
            if enumKey then
                Options.ChangeRotationMethodKey.Value = enumKey.Name
                log("Change Rotation Method Key changed to: " .. enumKey.Name)
            else
                Options.ChangeRotationMethodKey.Value = "L"
                log("Invalid keybind assigned to Change Rotation Method Key. Reverting to default: L", "warn")
            end
        else
            Options.ChangeRotationMethodKey.Value = "L"
            log("Invalid keybind type assigned to Change Rotation Method Key. Reverting to default: L", "warn")
        end
    end)

    -- Assign Pull-In Keybinds (1-4)
    for i = 1, 4 do
        local AssignPullInKeybind = Tabs.Keybinds:AddKeybind("AssignPullInKeybind" .. i, {
            Title = "Assign Pull-In Keybind " .. i,
            Mode = "Always",
            Default = (i == 1) and "A" or ((i == 2) and "S" or ((i == 3) and "D" or "F")),
            Description = "Assign a key to pull-in slot " .. i .. ". Press the desired key."
        })

        AssignPullInKeybind:OnChanged(function(New)
            if typeof(New) == "EnumItem" then
                Options["AssignPullInKeybind" .. i].Value = New.Name
                log("Pull-In Keybind " .. i .. " changed to: " .. New.Name)
            elseif typeof(New) == "string" then
                local enumKey = Enum.KeyCode[New]
                if enumKey then
                    Options["AssignPullInKeybind" .. i].Value = enumKey.Name
                    log("Pull-In Keybind " .. i .. " changed to: " .. enumKey.Name)
                else
                    local defaultKey = (i == 1) and "A" or ((i == 2) and "S" or ((i == 3) and "D" or "F"))
                    Options["AssignPullInKeybind" .. i].Value = defaultKey
                    log("Invalid keybind assigned to Pull-In Keybind " .. i .. ". Reverting to default: " .. defaultKey, "warn")
                end
            else
                local defaultKey = (i == 1) and "A" or ((i == 2) and "S" or ((i == 3) and "D" or "F"))
                Options["AssignPullInKeybind" .. i].Value = defaultKey
                log("Invalid keybind type assigned to Pull-In Keybind " .. i .. ". Reverting to default: " .. defaultKey, "warn")
            end
        end)
    end

    -- === Temp Rotation Tab Controls ===
    -- Added Temporary Rotation Time Adders, Min/Max Time Inputs, and Y-Angle Settings
    for i = 1, 4 do
        -- Existing Temp Rotation Toggle
        Tabs.TempRotation:AddToggle("TempRotationKey" .. i, {
            Title = "Temp Rotation Key " .. i,
            Default = keyRotationEnabled[i],
            Description = "Enable temporary rotation via number key " .. i .. "."
        }):OnChanged(function(value)
            keyRotationEnabled[i] = value
        end)

        -- Time Adder Input
        Tabs.TempRotation:AddInput("TempRotationKey" .. i .. "TimeAdder", {
            Title = "Time Adder for Temp Rotation Key " .. i .. " (sec)",
            Description = "Additional time to add after each toggle deactivation.",
            Default = tostring(tempRotationSettings[i].addTime),
            Placeholder = "0.5",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= 0 then
                tempRotationSettings[i].addTime = num
            else
                tempRotationSettings[i].addTime = 0.5
                Options["TempRotationKey" .. i .. "TimeAdder"]:SetValue("0.5")
                log("Invalid Time Adder input for Temp Rotation Key " .. i .. ". Reverting to default: 0.5", "warn")
            end
        end)

        -- Minimum Time Input
        Tabs.TempRotation:AddInput("TempRotationKey" .. i .. "MinTime", {
            Title = "Minimum Time for Temp Rotation Key " .. i .. " (sec)",
            Description = "Ensure temp remains active for at least this time.",
            Default = tostring(tempRotationSettings[i].minTime),
            Placeholder = "2",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num > 0 then
                tempRotationSettings[i].minTime = num
            else
                tempRotationSettings[i].minTime = 2
                Options["TempRotationKey" .. i .. "MinTime"]:SetValue("2")
                log("Invalid Minimum Time input for Temp Rotation Key " .. i .. ". Reverting to default: 2", "warn")
            end
        end)

        -- **Rotation Method Dropdown for Each Temp Rotation Key**
        Tabs.TempRotation:AddDropdown("TempRotationKey" .. i .. "RotationMethod", {
            Title = "Rotation Method for Temp Rotation Key " .. i,
            Values = {"X-Axis", "XY-Axis"},
            Multi = false,
            Default = tempRotationSettings[i].rotationMethod
        }):OnChanged(function(value)
            if value == "X-Axis" or value == "XY-Axis" then
                tempRotationSettings[i].rotationMethod = value
            else
                tempRotationSettings[i].rotationMethod = "X-Axis"
                Options["TempRotationKey" .. i .. "RotationMethod"]:SetValue("X-Axis")
                log("Invalid Rotation Method selected for Temp Rotation Key " .. i .. ". Reverting to default: X-Axis", "warn")
            end
        end)

        -- Maximum Time Input
        Tabs.TempRotation:AddInput("TempRotationKey" .. i .. "MaxTime", {
            Title = "Maximum Time for Temp Rotation Key " .. i .. " (sec)",
            Description = "Ensure temp turns off at this maximum time.",
            Default = tostring(tempRotationSettings[i].maxTime),
            Placeholder = "5",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= tempRotationSettings[i].minTime then
                tempRotationSettings[i].maxTime = num
            else
                tempRotationSettings[i].maxTime = 5
                Options["TempRotationKey" .. i .. "MaxTime"]:SetValue("5")
                log("Invalid Maximum Time input for Temp Rotation Key " .. i .. ". Reverting to default: 5", "warn")
            end
        end)

        -- Maximum CFrame Y Angle Forward Input
        Tabs.TempRotation:AddInput("TempRotationKey" .. i .. "MaxCFrameYAngleForward", {
            Title = "Max CFrame Y Angle Forward for Temp Rotation Key " .. i .. " (degrees)",
            Description = "Maximum downward rotation angle during temp rotation.",
            Default = tostring(tempRotationSettings[i].maxCFrameYAngleForward),
            Placeholder = "45",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= 0 and num <= 90 then
                tempRotationSettings[i].maxCFrameYAngleForward = num
            else
                tempRotationSettings[i].maxCFrameYAngleForward = 45
                Options["TempRotationKey" .. i .. "MaxCFrameYAngleForward"]:SetValue("45")
                log("Invalid Max CFrame Y Angle Forward input for Temp Rotation Key " .. i .. ". Reverting to default: 45", "warn")
            end
        end)

        -- Maximum CFrame Y Angle Reverse Input
        Tabs.TempRotation:AddInput("TempRotationKey" .. i .. "MaxCFrameYAngleReverse", {
            Title = "Max CFrame Y Angle Reverse for Temp Rotation Key " .. i .. " (degrees)",
            Description = "Maximum upward rotation angle during temp rotation.",
            Default = tostring(tempRotationSettings[i].maxCFrameYAngleReverse),
            Placeholder = "45",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= 0 and num <= 90 then
                tempRotationSettings[i].maxCFrameYAngleReverse = num
            else
                tempRotationSettings[i].maxCFrameYAngleReverse = 45
                Options["TempRotationKey" .. i .. "MaxCFrameYAngleReverse"]:SetValue("45")
                log("Invalid Max CFrame Y Angle Reverse input for Temp Rotation Key " .. i .. ". Reverting to default: 45", "warn")
            end
        end)
    end

    for i = 1, 4 do
        -- Toggle for Ultimate Temp Rotation Key
        Tabs.UltimateTemp:AddToggle("UltimateTempRotationKey" .. i, {
            Title = "Ultimate Temp Rotation Key " .. i,
            Default = ultimateTempRotationSettings[i].active,
            Description = "Enable Ultimate Temporary rotation via number key " .. i .. "."
        }):OnChanged(function(value)
            ultimateTempRotationSettings[i].active = value
        end)

        -- Time Adder Input
        Tabs.UltimateTemp:AddInput("UltimateTempRotationKey" .. i .. "TimeAdder", {
            Title = "Time Adder for Ultimate Temp Rotation Key " .. i .. " (sec)",
            Description = "Additional time to add after each toggle deactivation.",
            Default = tostring(ultimateTempRotationSettings[i].addTime),
            Placeholder = "0.7",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= 0 then
                ultimateTempRotationSettings[i].addTime = num
            else
                ultimateTempRotationSettings[i].addTime = 0.7
                Options["UltimateTempRotationKey" .. i .. "TimeAdder"]:SetValue("0.7")
                log("Invalid Time Adder input for Ultimate Temp Rotation Key " .. i .. ". Reverting to default: 0.7", "warn")
            end
        end)

        -- Minimum Time Input
        Tabs.UltimateTemp:AddInput("UltimateTempRotationKey" .. i .. "MinTime", {
            Title = "Minimum Time for Ultimate Temp Rotation Key " .. i .. " (sec)",
            Description = "Ensure ultimate temp remains active for at least this time.",
            Default = tostring(ultimateTempRotationSettings[i].minTime),
            Placeholder = "3",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num > 0 then
                ultimateTempRotationSettings[i].minTime = num
            else
                ultimateTempRotationSettings[i].minTime = 3
                Options["UltimateTempRotationKey" .. i .. "MinTime"]:SetValue("3")
                log("Invalid Minimum Time input for Ultimate Temp Rotation Key " .. i .. ". Reverting to default: 3", "warn")
            end
        end)

        -- Rotation Method Dropdown for Each Ultimate Temp Rotation Key
        Tabs.UltimateTemp:AddDropdown("UltimateTempRotationKey" .. i .. "RotationMethod", {
            Title = "Rotation Method for Ultimate Temp Rotation Key " .. i,
            Values = {"X-Axis", "XY-Axis"},
            Multi = false,
            Default = ultimateTempRotationSettings[i].rotationMethod
        }):OnChanged(function(value)
            if value == "X-Axis" or value == "XY-Axis" then
                ultimateTempRotationSettings[i].rotationMethod = value
            else
                ultimateTempRotationSettings[i].rotationMethod = "XY-Axis"
                Options["UltimateTempRotationKey" .. i .. "RotationMethod"]:SetValue("XY-Axis")
                log("Invalid Rotation Method selected for Ultimate Temp Rotation Key " .. i .. ". Reverting to default: XY-Axis", "warn")
            end
        end)

        -- Maximum Time Input
        Tabs.UltimateTemp:AddInput("UltimateTempRotationKey" .. i .. "MaxTime", {
            Title = "Maximum Time for Ultimate Temp Rotation Key " .. i .. " (sec)",
            Description = "Ensure ultimate temp turns off at this maximum time.",
            Default = tostring(ultimateTempRotationSettings[i].maxTime),
            Placeholder = "6",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= ultimateTempRotationSettings[i].minTime then
                ultimateTempRotationSettings[i].maxTime = num
            else
                ultimateTempRotationSettings[i].maxTime = 6
                Options["UltimateTempRotationKey" .. i .. "MaxTime"]:SetValue("6")
                log("Invalid Maximum Time input for Ultimate Temp Rotation Key " .. i .. ". Reverting to default: 6", "warn")
            end
        end)

        -- Maximum CFrame Y Angle Forward Input
        Tabs.UltimateTemp:AddInput("UltimateTempRotationKey" .. i .. "MaxCFrameYAngleForward", {
            Title = "Max CFrame Y Angle Forward for Ultimate Temp Rotation Key " .. i .. " (degrees)",
            Description = "Maximum downward rotation angle during ultimate temp rotation.",
            Default = tostring(ultimateTempRotationSettings[i].maxCFrameYAngleForward),
            Placeholder = "60",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= 0 and num <= 90 then
                ultimateTempRotationSettings[i].maxCFrameYAngleForward = num
            else
                ultimateTempRotationSettings[i].maxCFrameYAngleForward = 60
                Options["UltimateTempRotationKey" .. i .. "MaxCFrameYAngleForward"]:SetValue("60")
                log("Invalid Max CFrame Y Angle Forward input for Ultimate Temp Rotation Key " .. i .. ". Reverting to default: 60", "warn")
            end
        end)

        -- Maximum CFrame Y Angle Reverse Input
        Tabs.UltimateTemp:AddInput("UltimateTempRotationKey" .. i .. "MaxCFrameYAngleReverse", {
            Title = "Max CFrame Y Angle Reverse for Ultimate Temp Rotation Key " .. i .. " (degrees)",
            Description = "Maximum upward rotation angle during ultimate temp rotation.",
            Default = tostring(ultimateTempRotationSettings[i].maxCFrameYAngleReverse),
            Placeholder = "60",
            Numeric = true,
            Finished = true
        }):OnChanged(function(value)
            local num = tonumber(value)
            if num and num >= 0 and num <= 90 then
                ultimateTempRotationSettings[i].maxCFrameYAngleReverse = num
            else
                ultimateTempRotationSettings[i].maxCFrameYAngleReverse = 60
                Options["UltimateTempRotationKey" .. i .. "MaxCFrameYAngleReverse"]:SetValue("60")
                log("Invalid Max CFrame Y Angle Reverse input for Ultimate Temp Rotation Key " .. i .. ". Reverting to default: 60", "warn")
            end
        end)
    end

    -- === F Override Tab Controls ===
    Tabs.FOverride:AddToggle("FOverrideEnabled", {
        Title = "F Override",
        Default = fOverrideEnabled,
        Description = "Enable or disable F Override."
    }):OnChanged(function(value)
        fOverrideEnabled = value
    end)

    Tabs.FOverride:AddDropdown("FOverrideRotationMethod", {
        Title = "F Override Rotation Method",
        Values = {"X-Axis", "XY-Axis"},
        Multi = false,
        Default = "X-Axis"
    }):OnChanged(function(value)
        if value == "X-Axis" then
            fOverrideRotationMethod = "X-Axis"
        elseif value == "XY-Axis" then
            fOverrideRotationMethod = "XY-Axis"
        else
            fOverrideRotationMethod = "X-Axis"
            log("Invalid F Override Rotation Method selected. Reverting to default.", "warn")
        end
    end)

    Tabs.FOverride:AddDropdown("FOverrideTargetingMethod", {
        Title = "F Override Targeting Method",
        Values = {"Closest to Mouse", "Closest to Torso"},
        Multi = false,
        Default = "Closest to Torso"
    }):OnChanged(function(value)
        if value == "Closest to Mouse" then
            fOverrideTargetingMethod = "closestToMouse"
        elseif value == "Closest to Torso" then
            fOverrideTargetingMethod = "closestToTorso"
        else
            fOverrideTargetingMethod = "closestToTorso"
            log("Invalid F Override Targeting Method selected. Reverting to default.", "warn")
        end
    end)

    Tabs.FOverride:AddToggle("NoRotateOnRightClickForFOverride", {
        Title = "No Rotate on Right Click (F Override)",
        Default = true,
        Description = "Disable rotation when holding right click during F Override."
    }):OnChanged(function(value)
        noRotateOnRightClickForFOverride = value
        updateAutoRotate()
    end)

    -- Add toggle for F Override Off On Right Click
    Tabs.FOverride:AddToggle("FOverrideOffOnRightClick", {
        Title = "F Override Off On Right Click",
        Default = fOverrideOffOnRightClick,
        Description = "Disable all regular aim assist when F Override is active and right-clicking."
    }):OnChanged(function(value)
        fOverrideOffOnRightClick = value
        updateAutoRotate()
    end)

    -- Add toggle for F Override Only On Right Click
    Tabs.FOverride:AddToggle("FOverrideOnlyOnRightClick", {
        Title = "F Override Only On Right Click",
        Default = fOverrideOnlyOnRightClick,
        Description = "Enable F Override only when holding right click."
    }):OnChanged(function(value)
        fOverrideOnlyOnRightClick = value
        updateAutoRotate()
    end)


    Tabs.FOverride:AddToggle("InverseDampingEnabled", {
        Title = "Inverse Damping",
        Default = predictionSettings.FOverride.inverseDampingEnabled,
        Description = "Enable inverse damping for F Override (increases prediction for closer targets, decreases for farther targets)."
    }):OnChanged(function(value)
        predictionSettings.FOverride.inverseDampingEnabled = value
        log("Inverse Damping for F Override set to: " .. tostring(value), "info")
    end)

    -- === Animations Tab Controls ===

    -- Ensure animations table exists
    animConfig.animations = animConfig.animations or {}

    -- Create UI elements for animations
    local AnimSection = Tabs.Animations:AddSection("Animation Configurations")

    -- Dropdown to list tracked animations
    local AnimationsDropdown = Tabs.Animations:AddDropdown("AnimationsDropdown", {
        Title = "Tracked Animations",
        Values = {}, -- Will refresh later
        Multi = false,
        Default = ""
    })

    AnimationsDropdown:OnChanged(function(value)
    end)

    -- Inputs to add a new animation
    local AnimationIdInput = Tabs.Animations:AddInput("AnimationIdInput", {
        Title = "Add Animation ID",
        Description = "Numeric Animation ID",
        Default = "",
        Placeholder = "7815618175",
        Numeric = true,
        Finished = true
    })

    local AnimationStartCommandInput = Tabs.Animations:AddInput("AnimationStartCommandInput", {
        Title = "Start Command",
        Description = "Command when animation starts",
        Default = "",
        Placeholder = "tpwalk 10",
        Numeric = false,
        Finished = true
    })

    local AnimationEndCommandInput = Tabs.Animations:AddInput("AnimationEndCommandInput", {
        Title = "End Command",
        Description = "Command when animation ends",
        Default = "",
        Placeholder = "tpstop",
        Numeric = false,
        Finished = true
    })

    -- Add Animation Button
    Tabs.Animations:AddButton({
        Title = "Add Animation",
        Callback = function()
            local animId = AnimationIdInput.Value
            local startCommand = AnimationStartCommandInput.Value
            local endCommand = AnimationEndCommandInput.Value

            if tonumber(animId) then
                if not animConfig.animations[animId] then
                    animConfig.animations[animId] = {
                        onStart = startCommand,
                        onEnd = endCommand
                    }
                    saveAnimConfig()

                    refreshAnimationsDropdown()
                    addAnimationSettingsInputs(animId)

                    Fluent:Notify({
                        Title = "Animations",
                        Content = "Added Animation ID: " .. animId,
                        Duration = 5
                    })
                else
                    Fluent:Notify({
                        Title = "Animations",
                        Content = "Animation ID already tracked: " .. animId,
                        Duration = 5
                    })
                end
            else
                Fluent:Notify({
                    Title = "Animations",
                    Content = "Invalid Animation ID. Enter a numeric value.",
                    Duration = 5
                })
            end
        end
    })

    -- Remove Selected Animation Button
    Tabs.Animations:AddButton({
        Title = "Remove Selected Animation",
        Callback = function()
            local selectedAnimId = Options.AnimationsDropdown.Value
            if selectedAnimId and animConfig.animations[selectedAnimId] then
                animConfig.animations[selectedAnimId] = nil
                saveAnimConfig()

                refreshAnimationsDropdown()
                removeAnimationSettingsInputs(selectedAnimId)
                Options.AnimationsDropdown:SetValue(nil) 

                Fluent:Notify({
                    Title = "Animations",
                    Content = "Removed Animation ID: " .. selectedAnimId,
                    Duration = 5
                })
            else
                Fluent:Notify({
                    Title = "Animations",
                    Content = "No Animation ID selected or ID not found.",
                    Duration = 5
                })
            end
        end
    })

    -- Copy Playing Animations Button
    Tabs.Animations:AddButton({
        Title = "Copy Playing Animations",
        Callback = function()
            copyanimidfrombutton()
        end
    })

    -- Recreate UI elements for tracked animations on load
    for animId, data in pairs(animConfig.animations) do
        addAnimationSettingsInputs(animId)
    end

    -- Refresh the dropdown with current animations
    refreshAnimationsDropdown()


    -- === Velocity Limiter Tab Controls ===
    Tabs.VelocityLimiter:AddInput("CloseRangeLimitDistance", {
        Title = "Close Range Limit Distance",
        Description = "Distance to begin limiting velocity.",
        Default = tostring(closeRangeLimitDistance),
        Placeholder = "10",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            closeRangeLimitDistance = num
        else
            closeRangeLimitDistance = 10
            Options.CloseRangeLimitDistance:SetValue("10")
            log("Invalid Close Range Limit Distance input. Reverting to default value: 10", "warn")
        end
    end)

    Tabs.VelocityLimiter:AddInput("CloseRangeVelocityLimit", {
        Title = "Close Range Velocity Limit (studs/sec)",
        Description = "Max velocity towards target in close range.",
        Default = tostring(closeRangeVelocityLimit),
        Placeholder = "30",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            closeRangeVelocityLimit = num
        else
            closeRangeVelocityLimit = 30
            Options.CloseRangeVelocityLimit:SetValue("30")
            log("Invalid Close Range Velocity Limit input. Reverting to default value: 30", "warn")
        end
    end)

    Tabs.VelocityLimiter:AddInput("OverallPullInVelocityLimiter", {
        Title = "Overall Pull-In Velocity Limiter (studs/sec)",
        Description = "Maximum velocity during pull-in for any distance.",
        Default = tostring(overallPullInVelocityLimiter),
        Placeholder = "50",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            overallPullInVelocityLimiter = num
        else
            overallPullInVelocityLimiter = 50
            Options.OverallPullInVelocityLimiter:SetValue("50")
            log("Invalid Overall Pull-In Velocity Limiter input. Reverting to default value: 50", "warn")
        end
    end)

    -- === Waypoint Tab Controls ===
    -- Button to set the waypoint to the player's current position
    Tabs.Waypoint:AddButton({
        Title = "Set Waypoint to Current Position",
        Callback = function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                waypointPosition = player.Character.HumanoidRootPart.Position
                -- Replace print with notification
                Fluent:Notify({
                    Title = "Waypoint",
                    Content = "Waypoint position set to current position.",
                    Duration = 2
                })
            end
        end
    })


    -- Toggle to enable or disable returning to the waypoint
    Tabs.Waypoint:AddToggle("ReturnToWaypointEnabled", {
        Title = "Return to Waypoint",
        Default = returnToWaypointEnabled,
        Description = "Enable or disable automatic return to waypoint."
    }):OnChanged(function(value)
        returnToWaypointEnabled = value
        if returnToWaypointEnabled then
            startReturningToWaypoint()
        else
            stopReturningToWaypoint()
        end
    end)

    -- gravity tab controls
    -- Add Gravity tab controls
    Tabs.Gravity:AddToggle("EnableGravityChanger", {
        Title = "Enable Gravity Changer",
        Default = enableGravityChanger
    }):OnChanged(function(value)
        enableGravityChanger = value
    end)

    Tabs.Gravity:AddInput("IncreasedGravityValue", {
        Title = "Increased Gravity",
        Default = tostring(increasedGravityValue),
        Placeholder = "400",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            increasedGravityValue = num
        else
            increasedGravityValue = 400
            Options.IncreasedGravityValue:SetValue("400")
        end
    end)

    Tabs.Gravity:AddInput("IncreasedDensityValue", {
        Title = "Increased Density",
        Default = tostring(increasedDensityValue),
        Placeholder = "100",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            increasedDensityValue = num
        else
            increasedDensityValue = 100
            Options.IncreasedDensityValue:SetValue("100")
        end
    end)

    Tabs.Gravity:AddInput("QResetTime", {
        Title = "Q Reset Time (seconds)",
        Default = tostring(qResetTime),
        Placeholder = "1.5",
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            qResetTime = num
        else
            qResetTime = 1.5
            Options.QResetTime:SetValue("1.5")
        end
    end)



	Tabs.Gravity:AddInput("CloneWalkSpeed", {
		Title       = "Clone Walk-Speed",
		Default     = tostring(cloneWalkSpeed),
		Placeholder = "10",
		Numeric     = true,
		Finished    = true
	}):OnChanged(function(value)
		local n = tonumber(value)
		if n and n > 0 then
			scale = n
		else
			scale = 30
			Options.CloneWalkSpeed:SetValue("30")
		end
	end)

    SaveManager:LoadAutoloadConfig()

    -- === Validate Keybinds After Loading ===
    local keybindDefaults = {
        AimAssistToggleKey = "M",
        ChangeTargetMethodKey = "K",
        ChangeRotationMethodKey = "L",
        AssignPullInKeybind1 = "A",
        AssignPullInKeybind2 = "S",
        AssignPullInKeybind3 = "D",
        AssignPullInKeybind4 = "F",
    }

    -- === Notifications upon loading ===
    Window:SelectTab(1)

    Fluent:Notify({
        Title = "Fluent",
        Content = "The script has been loaded.",
        Duration = 3
    })
end

player.CharacterRemoving:Connect(function()
    -- Disconnect all event connections
    if animationPlayedConn then
        animationPlayedConn:Disconnect()
        animationPlayedConn = nil
    end
    if stateChangedConn then
        stateChangedConn:Disconnect()
        stateChangedConn = nil
    end
    if inputBeganConn then
        inputBeganConn:Disconnect()
        inputBeganConn = nil
    end
    if inputEndedConn then
        inputEndedConn:Disconnect()
        inputEndedConn = nil
    end
end)


local function onCharacterAdded(character)
    Character = character
    Humanoid = safeFind(Character, "Humanoid", 5)
    RootPart = safeFind(Character, "HumanoidRootPart", 5)

    -- Reset or Initialize Variables
    isFOverrideActive = false
    isFHeld = false

    -- Save original mass for the character
    for _, part in pairs(character:GetDescendants()) do
        saveOriginalProperties(part)
    end

    -- Disconnect previous connections if they exist
    if animationPlayedConn then
        animationPlayedConn:Disconnect()
        animationPlayedConn = nil
    end
    if stateChangedConn then
        stateChangedConn:Disconnect()
        stateChangedConn = nil
    end
    if inputBeganConn then
        inputBeganConn:Disconnect()
        inputBeganConn = nil
    end
    if inputEndedConn then
        inputEndedConn:Disconnect()
        inputEndedConn = nil
    end

    -- InputBegan Event
    inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if enableGravityChanger then
            if input.KeyCode == Enum.KeyCode.Space then
                -- Apply increased mass and gravity while jumping
                workspace.Gravity = increasedGravityValue
                applyIncreasedMass(character)
            elseif input.KeyCode == Enum.KeyCode.Q then
                -- Reset mass and gravity for qResetTime seconds
                resetCharacterMass(character)
                workspace.Gravity = originalGravity
                wait(qResetTime)
            end
        end
    end)

    -- InputEnded Event
    inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if enableGravityChanger then
            if input.KeyCode == Enum.KeyCode.Space then
                resetCharacterMass(character)
                workspace.Gravity = originalGravity
            end
        end
    end)

    if Humanoid then
        -- StateChanged Event
        stateChangedConn = Humanoid.StateChanged:Connect(function(oldState, newState)
            local onGroundStates = {
                [Enum.HumanoidStateType.Running] = true,
                [Enum.HumanoidStateType.RunningNoPhysics] = true,
                [Enum.HumanoidStateType.Seated] = true,
                [Enum.HumanoidStateType.GettingUp] = true,
                [Enum.HumanoidStateType.Climbing] = true,
            }
            if onGroundStates[newState] then
                -- Check if any temp rotations are active
                local anyTempActive = false
                for i = 1, 4 do
                    if tempRotationSettings[i].active and tempRotationSettings[i].timer > 0 then
                        anyTempActive = true
                        break
                    end
                end

                -- Revert rotation methods if no active temp rotations
                if not anyTempActive and originalRotationMethodTemp then
                    rotationMethod = baseRotationMethod
                    setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
                    originalRotationMethodTemp = nil
                    ensureRotationMethod()
                    log("Temporary Rotation reverted after landing due to state: " .. newState.Name)
                end

                -- Revert ultimate temp rotation methods if no active ultimate temp rotations
                local anyUltimateTempActive = false
                if isUltimateModeActive() then
                    for i = 1, 4 do
                        if ultimateTempRotationSettings[i].active and ultimateTempRotationSettings[i].timer > 0 then
                            anyUltimateTempActive = true
                            break
                        end
                    end
                    if not anyUltimateTempActive and originalRotationMethodUltimateTemp then
                        rotationMethod = originalRotationMethodUltimateTemp
                        setDropdownValue("RotationMethod", rotationMethod, {"X-Axis", "XY-Axis"})
                        originalRotationMethodUltimateTemp = nil
                        ensureRotationMethod()
                        log("Ultimate Temporary Rotation reverted after landing due to state: " .. newState.Name)
                    end
                end

                -- Update AutoRotate
                updateAutoRotate()
            end

            -- Reset Flags
            monitorCooldownFrames()
        end)
    end
end


-- Connect the character added event


-- Initialize if character already exists
if player.Character then
    onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

-- === InputBegan Event Handler ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if keybindsEnabled and not UserInputService:GetFocusedTextBox() then
        -- === Prevent Regular Aim Assist Keybinds When F Override is Active ===
        if isFOverrideActive then
            local aimAssistToggleKey = Enum.KeyCode[Options.AimAssistToggleKey.Value]
            local changeTargetMethodKey = Enum.KeyCode[Options.ChangeTargetMethodKey.Value]
            local changeRotationMethodKey = Enum.KeyCode[Options.ChangeRotationMethodKey.Value]
            
            if input.KeyCode == aimAssistToggleKey or 
               input.KeyCode == changeTargetMethodKey or 
               input.KeyCode == changeRotationMethodKey then
                   -- Skip processing these keybinds when F Override is active
                   return
            end
        end

        -- === Handle F Key Press ===
        if input.KeyCode == Enum.KeyCode.F then
            isFHeld = true -- Set the flag to true when F is pressed

            if fOverrideEnabled then
                if fOverrideOnlyOnRightClick then
                    if rightClickHeld and not isFOverrideActive then
                        activateFOverride()
                    end
                else
                    if not isFOverrideActive then
                        activateFOverride()
                    end
                end
            end

            -- Update AutoRotate to reflect that F is held (main aim assist off)
            updateAutoRotate()
        end

        -- === Handle Aim Assist Toggle Key ===
        local aimAssistToggleKey = Enum.KeyCode[Options.AimAssistToggleKey.Value]
        if input.KeyCode == aimAssistToggleKey then
            aimAssistEnabled = not aimAssistEnabled
            log("Aim Assist toggled to: " .. tostring(aimAssistEnabled))
            updateAutoRotate()
        end

        -- === Handle Change Target Method Key ===
        local changeTargetMethodKey = Enum.KeyCode[Options.ChangeTargetMethodKey.Value]
        if input.KeyCode == changeTargetMethodKey then
            if targetingMethod == "closestToMouse" then
                targetingMethod = "closestToTorso"
            else
                targetingMethod = "closestToMouse"
            end
            log("Targeting Method changed to: " .. targetingMethod)
            -- No need to call updateAutoRotate() here as it doesn't affect AutoRotate directly
        end

        -- === Handle Change Rotation Method Key ===
        local changeRotationMethodKey = Enum.KeyCode[Options.ChangeRotationMethodKey.Value]
        if input.KeyCode == changeRotationMethodKey then
            if rotationMethod == "X-Axis" then
                rotationMethod = "XY-Axis"
            else
                rotationMethod = "X-Axis"
            end
            ensureRotationMethod()
            log("Rotation Method changed to: " .. rotationMethod)
            -- No need to call updateAutoRotate() here as it doesn't affect AutoRotate directly
        end

        -- === Handle Right Mouse Button Press ===
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rightClickHeld = true
            updateAutoRotate()

            if fOverrideOnlyOnRightClick and UserInputService:IsKeyDown(Enum.KeyCode.F) and not isFOverrideActive and fOverrideEnabled then
                activateFOverride()
            end

            -- Handle F Override Off On Right Click Activation
            if fOverrideOffOnRightClick and isFOverrideActive then
                updateAutoRotate()
            end
        end

        -- === Handle Pull-In Feature Activation via Q Key ===
        if input.KeyCode == Enum.KeyCode.Q and pullInEnabled then
            -- Check if any of the assigned pull-in keys are being held
            local anyPullInKeyHeld = false
            for i = 1, 4 do
                local keyName = Options["AssignPullInKeybind" .. i].Value
                local assignedKey = Enum.KeyCode[keyName]
                if assignedKey and UserInputService:IsKeyDown(assignedKey) then
                    anyPullInKeyHeld = true
                    break
                end
            end

            if anyPullInKeyHeld then
                local target
                if pullTargetingMethod == "closestToMouse" then
                    target = getClosestPlayerToMouse()
                else
                    target = getClosestPlayerToTorsoLimited()
                end

                if target then
                    activatePullIn(target)
                    log("Pull-In activated via Q key towards: " .. target.Name)
                else
                    log("No valid target found within pull distance range; Pull-In not activated.", "warn")
                end
            else
                log("No Pull-In keys are held; Pull-In not activated.")
            end
        end
    end
end)

-- === InputEnded Event Handler ===
UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if keybindsEnabled and not UserInputService:GetFocusedTextBox() then
        -- === Prevent Regular Aim Assist Keybinds When F Override is Active ===
        if isFOverrideActive then
            local aimAssistToggleKey = Enum.KeyCode[Options.AimAssistToggleKey.Value]
            local changeTargetMethodKey = Enum.KeyCode[Options.ChangeTargetMethodKey.Value]
            local changeRotationMethodKey = Enum.KeyCode[Options.ChangeRotationMethodKey.Value]
            
            if input.KeyCode == aimAssistToggleKey or 
               input.KeyCode == changeTargetMethodKey or 
               input.KeyCode == changeRotationMethodKey then
                   -- Skip processing these keybinds when F Override is active
                   return
            end
        end

        -- === Handle F Key Release ===
        if input.KeyCode == Enum.KeyCode.F then
            isFHeld = false -- Reset the flag when F is released

            if isFOverrideActive then
                deactivateFOverride()
            end

            -- Update AutoRotate to reflect that F is no longer held
            updateAutoRotate()
        end

        -- === Handle Right Mouse Button Release ===
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rightClickHeld = false
            updateAutoRotate()

            -- If F Override Only On Right Click and F is held, deactivate F Override
            if fOverrideOnlyOnRightClick and UserInputService:IsKeyDown(Enum.KeyCode.F) and isFOverrideActive and fOverrideEnabled then
                deactivateFOverride()
            end

            -- Handle F Override Off On Right Click Deactivation
            if fOverrideOffOnRightClick and isFOverrideActive then
                updateAutoRotate()
            end
        end
    end
end)

local function isAnyPlayerWithinRadius(radius)
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = otherPlayer.Character.HumanoidRootPart
            local distance = (hrp.Position - humanoidRootPart.Position).Magnitude
            if distance <= radius then
                return true
            end
        end
    end
    return false
end


-- RUNSERVICE RAHHHH
RunService.RenderStepped:Connect(function(deltaTime)
    startTime = tick() -- Start tracking time
    -- Update camera reference    
    if not Humanoid then
       return
    end

    if Humanoid:GetState() == Enum.HumanoidStateType.FallingDown or isRagdollPresent() then
        Humanoid.AutoRotate = false
        return
    end




    updateAutoRotate()
    -- Ensure Character, Humanoid, and RootPart are valid
    if not Character or not Humanoid or not RootPart then
        Character = player.Character
        if Character then
            Humanoid = Character:FindFirstChild("Humanoid")
            RootPart = Character:FindFirstChild("HumanoidRootPart")
        end
    end

    if not Character or not Humanoid or not RootPart then
        return
    end

    if lockOriginalEnabled then
        return
    end

    -- Ensure the player and character are valid
    if player and player.Character then
        character = player.Character
        humanoid = character:FindFirstChild("Humanoid")

        if humanoid then
            -- Attempt to find the Animator
            animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then
                animator = waitForAnimator(humanoid, 1) -- Call your waitForAnimator function
                if not animator then
                    warn("Animator not found for humanoid after waiting.")
                    return -- Exit if no animator is found
                end
            end

            local anyTurnOffAnimPlaying = false
            local playerCharacterValue = getPlayerCharacterAttribute()

            -- Iterate through all playing animation tracks
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local trackAnimId = extractAssetId(track.Animation.AnimationId)
                for _, anim in ipairs(turnoffanims) do
                    local animTableId = extractAssetId(anim.AnimationId)
                    if trackAnimId == animTableId then

                        -- Check if the animation applies to the player's character
                        local requiredCharacter = anim.Character or "all"

                        if requiredCharacter == "all" or playerCharacterValue == requiredCharacter then
                            anyTurnOffAnimPlaying = true
                            break -- No need to check other animations
                        end
                    end
                end
                if anyTurnOffAnimPlaying then break end
            end
            
            -- Manage Aim Assist based on animations and user toggle
            if anyTurnOffAnimPlaying then
                if aimAssistEnabled then
                    aimAssistEnabled = false
                    updateAutoRotate()
                end
            else
                if not userAimAssistToggledOff then
                    aimAssistEnabled = true
                    updateAutoRotate()
                end
            end
        else
            warn("Humanoid not found in character.")
        end
    else
        -- If player or character is invalid, ensure aim assist is enabled
        if not aimAssistEnabled and not userAimAssistToggledOff then
            aimAssistEnabled = true
            updateAutoRotate()
        end
    end


    local currentTime = tick()

    -- Handle Temporary Rotation Timers
    for i = 1, 4 do
        local temp = tempRotationSettings[i]
        if temp.active then
            temp.timer = temp.timer - deltaTime
            if temp.timer <= 0 then
                deactivateTempRotationForSlot(i)
            end
        end
    end

    -- Handle Ultimate Temporary Rotation Timers
    if isUltimateModeActive() then
        for i = 1, 4 do
            local temp = ultimateTempRotationSettings[i]
            if temp.active then
                temp.timer = temp.timer - deltaTime
                if temp.timer <= 0 then
                    deactivateUltimateTempRotationForSlot(i)
                end
            end
        end
    end

    -- === Pull-In Feature Handling ===
    if Humanoid and Humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown and not isRagdollPresent() then
        for _, pullIn in ipairs(activePullIns) do
            local elapsedTime = currentTime - pullIn.ActivationTime

            -- Check if the pull-in duration has elapsed
            if elapsedTime >= pullIn.EndTime then
                deactivatePullIn(pullIn)
                log("Pull-In duration elapsed; Pull-In deactivated.")
            else
                -- Check if the pull-in should start
                if not pullIn.Started and elapsedTime >= pullIn.StartTime then
                    pullIn.Started = true

                    -- Apply initial force towards the target based on Pull Direction Method
                    local targetCharacter = pullIn.Target and pullIn.Target.Character
                    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
                    local targetHumanoidRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

                    if targetCharacter and targetHumanoid and targetHumanoidRoot and targetHumanoid.Health > 0 then
                        local targetPosition = targetHumanoidRoot.Position
                        local playerPosition = RootPart.Position
                        local direction = CalculateDirection(targetPosition, playerPosition, pullDirectionMethod)
                        local forceMagnitude = CalculateForceMagnitude(pullVelocity, Humanoid)
                        ApplyPullInForce(pullIn, direction, forceMagnitude)
                        log("Pull-In force applied towards: " .. pullIn.Target.Name)
                    else
                        deactivatePullIn(pullIn)
                        log("Target invalid; Pull-In deactivated.", "warn")
                    end
                end

                -- If started, update the force direction towards the target's current position
                if pullIn.Started then
                    local targetCharacter = pullIn.Target and pullIn.Target.Character
                    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
                    local targetHumanoidRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
                    if targetCharacter and targetHumanoid and targetHumanoidRoot and targetHumanoid.Health > 0 then
                        local targetPosition = targetHumanoidRoot.Position
                        local playerPosition = RootPart.Position
                        local direction = CalculateDirection(targetPosition, playerPosition, pullDirectionMethod)
                        local forceMagnitude = CalculateForceMagnitude(pullVelocity, Humanoid)
                        ApplyPullInForce(pullIn, direction, forceMagnitude)

                        -- === Overall Velocity Limiter ===
                        local currentVelocity = RootPart.Velocity
                        local velocityTowardsTarget = direction:Dot(currentVelocity)
                        if velocityTowardsTarget > overallPullInVelocityLimiter then
                            RootPart.Velocity = RootPart.Velocity - direction * (velocityTowardsTarget - overallPullInVelocityLimiter)
                            log("Overall velocity limited to: " .. overallPullInVelocityLimiter)
                        end

                        -- === Close Range Velocity Limiter ===
                        local distance = (targetPosition - playerPosition).Magnitude
                        if distance <= closeRangeLimitDistance and velocityTowardsTarget > closeRangeVelocityLimit then
                            RootPart.Velocity = RootPart.Velocity - direction * (velocityTowardsTarget - closeRangeVelocityLimit)
                            log("Close Range velocity limited to: " .. closeRangeVelocityLimit)
                        end

                        -- Check if within stopping distance
                        if distance <= pullStoppingDistance then
                            deactivatePullIn(pullIn)
                            log("Within stopping distance; Pull-In deactivated.")
                        end
                    else
                        deactivatePullIn(pullIn)
                        log("Target invalid; Pull-In deactivated.", "warn")
                    end
                end
            end
        end
    end

    -- === Handle Pull-In Activation Status ===
    if #activePullIns > 0 then
        local stillHeld = false
        for i = 1, 4 do
            local keyName = Options["AssignPullInKeybind" .. i].Value
            local assignedKey = Enum.KeyCode[keyName]
            if assignedKey and UserInputService:IsKeyDown(assignedKey) then
                stillHeld = true
                break
            end
        end
        if not stillHeld then
            for _, pullIn in ipairs(activePullIns) do
                deactivatePullIn(pullIn)
            end
            pullInActive = false
            log("Pull-In deactivated due to no pull-in keys held.")
        end
    end

    if not aimAssistEnabled or (aimAssistOnlyOnRightClick and not rightClickHeld) then
        return  -- Skip the aim assist calculations
    end


    -- === Aim Assist Active Calculation ===
    local aimAssistActive = aimAssistEnabled

    -- If F Override is active or F is held
    if isFHeld or isFOverrideActive then
        -- Check if Aim Assist Only on Right Click is enabled
        if aimAssistOnlyOnRightClick and rightClickHeld then
            aimAssistActive = true -- Right-click overrides F Override
        else
            aimAssistActive = false -- F Override takes precedence
        end
    else
        -- If no F Override, handle normal right-click logic
        if aimAssistOnlyOnRightClick then
            aimAssistActive = rightClickHeld -- Activate aim assist only on right-click
        end

        if aimAssistOffOnRightClick and rightClickHeld then
            aimAssistActive = false -- Disable aim assist on right-click if this flag is enabled
        end
    end

    -- Determine the effective targeting method based on autoSwitchRadius
    local effectiveTargetingMethod = targetingMethod
    if autoSwitchRadius > 0 then
        if isAnyPlayerWithinRadius(autoSwitchRadius) then
            effectiveTargetingMethod = "closestToTorso"
        else
            effectiveTargetingMethod = "closestToMouse"
        end
    end

    -- Determine target based on targeting method
    local target
    if isFOverrideActive then
        target = (fOverrideTargetingMethod == "closestToMouse") and getClosestPlayerToMouse() or getClosestPlayerToTorsoUnlimited()
    else
        if effectiveTargetingMethod == "closestToMouse" then
            target = getClosestPlayerToMouse()
        else
            target = getClosestPlayerToTorsoUnlimited()
        end
    end

    -- Only run aim assist if conditions are met
    if aimAssistActive and isPlayerAllowedToTurn() and Humanoid then
        local currentRotationMethod = rotationMethod

        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local activeTempKey = activeHotbarSlot
            if currentRotationMethod == "XY-Axis" then
                if isFOverrideActive and predictionSettings.FOverride.strength > 0 then
                    AimStabilizerXY(target.Character.HumanoidRootPart, predictionSettings.FOverride.reactionTime, predictionSettings.FOverride.dampingFactor, predictionSettings.FOverride.strength, activeTempKey)
                elseif not isFOverrideActive and predictionSettings.RegularAimXY.strength > 0 then
                    AimStabilizerXY(target.Character.HumanoidRootPart, predictionSettings.RegularAimXY.reactionTime, predictionSettings.RegularAimXY.dampingFactor, predictionSettings.RegularAimXY.strength, activeTempKey)
                end
            elseif currentRotationMethod == "X-Axis" then
                if isFOverrideActive and predictionSettings.FOverride.strength > 0 then
                    AimStabilizerX(target.Character.HumanoidRootPart, predictionSettings.FOverride.reactionTime, predictionSettings.FOverride.dampingFactor, predictionSettings.FOverride.strength, activeTempKey)
                elseif not isFOverrideActive and predictionSettings.RegularAimX.strength > 0 then
                    AimStabilizerX(target.Character.HumanoidRootPart, predictionSettings.RegularAimX.reactionTime, predictionSettings.RegularAimX.dampingFactor, predictionSettings.RegularAimX.strength, activeTempKey)
                end
            end
        end
    end

    -- === F Override Aim Assist Handling ===
    if isFOverrideActive and isPlayerAllowedToTurn() and Humanoid then
        local target = (fOverrideTargetingMethod == "closestToMouse") and getClosestPlayerToMouse() or getClosestPlayerToTorsoUnlimited()
        local currentRotationMethod = fOverrideRotationMethod

        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local activeTempKey = activeHotbarSlot -- Since only one active slot exists

            -- Call AimStabilizer based on the determined rotation method
            if currentRotationMethod == "XY-Axis" then
                if predictionSettings.FOverride.strength > 0 then
                    AimStabilizerXY(target.Character.HumanoidRootPart, predictionSettings.FOverride.reactionTime, predictionSettings.FOverride.dampingFactor, predictionSettings.FOverride.strength, activeTempKey)
                end
            elseif currentRotationMethod == "X-Axis" then
                if predictionSettings.FOverride.strength > 0 then
                    AimStabilizerX(target.Character.HumanoidRootPart, predictionSettings.FOverride.reactionTime, predictionSettings.FOverride.dampingFactor, predictionSettings.FOverride.strength, activeTempKey)
                end
            end
        end
    end
   

    -- === Update Humanoid.AutoRotate Based on Conditions ===
    updateAutoRotate()

    aimAssistEndTime = tick() -- End tracking time
    logFunctionExecution("AimAssistCalculation", aimAssistEndTime - startTime)
end)









-- Invis + Animation-Lock w/ Orb Indicator
-- Needs an “EsperShield” with a child ParticleEmitter named “orb”
-- under StarterPlayer ▸ StarterCharacter ▸ HumanoidRootPart.
-- Relies on a global **isSkidFlinging** set elsewhere.

Players            = game:GetService("Players")
RunService         = game:GetService("RunService")
UserInputService   = game:GetService("UserInputService")

player             = Players.LocalPlayer
blockAnimationId   = "rbxassetid://77727115892579"
playAnimationId    = "rbxassetid://77727115892579"
startAtSecond      = 16.05
animSpeed          = 0

-- state
stopAnimationsConnection = nil
heartbeatConnection      = nil
descendantAddedConnection= nil

inputConnection          = nil
animTrack                = nil
isToggled                = false

----------------------------------------------------------- helpers
function getHRP(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    while not hrp do task.wait(); hrp = char:FindFirstChild("HumanoidRootPart") end
    return hrp
end

function getOrb(char)
    local es = getHRP(char):FindFirstChild("EsperShield")
    return es and es:FindFirstChild("orb") or nil
end

function enableOrb(char)
    local o = getOrb(char)
    if o then
        o.Color  = ColorSequence.new(Color3.fromRGB(173,216,230))
        o.Size   = NumberSequence.new(3.5)
        o.Enabled= true
    end
end

function disableOrb(char) local o=getOrb(char) if o then o.Enabled=false end end

function stopUnwanted(animator)
    for _,t in ipairs(animator:GetPlayingAnimationTracks()) do
        if t.Animation.AnimationId==blockAnimationId then t:Stop() end
    end
end

function playFrozen(animator)
    if isSkidFlinging then return end
    if animTrack and animTrack.IsPlaying then return end
    local ok,track = pcall(function()
        local a=Instance.new("Animation"); a.AnimationId=playAnimationId
        return animator:LoadAnimation(a)
    end)
    if ok and track then
        animTrack = track
        animTrack:Play()
        animTrack.TimePosition = startAtSecond
        animTrack:AdjustSpeed(animSpeed)
    else
        task.delay(1,function() playFrozen(animator) end)
    end
end

----------------------------------------------------------- toggle/disable
function disable(char)
    isToggled=false
    disableOrb(char)

    if animTrack               then animTrack:Stop(); animTrack=nil end
    if stopAnimationsConnection then stopAnimationsConnection:Disconnect(); stopAnimationsConnection=nil end
    if heartbeatConnection      then heartbeatConnection:Disconnect();      heartbeatConnection=nil end
    if descendantAddedConnection then descendantAddedConnection:Disconnect();descendantAddedConnection=nil end
end


function toggle(char,animator)
    if isToggled then
        disable(char)
    else
        isToggled=true
        enableOrb(char)

        stopAnimationsConnection = RunService.RenderStepped:Connect(function() stopUnwanted(animator) end)
        heartbeatConnection      = RunService.Heartbeat:Connect(function()  playFrozen(animator) end)
    end
end

----------------------------------------------------------- character handler
function onCharacterAdded(char)
    task.wait(1)
    local humanoid = char:WaitForChild("Humanoid",5)
    if not humanoid then return end
    local animator = humanoid:WaitForChild("Animator")

    humanoid.HealthChanged:Connect(function(h) if h<=0 then disable(char) end end)

    if inputConnection then inputConnection:Disconnect() end
    inputConnection = UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.KeyCode==Enum.KeyCode.T then toggle(char,animator) end
    end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

print("[Orb Invis/Anim script loaded]")






Players          = game:GetService("Players")
RunService       = game:GetService("RunService")
Workspace        = game:GetService("Workspace")
UserInputService = game:GetService("UserInputService")

player           = Players.LocalPlayer
AllBool          = false

function logFunctionExecution(name, duration) end
function stopUnwantedAnimations(animator) end
function playAnimation(animator) end

function GetPlayer(Name)
    Name = (Name or ""):lower()
    if Name == "all" or Name == "others" then
        AllBool = true
        return
    elseif Name == "random" then
        local list = Players:GetPlayers()
        if table.find(list, player) then table.remove(list, table.find(list, player)) end
        return list[math.random(#list)]
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                if p.Name:lower():match("^"..Name) or p.DisplayName:lower():match("^"..Name) then
                    return p
                end
            end
        end
    end
end

desiredFOV                    = 70
UltMode                       = false
RemoveCameraRigEnabled        = false
AlwaysRotateEnabled           = false

humanoidStateConnections      = {}
charactersWithCameraRigRemoval_UltOff, charactersWithCameraRigRemoval_UltOn = {}, {}
charactersWithAlwaysRotate_UltOff,   charactersWithAlwaysRotate_UltOn     = {}, {}

Characters = {
    ["Purple"] = {Name="Suiryu"},    ["Cyborg"]={Name="Genos"},   ["Hunter"]={Name="Garou"},
    ["Bald"]   = {Name="Saitama"},   ["Esper"] ={Name="Tatsumaki"},["Ninja"]={Name="Sonic"},
    ["Blade"]  = {Name="Atomic"},    ["Batter"]={Name="MetalBat"},["KJ"]   ={Name="KJ"},
    ["Tech"]   = {Name="ChildEmperor"},
    ["Monster"]   = {Name="Monster"},
}
displayNameToAttribute = {} for attr,info in pairs(Characters) do displayNameToAttribute[info.Name]=attr end

function UpdateFOV()
    if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = desiredFOV end
end

cameraRigConnection = nil
function removeCameraRigsFromFolder(folder)
    for _,obj in ipairs(folder:GetDescendants()) do
        if obj.Name == "CameraRig" then
            obj:Destroy()
        end
    end
end

function setupCameraRigListener()
    if cameraRigConnection then cameraRigConnection:Disconnect(); cameraRigConnection=nil end
    if not RemoveCameraRigEnabled then return end
    local live = Workspace:FindFirstChild("Live"); if not live then return end
    local meFolder = live:FindFirstChild(player.Name); if not meFolder then return end
    cameraRigConnection = RunService.Heartbeat:Connect(function()
        local t0 = tick()
        if RemoveCameraRigEnabled then removeCameraRigsFromFolder(meFolder) end
        logFunctionExecution("CameraRigRemoval", tick()-t0)
    end)
end

function cleanupCameraRigListener() if cameraRigConnection then cameraRigConnection:Disconnect();cameraRigConnection=nil end end
function monitorRemoveCameraRigToggle() if RemoveCameraRigEnabled then setupCameraRigListener() else cleanupCameraRigListener() end end

shouldAlwaysRotate = false
function applyAlwaysRotate()
    if not AlwaysRotateEnabled then return end
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = true end
end

function applySettings() UpdateFOV(); applyAlwaysRotate() end

function monitorPlayerFolder()
    local function onLiveChildAdded(child)
        if child.Name == player.Name then
            if RemoveCameraRigEnabled then setupCameraRigListener() end
        end
    end
    local live = Workspace:FindFirstChild("Live")
    if live then live.ChildAdded:Connect(onLiveChildAdded) else
        Workspace.ChildAdded:Connect(function(c) if c.Name=="Live" then c.ChildAdded:Connect(onLiveChildAdded) end end)
    end
end
monitorPlayerFolder()

function monitorUltedAttribute()
    task.spawn(function()
        local live = Workspace:WaitForChild("Live",1)
        if not live then return end
        local meFolder = live:FindFirstChild(player.Name); if not meFolder then return end
        local function refreshUlt()
            UltMode = (meFolder:GetAttribute("Ulted") == true)
        end
        refreshUlt()
        meFolder:GetAttributeChangedSignal("Ulted"):Connect(function()
            refreshUlt(); applySettings()
        end)
    end)
end
monitorUltedAttribute()

local function selected(drop)
    return drop.GetValue and drop:GetValue() or drop.Value or {}
end

Library = loadstring(game:HttpGetAsync(
    "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"
))()

SaveManager      = loadstring(game:HttpGetAsync(
    "https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
InterfaceManager = loadstring(game:HttpGetAsync(
    "https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)

Window = Library:CreateWindow{
    Title="TSBnocutsceneandFOV",SubTitle="Created by Azacks",
    TabWidth=120,Size=UDim2.fromOffset(670,710),
    Resize=true,MinSize=Vector2.new(170,150),Acrylic=false,
    Theme="GitHub Dark Default",
}

Tabs = {
    Main     = Window:CreateTab{Title="Main",     Icon="circle-user-round"},
    Settings = Window:CreateTab{Title="Settings", Icon="settings"},
}

ListTab   = Window:CreateTab{Title="Player Lists", Icon="users"}
SkidTab   = Window:CreateTab{Title="Skid", Icon="triangle-alert"}
SpoofTab  = Window:CreateTab{Title="Spoof Velocity", Icon="send-horizontal"}

Tabs.Main:CreateSlider("FOVSlider",{Title="Field of View",Default=desiredFOV,Min=0,Max=120,Rounding=1,
    Callback=function(v) desiredFOV=v; UpdateFOV() end})

Tabs.Main:CreateInput("ManualFOV",{Title="Manual FOV Override",Placeholder="90",Numeric=true,Finished=true,
    Callback=function(v) local n=tonumber(v); if n then desiredFOV=n; UpdateFOV(); Library.Options["FOVSlider"]:SetValue(n) end end})

Tabs.Main:CreateButton{Title="Reset FOV",Description="Back to 70",
    Callback=function() desiredFOV=70; UpdateFOV(); Library.Options["FOVSlider"]:SetValue(70) end}

Tabs.Main:CreateToggle("EnableCameraRigRemoval",{Title="Enable NOCUTSCENE",Default=false,
    Callback=function(e) RemoveCameraRigEnabled=e; monitorRemoveCameraRigToggle() end})

for mode,store in pairs({UltOff="charactersWithCameraRigRemoval_UltOff", UltOn="charactersWithCameraRigRemoval_UltOn"}) do
    Tabs.Main:CreateDropdown("CameraRigRemoval_"..mode,{
        Title       = "CameraRig Removal – Ultimate "..(mode=="UltOff" and "OFF" or "ON"),
        Values      = {"Suiryu","Genos","Garou","Saitama","Tatsumaki","Sonic","Atomic","MetalBat","KJ","ChildEmperor","Monster"},
        Multi       = true,
        Default     = {Suiryu=true,Genos=true,Garou=true,Saitama=true,Tatsumaki=true,Sonic=true,Atomic=true,MetalBat=true,KJ=true,ChildEmperor=true,Monster=true},
        Callback    = function(tbl)
            _G[store]={}
            for disp,sel in pairs(tbl) do if sel then local attr=displayNameToAttribute[disp]; if attr then _G[store][attr]=true end end end
        end
    })
end

Tabs.Main:CreateToggle("EnableAlwaysRotate",{Title="Enable ALWAYS ROTATE",Default=false,
    Callback=function(e) AlwaysRotateEnabled=e; applyAlwaysRotate() end})
for mode,store in pairs({UltOff="charactersWithAlwaysRotate_UltOff", UltOn="charactersWithAlwaysRotate_UltOn"}) do
    Tabs.Main:CreateDropdown("AlwaysRotate_"..mode,{
        Title       = "AlwaysRotate – Ultimate "..(mode=="UltOff" and "OFF" or "ON"),
        Values      = {"Suiryu","Genos","Garou","Saitama","Tatsumaki","Sonic","Atomic","MetalBat","KJ","ChildEmperor","Monster"},
        Multi       = true,
        Default     = {Suiryu=true,Genos=true,Garou=true,Saitama=true,Tatsumaki=true,Sonic=true,Atomic=true,MetalBat=true,KJ=true,ChildEmperor=true,Monster=true},
        Callback    = function(tbl)
            _G[store]={}
            for disp,sel in pairs(tbl) do if sel then local attr=displayNameToAttribute[disp]; if attr then _G[store][attr]=true end end end
        end
    })
end

clickFlingStatusGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
clickFlingStatusGui.Name, clickFlingStatusGui.ResetOnSpawn = "ClickFlingStatus", false
statusFrame = Instance.new("Frame", clickFlingStatusGui)
statusFrame.Size, statusFrame.Position = UDim2.fromOffset(40,40), UDim2.new(1,-50,0.5,-20)
statusFrame.BackgroundColor3, statusFrame.BorderSizePixel = Color3.fromRGB(200,0,0), 0
Instance.new("UICorner",statusFrame).CornerRadius = UDim.new(1,0)
statusLabel = Instance.new("TextLabel", statusFrame)
statusLabel.Size, statusLabel.BackgroundTransparency, statusLabel.TextScaled =
    UDim2.fromScale(1,1), 1, true
statusLabel.Font, statusLabel.TextColor3 = Enum.Font.GothamBold, Color3.new(1,1,1)
statusLabel.Text = "OFF"
function updateClickFlingIndicator(on)
    statusFrame.BackgroundColor3 = on and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0)
    statusLabel.Text             = on and "ON" or "OFF"
end

ListState, newPlayersDefault, playerDisplayToUsername = {}, "Blacklist", {}
WhitelistDD, BlacklistDD = nil, nil
function IsWhitelisted(plr) return ListState[plr.Name]=="Whitelist" end

function refreshLists()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and not ListState[p.Name] then ListState[p.Name] = newPlayersDefault end
    end
    local wl,bl = {},{} ; playerDisplayToUsername={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player then
            playerDisplayToUsername[p.DisplayName]=p.Name
            if ListState[p.Name]=="Whitelist" then wl[#wl+1]=p.DisplayName else bl[#bl+1]=p.DisplayName end
        end
    end
    if WhitelistDD then WhitelistDD:SetValues(wl) end
    if BlacklistDD then BlacklistDD:SetValues(bl) end
end

ListTab:CreateDropdown("DefaultNew",{Title="Default for New Players",Values={"Blacklist","Whitelist"},
    Multi=false,Default="Blacklist",Callback=function(v) newPlayersDefault=v end})

WhitelistDD = ListTab:CreateDropdown("WL",{Title="Whitelist",Values={},Multi=true,Default={},Description="Whitelisted"})
BlacklistDD = ListTab:CreateDropdown("BL",{Title="Blacklist",Values={},Multi=true,Default={},Description="Blacklisted"})

ListTab:CreateButton{
    Title      = "Move Selected → WL",
    Callback   = function()
        for disp,_ in pairs(selected(BlacklistDD)) do
            local uname = playerDisplayToUsername[disp]
            if uname then ListState[uname] = "Whitelist" end
        end
        BlacklistDD:SetValue({})
        refreshLists()
    end
}
ListTab:CreateButton{
    Title      = "Move Selected → BL",
    Callback   = function()
        for disp,_ in pairs(selected(WhitelistDD)) do
            local uname = playerDisplayToUsername[disp]
            if uname then ListState[uname] = "Blacklist" end
        end
        WhitelistDD:SetValue({})
        refreshLists()
    end
}
ListTab:CreateButton{Title="ALL → Whitelist",Description="Everyone WL",Callback=function()
    for _,p in ipairs(Players:GetPlayers()) do if p~=player then ListState[p.Name]="Whitelist" end end; refreshLists()
end}
ListTab:CreateButton{Title="ALL → Blacklist",Description="Everyone BL",Callback=function()
    for _,p in ipairs(Players:GetPlayers()) do if p~=player then ListState[p.Name]="Blacklist" end end; refreshLists()
end}

Players.PlayerAdded:Connect(function() task.wait(1); refreshLists() end)
Players.PlayerRemoving:Connect(function() refreshLists() end)
refreshLists()

flingDuration = 2
SkidTab:CreateInput("FlingDurInput",{
    Title="Fling Duration (sec)",Placeholder="2",Numeric=true,Finished=true,
    Callback=function(v)
        local n = tonumber(v)
        if n then flingDuration = n end
    end
})

stopAnimationsConnection, heartbeatConnection = nil,nil
function disableAnimLockLoop()
    if stopAnimationsConnection then stopAnimationsConnection:Disconnect(); stopAnimationsConnection=nil end
    if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection=nil end
end
function enableAnimLockLoop(character, animator)
    stopAnimationsConnection = RunService.RenderStepped:Connect(function() stopUnwantedAnimations(animator) end)
    heartbeatConnection      = RunService.Heartbeat:Connect(function()
        if not animTrack or not animTrack.IsPlaying then playAnimation(animator) end
    end)
end

local overrideConnection
local SkidFlingEndTimes = {}

local function setFlingCamera(targetChar)
    if not targetChar then
        warn("Cannot set fling camera: targetChar is nil.")
        return
    end
    if overrideConnection then
        overrideConnection:Disconnect()
        overrideConnection = nil
    end

    local oldCam = Workspace.CurrentCamera
    local savedCF = oldCam and oldCam.CFrame

    local existingCam = Workspace:FindFirstChild("Camera")
    if existingCam then existingCam:Destroy() end

    local cam = Instance.new("Camera")
    cam.Name       = "Camera"
    cam.CameraType = Enum.CameraType.Custom
    cam.Parent     = Workspace

    if savedCF then cam.CFrame = savedCF end
    Workspace.CurrentCamera = cam

    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    local part = hum or targetChar:FindFirstChild("HumanoidRootPart")
    if not part then
        warn("Cannot set fling camera: no Humanoid or HumanoidRootPart.")
        return
    end
    cam.CameraSubject = part

    overrideConnection = cam:GetPropertyChangedSignal("CameraSubject"):Connect(function()
        if cam.CameraSubject ~= part then
            cam.CameraType    = Enum.CameraType.Custom
            cam.CameraSubject = part
        end
    end)
end

function SkidFling(TargetPlayer, bypassWhitelist, durationOverride)
    if (not TargetPlayer)
       or TargetPlayer == player
       or (not bypassWhitelist and IsWhitelisted(TargetPlayer))
    then
        return
    end

    isSkidFlinging = true

    Character = player.Character
    Humanoid  = Character and Character:FindFirstChildOfClass("Humanoid")
    RootPart  = Humanoid  and Humanoid.RootPart

    local TCharacter = TargetPlayer.Character
    local THumanoid, TRootPart, THead, Accessory, Handle

    if TCharacter and TCharacter:FindFirstChildOfClass("Humanoid") then
        THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        TRootPart = THumanoid.RootPart
    end
    if TCharacter then
        THead     = TCharacter:FindFirstChild("Head")
        Accessory = TCharacter:FindFirstChildOfClass("Accessory")
        if Accessory then Handle = Accessory:FindFirstChild("Handle") end
    end

    if Character and Humanoid and RootPart and TCharacter then
        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end

        if THumanoid and THumanoid.Sit and not AllBool then return end

        if game.GameId == 10449761463 then
            setFlingCamera(TCharacter)
        end

        if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

        local maxDuration = durationOverride or flingDuration
        local baseEndTime = tick() + maxDuration

        local function FPos(bp, pos, ang)
            RootPart.CFrame         = CFrame.new(bp.Position) * pos * ang
            Character:SetPrimaryPartCFrame(RootPart.CFrame)
            RootPart.Velocity       = Vector3.new(9e7, 9e8, 9e7)
            RootPart.RotVelocity    = Vector3.new(9e8, 9e8, 9e8)
        end

        local function SFBasePart(bp)
            local angle   = 0
            repeat
                if not (RootPart and Humanoid and Humanoid.Health > 0 and THumanoid and THumanoid.Health > 0) then break end

                if bp.Velocity.Magnitude < 50 then
                    angle += 100
                    FPos(bp, CFrame.new(0, 1.5, 0)     + THumanoid.MoveDirection * bp.Velocity.Magnitude/1.25,
                            CFrame.Angles(math.rad(angle),0,0)); task.wait()
                    FPos(bp, CFrame.new(0,-1.5, 0)     + THumanoid.MoveDirection * bp.Velocity.Magnitude/1.25,
                            CFrame.Angles(math.rad(angle),0,0)); task.wait()
                    FPos(bp, CFrame.new( 2.25, 1.5,-2.25)+ THumanoid.MoveDirection * bp.Velocity.Magnitude/1.25,
                            CFrame.Angles(math.rad(angle),0,0)); task.wait()
                    FPos(bp, CFrame.new(-2.25,-1.5, 2.25)+ THumanoid.MoveDirection * bp.Velocity.Magnitude/1.25,
                            CFrame.Angles(math.rad(angle),0,0)); task.wait()
                    FPos(bp, CFrame.new(0, 1.5, 0)     + THumanoid.MoveDirection,
                            CFrame.Angles(math.rad(angle),0,0)); task.wait()
                    FPos(bp, CFrame.new(0,-1.5, 0)     + THumanoid.MoveDirection,
                            CFrame.Angles(math.rad(angle),0,0)); task.wait()
                else
                    FPos(bp, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90),0,0)); task.wait()
                    FPos(bp, CFrame.new(0,-1.5,-THumanoid.WalkSpeed), CFrame.Angles(0,0,0));            task.wait()
                    FPos(bp, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90),0,0)); task.wait()

                    if TRootPart then
                        local mag = TRootPart.Velocity.Magnitude/1.25
                        FPos(bp, CFrame.new(0, 1.5, mag), CFrame.Angles(math.rad(90),0,0)); task.wait()
                        FPos(bp, CFrame.new(0,-1.5,-mag), CFrame.Angles(0,0,0));            task.wait()
                        FPos(bp, CFrame.new(0, 1.5, mag), CFrame.Angles(math.rad(90),0,0)); task.wait()
                    end

                    FPos(bp, CFrame.new(0,-1.5,0), CFrame.Angles(math.rad(90),0,0)); task.wait()
                    FPos(bp, CFrame.new(0,-1.5,0), CFrame.Angles(0,0,0));           task.wait()
                    FPos(bp, CFrame.new(0,-1.5,0), CFrame.Angles(math.rad(-90),0,0));task.wait()
                    FPos(bp, CFrame.new(0,-1.5,0), CFrame.Angles(0,0,0));           task.wait()
                end
            until bp.Velocity.Magnitude > 500
                  or bp.Parent ~= TCharacter
                  or (THumanoid and THumanoid.Sit)
                  or Humanoid.Health <= 0
                  or tick() > (SkidFlingEndTimes[TargetPlayer] or baseEndTime)
        end

        pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
        getgenv().FPDH = workspace.FallenPartsDestroyHeight

        local BV = Instance.new("BodyVelocity", RootPart)
        BV.Name      = "EpixVel"
        BV.Velocity  = Vector3.new(9e8, 9e8, 9e8)
        BV.MaxForce  = Vector3.new(1/0, 1/0, 1/0)

        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

        if TRootPart and THead then
            if (TRootPart.Position - THead.Position).Magnitude > 5 then
                SFBasePart(THead)
            else
                SFBasePart(TRootPart)
            end
        elseif TRootPart then
            SFBasePart(TRootPart)
        elseif THead then
            SFBasePart(THead)
        elseif Handle then
            SFBasePart(Handle)
        end

        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        if game.GameId == 10449761463 then
            workspace.CurrentCamera.CameraSubject = Humanoid
        end
	    if overrideConnection then
	        overrideConnection:Disconnect()
	        overrideConnection = nil
	    end

        repeat
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0,0.5,0)
            Character:SetPrimaryPartCFrame(RootPart.CFrame)
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            for _,bp in ipairs(Character:GetChildren()) do
                if bp:IsA("BasePart") then
                    bp.Velocity, bp.RotVelocity = Vector3.new(), Vector3.new()
                end
            end
            task.wait()
        until (RootPart.Position - getgenv().OldPos.Position).Magnitude < 25

        pcall(function()
            workspace.FallenPartsDestroyHeight = getgenv().FPDH
        end)
    end

    isSkidFlinging = false
end

clickFlingEnabled, mouseConnection = false, nil
clickFlingSoundOn  = Instance.new("Sound",player) clickFlingSoundOn.SoundId="rbxassetid://7153189899" clickFlingSoundOn.Volume=2
clickFlingSoundOff = Instance.new("Sound",player) clickFlingSoundOff.SoundId="rbxassetid://489109520" clickFlingSoundOff.Volume=4

function GetClosestPlayerToMouse()
    local cam = Workspace.CurrentCamera; if not cam then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=player then
            local hrp=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local sp,onScr=cam:WorldToViewportPoint(hrp.Position)
                if onScr then
                    local d=(Vector2.new(sp.X,sp.Y)-mousePos).Magnitude
                    if d<bestDist then bestDist,best= d,plr end
                end
            end
        end
    end
    return best
end
function startClickFling()
    if mouseConnection then return end
    mouseConnection = player:GetMouse().Button1Down:Connect(function()
        local tgt=GetClosestPlayerToMouse()
        if tgt then SkidFling(tgt,true) end
    end)
end
function stopClickFling() if mouseConnection then mouseConnection:Disconnect();mouseConnection=nil end end
function toggleClickFling(state)
    clickFlingEnabled=state; updateClickFlingIndicator(state)
    if state then clickFlingSoundOn:Play(); startClickFling()
    else        clickFlingSoundOff:Play(); stopClickFling() end
end

SkidTab:CreateToggle("ClickFlingToggle", {
    Title   = "Enable Click Fling (Closest to Mouse)",
    Default = false,
    Callback = function(enabled)
        toggleClickFling(enabled)
        print("ClickFlingToggle =>", enabled)
    end
})

function ToggleUI()
    local guiObject = Window.GUI
    if guiObject then
        guiObject.Enabled = not guiObject.Enabled
    end
end

SkidTab:CreateKeybind("ClickFlingKeybind", {
    Title   = "Toggle Click Fling + UI",
    Mode    = "Toggle",
    Default = "Y",
    Callback = function(isActive)
        local CFOption = Library.Options["ClickFlingToggle"]
        if CFOption then
            CFOption:SetValue(isActive) 
        end
        ToggleUI()
    end
})

local function getAttrInsensitive(inst, attrName)
    if not inst or not attrName then return nil end
    local attrs = inst:GetAttributes()
    for k,v in pairs(attrs) do
        if string.lower(k) == string.lower(attrName) then
            return v
        end
    end
    return inst:GetAttribute(attrName)
end

lastHitFlingDuration = 5
local LastHitFlingEnabled = false
local lastHitAttrConn
local lastHitHealthConn
local lastHitCharConn
local lastHitFlingActive = {}

local function handleLastHitChange(char)
    if not LastHitFlingEnabled or not char then return end
    local lastHit = getAttrInsensitive(char, "LastHit")
    if typeof(lastHit) == "string" and lastHit ~= "" then
        local target
        for _,p in ipairs(Players:GetPlayers()) do
            if p.Name == lastHit or p.DisplayName == lastHit then
                target = p
                break
            end
        end
        if target then
            SkidFlingEndTimes[target] = tick() + lastHitFlingDuration
            if not lastHitFlingActive[target] then
                lastHitFlingActive[target] = true
                task.spawn(function()
                    SkidFling(target,false,lastHitFlingDuration)
                    lastHitFlingActive[target] = nil
                    SkidFlingEndTimes[target] = nil
                end)
            end
        end
    end
end

local function attachLastHitListenerToChar(char)
    if lastHitAttrConn then
        lastHitAttrConn:Disconnect()
        lastHitAttrConn = nil
    end
    if lastHitHealthConn then
        lastHitHealthConn:Disconnect()
        lastHitHealthConn = nil
    end
    if not char then return end
    lastHitAttrConn = char:GetAttributeChangedSignal("LastHit"):Connect(function()
        handleLastHitChange(char)
    end)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        lastHitHealthConn = hum.HealthChanged:Connect(function()
            handleLastHitChange(char)
        end)
    end
end

local function updateLastHitFling()
    if lastHitCharConn then
        lastHitCharConn:Disconnect()
        lastHitCharConn = nil
    end
    if not LastHitFlingEnabled then
        if lastHitAttrConn then
            lastHitAttrConn:Disconnect()
            lastHitAttrConn = nil
        end
        if lastHitHealthConn then
            lastHitHealthConn:Disconnect()
            lastHitHealthConn = nil
        end
        return
    end
    if player.Character then
        attachLastHitListenerToChar(player.Character)
    end
    lastHitCharConn = player.CharacterAdded:Connect(function(char)
        attachLastHitListenerToChar(char)
    end)
end

SkidTab:CreateToggle("LastHitFlingToggle", {
    Title   = "Last Hit Fling",
    Default = false,
    Callback = function(on)
        LastHitFlingEnabled = on
        updateLastHitFling()
    end
})

SkidTab:CreateInput("LastHitFlingDurInput",{
    Title="Last Hit Fling Duration (sec)",Placeholder="5",Numeric=true,Finished=true,
    Callback=function(v)
        local n = tonumber(v)
        if n then lastHitFlingDuration = n end
    end
})

FlingAllEnabled, RadiusFlingEnabled = false, false
FlingRadius,   FlingLoopDelay      = 25, 2
flingAllRunning, radiusFlingRunning = false, false

local function SkidFlingAll()
    AllBool = false
    for _,p in ipairs(Players:GetPlayers()) do
        SkidFling(p)
    end
end

local function startFlingAllLoop()
    if flingAllRunning then return end
    flingAllRunning = true
    task.spawn(function()
        while flingAllRunning do
            SkidFlingAll()
            task.wait(FlingLoopDelay)
        end
    end)
end
local function stopFlingAllLoop() flingAllRunning = false end

SkidTab:CreateToggle("FlingAllToggle",{
    Title="Fling ALL (loop)",Default=false,
    Callback=function(on)
        FlingAllEnabled = on
        if on then startFlingAllLoop() else stopFlingAllLoop() end
    end
})

local individualDistances, displayToUser = {}, {}

local function rebuildIndividualPlayerList()
    local list = {}
    displayToUser = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            list[#list+1] = p.DisplayName
            displayToUser[p.DisplayName] = p.Name
        end
    end
    if distanceDropdown then distanceDropdown:SetValues(list) end
end

local function pick(drop)
    local v = drop.GetValue and drop:GetValue() or drop.Value
    if typeof(v) == "table" then
        for k,sel in pairs(v) do if sel then return k end end
        return nil
    end
    return v
end

distanceDropdown = SkidTab:CreateDropdown("IndivDistDrop",{
    Title="Select Player",Values={},Multi=false
})
distanceInput = SkidTab:CreateInput("IndivDistInput",{
    Title="Distance (studs)",Placeholder="150",Numeric=true,Finished=true,
    Callback=function(v)
        local name = pick(distanceDropdown)
        local num  = tonumber(v)
        if name and num then
            local uname = displayToUser[name] or name
            individualDistances[uname] = num
        end
    end
})

rebuildIndividualPlayerList()
Players.PlayerAdded:Connect(function() task.delay(1, rebuildIndividualPlayerList) end)
Players.PlayerRemoving:Connect(rebuildIndividualPlayerList)

local function startRadiusFlingLoop()
    if radiusFlingRunning then return end
    radiusFlingRunning = true
    task.spawn(function()
        while radiusFlingRunning do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=player and not IsWhitelisted(p) then
                        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local limit = individualDistances[p.Name] or FlingRadius
                            if (root.Position-hrp.Position).Magnitude <= limit then
                                SkidFling(p)
                            end
                        end
                    end
                end
            end
            task.wait(FlingLoopDelay)
        end
    end)
end
local function stopRadiusFlingLoop() radiusFlingRunning = false end

SkidTab:CreateToggle("RadiusFlingToggle",{
    Title="RadiusFling (loop)",Default=false,
    Callback=function(on)
        RadiusFlingEnabled = on
        if on then startRadiusFlingLoop() else stopRadiusFlingLoop() end
    end
})
SkidTab:CreateInput("FlingRadiusInput",{
    Title="Fling Radius",Placeholder="25",Numeric=true,Finished=true,
    Callback=function(v) local n=tonumber(v) if n then FlingRadius=n end end
})

SpoofVelEnabled, SpoofVelX, SpoofVelY, SpoofVelZ = false,0,0,0
local spoofLoopThread

local function startSpoofLoop()
    if spoofLoopThread and coroutine.status(spoofLoopThread) ~= "dead" then return end

    spoofLoopThread = coroutine.create(function()
        while SpoofVelEnabled do
            RunService.Heartbeat:Wait()

            local char = player.Character
            local Root = char and char:FindFirstChild("HumanoidRootPart")
            if Root then
                local vel = Root.Velocity

                Root.Velocity = Vector3.new(
                    vel.X * (SpoofVelX ~= 0 and SpoofVelX or 1),
                    vel.Y * (SpoofVelY ~= 0 and SpoofVelY or 1),
                    vel.Z * (SpoofVelZ ~= 0 and SpoofVelZ or 1)
                ) + Vector3.new(SpoofVelX, SpoofVelY, SpoofVelZ)

                RunService.RenderStepped:Wait()

                Root.Velocity = vel

                RunService.Stepped:Wait()

                Root.Velocity = vel + Vector3.new(0, 0.1, 0)
            end
        end
    end)
    coroutine.resume(spoofLoopThread)
end

SpoofTab:CreateToggle("SpoofVelToggle",{
    Title   = "Enable Spoof Velocity",
    Default = false,
    Callback = function(on)
        SpoofVelEnabled = on
        if on then
            startSpoofLoop()
        end
    end
})

local function addAxisInput(axis)
    SpoofTab:CreateInput("SpoofVel"..axis,{
        Title=axis.." Velocity",Placeholder="0",Numeric=true,Finished=true,
        Callback=function(v)
            local n=tonumber(v) or 0
            if axis=="X" then SpoofVelX=n elseif axis=="Y" then SpoofVelY=n else SpoofVelZ=n end
        end
    })
end
addAxisInput("X") ; addAxisInput("Y") ; addAxisInput("Z")

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/TSBnocutscene")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
Window:SelectTab(1)

RunService.Heartbeat:Connect(function()
    applySettings()
end)
monitorRemoveCameraRigToggle()













game.Chat.BubbleChatEnabled = false

task.spawn(function()
    while true do
        wait(5) -- Adjust to your preference
        printFunctionLogs()
        -- Reset if needed
        FunctionTiming = {}
    end
end)



workspace:SetAttribute("VIPServer", true)

if game.PlaceId == 10449761463 then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/joep26020/joehub/refs/heads/main/StatGui%2BAntiDC%2BUltraInstinct.lua"))()
end


