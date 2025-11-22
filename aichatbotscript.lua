local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local GEMINI_API_KEY = "key"
local GEMINI_MODEL = "gemini-2.5-flash"
local GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/" .. GEMINI_MODEL .. ":generateContent?key=" .. GEMINI_API_KEY

local INSTRUCTIONS = [[you are a blunt trash-talking bot.
you roast people but never use slurs, gore, or nsfw.
no emojis, no hashtags, no commas, no quotes.
keep replies under 12 words, one short sentence, lowercase, no period, not corny.
make the roasts personal.]]

local ChatEnabled = true
local ChatDistance = 80
local MaxContextPerUser = 6
local MinReplyDelay = 4
local MaxReplyDelay = 5
local MaxRepliesPerWindow = 2
local RateWindowSeconds = 15
local MinGapBetweenReplies = 6

local ReplyTimestamps = {}
local LastReplyTime = 0

local isLegacyChat = true
pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        isLegacyChat = false
    end
end)

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "ChatBot"),
            Text = tostring(text or ""),
            Duration = dur or 0.5
        })
    end)
end

local function chatMessage(str)
    str = tostring(str)
    if not isLegacyChat then
        local ok, err = pcall(function()
            local chans = TextChatService:FindFirstChild("TextChannels")
            local general = chans and chans:FindFirstChild("RBXGeneral")
            if general then
                general:SendAsync(str)
            else
                TextChatService:Chat(str)
            end
        end)
        if not ok then
            warn("[ChatBot] TextChatService send failed:", err)
        end
    else
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvents and chatEvents:FindFirstChild("SayMessageRequest") then
            chatEvents.SayMessageRequest:FireServer(str, "All")
        else
            warn("[ChatBot] Legacy SayMessageRequest missing.")
        end
    end
end

local request =
    (syn and syn.request)
    or (http and http.request)
    or (request)
    or (http_request)
    or nil

local function httpPostJson(url, bodyTable)
    local jsonBody = HttpService:JSONEncode(bodyTable)
    if request then
        local ok, res = pcall(request, {
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonBody
        })
        if not ok then
            return false, "[executor request] " .. tostring(res)
        end
        return true, res.Body
    end
    local ok, res = pcall(function()
        return HttpService:PostAsync(
            url,
            jsonBody,
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)
    if not ok then
        return false, "[PostAsync] " .. tostring(res)
    end
    return true, res
end

local ListState = {}
local newPlayersDefault = "Whitelist"
local playerDisplayToUsername = {}

local function effectiveListState(name)
    return ListState[name] or newPlayersDefault
end

local function IsWhitelisted(plr)
    if not plr then return false end
    return effectiveListState(plr.Name) == "Whitelist"
end

local PerUserHistory = {}
local GlobalHistory = {}
local GlobalHistoryMax = 500

local function addHistoryLine(plr, text)
    if not plr or plr == LocalPlayer then return end
    local uname = plr.Name
    local stamp = os.date("%X")
    local name = plr.DisplayName or plr.Name
    local line = string.format("[%s] %s: %s", stamp, name, text)
    GlobalHistory[#GlobalHistory + 1] = line
    if #GlobalHistory > GlobalHistoryMax then
        table.remove(GlobalHistory, 1)
    end
    local bucket = PerUserHistory[uname]
    if not bucket then
        bucket = {}
        PerUserHistory[uname] = bucket
    end
    bucket[#bucket + 1] = line
    while #bucket > MaxContextPerUser do
        table.remove(bucket, 1)
    end
end

local function buildPromptFor(plr, latestMsg)
    local bucket = PerUserHistory[plr.Name]
    local ctx = ""
    if bucket and #bucket > 0 then
        ctx = table.concat(bucket, "\n") .. "\n"
    end
    local prompt = INSTRUCTIONS
        .. "\n\nconversation so far with this player:\n"
        .. ctx
        .. plr.Name .. ": " .. latestMsg
    return prompt
end

local function callGemini(plr, latestMsg)
    local prompt = buildPromptFor(plr, latestMsg)
    local body = {
        contents = {
            {
                role = "user",
                parts = { { text = prompt } }
            }
        }
    }
    notify("ChatBot", "thinking", 0.4)
    local ok, response = httpPostJson(GEMINI_URL, body)
    if not ok then
        warn("[ChatBot] HTTP error:", response)
        notify("ChatBot", "http error", 1)
        return nil
    end
    if not response or response == "" then
        warn("[ChatBot] Empty Gemini response.")
        notify("ChatBot", "empty response", 1)
        return nil
    end
    local data
    ok, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if not ok then
        warn("[ChatBot] JSON error:", data)
        notify("ChatBot", "json error", 1)
        return nil
    end
    local text = ""
    local cand = data.candidates and data.candidates[1]
    if cand and cand.content and cand.content.parts and cand.content.parts[1] then
        text = cand.content.parts[1].text or ""
    end
    if text == "" then
        warn("[ChatBot] Gemini returned no text.")
        return nil
    end
    text = string.gsub(text, "[\n\r]+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.lower(text)
    if string.sub(text, -1) == "." then
        text = string.sub(text, 1, -2)
    end
    return text
end

local function inRange(speaker)
    if ChatDistance <= 0 then return true end
    local myChar = LocalPlayer.Character
    local spChar = speaker.Character
    if not (myChar and spChar) then return false end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local spRoot = spChar:FindFirstChild("HumanoidRootPart")
    if not (myRoot and spRoot) then return false end
    return (myRoot.Position - spRoot.Position).Magnitude <= ChatDistance
end

local function canSendReply()
    local now = os.clock()
    local cutoff = now - RateWindowSeconds
    local newList = {}
    for i = 1, #ReplyTimestamps do
        if ReplyTimestamps[i] >= cutoff then
            newList[#newList + 1] = ReplyTimestamps[i]
        end
    end
    ReplyTimestamps = newList
    if #ReplyTimestamps >= MaxRepliesPerWindow then
        return false
    end
    ReplyTimestamps[#ReplyTimestamps + 1] = now
    return true
end

local Library = loadstring(game:HttpGetAsync(
    "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"
))()

local SaveManager = loadstring(game:HttpGetAsync(
    "https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"
))()

local InterfaceManager = loadstring(game:HttpGetAsync(
    "https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"
))()

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)

local Window = Library:CreateWindow{
    Title = "Gemini ChatBot",
    SubTitle = "client-side key",
    TabWidth = 100,
    Size = UDim2.fromOffset(700, 500),
    Resize = true,
    MinSize = Vector2.new(200, 150),
    Acrylic = false,
    Theme = "Viow Mars",
    MinimizeKey = Enum.KeyCode.Left
}

local Tabs = {
    Main = Window:CreateTab{Title = "Main", Icon = "bot"},
    Lists = Window:CreateTab{Title = "Lists", Icon = "users"},
    Settings = Window:CreateTab{Title = "Settings", Icon = "settings"},
}

local function selected(drop)
    return (drop.GetValue and drop:GetValue()) or drop.Value or {}
end

Tabs.Main:CreateToggle("EnableChatBot", {
    Title = "Enable ChatBot",
    Default = ChatEnabled,
    Callback = function(on)
        ChatEnabled = on
    end,
})

Tabs.Main:CreateInput("ChatDistanceInput", {
    Title = "Chat Distance (studs, 0 = ignore)",
    Placeholder = tostring(ChatDistance),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n then
            ChatDistance = n
        end
    end,
})

Tabs.Main:CreateInput("ContextLinesInput", {
    Title = "Context lines per player",
    Placeholder = tostring(MaxContextPerUser),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n and n > 0 then
            MaxContextPerUser = n
        end
    end,
})

Tabs.Main:CreateInput("MinDelayInput", {
    Title = "Min reply delay (s)",
    Placeholder = tostring(MinReplyDelay),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n and n >= 5 then
            MinReplyDelay = n
            if MaxReplyDelay < MinReplyDelay then
                MaxReplyDelay = MinReplyDelay
            end
        end
    end,
})

Tabs.Main:CreateInput("MaxDelayInput", {
    Title = "Max reply delay (s)",
    Placeholder = tostring(MaxReplyDelay),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n and n >= 5 then
            MaxReplyDelay = n
            if MaxReplyDelay < MinReplyDelay then
                MinReplyDelay = MaxReplyDelay
            end
        end
    end,
})

Tabs.Main:CreateInput("MinGapInput", {
    Title = "Min gap between replies (s)",
    Placeholder = tostring(MinGapBetweenReplies),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n and n >= 0 then
            MinGapBetweenReplies = n
        end
    end,
})

Tabs.Main:CreateInput("MaxRepliesInput", {
    Title = "Max replies per window",
    Placeholder = tostring(MaxRepliesPerWindow),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n and n >= 1 then
            MaxRepliesPerWindow = math.floor(n)
        end
    end,
})

Tabs.Main:CreateInput("WindowSecondsInput", {
    Title = "Window length (s)",
    Placeholder = tostring(RateWindowSeconds),
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local n = tonumber(val)
        if n and n > 0 then
            RateWindowSeconds = n
        end
    end,
})

Tabs.Main:CreateInput("PersonaInput", {
    Title = "Persona / Instructions",
    Placeholder = "toxic but not cringe...",
    Numeric = false,
    Finished = true,
    Callback = function(txt)
        if txt and txt ~= "" then
            INSTRUCTIONS = txt
        end
    end,
})

local WhitelistDD, BlacklistDD

local function refreshLists()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not ListState[p.Name] then
            ListState[p.Name] = newPlayersDefault
        end
    end
    local wl, bl = {}, {}
    playerDisplayToUsername = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            playerDisplayToUsername[p.DisplayName] = p.Name
            if effectiveListState(p.Name) == "Whitelist" then
                wl[#wl + 1] = p.DisplayName
            else
                bl[#bl + 1] = p.DisplayName
            end
        end
    end
    if WhitelistDD then WhitelistDD:SetValues(wl) end
    if BlacklistDD then BlacklistDD:SetValues(bl) end
end

Tabs.Lists:CreateDropdown("DefaultNewPlayers", {
    Title = "Default group for new players",
    Values = {"Whitelist", "Blacklist"},
    Multi = false,
    Default = newPlayersDefault,
    Callback = function(val)
        newPlayersDefault = val
        refreshLists()
    end,
})

WhitelistDD = Tabs.Lists:CreateDropdown("WL", {
    Title = "Whitelist",
    Values = {},
    Multi = true,
    Default = {},
    Description = "bot can read/respond to these players",
})

BlacklistDD = Tabs.Lists:CreateDropdown("BL", {
    Title = "Blacklist",
    Values = {},
    Multi = true,
    Default = {},
    Description = "bot ignores these players",
})

Tabs.Lists:CreateButton{
    Title = "Move Selected → WL",
    Callback = function()
        for disp,_ in pairs(selected(BlacklistDD)) do
            local uname = playerDisplayToUsername[disp]
            if uname then ListState[uname] = "Whitelist" end
        end
        BlacklistDD:SetValue({})
        refreshLists()
    end,
}

Tabs.Lists:CreateButton{
    Title = "Move Selected → BL",
    Callback = function()
        for disp,_ in pairs(selected(WhitelistDD)) do
            local uname = playerDisplayToUsername[disp]
            if uname then ListState[uname] = "Blacklist" end
        end
        WhitelistDD:SetValue({})
        refreshLists()
    end,
}

Tabs.Lists:CreateButton{
    Title = "ALL → Whitelist",
    Callback = function()
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                ListState[p.Name] = "Whitelist"
            end
        end
        refreshLists()
    end,
}

Tabs.Lists:CreateButton{
    Title = "ALL → Blacklist",
    Callback = function()
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                ListState[p.Name] = "Blacklist"
            end
        end
        refreshLists()
    end,
}

Players.PlayerAdded:Connect(function()
    task.wait(1)
    refreshLists()
end)

Players.PlayerRemoving:Connect(function()
    task.wait()
    refreshLists()
end)

refreshLists()

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/GeminiChatBot")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

local function messageWithinDistance(speaker)
    if ChatDistance <= 0 then return true end
    local myChar = LocalPlayer.Character
    local spChar = speaker.Character
    if not (myChar and spChar) then return false end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local spRoot = spChar:FindFirstChild("HumanoidRootPart")
    if not (myRoot and spRoot) then return false end
    return (myRoot.Position - spRoot.Position).Magnitude <= ChatDistance
end

local function scheduleReplySend(reply)
    if not ChatEnabled then return end
    local now = os.clock()
    local gap = math.max(MinGapBetweenReplies, 3)
    local sinceLast = now - LastReplyTime
    if sinceLast < gap then
        local extra = gap - sinceLast
        task.delay(extra, function()
            if not ChatEnabled then return end
            if not canSendReply() then return end
            LastReplyTime = os.clock()
            notify("ChatBot", "reply sent", 0.4)
            chatMessage(reply)
        end)
        return
    end
    if not canSendReply() then return end
    LastReplyTime = now
    notify("ChatBot", "reply sent", 0.4)
    chatMessage(reply)
end

local function handleIncomingMessage(plr, text)
    if not ChatEnabled then return end
    if not plr or plr == LocalPlayer then return end
    if not IsWhitelisted(plr) then return end
    if not messageWithinDistance(plr) then return end
    addHistoryLine(plr, text)
    notify("ChatBot", "msg from "..plr.Name, 0.4)
    local reply = callGemini(plr, text)
    if not reply or reply == "" then return end
    local minD = math.max(MinReplyDelay, 5)
    local maxD = math.max(MaxReplyDelay, minD)
    local delay = minD
    if maxD > minD then
        delay = minD + math.random() * (maxD - minD)
    end
    task.delay(delay, function()
        scheduleReplySend(reply)
    end)
end

if isLegacyChat then
    local function hook(plr)
        if not plr or plr == LocalPlayer then return end
        plr.Chatted:Connect(function(msg)
            handleIncomingMessage(plr, msg)
        end)
    end
    for _,p in ipairs(Players:GetPlayers()) do
        hook(p)
    end
    Players.PlayerAdded:Connect(hook)
else
    TextChatService.MessageReceived:Connect(function(msg)
        local src = msg.TextSource
        if not src then return end
        if src.UserId == LocalPlayer.UserId then return end
        local plr = Players:GetPlayerByUserId(src.UserId)
        if not plr then return end
        handleIncomingMessage(plr, msg.Text)
    end)
end

print("[ChatBot] Gemini ChatBot loaded.")
