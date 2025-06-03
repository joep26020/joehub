-- Saitama Animation Replacement Script with Uppercut/Downslam Variants, Hit/Backhit & FallingDown Cancellation, and Preloading

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Keep track of which tracks we've already replaced in this frame
local replacedTracks = {}

-- Active replacement tracks for cancellation on hit/backhit or falling down
local activeTracks = {}

-- Hit/backhit IDs that should cancel any active replacement tracks
local HIT_IDS = {
    ["10473655645"] = true, -- hit 1
    ["10473654583"] = true, -- hit 2
    ["10473655082"] = true, -- hit 3
    ["10473653782"] = true, -- hit 4
    ["10471478869"] = true, -- backhit
}

-- Garou‐style variants for Uppercut/Downslam
local garouReplacements = {
    ["10503381238"] = {  -- Uppercut
        {
            intendedID   = "140164642047188",
            playbackSpeed = 0.7,
            startTime    = 0,
            duration     = 0.8,
            playUntilEnd = false,
            chance       = 33,
        },
        {
            intendedID   = "136370737633649",
            playbackSpeed = 1,
            startTime    = 1.2,
            duration     = 0.7,
            playUntilEnd = false,
            chance       = 33,
        },
        {
            intendedID   = "18179181663",
            playbackSpeed = 1.6,
            startTime    = 0,
            duration     = 0.7,
            playUntilEnd = false,
            chance       = 34,
        },
    },
    ["10470104242"] = {  -- Downslam
        {
            intendedID   = "18464356233",
            playbackSpeed = 2.45,
            startTime    = 0.4,
            duration     = 0.85,
            playUntilEnd = false,
            chance       = 20,
        },
        {
            intendedID   = "17859055671",
            playbackSpeed = 2.2,
            startTime    = 0,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
        {
            intendedID   = "17858878027",
            playbackSpeed = 2.2,
            startTime    = 0,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
        {
            intendedID   = "17858997926",
            playbackSpeed = 2.2,
            startTime    = 0.1,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
        {
            intendedID   = "17859015788",
            playbackSpeed = 2.6,
            startTime    = 0,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
    },
}

-- Table of animations to replace (other than Uppercut/Downslam which use garouReplacements)
local animationReplacements = {
    -- M1
    ["10469493270"] = {
        {
            intendedID = "17325510002",
            playbackSpeed = 1.05,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- M2
    ["10469630950"] = {
        {
            intendedID = "17325513870",
            playbackSpeed = 1.05,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- M3
    ["10469639222"] = {
        {
            intendedID = "17325522388",
            playbackSpeed = 1.05,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- M4
    ["10469643643"] = {
        {
            intendedID = "17325537719",
            playbackSpeed = 1.05,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- Wall Combo
    ["15955393872"] = {
        {
            intendedID = "18447913645",
            playbackSpeed = 2.1,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- Normal Punch
    ["10468665991"] = {
        {
            intendedID = "16945550029",
            playbackSpeed = 2,
            startTime = 3.98,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- Consecutive Punches (handled as special sequence)
    ["10466974800"] = {
        {
            specialSequence = "consecutive_punches_sequence",
            chance = 100,
        },
    },
    -- Shove
    ["10471336737"] = {
        {
            intendedID = "16944265635",
            playbackSpeed = 1.07,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- Uppercut (single fallback, overridden by garouReplacements)
    ["12510170988"] = {
        {
            intendedID = "17325254223",
            playbackSpeed = 2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
    -- Ult Intro (chance‐based multiple)
    ["12447707844"] = {
        {
            intendedID = "17325160621",
            playbackSpeed = 2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
        {
            intendedID = "18445236460",
            playbackSpeed = 2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
        {
            intendedID = "17140902079",
            playbackSpeed = 2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 34,
        },
    },
    -- Omni
    ["13927612951"] = {
        {
            intendedID = "17141153099",
            playbackSpeed = 1.2,
            startTime = 0.25,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },
}

-- Helper: extract numeric ID from an asset ID
local function getAnimationIdFromAssetId(assetId)
    return assetId:match("%d+$")
end

-- Replace a Garou animation with one of its variants
local function replaceGarouAnimation(params, animator)
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. params.intendedID
    local track = animator:LoadAnimation(anim)
    track:Play()
    track:AdjustSpeed(params.playbackSpeed or 1)
    track.TimePosition = params.startTime or 0

    -- Track for potential cancellation
    table.insert(activeTracks, track)

    if not params.playUntilEnd and params.duration then
        task.delay(params.duration, function()
            if track.IsPlaying then
                track:Stop(0)
            end
        end)
    end
end

local function handleGarouReplacer(animationTrack, animator)
    local unwantedID = animationTrack.Animation.AnimationId:match("%d+$")
    local replacements = garouReplacements[unwantedID]
    if not replacements then return end

    animationTrack:Stop(0)

    -- Build weighted list
    local totalChance = 0
    for _, repl in ipairs(replacements) do
        totalChance = totalChance + (repl.chance or 0)
    end
    if totalChance == 0 then
        totalChance = #replacements
        for _, repl in ipairs(replacements) do
            repl.chance = 1
        end
    end

    local pick = math.random(1, totalChance)
    local cum = 0
    local selected
    for _, repl in ipairs(replacements) do
        cum = cum + (repl.chance or 0)
        if pick <= cum then
            selected = repl
            break
        end
    end

    if selected then
        replaceGarouAnimation(selected, animator)
    end
end

-- Handle special sequence "consecutive_punches_sequence"
local isConsecutivePunchesSequenceRunning = false
local function handleSpecialSequence(sequenceName, params, animator)
    if sequenceName == "consecutive_punches_sequence" then
        if isConsecutivePunchesSequenceRunning then return end
        isConsecutivePunchesSequenceRunning = true

        local humanoid = animator.Parent
        local character = humanoid.Parent
        local playerName = character.Name

        task.delay(0.55, function()
            while isConsecutivePunchesSequenceRunning do
                local barrageExists = false
                local liveFolder = workspace:FindFirstChild("Live")
                if liveFolder then
                    local playerFolder = liveFolder:FindFirstChild(playerName)
                    if playerFolder and playerFolder:FindFirstChild("BarrageBind") then
                        barrageExists = true
                    end
                end
                if not barrageExists then
                    isConsecutivePunchesSequenceRunning = false
                end
                task.wait(0.1)
            end
        end)

        for i = 1, 3 do
            if not isConsecutivePunchesSequenceRunning then break end
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://16945550029"
            local track = animator:LoadAnimation(anim)
            track:Play()
            track:AdjustSpeed(1.8)
            track.TimePosition = 2.2
            table.insert(activeTracks, track)
            task.wait(0.5)
            track:Stop(0)
            if not isConsecutivePunchesSequenceRunning then break end
        end

        isConsecutivePunchesSequenceRunning = false
    end
end

-- Main animator handler
local function onAnimationPlayed(animationTrack, animator)
    if not animationTrack.Animation then return end
    local unwantedID = getAnimationIdFromAssetId(animationTrack.Animation.AnimationId)

    -- If a hit/backhit plays, stop all active replacement tracks
    if HIT_IDS[unwantedID] then
        for _, t in ipairs(activeTracks) do
            if t.IsPlaying then
                t:Stop(0)
            end
        end
        activeTracks = {}
    end

    -- If this is Uppercut or Downslam, use Garou replacer
    if garouReplacements[unwantedID] then
        handleGarouReplacer(animationTrack, animator)
        return
    end

    local replacements = animationReplacements[unwantedID]
    if not replacements then
        return
    end

    -- Prevent replacing the same track multiple times in one instant (except special sequences)
    if unwantedID ~= "10466974800" then
        if replacedTracks[animationTrack] then return end
        replacedTracks[animationTrack] = true
    end

    -- Stop the original track immediately
    animationTrack:Stop(0)
    replacedTracks[animationTrack] = nil

    -- Choose replacement entry (chance logic for multiple entries)
    local chosenReplacement
    if #replacements > 1 then
        local totalChance = 0
        for _, repl in ipairs(replacements) do
            totalChance = totalChance + (repl.chance or 0)
        end
        if totalChance == 0 then
            totalChance = #replacements
            for _, repl in ipairs(replacements) do
                repl.chance = 1
            end
        end
        local pick = math.random(1, totalChance)
        local cum = 0
        for _, repl in ipairs(replacements) do
            cum = cum + (repl.chance or 0)
            if pick <= cum then
                chosenReplacement = repl
                break
            end
        end
    else
        chosenReplacement = replacements[1]
    end

    if not chosenReplacement then return end

    if chosenReplacement.specialSequence then
        handleSpecialSequence(chosenReplacement.specialSequence, chosenReplacement, animator)
    else
        local humanoid = animator.Parent
        local replacementAnim = Instance.new("Animation")
        replacementAnim.AnimationId = "rbxassetid://" .. chosenReplacement.intendedID
        local replacementTrack = humanoid:LoadAnimation(replacementAnim)
        replacementTrack:Play()
        replacementTrack:AdjustSpeed(chosenReplacement.playbackSpeed or 1)
        replacementTrack.TimePosition = chosenReplacement.startTime or 0
        table.insert(activeTracks, replacementTrack)
        if not chosenReplacement.playUntilEnd and chosenReplacement.duration then
            task.delay(chosenReplacement.duration, function()
                if replacementTrack.IsPlaying then
                    replacementTrack:Stop(0)
                end
            end)
        end
    end
end

-- Character setup: preload animations, connect handlers, and state cancellation
local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    local animator = humanoid:WaitForChild("Animator")
    local connections = {}

    -- Preload all animations from animationReplacements and garouReplacements
    local animIds = {}
    for _, replList in pairs(animationReplacements) do
        for _, repl in ipairs(replList) do
            if repl.intendedID then
                animIds[tostring(repl.intendedID)] = true
            end
        end
    end
    for _, variants in pairs(garouReplacements) do
        for _, variant in ipairs(variants) do
            animIds[tostring(variant.intendedID)] = true
        end
    end
    for id, _ in pairs(animIds) do
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. id
        local track = animator:LoadAnimation(anim)
        track:Play()
        track:AdjustSpeed(10)
        task.delay(0.1, function()
            if track.IsPlaying then
                track:Stop(0)
            end
        end)
    end

    -- Connect animation played handler
    table.insert(connections, animator.AnimationPlayed:Connect(function(track)
        onAnimationPlayed(track, animator)
    end))

    -- Cancel all active replacement tracks on FallingDown, and stop dive on Landed if playing dive
    table.insert(connections, humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.FallingDown then
            for _, t in ipairs(activeTracks) do
                if t.IsPlaying then
                    t:Stop(0)
                end
            end
            activeTracks = {}
        elseif newState == Enum.HumanoidStateType.Landed then
            for _, t in ipairs(activeTracks) do
                local playingID = t.Animation and t.Animation.AnimationId:match("%d+$")
                if playingID == "18464372850" and t.IsPlaying then
                    t:Stop(0)
                end
            end
        end
    end))

    -- Disconnect connections on death
    table.insert(connections, humanoid.Died:Connect(function()
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        connections = {}
    end))
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
