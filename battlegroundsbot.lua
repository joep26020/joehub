

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VIM         = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

local ConfigFileName = "TSB_Bot_Config.json"

local function cfgDeepCopy(v)
    if type(v) ~= "table" then
        return v
    end
    local t = {}
    for k, val in pairs(v) do
        t[k] = cfgDeepCopy(val)
    end
    return t
end

local function cfgDeepMerge(defaults, saved)
    if type(defaults) ~= "table" then
        if saved ~= nil and type(saved) == type(defaults) then
            return saved
        else
            return defaults
        end
    end
    local result = {}
    local savedTable = type(saved) == "table" and saved or nil
    for k, defVal in pairs(defaults) do
        local savedVal = savedTable and savedTable[k] or nil
        if type(defVal) == "table" then
            if type(savedVal) == "table" then
                result[k] = cfgDeepMerge(defVal, savedVal)
            else
                result[k] = cfgDeepCopy(defVal)
            end
        else
            if savedVal ~= nil and type(savedVal) == type(defVal) then
                result[k] = savedVal
            else
                result[k] = defVal
            end
        end
    end
    return result
end

local function cfgRead()
    if typeof(isfile) == "function" and isfile(ConfigFileName) then
        local ok, data = pcall(readfile, ConfigFileName)
        if ok and type(data) == "string" then
            return data
        end
    end
    return nil
end

local function cfgWrite(str)
    if type(str) ~= "string" then
        return false, "invalid config payload"
    end
    if typeof(writefile) ~= "function" then
        return false, "writefile unavailable"
    end
    local ok, err = pcall(writefile, ConfigFileName, str)
    if not ok then
        return false, err
    end
    return true
end

local function cfgLoad(defaults)
    local base = cfgDeepCopy(defaults or {})
    local raw = cfgRead()
    if not raw or raw == "" then
        return base
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok or type(decoded) ~= "table" then
        return base
    end
    return cfgDeepMerge(base, decoded)
end

local function cfgSave(tbl)
    local ok, jsonOrErr = pcall(function()
        return HttpService:JSONEncode(tbl or {})
    end)
    if not ok or type(jsonOrErr) ~= "string" then
        return false, jsonOrErr
    end
    return cfgWrite(jsonOrErr)
end

local function cfgSplitPath(path)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function cfgGetPath(root, path)
    if type(root) ~= "table" or type(path) ~= "string" then
        return nil
    end
    local node = root
    for part in string.gmatch(path, "[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[part]
        if node == nil then
            return nil
        end
    end
    return node
end

local function cfgSetPath(root, path, value)
    if type(root) ~= "table" or type(path) ~= "string" then
        return
    end
    local parts = cfgSplitPath(path)
    if #parts == 0 then
        return
    end
    if parts[1] == "Bind" or parts[1] == "Cooldown" then
        return
    end
    local node = root
    for i = 1, #parts - 1 do
        local key = parts[i]
        if type(node[key]) ~= "table" then
            node[key] = {}
        end
        node = node[key]
    end
    local finalKey = parts[#parts]
    node[finalKey] = value
end


local DashAnim = {
    F  = "10479335397",
    B  = "10491993682",
    SL = "10480796021",
    SR = "10480793962",
}
local CFG = {
    CharKey = "saitama",


    ComboDist      = 5,
    SpaceMin       = 4.6,
    SpaceMax       = 5.5,
    CloseUseRange  = 5,
    SnipeRange     = 60.0,
    SnipeHP        = 10,



    Cooldown = {
        F = 15.0,
        B =  12.0,
        S =  7.0,
    },

    M1Range  = 5,
    M1MaxGap = 0.62,
    InputTap = 0.10,
    TapS     = 0.05,
    TapM     = 0.25,
    M1Min    = 0.4,
    M1Rand   = 0.05,

    NPFinisherId  = "normal_punch",
    UPFinisherId  = "uppercut",


    EvasiveCD = 30,


    Gates = {
        F = { lo= 23.0, hi=33.0 },
        S = { lo= 7, hi=16 },
        B = { lo= 12, hi=30.0 },
    },






    Dash = {
        KeyQ        = Enum.KeyCode.Q,
        HoldQ       = 0.10,
        RefaceTail  = 0.60,

        FWindow     = 0.80,
        BWindow     = .90,
        SWindow     = 0.40,

        OrbitTrigger   = 5.0,
        OrbitDur       = 0.35,
        BackClose      = 2.0,
        SideOffLock    = 6,
        PreEndBackFace = 0.20,


        Anim = {
            fdash = { DashAnim.F },
            bdash = { DashAnim.B },
            side  = { DashAnim.SL, DashAnim.SR },
        }
    },


    Attack = {
        AnimIds = {
            m1    = "10469493270",
            m2    = "10469630950",
            m3    = "10469639222",
            m4    = "10469643643",
            np    = "10468665991",
            cp    = "10466974800",
            shove = "10471336737",
            upper = "12510170988",
        },
        Info = {
            ["10468665991"] = {dur=1.00, interruptible=true},
            ["10466974800"] = {dur=2.00, interruptible=true},
            ["10471336737"] = {dur=0.30, interruptible=true},
            ["12510170988"] = {dur=0.80, interruptible=true},
            ["10469493270"] = {dur=0.25, interruptible=true},
            ["10469630950"] = {dur=0.25, interruptible=true},
            ["10469639222"] = {dur=0.25, interruptible=true},
            ["10469643643"] = {dur=0.25, interruptible=true},
        }
    },


    MaxNoAtk = .5,
    ForceAtk = 2,
    CloseGain = 4.0, CloseWindow = 3.0, FarChase = 40.0,

    StillPunish = 5.0,
    AttackPunish = 6.5,


    Data  = "bgbot",
    Flush = 0.05,

    BlockAnimId = "rbxassetid://10470389827",

    
    Reward = {
        dmgDealt       = 2.00,
        dmgTaken       = -0.30,
        finisherBonus  = 3.00,
        forcedUnblock  = 2.00,
        keptAdvantage  = 4.00,
        earlyPunish    = -4.00,
        blockNoDamage  = -10.00,
        lostSpacing    = -0.50,

        applyAlpha     = 0.70,
        prevAlpha      = 0.30,
        prevWeight     = 0.50,
    },


    TuneLimits = {},
    AI = { external = false },

    AutoSave = 10,
}

local DEFAULT_CFG = cfgDeepCopy(CFG)
CFG = cfgLoad(DEFAULT_CFG)
CFG.TuneLimits = CFG.TuneLimits or {}
CFG.AI = CFG.AI or { external = false }



local BASE_COOLDOWN = {
    F = CFG.Cooldown.F,
    B = CFG.Cooldown.B,
    S = CFG.Cooldown.S,
}

local BASE_GATES = {
    F = { lo = CFG.Gates.F.lo, hi = CFG.Gates.F.hi },
    S = { lo = CFG.Gates.S.lo, hi = CFG.Gates.S.hi },
    B = { lo = CFG.Gates.B.lo, hi = CFG.Gates.B.hi },
}

CFG.Config = {
    Cooldown = CFG.Cooldown,
    Gates = CFG.Gates,
}

local SAVEABLE_CFG_KEYS = {
    Reward   = true,
    Cooldown = true,
    Gates    = true,
    SpaceMin = true,
    SpaceMax = true,
    M1Range  = true,
    AutoSave = true,
    TuneLimits = true,
    AI = true,
}

local function cfgBuildSnapshot()
    local snap = {}
    for key in pairs(SAVEABLE_CFG_KEYS) do
        if CFG[key] ~= nil then
            snap[key] = cfgDeepCopy(CFG[key])
        end
    end
    return snap
end


local function LOCK(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function() error("Locked: not editable at runtime") end,
        __metatable = "locked"
    })
end
DashAnim = LOCK(DashAnim)
CFG.Attack.AnimIds = LOCK(CFG.Attack.AnimIds) 


local BASE_SPACES = {
    SpaceMin = CFG.SpaceMin,
    SpaceMax = CFG.SpaceMax,
    M1Range  = CFG.M1Range,
}

local FORWARD_DASH_COOLDOWN = 20.0


local TUNE_SCHEMA = {
    ["Gates.F.lo"] = {min=5,  max=60, round=0.1},
    ["Gates.F.hi"] = {min=10, max=90, round=0.1},
    ["Gates.S.lo"] = {min=2,  max=20, round=0.1},
    ["Gates.S.hi"] = {min=4,  max=30, round=0.1},
    ["Gates.B.lo"] = {min=6,  max=30, round=0.1},
    ["Gates.B.hi"] = {min=10, max=60, round=0.1},

    ["SpaceMin"]   = {min=2,  max=10, round=0.05},
    ["SpaceMax"]   = {min=3,  max=14, round=0.05},
    ["M1Range"]    = {min=3,  max=8,  round=0.05},
}

local function applySavedTuneLimits()
    local saved = (type(CFG.TuneLimits) == "table") and CFG.TuneLimits or {}
    local sanitized = {}
    for key, range in pairs(saved) do
        local schema = TUNE_SCHEMA[key]
        if schema and type(range) == "table" then
            local minVal = type(range.min) == "number" and range.min or schema.min
            local maxVal = type(range.max) == "number" and range.max or schema.max
            schema.min = minVal
            schema.max = maxVal
            sanitized[key] = {min = minVal, max = maxVal}
        end
    end
    CFG.TuneLimits = sanitized
end

applySavedTuneLimits()

local function _roundTo(v, step)
    if not step or step <= 0 then return v end
    return math.round(v/step)*step
end

local function _setByPath(root, parts, value)
    local last = table.remove(parts)
    local cur  = root
    for _,k in ipairs(parts) do cur = cur[k] end
    cur[last] = value
end

local function _getByPath(root, parts)
    local cur = root
    for _,k in ipairs(parts) do cur = cur[k] end
    return cur
end

local function _applyTunable(path, val)
    local sch = TUNE_SCHEMA[path]; if not sch then return false, "not tunable" end
    if typeof(val) ~= "number" then return false, "bad type" end
    local v = math.clamp(val, sch.min, sch.max)
    v = _roundTo(v, sch.round)

    local parts = {}
    for token in string.gmatch(path, "[^%.]+") do table.insert(parts, token) end
    if parts[1] == "Cooldown" or parts[1] == "Gates" then
        _setByPath(CFG, parts, v)
    else
        CFG[parts[1]] = v
    end
    return true
end

local function _snapshotTunables()
    local snap = {}
    for k,_ in pairs(TUNE_SCHEMA) do
        local parts = {}; for token in string.gmatch(k,"[^%.]+") do table.insert(parts, token) end
        snap[k] = (parts[1]=="Cooldown" or parts[1]=="Gates")
            and _getByPath(CFG, parts)
            or CFG[parts[1]]
    end
    return snap
end



local function mkfolder(p) if makefolder and isfolder and not isfolder(p) then pcall(makefolder,p) end end
local function wfile(p,c) if writefile then pcall(writefile,p,c) end end
local function afile(p,c) if appendfile then pcall(appendfile,p,c) end end
local function rfile(p) if readfile and isfile and isfile(p) then local ok,res=pcall(readfile,p); if ok then return res end end end



local function getHotbarBase(slot:number):Frame?
    local pg = LP:FindFirstChild("PlayerGui")
    local hb = pg and pg:FindFirstChild("Hotbar")
    local bp = hb and hb:FindFirstChild("Backpack")
    local H  = bp and bp:FindFirstChild("Hotbar")
    local s  = H and H:FindFirstChild(tostring(slot))
    local base = s and s:FindFirstChild("Base")
    if base and base:IsA("Frame") then return base end
    return nil
end
local function slotCooling(slot:number):boolean
    local base = getHotbarBase(slot)
    if not base then return false end

    local y = base.Size and base.Size.Y and base.Size.Y.Scale or 0
    local vis = (base.Visible == nil) and true or base.Visible
    return vis and (math.abs(y) > 0.01)
end
local function slotReady(slot:number):boolean
    return not slotCooling(slot)
end


local SLOT = { NP=1, CP=2, Shove=3, Upper=4 }


local function pressKey(k:Enum.KeyCode, down:boolean, hold:number?)
    VIM:SendKeyEvent(down, k, false, game)
    if hold and hold>0 and down then
        task.wait(hold)
        VIM:SendKeyEvent(false, k, false, game)
    end
end

local function pressMouse(mb:Enum.UserInputType, hold:number?)
    local b = typeof(mb)=="EnumItem" and mb.Value or mb
    VIM:SendMouseButtonEvent(0,0,b,true,game,0); task.wait(hold or CFG.InputTap)
    VIM:SendMouseButtonEvent(0,0,b,false,game,0)
end

local function attrOn(v:any):boolean
    if v==nil then return false end
    local t=typeof(v)
    if t=="boolean" then return v end
    if t=="number" then return v~=0 end
    if t=="string" then local s=v:lower(); return s~="false" and s~="0" and s~="" end
    return true
end

local function getAttrInsensitive(inst:Instance?, name:string):any
    if not (inst and typeof(inst.GetAttribute)=="function" and typeof(name)=="string") then return nil end
    local attrs = inst:GetAttributes()
    local target = name:lower()
    for key,value in pairs(attrs) do
        if type(key)=="string" and key:lower()==target then
            return value
        end
    end
    return inst:GetAttribute(name)
end

local function attrTrue(inst:Instance?, name:string):boolean
    return attrOn(getAttrInsensitive(inst, name))
end

local function m1Gap()
    
    local w = CFG.M1Min + math.random() * CFG.M1Rand
    return math.min(w, CFG.M1MaxGap)
end



local function flat(v:Vector3) return Vector3.new(v.X,0,v.Z) end

local function safePos(part:BasePart?):Vector3?
    if not (part and part.Parent) then return nil end
    local ok, pos = pcall(function() return part.Position end)
    if ok then return pos end
    return nil
end

local FALL_STATES = {
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true,
}
local STUN_TAILS = {
    ["10473655082"] = true,
    ["10473654583"] = true,
    ["10473655645"] = true,
    ["10473653782"] = true,
}
local function aimCFrame(root:BasePart, tgt:BasePart)
    if not(root and tgt) then return end
    local rp, tp = root.Position, tgt.Position
    local dir = tp - rp; if dir.Magnitude<0.05 then return end
    local old = root.CFrame.LookVector; local oldPitch = math.asin(old.Y)
    local horiz = Vector3.new(tp.X,rp.Y,tp.Z); local flatv = (horiz - rp)
    if flatv.Magnitude<=1e-3 then flatv = Vector3.new(old.X,0,old.Z) end
    flatv = flatv.Unit
    local cosP = math.cos(oldPitch)
    local v = Vector3.new(flatv.X*cosP, math.sin(oldPitch), flatv.Z*cosP)
    root.CFrame = CFrame.lookAt(rp, rp+v)
end


local Bridge={}; Bridge.__index=Bridge


local LS={}; LS.__index=LS
local function sid(id:string?):string if not id then return "unk" end local n=id:match("(%d+)$"); return n or id end
local function ema(old,v,a) return old + a*(v-old) end
function LS.new()
    local self=setmetatable({},LS)
    self.dir=CFG.Data; self.file=self.dir.."/learning.json"; self.sdir=self.dir.."/sessions"
    self.data={combos={},A={},moves={},sessions=0,last=os.time(),ev={total=0,optimal=0,subopt=0}}
    self._dirty=false; self._lastFlush=0
    mkfolder(self.dir); mkfolder(self.sdir)
    local raw=rfile(self.file); if raw then pcall(function()
        local d=HttpService:JSONDecode(raw)
        if typeof(d)=="table" then
            self.data.combos=d.combos or {}; self.data.A=d.A or {}; self.data.moves=d.moves or {}
            self.data.sessions=d.sessions or 0; self.data.ev=d.ev or self.data.ev
        end
    end) end
    return self
end
function LS:_flag() self._dirty=true end
function LS:flush() local now=os.clock(); if self._dirty and now-(self._lastFlush or 0)>=CFG.Flush then self.data.last=os.time(); wfile(self.file,HttpService:JSONEncode(self.data)); self._dirty=false; self._lastFlush=now end end
function LS:startSession() self.data.sessions = self.data.sessions + 1; self:_flag(); local id=os.date("%Y%m%d-%H%M%S"); local p=self.sdir.."/"..id..".jsonl"; wfile(p,""); self.cur=p; return p end
function LS:log(ev,p) if self.cur then afile(self.cur, HttpService:JSONEncode({t=os.clock(),event=ev,data=p}).."\n") end end

function LS:combo(id)
    local c=self.data.combos[id]
    if not c then
        c={att=0,succ=0,dmgt=0,last=0}
        self.data.combos[id]=c
    end
    c.distAttemptSum=c.distAttemptSum or 0
    c.distAttemptCount=c.distAttemptCount or 0
    c.distAttemptAvg=c.distAttemptAvg or 0
    c.distSuccessSum=c.distSuccessSum or 0
    c.distSuccessCount=c.distSuccessCount or 0
    c.distSuccessAvg=c.distSuccessAvg or 0
    return c
end
function LS:att(id, dist:number?)
    local c=self:combo(id)
    c.att = c.att + 1
    c.last=os.time()
    if dist then
        c.distAttemptSum=(c.distAttemptSum or 0)+dist
        c.distAttemptCount=(c.distAttemptCount or 0)+1
        c.distAttemptAvg=c.distAttemptSum/math.max(1,c.distAttemptCount)
        c.distLastAttempt=dist
        c.distLast=dist
    end
    self:_flag()
end
function LS:res(id, ok:boolean, dm:number, dist:number?)
    local c=self:combo(id)
    if ok then
        c.succ = c.succ + 1
        c.last=os.time()
        if dist then
            c.distSuccessSum=(c.distSuccessSum or 0)+dist
            c.distSuccessCount=(c.distSuccessCount or 0)+1
            c.distSuccessAvg=c.distSuccessSum/math.max(1,c.distSuccessCount)
            c.distLastSuccess=dist
        end
    end
    c.dmgt = c.dmgt + (dm>0 and dm or 0)
    if dist then c.distLast=dist end
    self:_flag()
end

local function getA(self,id) id=sid(id); local a=self.data.A[id]; if not a then a={seen=0,open=0,block=0,prevent=0,dealt=0}; self.data.A[id]=a end; return id,a end
function LS:seen(id,dur) local _,a=getA(self,id); a.seen = a.seen + 1; self:_flag() end
function LS:dmgFrom(id,blocked,amt) local _,a=getA(self,id); local al=0.2; if blocked then a.block=ema(a.block,math.max(0,amt),al) else a.open=ema(a.open,math.max(0,amt),al) end; self:_flag() end
function LS:prevent(id) local _,a=getA(self,id); a.prevent=ema(a.prevent,1.0,0.1); self:_flag() end
function LS:deal(id,amt) local _,a=getA(self,id); a.dealt=ema(a.dealt,math.max(0,amt),0.2); self:_flag() end
function LS:threat(id) local _,a=getA(self,id); return (a.open - a.block) + (a.prevent or 0)*1.5 end
function LS:moveStats(name:string)
    local m=self.data.moves[name]
    if not m then
        m={n=0,rsum=0.0,ravg=0.0,last=0,distSum=0.0,distCount=0,distAvg=0.0,distLast=0.0}
        self.data.moves[name]=m
    else
        m.distSum=m.distSum or 0.0
        m.distCount=m.distCount or 0
        m.distAvg=m.distAvg or 0.0
        m.distLast=m.distLast or 0.0
    end
    return m
end
function LS:moveAdd(name:string, reward:number, dist:number?)
    local m=self:moveStats(name)
    m.n = m.n + 1
    m.rsum = m.rsum + reward
    m.ravg=m.rsum/math.max(1,m.n)
    m.last=os.time()
    if dist then
        m.distSum=m.distSum+dist
        m.distCount=m.distCount+1
        m.distAvg=m.distSum/math.max(1,m.distCount)
        m.distLast=dist
    end
    self:_flag()
    self:log("move_result",{name=name,reward=reward,n=m.n,ravg=m.ravg,dist=dist,distAvg=m.distAvg})
end
function LS:markEv(opt:boolean) self.data.ev.total = self.data.ev.total + 1; if opt then self.data.ev.optimal = self.data.ev.optimal + 1 else self.data.ev.subopt = self.data.ev.subopt + 1 end; self:_flag() end


local GUI={}; GUI.__index=GUI
local function text(p,n,t,sz,pos,ts,bold)
    local l=Instance.new("TextLabel"); l.Name=n; l.Size=sz; l.Position=pos
    l.BackgroundColor3=Color3.fromRGB(24,24,24); l.BackgroundTransparency=0.35
    l.TextColor3=Color3.fromRGB(235,235,235); l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize=ts; l.Text=t; l.BorderSizePixel=0; l.TextXAlignment=Enum.TextXAlignment.Left; l.TextYAlignment=Enum.TextYAlignment.Center; l.Parent=p
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,10); pad.Parent=l; return l
end

local function createPanelSection(parent, title, startCollapsed)
    local section = Instance.new("Frame")
    section.Name = title:gsub("%s+","").."Section"
    section.BackgroundColor3 = Color3.fromRGB(22,24,33)
    section.BorderSizePixel = 0
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Size = UDim2.new(1,0,0,0)
    section.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(76,110,255)
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Parent = section

    -- clickable header
    local header = Instance.new("TextButton")
    header.Name = "Header"
    header.BackgroundTransparency = 1
    header.Position = UDim2.new(0,10,0,4)
    header.Size = UDim2.new(1,-20,0,22)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 14 -- smaller
    header.TextColor3 = Color3.fromRGB(220,230,255)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.AutoButtonColor = false
    header.Text = "" -- set in setCollapsed
    header.Parent = section

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0,10,0,28)
    body.Size = UDim2.new(1,-20,0,0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Parent = section

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0,4)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    local function setCollapsed(collapsed)
        section:SetAttribute("Collapsed", collapsed and true or false)
        body.Visible = not collapsed
        if collapsed then
            header.Text = "[+] " .. title
        else
            header.Text = "[-] " .. title
        end
    end

    local initial = startCollapsed and true or false
    setCollapsed(initial)

    header.MouseButton1Click:Connect(function()
        local cur = section:GetAttribute("Collapsed")
        setCollapsed(not cur)
    end)

    return section, body
end


local function btn(p,n,t,sz,pos,clr)
    local b = Instance.new("TextButton")
    b.Name = n
    b.Size = sz
    b.Position = pos
    b.BackgroundColor3 = clr or Color3.fromRGB(48,60,96)
    b.TextColor3 = Color3.fromRGB(240,240,240)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14 -- smaller text
    b.Text = t
    b.BorderSizePixel = 0
    b.AutoButtonColor = true

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(94,123,255)
    s.Thickness = 1.4
    s.Transparency = 0.35
    s.Parent = b

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,4)
    corner.Parent = b

    b.Parent = p
    return b
end

local function drag(f:Frame)
    local g=false; local st,sp
    f.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then g=true; st=i.Position; sp=f.Position; i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then g=false end end) end end)
    f.InputChanged:Connect(function(i) if g and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-st; f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end

local function createInfoCard(parent:Instance, title:string, initialText:string?, opts)
    local card = Instance.new("Frame")
    card.Name = title:gsub("%s+","").."Card"
    card.BackgroundColor3 = Color3.fromRGB(20,22,32)
    card.BorderSizePixel = 0
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,8)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70,98,180)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = card

    local header = Instance.new("TextLabel")
    header.Name = title.."Header"
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1,-20,0,14)
    header.Position = UDim2.new(0,10,0,8)
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 11 -- smaller
    header.TextColor3 = Color3.fromRGB(150,160,210)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = string.upper(title)
    header.Parent = card

    local value = Instance.new("TextLabel")
    value.Name = title.."Value"
    value.BackgroundTransparency = 1
    value.Size = UDim2.new(1,-20,1,-28)
    value.Position = UDim2.new(0,10,0,22)
    value.Font = (opts and opts.font) or Enum.Font.GothamBold
    value.TextSize = (opts and opts.textSize) or 16 -- was 18
    value.TextColor3 = (opts and opts.textColor) or Color3.fromRGB(230,235,255)
    value.TextXAlignment = (opts and opts.textXAlignment) or Enum.TextXAlignment.Left
    value.TextYAlignment = Enum.TextYAlignment.Top
    value.TextWrapped = true
    value.Text = initialText or ""
    value.Parent = card

    return value, header, card
end

function GUI.new()
    local self = setmetatable({}, GUI)

    local g = Instance.new("ScreenGui")
    g.Name = "BGBotUI"
    g.ResetOnSpawn = false
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g.Parent = gethui and gethui() or game:GetService("CoreGui")

    local f = Instance.new("Frame")
    f.Name = "Main"
    f.Size = UDim2.new(0, 640, 0, 540) -- smaller
    f.Position = UDim2.new(0.5, -320, 0.5, -270)
    f.BackgroundColor3 = Color3.fromRGB(17,18,26)
    f.BorderSizePixel = 0
    f.Parent = g
    drag(f)

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(76,110,255)
    s.Thickness = 1.5
    s.Transparency = 0.15
    s.Parent = f

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,8)
    corner.Parent = f

    -- header
    local title = Instance.new("TextLabel")
    title.Name = "Header"
    title.Size = UDim2.new(1,-40,0,40)
    title.Position = UDim2.new(0,20,0,10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22 -- smaller
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(205,214,255)
    title.Text = "Aggro Bot v6.0"
    title.Parent = f

    -- top buttons
    local controlRow = Instance.new("Frame")
    controlRow.Name = "ControlRow"
    controlRow.Size = UDim2.new(1,-40,0,36)
    controlRow.Position = UDim2.new(0,20,0,54)
    controlRow.BackgroundTransparency = 1
    controlRow.Parent = f

    local controlLayout = Instance.new("UIGridLayout")
    controlLayout.CellPadding = UDim2.new(0,8,0,0)
    controlLayout.CellSize = UDim2.new(1/3,-6,1,0)
    controlLayout.FillDirectionMaxCells = 3
    controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    controlLayout.Parent = controlRow

    local startB = btn(controlRow,"Start","Start",UDim2.new(1,0,1,0),UDim2.new(0,0,0,0))
    startB.LayoutOrder = 1
    local stopB  = btn(controlRow,"Stop","Stop", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(120,50,50))
    stopB.LayoutOrder = 2
    local exitB  = btn(controlRow,"Exit","Exit", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(80,30,30))
    exitB.LayoutOrder = 3

    -- status cards
    local statsGrid = Instance.new("Frame")
    statsGrid.Name = "StatusGrid"
    statsGrid.Size = UDim2.new(1,-40,0,120)
    statsGrid.Position = UDim2.new(0,20,0,96)
    statsGrid.BackgroundTransparency = 1
    statsGrid.Parent = f

    local grid = Instance.new("UIGridLayout")
    grid.CellPadding = UDim2.new(0,8,0,8)
    grid.CellSize = UDim2.new(0.5,-4,0,64) -- shorter cards
    grid.FillDirectionMaxCells = 2
    grid.Parent = statsGrid

    local statusValue, statusHeader = createInfoCard(statsGrid, "Status", "Idle")
    local targetValue, targetHeader = createInfoCard(statsGrid, "Target", "None")
    local comboValue,  comboHeader  = createInfoCard(statsGrid, "Combo", "None")
    local evValue,     evHeader     = createInfoCard(statsGrid, "Evasive", "Ready")

    self.status = statusValue; self.statusHeader = statusHeader
    self.target = targetValue; self.targetHeader = targetHeader
    self.combo  = comboValue;  self.comboHeader  = comboHeader
    self.ev     = evValue;     self.evHeader     = evHeader
    self.cooldownBars = {}

    -- mid row: cooldowns + rules
    local detailRow = Instance.new("Frame")
    detailRow.Name = "DetailRow"
    detailRow.Size = UDim2.new(1,-40,0,72)
    detailRow.Position = UDim2.new(0,20,0,226)
    detailRow.BackgroundTransparency = 1
    detailRow.Parent = f

    local detailLayout = Instance.new("UIListLayout")
    detailLayout.FillDirection = Enum.FillDirection.Horizontal
    detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
    detailLayout.Padding = UDim.new(0,8)
    detailLayout.Parent = detailRow

    local movesValue, movesHeader, movesCard =
        createInfoCard(detailRow, "Dash Cooldowns", "", {textSize=14, font=Enum.Font.Gotham})
    movesCard.Size = UDim2.new(0.5,-4,1,0)
    self.moves = movesValue; self.movesHeader = movesHeader

    local rulesText = "FDash[14..30] • SideOff relock≤3.5 • Still>5s→dash • Idle atk≤15s • M1 openers"
    local rulesValue, rulesHeader, rulesCard =
        createInfoCard(detailRow, "Rules", rulesText, {textSize=13, font=Enum.Font.Gotham, textColor=Color3.fromRGB(210,220,255)})
    rulesCard.Size = UDim2.new(0.5,-4,1,0)
    self.rules = rulesValue; self.rulesHeader = rulesHeader

    -- bottom panel
    local panel = Instance.new("Frame")
    panel.Name = "DataPanel"
    panel.Size = UDim2.new(1,-40,0,220) -- smaller height
    panel.Position = UDim2.new(0,20,0,310)
    panel.BackgroundColor3 = Color3.fromRGB(20,22,30)
    panel.BorderSizePixel = 0
    panel.Parent = f

    local pst = Instance.new("UIStroke")
    pst.Color = Color3.fromRGB(76,110,255)
    pst.Thickness = 1
    pst.Transparency = 0.2
    pst.Parent = panel

    local columns = Instance.new("Frame")
    columns.BackgroundTransparency = 1
    columns.Size = UDim2.new(1,-24,1,-20)
    columns.Position = UDim2.new(0,12,0,10)
    columns.Parent = panel

    local leftCol = Instance.new("Frame")
    leftCol.Name = "LeftColumn"
    leftCol.BackgroundTransparency = 1
    leftCol.Size = UDim2.new(0.46,-4,1,0)
    leftCol.Position = UDim2.new(0,0,0,0)
    leftCol.Parent = columns

    -- right column is scrollable
    local rightCol = Instance.new("ScrollingFrame")
    rightCol.Name = "RightColumn"
    rightCol.BackgroundTransparency = 1
    rightCol.Size = UDim2.new(0.54,-4,1,0)
    rightCol.Position = UDim2.new(0.46,8,0,0)
    rightCol.ScrollBarThickness = 4
    rightCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rightCol.CanvasSize = UDim2.new(0,0,0,0)
    rightCol.BorderSizePixel = 0
    rightCol.Parent = columns

    -- combo tracker (left)
    local comboFrame = Instance.new("Frame")
    comboFrame.Name = "Combos"
    comboFrame.Size = UDim2.new(1,0,1,0)
    comboFrame.BackgroundColor3 = Color3.fromRGB(16,18,26)
    comboFrame.BorderSizePixel = 0
    comboFrame.Parent = leftCol

    local comboStroke = Instance.new("UIStroke")
    comboStroke.Color = Color3.fromRGB(76,110,255)
    comboStroke.Thickness = 1
    comboStroke.Transparency = 0.25
    comboStroke.Parent = comboFrame

    local comboPad = Instance.new("UIPadding")
    comboPad.PaddingLeft  = UDim.new(0,6)
    comboPad.PaddingRight = UDim.new(0,6)
    comboPad.PaddingTop   = UDim.new(0,6)
    comboPad.Parent = comboFrame

    self.ctitle = text(comboFrame,"CT","Combo Tracker",UDim2.new(1,-12,0,22),UDim2.new(0,0,0,0),16,true)
    self.ctitle.BackgroundTransparency = 1

    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.Size = UDim2.new(1,-2,1,-30)
    list.Position = UDim2.new(0,0,0,26)
    list.CanvasSize = UDim2.new(0,0,0,0)
    list.BackgroundColor3 = Color3.fromRGB(11,13,18)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.Parent = comboFrame

    local ul = Instance.new("UIListLayout")
    ul.Padding = UDim.new(0,2)
    ul.SortOrder = Enum.SortOrder.LayoutOrder
    ul.Parent = list

    self.comboList  = list
    self.comboLayout = ul

    self.gui   = g
    self.frame = f
    self.startB = startB
    self.stopB  = stopB
    self.exitB  = exitB

    self:setS("Status: idle")
    self:setT("Target: none")
    self:setC("Combo: none")
    self:setE("Evasive: ready")
    self:updateCDs(0,0,0)
    self.rules.Text = rulesText

    self:addConsole(rightCol)
    return self
end


local function applyCardText(label:TextLabel?, header:TextLabel?, fallback:string, text:string)
    if not label then return end
    text = text or ""
    local prefix, rest = text:match("^([^:]+):%s*(.+)$")
    if prefix and rest then
        if header then header.Text = string.upper(prefix) end
        label.Text = rest
    else
        if header and fallback then header.Text = string.upper(fallback) end
        label.Text = text
    end
end

function GUI:setS(t) applyCardText(self.status, self.statusHeader, "Status", t) end
function GUI:setT(t) applyCardText(self.target, self.targetHeader, "Target", t) end
function GUI:setC(t) applyCardText(self.combo, self.comboHeader, "Combo", t) end
function GUI:setE(t) applyCardText(self.ev, self.evHeader, "Evasive", t) end
function GUI:updateCDs(f,b,s)
    if not self.moves then return end
    self.moves.Text = string.format("F %.2fs   B %.2fs   S %.2fs", math.max(0,f), math.max(0,b), math.max(0,s))
end

function GUI:updateCooldownBar(name, value)
    local bars = self.cooldownBars
    if not bars then return end
    local bar = bars[name]
    if not (bar and bar.Parent) then return end
end
function GUI:updateCombos(data)
    for _,ch in ipairs(self.comboList:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
    local combos = data.combos or {}
    local rows = {}
    for id,info in pairs(combos) do
        local att = info.att or 0; local succ=info.succ or 0; local sr = (att>0) and (succ/att*100) or 0
        table.insert(rows, {id=id, att=att, succ=succ, sr=sr, dmgt=info.dmgt or 0})
    end
    table.sort(rows,function(a,b) if a.sr==b.sr then return a.dmgt>b.dmgt end return a.sr>b.sr end)
    for _,r in ipairs(rows) do
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-6,0,20); l.BackgroundTransparency=1
        l.TextColor3=Color3.fromRGB(210,220,255); l.Font=Enum.Font.Gotham; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Left
        l.Text=string.format("%-14s | %2d/%2d | %5.1f%% | dmg %.0f", r.id, r.succ, r.att, r.sr, r.dmgt); l.Parent=self.comboList
    end
    self.comboList.CanvasSize=UDim2.new(0,0,0,self.comboLayout.AbsoluteContentSize.Y+8)
end
function GUI:destroy() if self.gui then self.gui:Destroy() end end

function GUI:addConsole(container)
    local layout = Instance.new("UIListLayout")
    layout.Name = "SectionLayout"
    layout.Padding = UDim.new(0,10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = container

    local saveSection, saveBody = createPanelSection(container, "Configuration")
    saveSection.LayoutOrder = 1

    local saveRow = Instance.new("Frame")
    saveRow.BackgroundTransparency = 1
    saveRow.Size = UDim2.new(1,0,0,28)
    saveRow.Parent = saveBody

    local saveBtn = btn(saveRow, "SaveConfig", "Save Config", UDim2.new(0,120,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(60,88,140))
    saveBtn.TextSize = 13

    local cfgStatus = Instance.new("TextLabel")
    cfgStatus.BackgroundTransparency = 1
    cfgStatus.Position = UDim2.new(0,130,0,0)
    cfgStatus.Size = UDim2.new(1,-130,1,0)
    cfgStatus.Font = Enum.Font.Gotham
    cfgStatus.TextSize = 13
    cfgStatus.TextXAlignment = Enum.TextXAlignment.Left
    cfgStatus.TextColor3 = Color3.fromRGB(180,235,190)
    cfgStatus.Text = "Config: saved"
    cfgStatus.Parent = saveRow

    saveBtn.MouseButton1Click:Connect(function()
        self:saveConfigToDisk()
    end)

    self.saveConfigButton = saveBtn
    self.configStatusLabel = cfgStatus

    self:addRewardEditor(container, 2)
    self:addLimiterEditor(container, 3)

    self:updateConfigSaveState(false)
end


function GUI:updateConfigSaveState(dirty)
    self.configDirty = dirty and true or false
    local lbl = self.configStatusLabel
    if lbl then
        if self.configDirty then
            lbl.Text = "Config: unsaved changes"
            lbl.TextColor3 = Color3.fromRGB(255,210,140)
        else
            lbl.Text = "Config: saved"
            lbl.TextColor3 = Color3.fromRGB(180,235,190)
        end
    end
end

function GUI:markConfigDirty()
    if self.configDirty then return end
    self:updateConfigSaveState(true)
end

function GUI:saveConfigToDisk()
    local ok, err = cfgSave(cfgBuildSnapshot())
    if ok then
        self:updateConfigSaveState(false)
        warn("[BGBot] config saved to " .. ConfigFileName)
    else
        warn("[BGBot] config save failed: " .. tostring(err or "unknown"))
    end
end

function GUI:addRewardEditor(container, order)
    local section, body = createPanelSection(container, "Reward Editor", true)
    section.LayoutOrder = order or (section.LayoutOrder or 4)
    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.TextWrapped = true
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 13
    desc.TextColor3 = Color3.fromRGB(200,210,255)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Size = UDim2.new(1,0,0,32)
    desc.Text = "Adjust action rewards without retyping commands. Values feed directly into CFG.Reward."
    desc.Parent = body

    local rows = Instance.new("Frame")
    rows.BackgroundTransparency = 1
    rows.Size = UDim2.new(1,0,0,0)
    rows.AutomaticSize = Enum.AutomaticSize.Y
    rows.Parent = body
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Padding = UDim.new(0,4)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = rows

    local keys = {}
    for k,_ in pairs(CFG.Reward or {}) do table.insert(keys, k) end
    table.sort(keys)

    for _,key in ipairs(keys) do
        local row = Instance.new("Frame")
        row.BackgroundColor3 = Color3.fromRGB(14,16,24)
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1,0,0,28)
        row.Parent = rows

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0,8,0,4)
        lbl.Size = UDim2.new(0.45, -8, 1, -8)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(220,230,255)
        lbl.Text = key
        lbl.Parent = row

        local box = Instance.new("TextBox")
        box.BackgroundColor3 = Color3.fromRGB(28,30,40)
        box.TextColor3 = Color3.fromRGB(240,240,240)
        box.Font = Enum.Font.Gotham
        box.TextSize = 14
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.Size = UDim2.new(0.30, -6, 0, 24)
        box.Position = UDim2.new(0.48,0,0,2)
        box.Text = tostring(CFG.Reward[key])
        box.ClearTextOnFocus = false
        box.Parent = row

        local apply = Instance.new("TextButton")
        apply.Size = UDim2.new(0,60,0,24)
        apply.Position = UDim2.new(1,-66,0,2)
        apply.BackgroundColor3 = Color3.fromRGB(52,64,104)
        apply.TextColor3 = Color3.fromRGB(240,240,240)
        apply.Font = Enum.Font.GothamBold
        apply.TextSize = 14
        apply.Text = "Set"
        apply.Parent = row

        local function applyValue()
            local value = tonumber(box.Text)
            if not value then
                warn(string.format("[BGBot] Reward %s requires a number", key))
                return
            end
            CFG.Reward[key] = value
            if self.markConfigDirty then
                self:markConfigDirty()
            end
            warn(string.format("[BGBot] reward %s = %.3f", key, value))
        end

        apply.MouseButton1Click:Connect(applyValue)
        box.FocusLost:Connect(function(enter)
            if enter then applyValue() end
        end)
    end
end

function GUI:addLimiterEditor(container, order)
    local section, body = createPanelSection(container, "Value Limiters", true)
    section.LayoutOrder = order or (section.LayoutOrder or 5)
    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.TextWrapped = true
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 13
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextColor3 = Color3.fromRGB(200,210,255)
    desc.Size = UDim2.new(1,0,0,34)
    desc.Text = "Change the min/max bounds for tunables (used by /set and the AI auto-tuner)."
    desc.Parent = body

    local rows = Instance.new("Frame")
    rows.BackgroundTransparency = 1
    rows.Size = UDim2.new(1,0,0,0)
    rows.AutomaticSize = Enum.AutomaticSize.Y
    rows.Parent = body
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Padding = UDim.new(0,4)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = rows

    local keys = {}
    for k,_ in pairs(TUNE_SCHEMA or {}) do table.insert(keys, k) end
    table.sort(keys)

    for _,key in ipairs(keys) do
        local schema = TUNE_SCHEMA[key]
        local row = Instance.new("Frame")
        row.BackgroundColor3 = Color3.fromRGB(14,16,24)
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1,0,0,32)
        row.Parent = rows

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0,8,0,6)
        lbl.Size = UDim2.new(0.40,-8,0,20)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(220,230,255)
        lbl.Text = key
        lbl.Parent = row

        local minBox = Instance.new("TextBox")
        minBox.BackgroundColor3 = Color3.fromRGB(28,30,40)
        minBox.TextColor3 = Color3.fromRGB(240,240,240)
        minBox.Font = Enum.Font.Gotham
        minBox.TextSize = 13
        minBox.Size = UDim2.new(0,64,0,24)
        minBox.Position = UDim2.new(0.45,0,0,4)
        minBox.Text = tostring(schema.min)
        minBox.Parent = row

        local maxBox = Instance.new("TextBox")
        maxBox.BackgroundColor3 = Color3.fromRGB(28,30,40)
        maxBox.TextColor3 = Color3.fromRGB(240,240,240)
        maxBox.Font = Enum.Font.Gotham
        maxBox.TextSize = 13
        maxBox.Size = UDim2.new(0,64,0,24)
        maxBox.Position = UDim2.new(0.60,0,0,4)
        maxBox.Text = tostring(schema.max)
        maxBox.Parent = row

        local apply = Instance.new("TextButton")
        apply.Size = UDim2.new(0,60,0,24)
        apply.Position = UDim2.new(1,-66,0,4)
        apply.BackgroundColor3 = Color3.fromRGB(52,64,104)
        apply.TextColor3 = Color3.fromRGB(240,240,240)
        apply.Font = Enum.Font.GothamBold
        apply.TextSize = 14
        apply.Text = "Limit"
        apply.Parent = row

        local function applyLimit()
            local minVal = tonumber(minBox.Text)
            local maxVal = tonumber(maxBox.Text)
            if not (minVal and maxVal) then
                warn(string.format("[BGBot] Limiter %s needs numeric min/max", key))
                return
            end
            if minVal > maxVal then
                warn(string.format("[BGBot] Limiter %s min cannot exceed max", key))
                return
            end
            schema.min = minVal
            schema.max = maxVal
            CFG.TuneLimits = CFG.TuneLimits or {}
            CFG.TuneLimits[key] = {min = minVal, max = maxVal}
            if self.markConfigDirty then
                self:markConfigDirty()
            end
            warn(string.format("[BGBot] limits %s = %.3f..%.3f", key, minVal, maxVal))
        end

        apply.MouseButton1Click:Connect(applyLimit)
        minBox.FocusLost:Connect(function(enter)
            if enter then applyLimit() end
        end)
        maxBox.FocusLost:Connect(function(enter)
            if enter then applyLimit() end
        end)
    end
end

function GUI:setKPI(gen, eps, life)
    local kd = 0
    if life and life.kd then
        kd = life.kd
    elseif life and life.deaths ~= nil then
        local deaths = life.deaths
        local kills = life.kills or 0
        if deaths > 0 then
            kd = kills / math.max(1, deaths)
        else
            kd = kills
        end
    end
    self.rules.Text = string.format(
        "Gen=%d • ε=%.2f • LastLife: R=%.1f, KD=%.2f, Dmg %d/%d",
        gen or 0,
        eps or 0.15,
        life and life.reward or 0,
        kd,
        life and life.damage and life.damage.dealt or 0,
        life and life.damage and life.damage.taken or 0
    )
end


type Step = {kind:string, action:string?, hold:number?, wait:number?, dir:string?}
type Combo = {id:string, name:string, reqNoEv:boolean?, min:number?, max:number?, steps:{Step}, traits:{string}?, risk:number?}
local function hasTrait(c:Combo,t:string):boolean if not c.traits then return false end for _,x in ipairs(c.traits) do if x==t then return true end end return false end


local LIB:{Combo} = {

    {
        id="sai_sd_m1h",
        name="M1>Shove->Side(off)->M1(HOLD)",
        min=0, max=7.5, risk=0.28,
        steps={
            {kind="aim"},
            {kind="press",action="M1",hold=CFG.TapS,wait=m1Gap()},
            {kind="press",action="Shove",wait=0.12},
            {kind="dash",action="side",dir="off",wait=0.08},
            {kind="press",action="M1HOLD",hold=CFG.TapM,wait=m1Gap()},
        },
        traits={"pressure","guardbreak"}
    },

    {
        id="sai_m1cp_np",
        name="M1x2>CP>M1>NP",
        min=0, max=7.2, risk=0.35,
        steps={
            {kind="aim"},
            {kind="press",action="M1",hold=CFG.TapS,wait=m1Gap()},
            {kind="press",action="M1",hold=CFG.TapS,wait=m1Gap()},
            {kind="press",action="CP",wait=0.40},
            {kind="press",action="M1",wait=m1Gap()},
            {kind="press",action="NP"},
        },
        traits={"finisher_np"}
    },

    {
        id="sai_upper_path",
        name="M1>Upper (situational) -> Dash follow",
        min=0, max=8, reqNoEv=true, risk=0.55,
        steps={
            {kind="aim"},
            {kind="press",action="M1",hold=CFG.TapS,wait=m1Gap()},
            {kind="press",action="Upper",wait=0.28},
            {kind="dash",action="auto_after_upper",dir="smart",wait=0.10},
        },
        traits={"launcher","requires_evasive"}
    },

    {
        id="sai_m1_shove_sd_cp_np",
        name="M1->Shove->M1(HOLD)->Side(off)->CP->M1->NP",
        min=0, max=7.5, risk=0.42,
        steps={
            {kind="aim"},
            {kind="press",action="M1",hold=CFG.TapS,wait=m1Gap()},
            {kind="press",action="Shove",wait=0.12},
            {kind="press",action="M1HOLD",hold=CFG.TapM,wait=0.30},
            {kind="dash",action="side",dir="off",wait=0.08},
            {kind="press",action="CP",wait=0.36},
            {kind="press",action="M1",hold=CFG.TapS,wait=m1Gap()},
            {kind="press",action="NP"},
        },
        traits={"pressure","branching"}
    },
}


local Bot={}; Bot.__index=Bot

function Bot:_trackConnection(conn)
    if not conn then return nil end
    self.connections = self.connections or {}
    table.insert(self.connections, conn)
    return conn
end

function Bot:_aimCameraAt(tHRP:BasePart?)
    if not tHRP then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local targetPos = safePos(tHRP)
    if not targetPos then return end
    local dir = targetPos - camPos
    if dir.Magnitude < 1e-3 then return end
    cam.CFrame = CFrame.new(camPos, camPos + dir.Unit)
end

function Bot:_restoreCamera()
    local cam = workspace.CurrentCamera
    if cam and self.savedCameraType then
        cam.CameraType = self.savedCameraType
    end
    self.savedCameraType = nil
end

function Bot:_cancelActiveCombo()
    if self.actThread then
        pcall(task.cancel, self.actThread)
        self.actThread = nil
    end
    self.curCombo = nil
    if self.gui then
        self.gui:setC("Combo: none")
    end
end

function Bot:_stopDashOrientation()
    self.dashState = nil
    self.inDash = false
end

function Bot:_stopBlocking()
    if self.blocking then
        self:_forceUnblockNow()
    end
    self.blockStartTime = nil
end
type Enemy = {
    model:Model, hum:Humanoid?, hrp:BasePart?, dist:number,
    hasEv:boolean, lastEv:number, score:number, ply:Player?, hp:number,
    style:{aggr:number, def:number, ev:number, lastAtk:number, lastBlk:number, lastDash:number},
    recent:number,
    aRecent:number,
    active:{[AnimationTrack]:{id:string,start:number,wasBlk:boolean,hit:boolean}},
    cons:{RBXScriptConnection},
    aggro:number,
    lastStunByMe:number?,
}

function Bot.new()
    local self=setmetatable({},Bot)


    self.gui=GUI.new()
    self.ls=LS.new()
    self.bridge=Bridge.new()


    self.run=false; self.state="idle"; self.actThread=nil
    self.char=nil; self.hum=nil; self.rp=nil; self.alive=false

    self.policyPath = CFG.Data.."/policy.json"
    self.kpiPath = CFG.Data.."/gen_kpis.json"
    self.policy = {}
    self.bandit = {
        epsilon = 0.15,
        generation = 0,
        actions = {},
        lastAction = nil,
        tune = {},
        meta = nil,
    }
    self.lifeStats = {index = 0, damageDealt = 0, damageTaken = 0, reward = 0, kills = 0}

    self.connections = {}
    self.destroyed = false
    self.savedCameraType = nil

    self.evReady=true; self.evTimer=0; self.shouldPanic=false
    self.lastRealDash = {F=-1e9, B=-1e9, S=-1e9}
    self.lastM1=0; self.lastSkill=0; self.lastSnipe=0
    self.lastAttacker=nil; self.lastAtkTime=0; self.lastDmg=0; self.lastHP=0

    self.blocking=false; self.blockUntil=0; self.lastBlockTime=0; self.blockCooldown=0
    self.blockStartTime=nil; self.blockReleaseAt=0; self.blockKeyDown=false

    self.stunFollow=nil
    self.lastStunTarget=nil

    self.moveKeys={ [Enum.KeyCode.W]=false,[Enum.KeyCode.A]=false,[Enum.KeyCode.S]=false,[Enum.KeyCode.D]=false }
    self.strafe=0; self.lastStrafe=0

    self.liveFolder = workspace:FindFirstChild("Live")
    self.liveChar = self.liveFolder and self.liveFolder:FindFirstChild(LP.Name) or nil
    self.liveConn=nil

    self:loadPolicy()


    self.myAnims={}; self.myHumConns={}
    self.attackActive={}
    self.isAttacking=false
    self.isM1ing=false
    self.m1ChainCount=0
    self.lastM1Target=nil
    self.lastM1AttemptTime=0

    local nowT=os.clock()
    self.lastAttempt=nowT; self.urgency=0
    self.arcUntil=0; self.closeT=os.clock(); self.closeD=math.huge
    self.pendingResume=false
    self.pendingLifeStart=false
    self._nextAutoSaveAt = os.clock() + (CFG.AutoSave or 30)
    self.errorState = false
    self.handlingError = false
    self.recoveringFromFall = false


    self.inDash=false
    self.dashState=nil
    self.dashPending = nil


    self.sticky=nil
    self.stickyT=0
    self.stickyHold=1.6
    self.switchMargin=math.huge
    self.lastStunTarget=nil


    self.stillTimer=0
    self.lastMoveTime=nowT
    self.lastOffenseTime=nowT


    self.isUlt=false
    self.lastUltCheck=0

    self:_trackConnection(self.gui.startB.MouseButton1Click:Connect(function()
        if getgenv().BattlegroundsBot then getgenv().BattlegroundsBot:start() end
    end))
    self:_trackConnection(self.gui.stopB.MouseButton1Click:Connect(function()
        if getgenv().BattlegroundsBot then getgenv().BattlegroundsBot:stop() end
    end))
    self:_trackConnection(self.gui.exitB.MouseButton1Click:Connect(function()
        if getgenv().BattlegroundsBot then getgenv().BattlegroundsBot:exit() end
    end))

    self.gui:setS("Status: idle"); self.gui:setT("Target: none"); self.gui:setC("Combo: none"); self.gui:setE("Evasive: unknown")
    self.gui:updateCombos(self.ls.data); self.gui:updateCDs(0,0,0)
    if self.gui and self.gui.setKPI then
        local meta = self.bandit.meta or {}
        self.gui:setKPI(meta.generation or 0, self.bandit.epsilon or 0.15, meta.lastLife)
    end

    self:connectChar(LP.Character or LP.CharacterAdded:Wait())
    self:_trackConnection(LP.CharacterAdded:Connect(function(c) self:connectChar(c) end))

    self:attachLive(self.liveChar)

    
    
    self.hb = RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(function()
            self:update(dt)
        end)

        if not ok then
            self:_handleRuntimeError("update", err)
        end
    end)

    self.hardAimHB = RunService.RenderStepped:Connect(function()
        local ok, err = pcall(function()
			if self.hum and self.hum:GetState()==Enum.HumanoidStateType.FallingDown then return end
            if self.inDash then return end

            local tgt = (self.currentTarget and self.currentTarget.hrp) or nil
            if not tgt then return end

            self.hum.AutoRotate = false
            aimCFrame(self.rp, tgt)

            local cam = workspace.CurrentCamera
            if cam then
                local cp = cam.CFrame.Position
                local lv = cf.LookVector
                cam.CFrame = CFrame.new(
                    cp,
                    Vector3.new(cp.X + lv.X, cp.Y, cp.Z + lv.Z)
                )
            end
        end)

        if not ok then
            self:_handleRuntimeError("hardAim", err)
        end
    end)



    return self
end
function Bot:_autoResumeTick()
    
    if self.autoStart and (not self.run) and self.hum and self.hum.Health > 0 then
        self:start()
    end
end

function Bot:destroy()
    if self.destroyed then return end
    self.destroyed = true
    self.autoStart = false
    self.run = false
    self.alive = false
    self.pendingResume = false

    self:_cancelActiveCombo()
    self:_stopDashOrientation()
    self.inDash = false
    self:_stopBlocking()
    self:_restoreCamera()
    if self.hb then self.hb:Disconnect() end
    if self.hardAimHB then self.hardAimHB:Disconnect() end
    if self.liveConn then self.liveConn:Disconnect() end
    self.hb = nil
    self.hardAimHB = nil
    self.liveConn = nil


    for _,conn in ipairs(self.connections or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self.connections = {}

    for _,c in ipairs(self.myHumConns) do pcall(function() c:Disconnect() end) end
    self.myHumConns = {}
    self:_clearTarget()

    self:clearMove()
    if self.hum then self.hum.AutoRotate = true end
    self.char = nil
    self.hum = nil
    self.rp = nil
    self.liveChar = nil
    self:_finalizeActionRecords(true)
    self:savePolicy()
    if self.gui then
        self.gui:destroy()
        self.gui = nil
    end
    if self.hardAimHB then self.hardAimHB:Disconnect() end
    self.hardAimHB = nil
end

function Bot:_handleRuntimeError(source:string, err:any)
    if self.destroyed or self.handlingError then return end
    self.handlingError = true
    local message = string.format("%s", tostring(err))
    warn(string.format("[BGBot] %s error: %s", source, message))
    self.autoStart = false
    local gui = self.gui
    local ok, stopErr = pcall(function()
        if self.run then
            self:stop()
        else
            self:clearMove()
            self:_stopDashOrientation()
            self:_stopBlocking()
            self:_restoreCamera()
        end
    end)
    if not ok then
        warn(string.format("[BGBot] stop cleanup error: %s", tostring(stopErr)))
    end
    self.errorState = true
    if gui then
        gui:setS("Status: error – press Start to retry or Exit to close")
    end
    self.handlingError = false
end



local function tailIdFromTrack(tr:AnimationTrack?):string
    local id = tr and tr.Animation and tostring(tr.Animation.AnimationId) or ""
    return id:match("(%d+)$") or "unknown"
end
local function listHas(list:{string}, tail:string):boolean
    for _,v in ipairs(list) do if v==tail then return true end end
    return false
end
local function isM1Tail(tail:string):boolean
    local A = CFG.Attack.AnimIds
    return tail==A.m1 or tail==A.m2 or tail==A.m3 or tail==A.m4
end
local function isAttackTail(tail:string):boolean
    local A = CFG.Attack.AnimIds
    return isM1Tail(tail) or tail==A.np or tail==A.cp or tail==A.shove or tail==A.upper
end

function Bot:_beginDashOrientation(kind:string, tr:AnimationTrack, style:("off"|"def"), tHRP:BasePart?, enemy:Enemy?)
    if self.inDash or not self.hum or not self.rp then return end
    self.inDash = true
    self.hum.AutoRotate = false
    local length = (tr.Length and tr.Length>0) and tr.Length
                  or (kind=="fdash" and CFG.Dash.FWindow)
                  or (kind=="bdash" and CFG.Dash.BWindow)
                  or CFG.Dash.SWindow
    local state = {
        kind = kind,
        style = style or "off",
        targetHRP = tHRP,
        enemy = enemy,
        start = os.clock(),
        length = length or 0.4,
        orbitCW = (math.random()<0.5),
        track = tr,
        stopped = false,
    }
    state.stoppedConn = tr.Stopped:Connect(function()
        state.stopped = true
    end)
    self.dashState = state
end

function Bot:_updateDashOrientation()
    local state = self.dashState
    if not state then return end
    if not self.run then
        self:_finishDashOrientation(state)
        return
    end
    local tr = state.track
    if state.stopped or not (tr and tr.IsPlaying) then
        self:_finishDashOrientation(state)
        return
    end
    local target = state.targetHRP
    if not (target and target.Parent) then
        local pick = self.currentTarget
        target = pick and pick.hrp or nil
        state.targetHRP = target
    end
    if not (self.rp and target) then return end
    local here = safePos(self.rp)
    local tgtPos = safePos(target)
    if not (here and tgtPos) then return end
    local to = Vector3.new(tgtPos.X, here.Y, tgtPos.Z) - here
    if to.Magnitude <= 1e-3 then return end
    local toU = to.Unit
    local lookDir
    if state.kind=="fdash" then
        lookDir = (state.style=="off") and toU or -toU
    elseif state.kind=="bdash" then
        lookDir = (state.style=="off") and -toU or toU
    else
        local cw = state.orbitCW
        local perp = cw and Vector3.new(toU.Z,0,-toU.X) or Vector3.new(-toU.Z,0,toU.X)
        lookDir = (state.style=="off") and perp.Unit or (-perp).Unit
    end
    self.rp.CFrame = CFrame.lookAt(here, here + lookDir)
    self:alignCam()
    if os.clock() - state.start >= state.length then
        self:_finishDashOrientation(state)
    end
end

function Bot:_finishDashOrientation(state)
    if self.dashState ~= state then return end
    if state.stoppedConn then
        pcall(function() state.stoppedConn:Disconnect() end)
    end
    self.dashState = nil
    local pick = self:selectTarget()
    local t2 = (state.targetHRP and state.targetHRP.Parent) and state.targetHRP or (pick and pick.hrp)
    if t2 and self.hum and self.hum.Health>0 and self.hum:GetState()~=Enum.HumanoidStateType.FallingDown then
        local here = safePos(self.rp)
        local tgtPos = safePos(t2)
        if here and tgtPos then
            self.rp.CFrame = CFrame.lookAt(here, Vector3.new(tgtPos.X, here.Y, tgtPos.Z))
            self:alignCam()
        end
    end
    local closeEnemy = state.enemy or pick
    if closeEnemy and closeEnemy.hrp and self.run and self.alive and not self.actThread then
        local dist = closeEnemy.dist or math.huge
        if dist==math.huge then
            local here = safePos(self.rp)
            local enemyPos = safePos(closeEnemy.hrp)
            if here and enemyPos then
                dist = (enemyPos - here).Magnitude
            end
        end
        if dist <= 5.0 and not self.blocking then
            self:_registerM1Attempt(closeEnemy)
            if self:_pressAction("M1", CFG.TapS) then
                local nowT = os.clock()
                self.lastM1 = nowT
                self.lastAttempt = nowT
            end
        end
    end
    local scoreKind = (state.kind=="fdash" and "F") or (state.kind=="bdash" and "B") or "S"
    if scoreKind then
        self:_postDashScore(scoreKind, closeEnemy or pick)
    end
    if pick and self:_hasRecentStun(pick) and (pick.dist or 99) <= CFG.CloseUseRange then
        if self.allowDashExtend and os.clock() < self.allowDashExtend then
            self:execBestCloseCombo(pick)
        end
    end
    self.allowDashExtend = nil
    self.inDash = false
end



function Bot:_hookMine(h:Humanoid)
    for _,c in ipairs(self.myHumConns) do pcall(function() c:Disconnect() end) end
    self.myHumConns={}
    self.myAnims={}
    self.attackActive={}
    self.isAttacking=false
    self.isM1ing=false
    self.m1ChainCount=0

    if not h then return end
    local function hook(an:Animator)
        local c=an.AnimationPlayed:Connect(function(tr)
            local tail = tailIdFromTrack(tr)
            local nowT = os.clock()
            if tail == DashAnim.F then self.lastRealDash.F = nowT end
            if tail == DashAnim.B then self.lastRealDash.B = nowT end
            if tail == DashAnim.SL or tail == DashAnim.SR then self.lastRealDash.S = nowT end
            self.myAnims[tr]={id=tail,start=os.clock()}
            tr.Stopped:Connect(function()
                self.myAnims[tr]=nil
                if self.attackActive[tr] then
                    self.attackActive[tr]=nil
                    local any=false; local anyM1=false
                    for t,_ in pairs(self.attackActive) do
                        if t and t.IsPlaying then
                            any=true
                            local tid = tailIdFromTrack(t)
                            if isM1Tail(tid) then anyM1=true end
                        end
                    end
                    self.isAttacking=any
                    self.isM1ing=anyM1
                end
            end)


            local DA=CFG.Dash.Anim
            local kind:string? = nil
            if listHas(DA.fdash, tail) then kind="fdash"
            elseif listHas(DA.bdash, tail) then kind="bdash"
            elseif listHas(DA.side,  tail) then kind="side"  end
            if kind~=nil then
                local style:("off"|"def") = "off"
                local tHRP:BasePart? = nil
                local enemy:Enemy? = nil
                if self.dashPending and self.dashPending.kind==kind then
                    style = self.dashPending.style
                    tHRP  = self.dashPending.tHRP
                    enemy = self.dashPending.enemy
                    self.dashPending = nil
                else
                    local tgt = self:selectTarget()
                    tHRP = tgt and tgt.hrp or nil
                    style = "off"
                    enemy = tgt
                end
                self:_beginDashOrientation(kind, tr, style, tHRP, enemy)
            end


            if isAttackTail(tail) then
                self.attackActive[tr]=true
                self.isAttacking=true
                self.lastAttackTime=os.clock()
                if isM1Tail(tail) then

                    if os.clock() - self.lastM1 > CFG.M1MaxGap then
                        self.m1ChainCount = 0
                    end
                    self.m1ChainCount = math.min(4, self.m1ChainCount + 1)
                    self.isM1ing=true
                    self.lastM1=os.clock()
                else

                end
            end
        end)
        table.insert(self.myHumConns,c)
    end
    local an=h:FindFirstChildOfClass("Animator")
    if an then hook(an) else
        table.insert(self.myHumConns, h.ChildAdded:Connect(function(ch) if ch:IsA("Animator") then hook(ch) end end))
    end
end
function Bot:_myAnimId():string? local best,ts=nil,-1; for _,v in pairs(self.myAnims) do if v.start>ts then ts=v.start; best=v.id end end; return best end

function Bot:isAnimPlaying(name:string):boolean
    if not name then return false end
    local targetTail
    if name == "ConsecutivePunches" then
        targetTail = CFG.Attack.AnimIds.cp
    end
    if not targetTail then return false end
    for _,meta in pairs(self.myAnims or {}) do
        if meta.id == targetTail then
            return true
        end
    end
    return false
end


function Bot:connectChar(char:Model)
    if self.destroyed then return end
    self.char=char; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5); if not hum then return end
    self.hum=hum; self.rp=char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5)
    self.alive=hum.Health>0; self.lastHP=hum.Health; self:_hookMine(hum)

    if hum.Health>0 then
        self.pendingLifeStart=false
        self:_beginLife()
    else
        self.pendingLifeStart=true
    end

    hum.Died:Connect(function()
        if self.destroyed then return end
        self:_cancelActiveCombo()
        self:_stopDashOrientation()
        self:_stopBlocking()
        self:clearMove()
        self.allowDashExtend = nil
        self.inDash = false
        self:_restoreCamera()
        self:_endLife()
        self.alive=false; self.gui:setS("Status: dead"); self.gui:setT("Target: none"); self.run=false; self.pendingResume=true
        task.spawn(function()
            local liveModel:Model? = nil
            while not self.destroyed and liveModel==nil do
                local lf=workspace:FindFirstChild("Live")
                if lf then liveModel=lf:FindFirstChild(LP.Name) end
                task.wait(0.25)
            end
            if self.destroyed then return end
            local ch=LP.Character or LP.CharacterAdded:Wait()
            if self.destroyed then return end
            if ch and ch~=self.char then
                self:connectChar(ch)
            end
            local h2=ch and (ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid",5)) or nil
            if self.destroyed then return end
            if h2 then
                repeat task.wait(0.15) until self.destroyed or h2.Health>0
                if self.destroyed then return end
                if self.pendingResume then self.pendingResume=false; self:start() end
            end
        end)
    end)

    hum.HealthChanged:Connect(function(hp)
        if self.pendingLifeStart and hp>0 then
            self.pendingLifeStart=false
            self.alive=true
            self:_beginLife()
        end
        local dmg=self.lastHP - hp
        if dmg>0 then
            self.lastDmg=dmg; self.lastAtkTime=os.clock(); self:updateAttacker()
            self.lifeStats.damageTaken = (self.lifeStats.damageTaken or 0) + dmg
            local curTarget = self.currentTarget
            local curDist = curTarget and curTarget.dist or nil
            self:_recordDamageEvent(nil, dmg, false, {dist = curDist})
            local attacker=self.lastAttacker
            if attacker then
                local rec=self.currentTarget
                if rec and rec.model and rec.model.Name ~= attacker then
                    rec = nil
                end
                if rec then
                    rec.recent=(rec.recent or 0)*0.5 + dmg
                    rec.style.aggr=math.clamp(rec.style.aggr + math.min(3,dmg/4),0,10)
                    rec.style.lastAtk=os.clock()
                    local lid=nil; local best=-1; for _,slot in pairs(rec.active) do if slot.start>best then best=slot.start; lid=slot.id end end
                    if lid then
                        local wasBlk = self.blocking or (os.clock()<self.blockUntil)
                        self.ls:dmgFrom(lid, wasBlk, dmg)
                        for _,slot in pairs(rec.active) do slot.hit=true; if wasBlk then slot.wasBlk=true end end
                    end
                end
            end
        end
        self.lastHP=hp
    end)
end

function Bot:onSelfEvasive() self:clearMove(); self.evReady=false; self.evTimer=CFG.EvasiveCD; self.shouldPanic=false; self.gui:setE(("Evasive: %.1fs"):format(math.max(0,self.evTimer))) end
function Bot:attachLive(model:Model?)
    if self.destroyed then return end
    if self.liveConn then self.liveConn:Disconnect() end; self.liveChar=model; if not model then return end
    local function chk(d:Instance) if d.Name=="RagdollCancel" then self:onSelfEvasive() end end
    for _,d in ipairs(model:GetDescendants()) do chk(d) end
    self.liveConn=model.DescendantAdded:Connect(chk)
end


function Bot:_ensureCharacterBindings()
    local char = LP.Character
    if char and char ~= self.char then
        self:connectChar(char)
    end

    local live = workspace:FindFirstChild("Live")
    self.liveFolder = live
    local mdl = live and live:FindFirstChild(LP.Name) or nil
    if mdl and mdl ~= self.liveChar then
        self:attachLive(mdl)
    elseif (not mdl) and self.liveChar then
        self:attachLive(nil)
    end

    if self.hum and self.hum.Parent==nil and char then
        self:connectChar(char)
    end
end


function Bot:setKey(k:Enum.KeyCode,down:boolean)
    if self.moveKeys[k]==down then return end
    self.moveKeys[k]=down; VIM:SendKeyEvent(down,k,false,game)
end
function Bot:clearMove() for k,down in pairs(self.moveKeys) do if down then VIM:SendKeyEvent(false,k,false,game); self.moveKeys[k]=false end end end
function Bot:setInput(f:number?,r:number?) local th=0.15; f=f or 0; r=r or 0
    self:setKey(Enum.KeyCode.W, f>th); self:setKey(Enum.KeyCode.S, f<-th); self:setKey(Enum.KeyCode.D, r>th); self:setKey(Enum.KeyCode.A, r<-th)
    if self.moveKeys[Enum.KeyCode.W] or self.moveKeys[Enum.KeyCode.S] or self.moveKeys[Enum.KeyCode.A] or self.moveKeys[Enum.KeyCode.D] then
        self.lastMoveTime = os.clock()
    end
end

function Bot:alignCam()
    local cam=workspace.CurrentCamera; if not(cam and self.rp) then return end
    local cp=cam.CFrame.Position; local look=self.rp.CFrame.LookVector; local flatv=Vector3.new(look.X,0,look.Z); if flatv.Magnitude<1e-3 then return end
    local tgt=cp+flatv.Unit; cam.CFrame=CFrame.new(cp, Vector3.new(tgt.X,cp.Y,tgt.Z))
end


function Bot:aimAt(tHRP:BasePart?)
    if self.destroyed or self.inDash then return end
    if not (self.hum and self.rp) then return end


    self.hum.AutoRotate = false

    if not tHRP then
        return
    end

    local ok, state = pcall(function()
        return self.hum:GetState()
    end)
    if not ok then return end

    if state == Enum.HumanoidStateType.FallingDown then
        return
    end

    local here = safePos(self.rp)
    local there = safePos(tHRP)
    if not (here and there) then return end

	aimCFrame(self.rp, tHRP)
    self:alignCam()
end


local function now() return os.clock() end
local function distOK(d:number, lo:number, hi:number) return d>=lo and d<=hi end
local BANDIT_ACTION_WINDOW = 1.6

local function isBehind(self:any, tgt:Enemy?):boolean
    if not (self and self.rp and tgt and tgt.hrp) then return false end
    local toMe = flat(self.rp.Position - tgt.hrp.Position)
    local look = flat(tgt.hrp.CFrame.LookVector)
    if toMe.Magnitude < 1e-3 or look.Magnitude < 1e-3 then return false end
    return toMe.Unit:Dot(look.Unit) < -0.25
end

function Bot:_ctxKey(tgt:Enemy?):string
    local dist = math.huge
    if tgt then
        dist = tgt.dist or dist
        if dist==math.huge and tgt.hrp and self.rp then
            dist = (tgt.hrp.Position - self.rp.Position).Magnitude
        end
    end
    local range = "chase"
    if dist <= 6 then range = "near"
    elseif dist <= 14 then range = "mid"
    elseif dist <= 35 then range = "far"
    end

    local nowT = os.clock()
    local blkRecent = (tgt and tgt.style and (nowT - (tgt.style.lastBlk or 0)) <= 0.45) and 1 or 0
    local hasEv = (tgt and tgt.hasEv) and 1 or 0
    local rag = self:_targetRagdolled(tgt) and 1 or 0
    local attk = (tgt and tgt.style and (nowT - (tgt.style.lastAtk or 0)) <= 0.5) and 1 or 0
    local m1Chain = math.clamp(self.m1ChainCount or 0, 0, 4)
    local fReady = self:dashReady("F") and 1 or 0
    local sReady = self:dashReady("S") and 1 or 0
    local bReady = self:dashReady("B") and 1 or 0

    local myHP = (self.hum and self.hum.Health) or 0
    local enemyHP = 0
    if tgt then
        enemyHP = (tgt.hum and tgt.hum.Health) or tgt.hp or 0
    end
    local diff = myHP - enemyHP
    local hpBin = "close"
    if diff >= 25 then hpBin = "high" elseif diff <= -25 then hpBin = "low" end

    return ("range=%s|blk=%d|ev=%d|rag=%d|attk=%d|m1=%d|F=%d|S=%d|B=%d|hp=%s")
        :format(range, blkRecent, hasEv, rag, attk, m1Chain, fReady, sReady, bReady, hpBin)
end

function Bot:_getOrInit(ctx:string, action:string)
    if not self.policy then self.policy = {} end
    local bucket = self.policy[ctx]
    if not bucket then
        bucket = {}
        self.policy[ctx] = bucket
    end
    local entry = bucket[action]
    if not entry then
        local seed = 0.0
        if action == "B" and string.find(ctx, "range=mid", 1, true) and string.find(ctx, "attk=1", 1, true) then
            seed = 1.0
        end
        entry = {n = 0, ravg = seed}
        bucket[action] = entry
    end
    entry.n = entry.n or 0
    entry.ravg = entry.ravg or 0.0
    return entry
end

function Bot:update_ravg(ctx:string?, action:string?, reward:number, weight:number?)
    if not (ctx and action) then return end
    local entry = self:_getOrInit(ctx, action)
    local w = math.max(0.0, weight or 1.0)
    local alpha = math.clamp(0.1 * w, 0.02, 0.5)
    entry.ravg = entry.ravg * (1 - alpha) + reward * alpha
    entry.n = entry.n + w
end


function Bridge.new()
    local env=rawget(getgenv(),"joehub") or rawget(getgenv(),"JoeHub")
    local self=setmetatable({},Bridge)
    if typeof(env)=="table" then self.env=env end
    if self.env then
        self.aim    = self.env.AimAt or self.env.AimTarget or self.env.AimStabilizer
        self.decide = (self.env.AI and self.env.AI.Decide) or self.env.Decide
        self.log    = (self.env.AI and self.env.AI.Log) or self.env.Log
    end
    return self
end


CFG.AI = CFG.AI or { external = false }

if not Bot.choose_action then
    function Bot:choose_action(ctx, candidates, epsilon)
        epsilon = math.clamp(tonumber(epsilon or self.bandit and self.bandit.epsilon or 0.15) or 0.15, 0, 1)
        
        local scored = {}
        local sumBias = 0
        for i,c in ipairs(candidates or {}) do
            local aName = c.name
            local entry = self:_getOrInit(ctx or "default", aName)
            local bias  = tonumber(c.bias or 0) or 0
            local val   = (entry.ravg or 0)
            local s     = bias + val
            scored[i]   = {i=i, c=c, s=s}
            sumBias = sumBias + math.max(0, s)
        end
        if #scored == 0 then return nil end

        
        if math.random() < epsilon then
            return scored[math.random(1, #scored)].c
        end
        
        table.sort(scored, function(a,b) return a.s > b.s end)
        return scored[1].c
    end
end


Bot._choose_action_raw = Bot.choose_action
function Bot:choose_action(ctx, candidates, epsilon)
    if CFG.AI.external and self.bridge and self.bridge.decide then
        local options = {}
        for i,c in ipairs(candidates or {}) do options[i] = c.name end
        local payload = {ctx=ctx, options=options, tuning=AI.GetTuning(), eps=self.bandit.epsilon, gen=self.bandit.generation}
        local ok, pickName = pcall(self.bridge.decide, payload)
        if ok and pickName then
            for _,c in ipairs(candidates) do if c.name==pickName then return c end end
        end
    end
    return self:_choose_action_raw(ctx, candidates, epsilon)
end

function Bot:_noteAction(actionName:string, ctx:string, tgt:Enemy?)
    self.bandit.actions = self.bandit.actions or {}
    local prev = self.bandit.lastAction
    local nowT = os.clock()
    local rec = {
        action = actionName,
        ctx = ctx,
        time = nowT,
        enemy = (tgt and tgt.model and tgt.model.Name) or nil,
        targetBlocking = tgt and tgt.style and ((nowT - (tgt.style.lastBlk or 0)) <= 0.35) or false,
        ragdolled = self:_targetRagdolled(tgt),
        startDist = tgt and tgt.dist or nil,
        prevCtx = prev and prev.ctx or nil,
        prevAction = prev and prev.action or nil,
        isFinisher = (actionName == "NP" or actionName == "UPPER"),
        isDash = (actionName == "S" or actionName == "B" or actionName == "F"),
        behindStart = isBehind(self, tgt),
        damageDealt = 0.0,
        damageTaken = 0.0,
        keptAdvantage = false,
        forcedUnblock = false,
        lostSpacing = false,
        firstDamageTaken = nil,
    }
    table.insert(self.bandit.actions, rec)
    self.bandit.lastAction = {ctx = ctx, action = actionName}
end

function Bot:_recordDamageEvent(targetName:string?, amount:number, isDealt:boolean, info:{dist:number?}?)
    if amount <= 0 then return end
    self.bandit.actions = self.bandit.actions or {}
    local nowT = os.clock()
    for _,act in ipairs(self.bandit.actions) do
        if (nowT - act.time) <= BANDIT_ACTION_WINDOW then
            local targetMatch = (not targetName) or (act.enemy == targetName) or (act.enemy == nil)
            if targetMatch then
                if isDealt then
                    act.damageDealt = act.damageDealt + amount
                    if act.isFinisher then act.keptAdvantage = true end
                    if act.targetBlocking then act.forcedUnblock = true end
                    if act.ragdolled then act.keptAdvantage = true end
                else
                    act.damageTaken = act.damageTaken + amount
                    act.firstDamageTaken = act.firstDamageTaken or nowT
                    if info and info.dist and info.dist < CFG.SpaceMin then
                        act.lostSpacing = true
                    end
                end
            end
        end
    end
end

function Bot:_applyActionReward(act)
    local R = CFG.Reward
    local dealt  = act.damageDealt or 0
    local taken  = act.damageTaken or 0

    local reward = 0
    reward = reward + R.dmgDealt * dealt
    reward = reward + R.dmgTaken * taken

    if act.isFinisher and dealt > 0 then reward = reward + R.finisherBonus end
    if act.forcedUnblock then reward = reward + R.forcedUnblock end

    local kept = act.keptAdvantage or (act.behindStart and taken <= 0)
    if kept then reward = reward + R.keptAdvantage end

    if act.firstDamageTaken and dealt <= 0 and (act.firstDamageTaken - act.time) <= 0.8 then
        reward = reward + R.earlyPunish
    end
    if act.targetBlocking and dealt <= 0 then reward = reward + R.blockNoDamage end
    if act.lostSpacing then reward = reward + R.lostSpacing end

    
    self:update_ravg(act.ctx, act.action, reward * R.applyAlpha, 1.0)
    if act.prevCtx and act.prevAction then
        self:update_ravg(act.prevCtx, act.prevAction, reward * R.prevAlpha, R.prevWeight)
    end

    self.lifeStats.reward = (self.lifeStats.reward or 0) + reward
end

function Bot:_finalizeActionRecords(force:boolean?)
    self.bandit.actions = self.bandit.actions or {}
    if #self.bandit.actions == 0 then return end
    local nowT = os.clock()
    local i = 1
    while i <= #self.bandit.actions do
        local act = self.bandit.actions[i]
        if force or (nowT - act.time) >= BANDIT_ACTION_WINDOW then
            self:_applyActionReward(act)
            table.remove(self.bandit.actions, i)
        else
            i = i + 1
        end
    end
end

function Bot:_averageReward(actionName:string, filters:{string}?)
    if not self.policy or typeof(self.policy) ~= "table" then return nil end

    local sum, count = 0.0, 0
    for ctx, actions in pairs(self.policy) do
        if typeof(actions) == "table" then
            local ok = true
            if filters then
                for _, f in ipairs(filters) do
                    if not string.find(ctx, f, 1, true) then
                        ok = false
                        break
                    end
                end
            end

            if ok then
                local entry = actions[actionName]
                if entry and entry.n and entry.n > 0 then
                    sum = sum + (entry.ravg or 0)
                    count = count + 1
                end
            end
        end
    end

    if count == 0 then return nil end
    return sum / count
end

function Bot:_applyTune(tune:any)
    
    CFG.Cooldown.F, CFG.Cooldown.S, CFG.Cooldown.B = BASE_COOLDOWN.F, BASE_COOLDOWN.S, BASE_COOLDOWN.B
    CFG.Gates.F.lo, CFG.Gates.F.hi = BASE_GATES.F.lo, BASE_GATES.F.hi
    CFG.Gates.S.lo, CFG.Gates.S.hi = BASE_GATES.S.lo, BASE_GATES.S.hi
    CFG.Gates.B.lo, CFG.Gates.B.hi = BASE_GATES.B.lo, BASE_GATES.B.hi
    CFG.SpaceMin,   CFG.SpaceMax    = BASE_SPACES.SpaceMin, BASE_SPACES.SpaceMax
    CFG.M1Range                      = BASE_SPACES.M1Range

    if not tune then return end

    
    local function set(path, val) if val~=nil then _applyTunable(path, val) end end

    if tune.F then
        set("Gates.F.lo", tune.F.gateLo and (BASE_GATES.F.lo + tune.F.gateLo))
        set("Gates.F.hi", tune.F.gateHi and (BASE_GATES.F.hi + tune.F.gateHi))
    end
    if tune.S then
        set("Gates.S.lo", tune.S.gateLo and (BASE_GATES.S.lo + tune.S.gateLo))
        set("Gates.S.hi", tune.S.gateHi and (BASE_GATES.S.hi + tune.S.gateHi))
    end
    if tune.B then
        set("Gates.B.lo", tune.B.gateLo and (BASE_GATES.B.lo + tune.B.gateLo))
        set("Gates.B.hi", tune.B.gateHi and (BASE_GATES.B.hi + tune.B.gateHi))
    end
    if tune.space then
        
        set("SpaceMin", tune.space.min and (BASE_SPACES.SpaceMin + tune.space.min))
        set("SpaceMax", tune.space.max and (BASE_SPACES.SpaceMax + tune.space.max))
        set("M1Range",  tune.space.m1  and (BASE_SPACES.M1Range  + tune.space.m1))
    end
end

local AI = {
    version = "1.0",
    _bot = nil,
}


function AI.SetTuning(tbl)
    if typeof(tbl)~="table" then return false end
    local any=false
    for k,v in pairs(tbl) do
        local ok = _applyTunable(k, v)
        any = any or ok
    end
    local b = AI._bot
    if any and b and b.ls then b.ls:log("tuning_apply", {tuning = tbl}) end
    return any
end

function AI.GetTuning()
    return _snapshotTunables()
end

function Bot:_applyGenerationKnobs(meta:any?)
    meta = meta or self.bandit.meta or {}
    local baseEps = meta.epsilon or self.bandit.epsilon or 0.15
    local newEps = baseEps
    local last = meta.lastLife
    if last then
        if last.reward and last.reward > 12 then newEps = newEps - 0.02 end
        if last.reward and last.reward < -12 then newEps = newEps + 0.02 end
        if last.kd and last.kd > 1.2 then newEps = newEps - 0.01 elseif last.kd and last.kd < 0.8 then newEps = newEps + 0.01 end
    end
    newEps = math.clamp(newEps, 0.05, 0.30)
    meta.epsilon = newEps
    meta.generation = (meta.generation or 0) + 1
    self.bandit.epsilon = newEps
    self.bandit.generation = meta.generation
    self.bandit.tune = meta.tune or self.bandit.tune or {}
    self:_applyTune(self.bandit.tune)
    self.bandit.meta = meta
end

function Bot:savePolicy()
    mkfolder(CFG.Data)
    self:_finalizeActionRecords(true)
    local avgB = self:_averageReward("B", {"range=mid", "attk=1"})
    self.bandit.tune = self.bandit.tune or {}
    local tuneB = self.bandit.tune.B or {cooldown = 0, gateLo = 0, gateHi = 0}
    if avgB then
        if avgB > 0.15 then
            tuneB.cooldown = math.max(-2.0, (tuneB.cooldown or 0) - 1.0)
            tuneB.gateLo = math.max(-2.0, (tuneB.gateLo or 0) - 0.5)
        elseif avgB < -0.15 then
            tuneB.cooldown = math.min(2.0, (tuneB.cooldown or 0) + 1.0)
            tuneB.gateLo = math.min(2.0, (tuneB.gateLo or 0) + 0.5)
        end
    end
    self.bandit.tune.B = tuneB

    local deaths = (self.lifeStats.deaths or 0)
    local kd = (self.lifeStats.kills or 0) / math.max(1, deaths)
    local meta = self.bandit.meta or {}
    meta.tune = self.bandit.tune
    meta.epsilon = self.bandit.epsilon
    meta.lastLife = {
        reward = self.lifeStats.reward or 0,
        kd = kd,
        damage = {dealt = self.lifeStats.damageDealt or 0, taken = self.lifeStats.damageTaken or 0},
        kills = self.lifeStats.kills or 0,
        deaths = deaths,
    }
    meta.generation = self.bandit.generation or meta.generation or 0
    self.bandit.meta = meta

    local data = {policy = self.policy or {}, meta = meta}
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok and encoded then wfile(self.policyPath, encoded) end

    local kpi = {
        generation = meta.generation,
        epsilon = meta.epsilon,
        lastLife = meta.lastLife,
        savedAt = os.time(),
    }
    local okK, encK = pcall(function() return HttpService:JSONEncode(kpi) end)
    if okK and encK then wfile(self.kpiPath, encK) end
end

function Bot:loadPolicy()
    mkfolder(CFG.Data)
    local raw = rfile(self.policyPath)
    if raw then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and typeof(decoded)=="table" then
            self.policy = decoded.policy or self.policy or {}
            self.bandit.meta = decoded.meta or self.bandit.meta or {}
            self.bandit.tune = (self.bandit.meta and self.bandit.meta.tune) or self.bandit.tune or {}
            self.bandit.epsilon = (self.bandit.meta and self.bandit.meta.epsilon) or self.bandit.epsilon or 0.15
            self.bandit.generation = self.bandit.meta and self.bandit.meta.generation or 0
        end
    end
    self.policy = self.policy or {}
    self.bandit.meta = self.bandit.meta or {epsilon = self.bandit.epsilon, generation = self.bandit.generation, tune = self.bandit.tune}
    self.bandit.tune = self.bandit.meta.tune or self.bandit.tune or {}
end

function Bot:_beginLife()
    self.lifeStats = {
        index = (self.lifeStats and self.lifeStats.index or 0) + 1,
        damageDealt = 0,
        damageTaken = 0,
        reward = 0,
        kills = 0,
        deaths = 0,
    }
    self.bandit.actions = {}
    self.bandit.lastAction = nil
    self:_applyGenerationKnobs(self.bandit.meta)
end

function Bot:_endLife()
    self.lifeStats.deaths = (self.lifeStats.deaths or 0) + 1
    self:_finalizeActionRecords(true)
    self.stunFollow = nil
    self:savePolicy()
end


function Bot:_targetRagdolled(r:Enemy?):boolean
    if not r or not r.hum then return false end
    local state = r.hum:GetState()
    if FALL_STATES[state] then return true end
    return false
end

function Bot:_targetImmortal(r:Enemy?):boolean
    if not r or not r.model then return false end
    if r.absoluteImmortal ~= nil then
        return r.absoluteImmortal
    end
    return r.model:FindFirstChild("AbsoluteImmortal") ~= nil
end

function Bot:_targetIsBlocking(r:Enemy?, window:number?):boolean
    if not r then return false end
    local nowT = os.clock()
    local limit = window or 0.35

    local blockingAttr = attrTrue(r.model, "blocking")
    local blockTail = CFG.BlockAnimId and CFG.BlockAnimId:match("(%d+)$")
    local blockingAnimPlaying = false
    if blockTail then
        for _,slot in pairs(r.active or {}) do
            if slot and slot.id == blockTail then
                blockingAnimPlaying = true
                break
            end
        end
    end

    if blockingAnimPlaying or blockingAttr then
        return true
    end

    if r.style and (nowT - (r.style.lastBlk or 0)) <= limit then
        return true
    end

    return false
end

function Bot:_registerM1Attempt(r:Enemy?)
    self.lastM1Target = r
    self.lastM1AttemptTime = os.clock()
end

function Bot:onM1Hit(r:Enemy)
    if not r or not r.hrp then return end
    local dist = r.dist
    if (not dist or dist==math.huge) and self.rp then
        dist = (r.hrp.Position - self.rp.Position).Magnitude
        r.dist = dist
    end
    
    if self.allowDashExtend and os.clock() < self.allowDashExtend then
        if self:dashReady("S") and distOK(dist or 99, CFG.Gates.S.lo, CFG.Gates.S.hi) then
            self:tryDash("S", r.hrp, "off", r)
        end
    end
end


function Bot:_noteStun(r:Enemy, tail:string)
    local nowT = os.clock()
    r.lastStun = nowT
    local byMe = (self.lastM1Target==r) and ((nowT - (self.lastM1AttemptTime or 0)) <= 0.7)
    local gain = byMe and 0.85 or 0.35
    r.stunScore = math.min(1.6, (r.stunScore or 0) + gain)
    r.lastStunAnim = tail
    self.lastStunTarget = r
    if byMe then
        r.lastStunByMe = nowT
        self.stunFollow = {target = r, time = nowT, didM1 = false, didCombo = false}
    end
    self.ls:log("stun_detected", {enemy = r.model.Name, anim = tail, score = r.stunScore, byMe = byMe})
end

function Bot:_hasRecentStun(r:Enemy?):boolean
    if not r then return false end
    local last = r.lastStun or 0
    if last == 0 then return false end
    return (os.clock() - last) <= 0.75 and (r.stunScore or 0) >= 0.35
end

function Bot:_processStunFollow(tgt:Enemy?, nowT:number):boolean
    local data = self.stunFollow
    if not data then return false end
    local target = data.target
    if not target or (tgt and tgt ~= target) then
        if target and target ~= tgt and (nowT - data.time) > 0.9 then
            self.stunFollow = nil
        end
        return false
    end
    if (nowT - data.time) > 1.1 then
        self.stunFollow = nil
        return false
    end
    if self.blocking or self.inDash then return false end
    if self.actThread then return false end

    local dist = tgt and (tgt.dist or math.huge) or math.huge
    if tgt and dist==math.huge and tgt.hrp and self.rp then
        dist = (tgt.hrp.Position - self.rp.Position).Magnitude
    end

    if tgt and (not data.didM1) and dist <= CFG.M1Range then
        if (nowT - (self.lastM1 or 0)) >= CFG.M1Min*0.5 then
            self:_registerM1Attempt(tgt)
            if self:_pressAction("M1", CFG.TapS) then
                self.lastM1 = nowT
                self.lastAttempt = nowT
                data.didM1 = true
            end
        end
    end

    local comboReady = tgt and tgt.lastStunByMe and ((nowT - tgt.lastStunByMe) <= 0.75)
    if tgt and comboReady and not data.didCombo then
        if self:_shouldStartCombo(tgt) then
            local combo = self:_chooseCombo(tgt)
            if combo then
                data.didCombo = true
                self.stunFollow = nil
                self:execCombo(combo, tgt)
                self.lastAttempt = nowT
                self.lastOffenseTime = nowT
                return true
            end
        end
    end

    if data.didM1 and (not comboReady) and (nowT - data.time) > 0.9 then
        self.stunFollow = nil
    end
    return false
end

function Bot:_waitForRange(r:Enemy, range:number, timeout:number):boolean
    if not (self.rp and r and r.hrp) then return false end
    local deadline = os.clock() + timeout

    while os.clock() < deadline do
        if not (r.model and r.model.Parent) or not (r.hrp and r.hrp.Parent) then
            break
        end
        if self:_targetImmortal(r) then
            break
        end

        local here  = safePos(self.rp)
        local there = safePos(r.hrp)
        if not (here and there) then break end

        local dist = (there - here).Magnitude
        r.dist = dist
        if dist <= range then
            self:setInput(0, 0)
            return true
        end

        self:aimAt(r.hrp)
        self:setInput(1, 0)
        RunService.Heartbeat:Wait()
    end

    self:setInput(0, 0)
    return false
end


function Bot:_cdLeft(which:string)
    local last = self.lastRealDash and self.lastRealDash[which]
    local cd = CFG.Cooldown[which]
    if not (last and cd) then return 0 end
    return math.max(0, cd - (os.clock() - last))
end


local function holdQ(d:number?) pressKey(CFG.Dash.KeyQ,true); task.wait(d or CFG.Dash.HoldQ); pressKey(CFG.Dash.KeyQ,false) end

function Bot:sideDash(tHRP:BasePart?, style:string?, r:Enemy?)
    if not (self.rp and tHRP) then return end
    local g = CFG.Gates.S
    local dist = r and r.dist
    if not dist then
        local here = safePos(self.rp)
        local targetPos = safePos(tHRP)
        if here and targetPos then
            dist = (targetPos - here).Magnitude
        end
    end
    if not dist or not distOK(dist, g.lo, g.hi) then return end


    self:aimAt(tHRP)

    local myPos   = safePos(self.rp)
    local tPos    = safePos(tHRP)
    if not (myPos and tPos) then return end
    local right   = flat(self.rp.CFrame.RightVector)
    if right.Magnitude < 1e-3 then right = Vector3.new(1,0,0) end
    right = right.Unit

    local sideLen = CFG.Dash.SideLen or 10.0
    local aPos    = myPos - right * sideLen 
    local dPos    = myPos + right * sideLen 

    local dA = (tPos - aPos).Magnitude
    local dD = (tPos - dPos).Magnitude

    local offensive = (style or "off") == "off"
    local sideKey
    if offensive then
        
        sideKey = (dA < dD) and Enum.KeyCode.A or Enum.KeyCode.D
    else
        
        sideKey = (dA > dD) and Enum.KeyCode.A or Enum.KeyCode.D
    end

    
    local wasW = self.moveKeys[Enum.KeyCode.W]
    local wasS = self.moveKeys[Enum.KeyCode.S]
    if wasW then self:setKey(Enum.KeyCode.W, false) end
    if wasS then self:setKey(Enum.KeyCode.S, false) end

    local dashStyle = (style == "def") and "def" or "off"
    self.dashPending = {kind="side", style=dashStyle, tHRP=tHRP, enemy=r}

    pressKey(sideKey, true)
    task.wait(0.02)
    pressKey(CFG.Dash.KeyQ, true); task.wait(CFG.Dash.HoldQ); pressKey(CFG.Dash.KeyQ, false)
    pressKey(sideKey, false)

    if wasW then self:setKey(Enum.KeyCode.W, true) end
    if wasS then self:setKey(Enum.KeyCode.S, true) end

    self.lastDashTime = os.clock() 
    self.lastDashKind = "S"  
    self.lastMoveTime = os.clock()
end




function Bot:forwardDash(r:Enemy, style:string?)
    if not (self.rp and r and r.hrp) then return end
    if self:_cdLeft("F")>0 then return end
    local d = r.dist
    local g = CFG.Gates.F
    if not distOK(d, g.lo, g.hi) then return end

    self.lastFD = os.clock()
    self.lastFDUser = os.clock()

    local dashStyle = (style == "def") and "def" or "off"
    self.dashPending = {kind="fdash", style=dashStyle, tHRP=r.hrp, enemy=r}
    pressKey(Enum.KeyCode.W, true); task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)
    pressKey(Enum.KeyCode.W, false)


    self.lastDashTime = os.clock()
    self.lastDashKind = "F"

    self.lastMoveTime = os.clock()
end


function Bot:backDash(tHRP:BasePart?, style:string?, r:Enemy?)
    if not (self.rp and tHRP) then return end
    local g = CFG.Gates.B
    local dist = r and r.dist
    if not dist then
        local here = safePos(self.rp)
        local targetPos = safePos(tHRP)
        if here and targetPos then
            dist = (targetPos - here).Magnitude
        end
    end
    if not dist or not distOK(dist, g.lo, g.hi) then return end

    local wasW = self.moveKeys[Enum.KeyCode.W]
    local wasA = self.moveKeys[Enum.KeyCode.A]
    local wasD = self.moveKeys[Enum.KeyCode.D]
    if wasW then self:setKey(Enum.KeyCode.W, false) end
    if wasA then self:setKey(Enum.KeyCode.A, false) end
    if wasD then self:setKey(Enum.KeyCode.D, false) end

    local dashStyle = (style == "def") and "def" or "off"
    self.dashPending = {kind="bdash", style=dashStyle, tHRP=tHRP, enemy=r}

    pressKey(Enum.KeyCode.S, true)
    task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)
    pressKey(Enum.KeyCode.S, false)

    
    self.lastDashTime = os.clock()
    self.lastDashKind = "B"

    if wasW then self:setKey(Enum.KeyCode.W, true) end
    if wasA then self:setKey(Enum.KeyCode.A, true) end
    if wasD then self:setKey(Enum.KeyCode.D, true) end

    self.lastMoveTime = os.clock()
end

function Bot:dashReady(kind:string):boolean
    local cd = CFG.Cooldown[kind]
    if not cd then return false end
    local last = self.lastRealDash and self.lastRealDash[kind] or -1e9
    return (os.clock() - last) >= cd
end

function Bot:_resolveDashStyle(kind:string, requested:string?, enemy:Enemy?):("off"|"def")
    local style = (requested == "def") and "def" or "off"
    local hum = self.hum
    local hpRatio = 1
    if hum then
        local maxHealth = hum.MaxHealth
        if typeof(maxHealth) == "number" and maxHealth > 0 then
            hpRatio = math.clamp(hum.Health / maxHealth, 0, 1)
        else
            hpRatio = hum.Health > 0 and 1 or 0
        end
    end
    local enemyAggro = (enemy and enemy.style and enemy.style.aggr) or 0
    local enemyDist = enemy and enemy.dist or math.huge
    local enemyUlt = enemy and enemy.ulted
    local threatened = (enemyAggro >= 6)
        or (enemyDist <= (CFG.SpaceMin + 1.5))
        or (enemyUlt == true)
        or (kind == "B")

    if style == "off" then
        if hpRatio < 0.4 or threatened then
            style = "def"
        end
    else
        local enemyLow = enemy and enemy.hp and enemy.hp <= (CFG.SnipeHP * 1.5)
        if hpRatio > 0.65 and (enemyLow or enemyAggro < 3) and enemyDist > (CFG.SpaceMin + 2.5) then
            style = "off"
        end
    end
    return style
end


function Bot:tryDash(kind:string, tHRP:BasePart?, style:string?, r:Enemy?)
    if r and self:_targetImmortal(r) then
        return false
    end

    local targetPart = tHRP
    if kind == "F" then
        targetPart = (r and r.hrp) or targetPart
    end
    if kind ~= "F" and not targetPart then return false end
    if self.inDash or self.blocking then return false end
    local allowDuringM1 = self.allowDashExtend and os.clock() < self.allowDashExtend
    if self.isM1ing and not allowDuringM1 then return false end
    local resolvedStyle = self:_resolveDashStyle(kind, style, r)
    local executed=false
    if kind=="S" then
        if self:dashReady("S") then self:sideDash(targetPart, resolvedStyle, r); executed=true end
    elseif kind=="F" then
        if self:dashReady("F") and r then
            self:forwardDash(r, resolvedStyle)
            executed=true
        end
    elseif kind=="B" then
        if self:dashReady("B") then self:backDash(targetPart, resolvedStyle, r); executed=true end
    end
    if executed then

        self.lastDashTime = os.clock()
        self.lastDashKind = kind

        local ctx=self:_ctxKey(r)
        self:_noteAction(kind, ctx, r)
        self.ls:log("dash",{kind=kind, enemy=r and r.model and r.model.Name or "none", dist=r and r.dist or nil, style=resolvedStyle})
        return true
    end
    return false
end

function Bot:_postDashScore(kind:string, r:Enemy?)
    local last = self.lastRealDash and self.lastRealDash[kind]
    if not last then return end
    local nowT = os.clock()
    if (nowT - last) >= 1.0 then return end
    local dist = (r and r.dist) or 99
    local reward = math.max(0, 8 - math.min(8, dist/4))
    if r and self:_hasRecentStun(r) then reward = reward + 2.0 end
    self.ls:moveAdd("dash_"..kind, reward, dist)
    if self.gui then self.gui:updateCombos(self.ls.data) end
end


function Bot:isSelfBlockingVisual():boolean
    local live = self.liveChar
    if live then
        if attrTrue(live, "blocking") then return true end
    end
    local bid = CFG.BlockAnimId and CFG.BlockAnimId:match("(%d+)$")
    if bid then
        for _,meta in pairs(self.myAnims) do
            if (meta.id or "") == bid then return true end
        end
    end
    return self.blocking or (os.clock() < (self.blockUntil or 0))
end

function Bot:_forceUnblockNow()
    local b=CFG.Bind.Block
    if b and b.t=="Key" and self.blockKeyDown then
        VIM:SendKeyEvent(false,b.k,false,game)
    end
    self.blockKeyDown = false
    self.blocking=false
    self.blockUntil=0
    self.blockReleaseAt = 0
end
function Bot:block(dur:number?, target:Enemy?, reason:string?)
    if os.clock() < self.blockCooldown then return end
    local b=CFG.Bind.Block; if not b or b.t~="Key" then return end
    local hold = math.clamp(dur or 0.35, 0.25, 0.60)
    self.blocking=true
    self.blockStartTime=os.clock()
    self.blockUntil = self.blockStartTime + hold
    self.blockReleaseAt = self.blockUntil
    if target and target.model then
        local aid=self:_animId(target)
        local threat = aid and self.ls:threat(aid) or 0
        self.ls:log("block", {enemy=target.model.Name, anim=aid, threat=threat, dur=hold, reason=reason or "auto"})
    end
end

function Bot:_processBlocking()
    local b = CFG.Bind.Block
    if not self.blocking then
        if self.blockKeyDown and b and b.t=="Key" then
            VIM:SendKeyEvent(false, b.k, false, game)
        end
        self.blockKeyDown = false
        return
    end
    if b and b.t=="Key" and not self.blockKeyDown then
        VIM:SendKeyEvent(true, b.k, false, game)
        self.blockKeyDown = true
    end
    if os.clock() >= (self.blockReleaseAt or 0) then
        self:_forceUnblockNow()
        self.blocking=false
        self.blockStartTime=nil
        self.lastBlockTime=os.clock()
        self.blockCooldown = self.lastBlockTime + 0.35
    end
end


function Bot:_clearTarget(target:Enemy?)
    local rec = target or self.currentTarget
    if not rec then return end
    for _,c in ipairs(rec.cons or {}) do
        pcall(function()
            c:Disconnect()
        end)
    end
    rec.cons = {}
    if rec.humConn then pcall(function() rec.humConn:Disconnect() end) end
    if rec.hrpConn then pcall(function() rec.hrpConn:Disconnect() end) end
    if rec.animWatchConn then pcall(function() rec.animWatchConn:Disconnect() end) end
    rec.animWatchConn = nil
    if self.currentTarget == rec then
        self.currentTarget = nil
    end
end

function Bot:_setCurrentTargetModel(model:Model?)
    if model and self.currentTarget and self.currentTarget.model == model then
        return self.currentTarget
    end
    self:_clearTarget()
    if not model then return nil end
    local rec = self:_createTargetRecord(model)
    self.currentTarget = rec
    return rec
end

function Bot:_attachEnemyHumanoid(r:Enemy, hum:Humanoid?)
    if r.humConn then pcall(function() r.humConn:Disconnect() end) end
    r.humConn = nil
    r.hum = hum
    if hum then
        r.hp = hum.Health
        local conn = hum:GetPropertyChangedSignal("Health"):Connect(function()
            local nh = hum.Health
            local prev = r.hp or nh
            local delta = math.max(0, prev - nh)
            if delta > 0 then
                local wasMe = false
                local last = getAttrInsensitive(r.model, "LastHit")
                if last == LP.Name then
                    wasMe = true
                end
                if not wasMe then
                    local creator = hum:FindFirstChild("creator")
                    if creator and creator.Value == LP then wasMe = true end
                end
                if not wasMe then
                    local dam = getAttrInsensitive(r.model, "LastDamager")
                    if dam == nil then
                        dam = getAttrInsensitive(r.model, "LastDamagerName")
                    end
                    if typeof(dam) == "Instance" and dam == LP then wasMe = true
                    elseif typeof(dam) == "string" and dam == LP.Name then wasMe = true end
                end

                if wasMe then
                    local myA = self:_myAnimId()
                    if myA then self.ls:deal(myA, delta) end
                    self.lifeStats.damageDealt = (self.lifeStats.damageDealt or 0) + delta
                    self:_recordDamageEvent(r.model.Name, delta, true, {dist = r.dist})
                    r.aRecent = (r.aRecent or 0)*0.5 + delta

                    if self.lastM1Target == r and os.clock() - (self.lastM1AttemptTime or 0) < 0.6 then
                        self:onM1Hit(r)
                    end
                else
                    self.lastAttacker = r.model.Name
                end
            end
            r.hp = nh
        end)
        r.humConn = conn
        table.insert(r.cons, conn)
    end
end

function Bot:_attachEnemyHRP(r:Enemy, hrp:BasePart?)
    if r.hrpConn then pcall(function() r.hrpConn:Disconnect() end) end
    r.hrpConn = nil
    r.hrp = hrp
    if hrp then
        local conn = hrp.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                r.hrp = nil
            end
        end)
        r.hrpConn = conn
        table.insert(r.cons, conn)
    end
end

function Bot:_ensureEnemyParts(r:Enemy):boolean
    if not r or not r.model or not r.model.Parent then return false end
    if (not r.hum) or (not r.hum.Parent) then
        local hum = r.model:FindFirstChildOfClass("Humanoid")
        self:_attachEnemyHumanoid(r, hum)
    end
    if (not r.hrp) or (not r.hrp.Parent) then
        local hrp = r.model:FindFirstChild("HumanoidRootPart")
        self:_attachEnemyHRP(r, hrp)
    end
    return (r.hum ~= nil) and (r.hrp ~= nil)
end


local function sidTail(id:string?):string if not id then return "unk" end local n=id:match("(%d+)$"); return n or id end

function Bot:_createTargetRecord(m:Model):Enemy?
    if not (m and m:IsA("Model")) then return nil end
    if m.Name==LP.Name then return nil end

    local ply = Players:FindFirstChild(m.Name)
    local r:Enemy = {
        model=m, hum=nil, hrp=nil,
        dist=math.huge, hasEv=true, lastEv=0, score=0, ply=ply, playerName = ply and ply.Name or nil, hp=100,
        style={aggr=0,def=0,ev=0,lastAtk=0,lastBlk=0,lastDash=0}, recent=0, aRecent=0, active={}, cons={}, aggro=0,
        lastStunByMe=0,
    }

    self:_attachEnemyHumanoid(r, m:FindFirstChildOfClass("Humanoid"))
    self:_attachEnemyHRP(r, m:FindFirstChild("HumanoidRootPart"))

    if r.hum then
        table.insert(r.cons, r.hum.Died:Connect(function()
            local last = getAttrInsensitive(r.model, "LastHit")
            if last == LP.Name then
                self.lifeStats.kills = (self.lifeStats.kills or 0) + 1
            end
        end))
    end

    local function onDesc(d:Instance)
        if d.Name=="RagdollCancel" then
            r.lastEv=os.clock(); r.hasEv=false; r.style.ev=math.clamp(r.style.ev+2,0,8); r.style.lastDash=os.clock()
        end
    end
    for _,d in ipairs(m:GetDescendants()) do onDesc(d) end
    table.insert(r.cons, m.DescendantAdded:Connect(onDesc))

    local function hookAnimator(an:Animator)
        table.insert(r.cons, an.AnimationPlayed:Connect(function(tr)
            local id=tr.Animation and tostring(tr.Animation.AnimationId) or "unknown"
            local tail = id:match("(%d+)$") or "unknown"
            r.active[tr]={id=tail,start=os.clock(),wasBlk=false,hit=false}
            if STUN_TAILS[tail] then self:_noteStun(r, tail) end
            if id==CFG.BlockAnimId then r.style.def=math.clamp(r.style.def+2,0,10); r.style.lastBlk=os.clock() end
            tr.Stopped:Connect(function()
                local slot=r.active[tr]
                if slot then
                    self.ls:seen(slot.id, os.clock()-slot.start)
                    if slot.wasBlk and not slot.hit then self.ls:prevent(slot.id) end
                    r.active[tr]=nil
                end
            end)
        end))
    end

    local function watchAnimator(humanoid:Humanoid?)
        if r.animWatchConn then pcall(function() r.animWatchConn:Disconnect() end) end
        r.animWatchConn = nil
        if not humanoid then return end
        local an = humanoid:FindFirstChildOfClass("Animator")
        if an then hookAnimator(an) end
        local conn = humanoid.ChildAdded:Connect(function(ch)
            if ch:IsA("Animator") then hookAnimator(ch) end
        end)
        r.animWatchConn = conn
        table.insert(r.cons, conn)
    end

    watchAnimator(r.hum)

    table.insert(r.cons, m.ChildAdded:Connect(function(child)
        if child:IsA("Humanoid") then
            self:_attachEnemyHumanoid(r, child)
            watchAnimator(child)
        elseif child:IsA("BasePart") and child.Name == "HumanoidRootPart" then
            self:_attachEnemyHRP(r, child)
        end
    end))

    table.insert(r.cons, m.ChildRemoved:Connect(function(child)
        if child == r.hum then
            watchAnimator(nil)
            self:_attachEnemyHumanoid(r, nil)
        elseif child == r.hrp then
            self:_attachEnemyHRP(r, nil)
        end
    end))

    table.insert(r.cons, m.AncestryChanged:Connect(function(_,p)
        if p==nil then
            if self.stunFollow and self.stunFollow.target == r then
                self.stunFollow = nil
            end
            self:_clearTarget(r)
        end
    end))

    return r
end


local function hasFreezeOnLive(name:string):boolean
    local live = workspace:FindFirstChild("Live")
    local m = live and live:FindFirstChild(name)
    if not m then return false end
    return (m:FindFirstChild("Freeze") ~= nil)
end

function Bot:_animId(rec:Enemy):string? local best,ts=nil,-1; for _,slot in pairs(rec.active) do if slot.start>ts then ts=slot.start; best=slot.id end end; return best end

function Bot:_updateCurrentTarget(dt:number)
    local r = self.currentTarget
    if not r then return end
    if not (r.model and r.model.Parent) then
        self:_clearTarget(r)
        return
    end
    if not self:_ensureEnemyParts(r) then
        self:_clearTarget(r)
        return
    end
    local here = safePos(self.rp)
    local enemyPos = safePos(r.hrp)
    if here and enemyPos then
        r.dist = (enemyPos - here).Magnitude
    else
        r.dist = math.huge
    end
    local nowT = os.clock()
    local st = r.style
    st.aggr=math.max(0, st.aggr - dt*0.35)
    st.def =math.max(0, st.def - dt*0.25)
    st.ev  =math.max(0, st.ev  - dt*0.25)
    r.recent = (r.recent or 0)*math.clamp(1-dt*0.6,0,1)
    r.aRecent= (r.aRecent or 0)*math.clamp(1-dt*0.6,0,1)
    if r.lastStunByMe and (nowT - r.lastStunByMe) > 1.2 then r.lastStunByMe = nil end
    if r.lastEv>0 then r.hasEv = (nowT - r.lastEv) >= CFG.EvasiveCD end
    if attrTrue(r.model, "blocking") then
        st.def=math.clamp(st.def+dt*3,0,10)
        st.lastBlk=nowT
    end
    r.hp = (r.hum and r.hum.Health) or r.hp
    r.blockReact = getAttrInsensitive(r.model, "BlockReact") or 0
    r.ulted = attrTrue(r.model, "Ulted")
    r.absoluteImmortal = r.model:FindFirstChild("AbsoluteImmortal") ~= nil
    r.slowed = r.model:FindFirstChild("Slowed") ~= nil
    local br = r.blockReact
	if (br >= 4.9 and br <= 5) or (br >= -5 and br <= -4.9) then
		-- This is a successful block, you can add tracking here if needed.
	end

    local meIsConsec = self:isAnimPlaying("ConsecutivePunches")
    if meIsConsec and r.slowed then
        if (not r.comboLockFromMeAt) or (nowT - r.comboLockFromMeAt) > 0.1 then
            r.comboLockFromMeAt = nowT
            local cpId = CFG.Attack.AnimIds and CFG.Attack.AnimIds.cp
            local tail = cpId and (cpId:match("(%d+)$") or cpId) or "cp"
            self:_noteStun(r, tail)
        end
    else

        if r.comboLockFromMeAt and (nowT - r.comboLockFromMeAt) > 1.2 then
            r.comboLockFromMeAt = nil
        end
    end

    local lastHit = getAttrInsensitive(r.model, "LastHit")
    if typeof(lastHit)=="string" and lastHit ~= "" then
        r.lastHitBy = lastHit
    end
    local lastM1 = getAttrInsensitive(r.model, "LastM1Hitted")
    if typeof(lastM1)=="string" then
        local name = lastM1:match("([^;]+)")
        if name and name ~= "" then
            r.lastM1By = name
        end
    end
end

function Bot:_scoreTargetCandidate(model:Model, hum:Humanoid, dist:number):number
    local hpScore = math.max(0, 100 - hum.Health)
    local distScore = math.max(0, 60 - dist * 1.5)
    local blockPenalty = attrTrue(model, "blocking") and -15 or 0
    local ultPenalty = attrTrue(model, "ulted") and -25 or 0
    local attackerBonus = (self.lastAttacker == model.Name) and 100 or 0
    local freezeBonus = hasFreezeOnLive(model.Name) and 50 or 0
    return hpScore + distScore + attackerBonus + freezeBonus + blockPenalty + ultPenalty
end

function Bot:selectTarget():Enemy?
    local live = workspace:FindFirstChild("Live")
    self.liveFolder = live
    if not (live and self.rp) then
        self:_clearTarget()
        return nil
    end

    local myPos = safePos(self.rp)
    if not myPos then
        self:_clearTarget()
        return nil
    end

    local bestModel, bestDist = nil, math.huge

    for _, m in ipairs(live:GetChildren()) do
        if m:IsA("Model") and m.Name ~= LP.Name then
            -- Never target AbsoluteImmortal
            if not m:FindFirstChild("AbsoluteImmortal") then
                local hum = m:FindFirstChildOfClass("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 and hrp.Parent then
                    local enemyPos = safePos(hrp)
                    if enemyPos then
                        local dist = (enemyPos - myPos).Magnitude
                        if dist < bestDist then
                            bestDist  = dist
                            bestModel = m
                        end
                    end
                end
            end
        end
    end

    local rec = self:_setCurrentTargetModel(bestModel)
    if rec and bestDist < math.huge then
        rec.dist = bestDist
    end
    return rec
end



function Bot:blockDur(r:Enemy?):number
    local base = 0.34
    if not r then return base end
    if r.style and r.style.aggr>6 then base = base + 0.10 end
    if self.lastAttacker==r.model.Name and os.clock()-(self.lastAtkTime or 0)<0.55 then base = base + 0.10 end

    local aid, tmax = nil, -1
    for _,slot in pairs(r.active or {}) do
        if slot.start>tmax then tmax=slot.start; aid=slot.id end
    end
    if aid then
        local th = self.ls:threat(aid)
        if th > 1.0 then base = base + 0.08 end
        if th > 2.0 then base = base + 0.08 end
    end

    if os.clock() - (self.lastOffenseTime or 0) < 0.6 then base = base - 0.05 end
    return math.clamp(base, 0.25, 0.60)
end

function Bot:shouldBlock(r:Enemy?):(boolean,string?)
    if not r then return false,nil end
    if r and r.dist <= (CFG.M1Range + 0.25)
       and not self.isAttacking
       and not self.inDash
       and (os.clock() - (self.lastM1 or 0)) >= (CFG.M1Min * 0.85) then
        return false, nil
    end

    if self.blocking then return true,"holding" end
    if self.isAttacking then return false,nil end
    if self:_hasRecentStun(r) then return false,nil end
    local nowT=os.clock()
    if nowT<self.blockCooldown then return false,nil end
    if nowT-self.lastBlockTime<0.18 then return false,nil end
    if r.dist>CFG.ComboDist+5 then return false,nil end

    local recentM1=false
    local newestId=nil
    local best=-1
    for _,slot in pairs(r.active) do
        if slot.start>best then
            best=slot.start
            newestId=slot.id
        end
        if slot.id and isM1Tail(slot.id) and (nowT - slot.start) <= 0.55 then
            recentM1=true
        end
    end

    if newestId then
        local threat=self.ls:threat(newestId)
        if threat>=1.5 then return true,"high_threat" end
        if threat>=1.0 and nowT-(r.style.lastAtk or 0)<0.70 then return true,"threat_follow" end
    end

    if recentM1 and r.dist<=CFG.M1Range+0.8 then
        return true,"m1_detected"
    end

    local st=r.style
    if st.aggr>6 and nowT-st.lastAtk<0.55 then return true,"aggressive_combo" end
    if st.aggr>4 and nowT-st.lastAtk<0.75 and r.dist<=CFG.ComboDist then return true,"pressure_close" end
    if self.lastAttacker==r.model.Name and nowT-self.lastAtkTime<0.85 then return true,"retaliate" end
    if st.lastAtk>0 and nowT-st.lastAtk<0.32 and r.dist<CFG.ComboDist+0.5 then return true,"swing_follow" end
    if st.lastDash>0 and nowT-st.lastDash<0.35 and r.dist<=CFG.SpaceMax+2 then return true,"dash_gap_close" end
    if st.def>4 and nowT-st.lastBlk>1.0 and r.dist<=CFG.ComboDist then return true,"guard_break" end
    return false,nil
end

function Bot:shouldEvasive(r:Enemy?):boolean
    if not r or not self.evReady then return false end
    local nowT=os.clock()
    if r.dist>CFG.ComboDist+6 then return false end
    if self.lastAttacker==r.model.Name and nowT-self.lastAtkTime<0.35 and self.lastDmg>10 then return true end
    if r.style.aggr>7 and nowT-r.style.lastAtk<0.35 then return true end
    if r.style.ev>6 and nowT-r.style.lastDash<0.30 and r.dist<CFG.SpaceMin then return true end
    return false
end

function Bot:_judgeEvasive(ts:number)
    task.delay(2.0, function()
        local tookAfter = (self.lastAtkTime > ts) and (os.clock()-self.lastAtkTime < 2.2)
        self.ls:markEv(not tookAfter)
        self.ls:log("evasive_judge",{t0=ts, optimal=not tookAfter})
        self.gui:updateCombos(self.ls.data)
    end)
end

function Bot:evasive(reason:string)
    if not self.evReady then return false end
    if self.blocking then self:_forceUnblockNow(); task.wait(0.05) end
    self:clearMove(); self.evReady=false; self.evTimer=CFG.EvasiveCD
    local dk = (math.random()<0.5) and Enum.KeyCode.A or Enum.KeyCode.D
    local t0=os.clock()
    VIM:SendKeyEvent(true,dk,false,game); task.wait(0.02)
    self:_pressAction("Evasive", CFG.TapS)
    VIM:SendKeyEvent(false,dk,false,game)
    self.ls:log("evasive",{why=reason,t=t0})
    self:_judgeEvasive(t0)
    return true
end

function Bot:evasive(reason:string?)
    return self:attemptEvasive(reason or "manual")
end


function Bot:_isUlted():boolean
    local t=os.clock()
    if t - self.lastUltCheck < 0.15 then return self.isUlt end
    self.lastUltCheck=t
    local live=workspace:FindFirstChild("Live")
    local me  = live and live:FindFirstChild(LP.Name)
    local flag = attrTrue(me, "Ulted")

    if not flag then
        local test = live and live:FindFirstChild("battlegr0undaitest")
        flag = flag or (test and true or false)
    end
    self.isUlt = flag and true or false
    return self.isUlt
end


function Bot:_pressAction(name:string, hold:number?)

    local function markOffense()
        self.lastOffenseTime = os.clock()
    end

    if name=="M1" or name=="M1HOLD" then
        if self:isSelfBlockingVisual() then
            return false
        end
        pressMouse(Enum.UserInputType.MouseButton1, hold or CFG.InputTap)
        markOffense()
        return true
    end
    if name=="Block" then pressKey(CFG.Bind.Block.k,true,hold or CFG.InputTap); return true end
    if name=="Evasive" then pressKey(CFG.Bind.Evasive.k,true,hold or CFG.InputTap); return true end

    local isUlt = self:_isUlted()

    local slot = (name=="NP" and 1) or (name=="CP" and 2) or (name=="Shove" and 3) or (name=="Upper" and 4) or nil
    if slot then
        if not slotReady(slot) then return false end

        local b = CFG.Bind[name]; if b and b.t=="Key" then
            pressKey(b.k,true, hold or CFG.InputTap)
            markOffense()
            return true
        end
        return false
    end
    return false
end


function Bot:maybeDash(r:Enemy)
    if not r or not r.hrp then return end
    if self:_targetImmortal(r) then return end
    if self.inDash or self.blocking or self.isM1ing then return end

    
    if r.dist and r.dist <= (CFG.M1Range + 0.4) and (os.clock() - (self.lastM1 or 0)) >= (CFG.M1Min * 0.7) and not self.isAttacking then
        return
    end

    local d = r.dist or 999
    local nowT = os.clock()
    local ctx = self:_ctxKey(r)

    local candidates = {}
    local canS = self:dashReady("S") and distOK(d, CFG.Gates.S.lo, CFG.Gates.S.hi)
    local canB = self:dashReady("B") and distOK(d, CFG.Gates.B.lo, CFG.Gates.B.hi)
    local canF = self:dashReady("F") and distOK(d, CFG.Gates.F.lo, CFG.Gates.F.hi)
        and ((nowT - (self.lastFDUser or -1e9)) >= FORWARD_DASH_COOLDOWN)

    if canS then
        table.insert(candidates, {name = "S", bias = 0.55, exec = function()
            return self:tryDash("S", r.hrp, "off", r)
        end})
    end
    if canB then
        local bBias = 0.35
        if not canS then bBias = bBias + 0.35 end
        if r.style and r.style.aggr>6 and (nowT - (r.style.lastAtk or 0)) < 0.35 and d>=5 and d<=14 and not canS then
            bBias = bBias + 0.8
        end
        table.insert(candidates, {name = "B", bias = bBias, exec = function()
            return self:tryDash("B", r.hrp, "off", r)
        end})
    end
    if canF then
        local fBias = 0.35
        if d > 40 then fBias = fBias + 0.25 end
        if d < CFG.SpaceMax then fBias = fBias + 0.15 end
        table.insert(candidates, {name = "F", bias = fBias, exec = function()
            return self:tryDash("F", r.hrp, "off", r)
        end})
    end
    if #candidates == 0 then return end

    if self:_hasRecentStun(r) then
        for _,cand in ipairs(candidates) do
            if cand.name == "S" then cand.bias = (cand.bias or 0) + 0.8 end
            if cand.name == "F" then cand.bias = (cand.bias or 0) + 0.4 end
        end
    end
    if d > 60 then
        for _,cand in ipairs(candidates) do
            if cand.name == "S" then cand.bias = (cand.bias or 0) + 0.5 end
            if cand.name == "F" then cand.bias = (cand.bias or 0) + 0.3 end
        end
    end

    local pick = self:choose_action(ctx, candidates, self.bandit.epsilon)
    if pick and pick.exec then
        if pick.exec() ~= false then
            self.lastDashTime = os.clock() 
            self:_noteAction(pick.name, ctx, r)
            self.ls:log("dash_auto", {kind = pick.name, enemy = r and r.model and r.model.Name or "none", dist = d, ctx = ctx})
        end
    end
end




local function probTake(p:number) return math.random() < p end

function Bot:_upperSucceeded(r:Enemy, y0:number):boolean
    if not (r and r.hrp) then return false end
    local air = (r.hum and r.hum.FloorMaterial==Enum.Material.Air)
    local y = r.hrp.Position.Y
    return air or (y - y0) > 1.8
end

function Bot:execCombo(c:Combo, r:Enemy)
    if self.actThread then return end
    self:_finalizeActionRecords(true)
    self.stunFollow = nil
    self.curCombo=c; self:clearMove(); self.lastComboTry=os.clock(); self.gui:setC("Combo: "..c.name)
    local attemptDist = r.dist or 0
    if attemptDist==math.huge then attemptDist=0 end
    self.ls:att(c.id, attemptDist); self.ls:log("combo_start",{id=c.id,tgt=r.model.Name,dist=attemptDist})
    local startHP = r.hum and r.hum.Health or r.hp

    self.actThread = task.spawn(function()
        local abort=false
        local waitForStun=false

        for _,st in ipairs(c.steps) do
            if not self.run or not r.model.Parent or self:_targetImmortal(r) then
                abort = true
                break
            end
            if waitForStun and st.kind ~= "aim" then
                local confirmed=false
                for _=1,6 do
                    if not self.run or not r.model.Parent then abort=true break end
                    if self:_hasRecentStun(r) then confirmed=true; break end
                    task.wait(0.05)
                end
                if not confirmed then abort=true break end
                waitForStun=false
            end

            if st.kind=="aim" then
                self:aimAt(r.hrp); task.wait(0.03)

            elseif st.kind=="press" and st.action then
                if st.action=="M1" then
                    if self:_targetRagdolled(r) then abort=true break end
                    if (r.dist or math.huge) > CFG.M1Range then
                        if not self:_waitForRange(r, CFG.M1Range, 0.45) then abort=true break end
                    end
                    self:_registerM1Attempt(r)
                    self:_pressAction("M1", st.hold)
                    self.lastM1 = os.clock()
                    local w = st.wait or m1Gap()
                    w = math.min(w, CFG.M1MaxGap or 0.60) 
                    task.wait(w)
                    waitForStun = true

                elseif st.action=="M1HOLD" then
                    if self:_targetRagdolled(r) then abort=true break end
                    if (r.dist or math.huge) > CFG.M1Range then
                        if not self:_waitForRange(r, CFG.M1Range, 0.45) then abort=true break end
                    end
                    self:_registerM1Attempt(r)
                    self:_pressAction("M1HOLD", st.hold)
                    self.lastM1 = os.clock()

                    
                    if self.lastShoveAt and (os.clock() - self.lastShoveAt) <= 0.40 then
                        self.allowDashExtend = os.clock() + 0.60
                    end

                    local w = st.wait or m1Gap()
                    w = math.min(w, CFG.M1MaxGap or 0.60)
                    task.wait(w)
                    waitForStun = true

                elseif st.action=="Shove" then
                    self:_pressAction("Shove", st.hold)
                    self.lastShoveAt = os.clock()
                    task.wait(st.wait or 0.12)

                elseif st.action=="Upper" then
                    local y0 = (r.hrp and r.hrp.Position.Y) or 0
                    local ok = false
                    if slotReady(SLOT.Upper) and self:_upperUseOK(r) and (os.clock() - (self.lastDashTime or 0) >= 0.45) then
                        self:_pressAction("Upper", st.hold)
                        ok = true
                    end
                    task.wait(st.wait or 0.26)
                
                    if ok and self:_upperSucceeded(r, y0) then
                        
                        self.allowDashExtend = os.clock() + 0.90
                        
                        local fired=false
                        if distOK(r.dist, CFG.Gates.F.lo, CFG.Gates.F.hi) and math.random()<0.60 then
                            fired = self:tryDash("F", r.hrp, "off", r)
                        end
                        if not fired and distOK(r.dist, CFG.Gates.S.lo, CFG.Gates.S.hi) and math.random()<0.25 then
                            fired = self:tryDash("S", r.hrp, "off", r)
                        end
                        if not fired and distOK(r.dist, CFG.Gates.B.lo, CFG.Gates.B.hi) then
                            self:tryDash("B", r.hrp, "off", r)
                        end
                    else
                        
                        if distOK(r.dist, CFG.Gates.S.lo, CFG.Gates.S.hi) then
                            self:tryDash("S", r.hrp, "off", r)
                        elseif distOK(r.dist, CFG.Gates.B.lo, CFG.Gates.B.hi) then
                            self:tryDash("B", r.hrp, "off", r)
                        end
                    end

                else
                    self:_pressAction(st.action, st.hold)
                    task.wait(st.wait or CFG.InputTap)
                end

            elseif st.kind=="dash" and st.action then
                if st.action=="side" then
                    self:tryDash("S", r.hrp, st.dir or "off", r)
                elseif st.action=="fdash" then
                    self:tryDash("F", r.hrp, st.dir or "off", r)
                elseif st.action=="bdash" then
                    self:tryDash("B", r.hrp, st.dir or "off", r)
                elseif st.action=="auto_after_upper" then
                    
                end
                task.wait(st.wait or CFG.InputTap)

            elseif st.kind=="wait" then
                task.wait(st.wait or CFG.InputTap)
            end
        end

        if abort or not self.run then
            self.gui:setC("Combo: none"); self.curCombo=nil; self.actThread=nil; return
        end

        
        if hasFreezeOnLive(r.model.Name) then
            if slotReady(SLOT.CP) then self:_pressAction("CP") end
            task.wait(0.12)
            if not self:_targetRagdolled(r) then
                if (r.dist or math.huge) > CFG.M1Range then
                    self:_waitForRange(r, CFG.M1Range, 0.35)
                end
                self:_registerM1Attempt(r)
                self:_pressAction("M1", CFG.TapS)
                self.lastM1=os.clock()
                task.wait(m1Gap())
            end
            if slotReady(SLOT.NP) then self:_pressAction("NP") end
        end

        task.wait(0.40)
        local endHP = r.hum and r.hum.Health or startHP
        local dmg=math.max(0,startHP-endHP); local ok=dmg>4
        self.ls:res(c.id,ok,dmg,attemptDist); self.ls:log("combo_res",{id=c.id,ok=ok,dmg=dmg,dist=attemptDist})
        self.gui:updateCombos(self.ls.data)
        if r.style then if ok then r.style.def=math.max(0,r.style.def-0.6) else r.style.def=math.clamp(r.style.def+0.8,0,10) end end
        self.gui:setC("Combo: none"); self.curCombo=nil; self.actThread=nil
    end)
end


function Bot:execBestCloseCombo(r:Enemy)
    if not r or not r.hrp then return end
    local preferUpper = (not r.hasEv) or self:_targetRagdolled(r) or ((r.dist or math.huge) < 4.0)
    local npStats = self.ls:combo("sai_m1cp_np")
    local upStats = self.ls:combo("sai_upper_path")
    local rNP = npStats.succ or 0
    local rUP = upStats.succ or 0

    local pick = "sai_m1cp_np"
    if preferUpper and (rUP >= rNP * 0.8) then
        pick = "sai_upper_path"
    end

    for _,c in ipairs(LIB) do
        if c.id == pick then
            if r.dist > (c.max or CFG.M1Range) then
                self:_waitForRange(r, math.min(CFG.M1Range, 6.5), 0.45)
            end
            self:execCombo(c, r)
            return
        end
    end
end

function Bot:_upperUseOK(r:Enemy):boolean
    if not r then return false end
    local dist    = r.dist or math.huge
    local ragdoll = self:_targetRagdolled(r)
    local noEv    = not r.hasEv
    local behindT = isBehind(self, r)

    
    local closeOK = dist <= math.min((CFG.SpaceMin or 4.6) + 1.5, 5.2)
    if ragdoll and dist <= 8.0 then return true end
    if closeOK and (noEv or behindT) then return true end
    return false
end


function Bot:chase(r:Enemy)
    if not r or not r.hrp then return end
    self:alignCam()
    self:aimAt(r.hrp)
    local forward=1
    local strafe=0
    local nowT=os.clock()
    if nowT-self.lastStrafe>0.35 then
        self.strafe=(math.random()<0.5) and -1 or 1
        self.lastStrafe=nowT
    end
    strafe=self.strafe * 0.65
    local spaceMin = CFG.SpaceMin or 4.6
    if r.dist < spaceMin * 0.35 then
        forward = -0.15
    elseif r.dist < spaceMin * 0.8 then
        forward = 0.9
    else
        forward = 1
    end
    self:setInput(forward,strafe)
    self:maybeDash(r)
end

function Bot:approachFarTarget(r:Enemy)
    if not self.run then return end
    if not (r and r.hrp and self.rp) then return end
    local d = r.dist or math.huge
    if d < 60 then return end

    
    self:aimAt(r.hrp)
    local t = os.clock()
    local weave = ((math.floor(t*3)%2)==0) and 0.55 or -0.55
    self:setInput(1, weave)

    
    if self:dashReady("S") then
        self:tryDash("S", r.hrp, "off", r)
    elseif self:dashReady("F") and (t - (self.lastFDUser or -1e9) >= FORWARD_DASH_COOLDOWN) then
        self:tryDash("F", r.hrp, "off", r)
    end
end



function Bot:_shouldStartCombo(tgt:Enemy):boolean
    if not tgt or not tgt.hrp then return false end
    if os.clock() - (self.lastComboTry or 0) < 0.25 then return false end
    if tgt.dist > CFG.ComboDist then return false end
    if self.blocking or self.inDash then return false end
    if self:_targetRagdolled(tgt) then return false end

    local nowT = os.clock()
    local hasBridge = self:_hasRecentStun(tgt)
    local stunOwned = tgt.lastStunByMe and ((nowT - tgt.lastStunByMe) <= 0.75)
    if stunOwned then
        hasBridge = true
    end
    local m1Recent  = (nowT - (self.lastM1 or 0)) <= 0.60
    local chainReady = (self.m1ChainCount or 0) >= 2 and (nowT - (self.lastM1 or 0)) <= 0.75
    local idlePush  = (nowT - (self.lastOffenseTime or 0)) > 0.90 and tgt.dist <= (CFG.M1Range + 0.5)

    
    
    return hasBridge or m1Recent or idlePush or chainReady
end


function Bot:_chooseCombo(tgt:Enemy):Combo?

    local best,bw=nil,-1
    for _,c in ipairs(LIB) do
        local ok=true
        if c.reqNoEv and tgt.hasEv then ok=false end
        if c.min and tgt.dist < c.min then ok=false end
        if c.max and tgt.dist > c.max then ok=false end

        if ok and c.id=="sai_sd_m1h" then
            if not (self.m1ChainCount==1 or self.m1ChainCount==2) then ok=false end
        end
        if ok then
            local st=self.ls:combo(c.id); local sr=(st.succ+1)/(st.att+2)
            local mid=((c.min or 0)+(c.max or 20))/2; local dBias=math.max(0.1, 1-math.abs((tgt.dist-mid)/20))
            local sBias=1; local s=tgt.style
            if s.def>4 and hasTrait(c,"guardbreak") then sBias = sBias + 0.45 end
            if s.aggr>5 and hasTrait(c,"burst") then sBias = sBias + 0.25 end
            if s.aggr<3 and hasTrait(c,"pressure") then sBias = sBias + 0.20 end
            if s.ev>5 and not c.reqNoEv then sBias = sBias - 0.2 end

            local risk = c.risk or 0.5
            local w=sr*dBias*sBias*(1.0 - risk*0.25)
            if w>bw then bw=w; best=c end
        end
    end
    return best
end

function Bot:_maybeUltActions(tgt:Enemy)
    if not self:_isUlted() then return false end

    if slotReady(1) and (tgt.style.aggr>6 or (self.lastAttacker==tgt.model.Name and os.clock()-self.lastAtkTime<0.5)) then
        self:_pressAction("NP")
        return true
    end

    if slotReady(2) and tgt.dist<=10.0 and self:_upperUseOK(tgt) then
        self:_pressAction("CP")
        return true
    end

    if slotReady(4) and tgt.dist<=30.0 then
        self:_pressAction("Upper")
        return true
    end

    if slotReady(3) and tgt.dist<=18.0 then
        self:_pressAction("Shove")
        return true
    end
    return false
end

function Bot:neutral(tgt:Enemy?)
    if not tgt or not tgt.hrp or self:_targetImmortal(tgt) then
        self:setInput(0, 0)
        return
    end
    self:alignCam()
    self:aimAt(tgt.hrp)
    local d,nowT=tgt.dist,os.clock()

    if d>CFG.FarChase then
        self:chase(tgt)
    else
        if (nowT - self.closeT) > CFG.CloseWindow then
            if (self.closeD - d) < CFG.CloseGain then
                self.urgency = math.min(5, self.urgency + 2)
                self:chase(tgt)
            end
            self.closeT=nowT; self.closeD=d
        end
    end

    self:maybeDash(tgt)

    local forward,strafe=0,0
    local spacingMode = (not self.curCombo) and (not self.isAttacking)
    local idealSpace = math.clamp((CFG.Gates.F.lo + CFG.Gates.F.hi) * 0.5, CFG.SpaceMax + 6, CFG.Gates.F.hi)
    local nearIdeal = idealSpace - 6
    local farIdeal = idealSpace + 8

    if spacingMode then
        if d < CFG.SpaceMin*0.85 then
            forward = -0.75
        elseif d < nearIdeal then
            forward = -0.35
        elseif d > farIdeal then
            forward = 0.95
        else
            forward = 0.65
        end

        if d < nearIdeal and self:dashReady("B") and not self.inDash then
            self:tryDash("B", tgt.hrp, "off", tgt)
        elseif d < idealSpace and self:dashReady("S") and not self.inDash then
            if math.random() < 0.35 then
                self:tryDash("S", tgt.hrp, "off", tgt)
            end
        end

        if nowT-self.lastStrafe>0.25 then
            self.strafe = (math.random()<0.5) and -1 or 1
            self.lastStrafe=nowT
        end
        strafe = self.strafe * 0.65
    else
        if d>CFG.SpaceMax then
            forward=1
            self.strafe=0
        elseif d<CFG.SpaceMin*0.45 then
            forward=-0.6
            self.strafe=0
        else
            local rangeSpan=math.max(0.1, CFG.SpaceMax-CFG.SpaceMin)
            local closeness=math.clamp((CFG.SpaceMax - d)/rangeSpan,0,1)
            forward=0.65 + 0.35*closeness
            local lateral=Vector3.new(0,0,0)
            if tgt.hrp then
                local vel=tgt.hrp.AssemblyLinearVelocity or tgt.hrp.Velocity
                if vel then lateral=flat(vel) end
            end
            if lateral.Magnitude>1 then
                local right=flat(self.rp.CFrame.RightVector)
                if right.Magnitude>1e-3 then
                    local side=lateral:Dot(right.Unit)
                    if math.abs(side)>0.5 then
                        self.strafe=side>0 and 1 or -1
                        self.lastStrafe=nowT
                    end
                end
            end
            if nowT-self.lastStrafe>0.35 then
                self.strafe=(math.random()<0.5) and -1 or 1
                self.lastStrafe=nowT
            end
            local strafeWeight=0.4 + 0.6*closeness
            strafe=self.strafe*strafeWeight
        end
    end


    if self:_maybeUltActions(tgt) then
        self:setInput(forward,strafe)
        return
    end


    local ctx = self:_ctxKey(tgt)
    local ragdolled = self:_targetRagdolled(tgt)
    local skillCandidates = {}

    if d<=CFG.M1Range and (nowT - (self.lastM1 or 0)) >= (CFG.M1Min * 0.55) and not ragdolled and not self.blocking then

        table.insert(skillCandidates, {
            name = "M1",
            bias = 0.65, 
            exec = function()
                self:_registerM1Attempt(tgt)
                local fired = self:_pressAction("M1", CFG.TapS)
                if fired then
                    self.lastM1        = nowT
                    self.lastAttempt   = nowT
                    self.lastOffenseTime = nowT
                end
                return fired
            end,
        })
    end


    local skillWindow = d<=CFG.CloseUseRange and (nowT - self.lastSkill)>0.28
    if skillWindow then
        if slotReady(SLOT.Shove) then
            local bias = 0.20
            if tgt.style and (nowT - (tgt.style.lastBlk or 0)) < 0.3 then bias = bias + 0.5 end
            table.insert(skillCandidates, {
                name = "SHOVE",
                bias = bias,
                exec = function()
                    if not self:_pressAction("Shove") then return false end
                    self.lastShoveAt = os.clock()
                    self.lastSkill = nowT
                    self.lastAttempt = nowT
                    task.delay(0.10, function()
                        if not (self.run and self.alive) then return end
                        if not (tgt and tgt.model and tgt.model.Parent) then return end
                        self:_registerM1Attempt(tgt)
                        if self:_pressAction("M1", CFG.TapM) then
                            self.lastM1 = os.clock()
                        end
                    end)
                    return true
                end,
            })
        end

        if slotReady(SLOT.CP) then
            table.insert(skillCandidates, {
                name = "CP",
                bias = ragdolled and 0.2 or 0.0,
                exec = function()
                    if not self:_pressAction("CP") then return false end
                    self.lastSkill = nowT
                    self.lastAttempt = nowT
                    return true
                end,
            })
        end

        if slotReady(SLOT.NP) then
            local npBias = 0.0
            if tgt.hp <= CFG.SnipeHP then npBias = npBias + 0.4 end
            table.insert(skillCandidates, {
                name = "NP",
                bias = npBias,
                exec = function()
                    if not self:_pressAction("NP") then return false end
                    self.lastSkill = nowT
                    self.lastAttempt = nowT
                    return true
                end,
            })
        end

        local dashAge = nowT - (self.lastDashTime or 0)
        local recentB = (self.lastDashKind == "B") and (dashAge < 0.80)  
        if slotReady(SLOT.Upper)
           and self:_upperUseOK(tgt)
           and dashAge >= ((self.lastDashKind == "S" or self.lastDashKind == "F") and 0.25 or 0.60)
           and not recentB
           and (self.m1ChainCount >= 1 or ragdolled)
        then
            local upBias = ragdolled and 0.50 or 0.08
            table.insert(skillCandidates, {
                name = "UPPER",
                bias = upBias,
                exec = function()
                    if not self:_pressAction("Upper") then return false end
                    self.lastSkill  = nowT
                    self.lastAttempt= nowT
                    return true
                end,
            })
        end

    end

    if #skillCandidates > 0 then
        local pick = self:choose_action(ctx, skillCandidates, self.bandit.epsilon)
        if pick and pick.exec then
            if pick.exec() then
                self:_noteAction(pick.name, ctx, tgt)
            end
        end
        if (not self.isAttacking) and d <= CFG.M1Range and not ragdolled and not self.blocking then
            self:_registerM1Attempt(tgt)
            if self:_pressAction("M1", CFG.TapS) then
                self.lastM1 = nowT
                self.lastAttempt = nowT
                self:_noteAction("M1", ctx, tgt)
            end
        end
    end

    if self.blocking then
        forward = math.clamp(forward, -0.25, 0.35)
        strafe  = math.clamp(strafe, -0.35, 0.35)
    end
    self:setInput(forward,strafe)
end

local function _getLiveModelFor(name:string)
    local live = workspace:FindFirstChild("Live")
    if not live then return nil end
    return live:FindFirstChild(name)
end


function Bot:updateAttacker()
    local live = _getLiveModelFor(LP.Name)
    self.liveFolder = workspace:FindFirstChild("Live")
    self.liveChar   = live

    if not live then return end
    local a = getAttrInsensitive(live, "LastHit")
    if typeof(a) == "string" and a ~= "" then
        self.lastAttacker = a
    end
end


function Bot:start()
    local h=self.hum
    if not h or h.Health<=0 then self.gui:setS("Status: waiting spawn"); return end
    if self.run then self.gui:setS("Status: running"); return end
    self.errorState = false
    self.autoStart=true; self.run=true; self.sess=self.ls:startSession(); self.since=os.clock()
    self.gui:setS("Status: running"); self.gui:setC("Combo: none"); self.ls:log("session_start",{char=CFG.CharKey})
    self.closeT=os.clock(); self.closeD=math.huge
end

function Bot:stop()
    if not self.run then self:clearMove(); return end
    self.autoStart=false; self.run=false; self:clearMove(); if self.hum then self.hum.AutoRotate=true end
    self:_cancelActiveCombo()
    self:_stopDashOrientation()
    self.inDash = false
    self:_stopBlocking()
    self:_restoreCamera()
    self.recoveringFromFall = false
    self.gui:setS("Status: idle"); self.gui:setC("Combo: none"); self.ls:log("session_stop",{dur=os.clock()-self.since})
    self.stunFollow = nil
end

function Bot:exit()
    self.autoStart=false; self.run=false; self:clearMove()
    self.ls:log("exit", {t=os.clock()})
    self:destroy()
    getgenv().BattlegroundsBot=nil
end


CFG.Bind = {
    M1      = {t="Mouse", b=Enum.UserInputType.MouseButton1},
    Shove   = {t="Key",   k=Enum.KeyCode.Three},
    CP      = {t="Key",   k=Enum.KeyCode.Two},
    Upper   = {t="Key",   k=Enum.KeyCode.Four},
    NP      = {t="Key",   k=Enum.KeyCode.One},
    Block   = {t="Key",   k=Enum.KeyCode.F},
    Evasive = {t="Key",   k=Enum.KeyCode.Q},
}

function Bot:update(dt:number)
    if self.destroyed then return end
    if self.ls and self.ls.flush then
        pcall(function()
            self.ls:flush()
        end)
    end

    self:_ensureCharacterBindings()
    if not (self.char and self.hum and self.rp) then return end
    if self.hum.Health <= 0 then
        self.run = false
        return
    end

    self:_processBlocking()
    self:_updateDashOrientation()

    local fallingNow = false
    do
        local ok, state = pcall(function()
            return self.hum:GetState()
        end)
        fallingNow = ok and FALL_STATES[state] or false
    end

    if fallingNow then
        if not self.recoveringFromFall then
            self.recoveringFromFall = true
            self:clearMove()
            self:_cancelActiveCombo()
            if self.gui then
                self.gui:setS("Status: recovering (knocked down)")
            end
        end
        return
    elseif self.recoveringFromFall then
        self.recoveringFromFall = false
        if self.gui then
            self.gui:setS(self.run and "Status: running" or "Status: idle")
        end
    end

    if not self.run then
        if self.autoStart then
            self:_autoResumeTick()
        end
    end


    self:_finalizeActionRecords(false)

    if os.clock() >= (self._nextAutoSaveAt or 0) then
        self:savePolicy()
        self._nextAutoSaveAt = os.clock() + (CFG.AutoSave or 30)
        if self.gui and self.gui.setKPI then
            local meta = self.bandit.meta or {}
            self.gui:setKPI(meta.generation or 0, meta.epsilon or self.bandit.epsilon or 0.15, meta.lastLife or {})
        end
    end


    if self.evTimer>0 then self.evTimer = self.evTimer - dt; if self.evTimer<=0 then self.evTimer=0; self.evReady=true end end
    self.gui:setE(self.evReady and "Evasive: ready" or ("Evasive: "..string.format("%.1fs",math.max(0,self.evTimer))))

    self:_updateCurrentTarget(dt)
    self:updateAttacker()
    local nowT=os.clock()
    if self.lastAttacker and nowT-self.lastAtkTime>3 then self.lastAttacker=nil; self.lastDmg=0 end

    local tgt=self:selectTarget()
    self.lastTargetDist = tgt and tgt.dist or nil
    if not tgt then
        self.gui:setT("Target: none")
        if not self.run then self:clearMove() end
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
    end
    if (not self.inDash) and tgt.hrp then
        self:aimAt(tgt.hrp)
    end
    self:approachFarTarget(tgt)
    local targetImmortal = self:_targetImmortal(tgt)
    if targetImmortal then
        self.gui:setT(("Target: %s (untouchable)"):format(tgt.model.Name))
        self:neutral(tgt)
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
    end
    local meConsec = self:isAnimPlaying("ConsecutivePunches")
    if meConsec and (tgt.slowed or (tgt.model and tgt.model:FindFirstChild("Slowed"))) then
        if not tgt.comboLockActive then
            tgt.comboLockActive = true
            self:_noteStun(tgt, "combo_lock")
        end
    elseif tgt.comboLockActive then
        tgt.comboLockActive = nil
    end
    self.gui:setT(("Target: %s (%.0f hp)"):format(tgt.model.Name, tgt.hp))

    nowT=os.clock()
    local preBlockEval, preBlockReason = self:shouldBlock(tgt)
    local blockedOnDash = false
    if tgt and tgt.dist <= CFG.SpaceMax then
        local justDashed = (tgt.style.lastDash>0) and (nowT - tgt.style.lastDash < 0.25)
        if justDashed and preBlockEval then
            self:block(self:blockDur(tgt), tgt, preBlockReason or "dash")
            blockedOnDash = true
        end
    end

    if self.blocking and self.blockStartTime and (nowT-self.blockStartTime)>5.0 then
        self:_forceUnblockNow()
        self.blocking=false
        self.blockStartTime=nil
        self:maybeDash(tgt)
    end

    if self:_processStunFollow(tgt, nowT) then
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
    end


    local md = self.hum.MoveDirection.Magnitude
    if md>0.10 then self.lastMoveTime = nowT end

    if self.run and (not self.blocking) and (not self.inDash) then
        if nowT - self.lastMoveTime >= CFG.StillPunish then
            self:chase(tgt)
            local sideKick = (math.random()<0.5) and -0.75 or 0.75
            self:setInput(0.95, sideKick)
            self.lastMoveTime = nowT
        end
        if (nowT - self.lastOffenseTime) >= CFG.AttackPunish and not self.isAttacking then
            if tgt.dist <= (CFG.M1Range + 1.2) and not self:_targetRagdolled(tgt) then
                self:_registerM1Attempt(tgt)
                if self:_pressAction("M1", CFG.TapS) then
                    self:_noteAction("M1", self:_ctxKey(tgt), tgt)
                    self.lastM1 = nowT
                end
            else
                self:chase(tgt)
                self:maybeDash(tgt)
            end
            self.lastOffenseTime = nowT
            self.lastAttempt = nowT
        end
    end

    local idleCond = (md<0.10) and (not self.inDash) and (not self.isAttacking) and (not self.blocking)
    if idleCond then
        self.stillTimer = self.stillTimer + dt
        if self.stillTimer > 1.2 then
            local idleCtx = self:_ctxKey(tgt)
            if distOK(tgt.dist, CFG.Gates.S.lo, CFG.Gates.S.hi) and math.random()<0.85 then
                local fired = self:_pressAction("Shove", CFG.TapS)
                if fired then
                    self:_noteAction("SHOVE", idleCtx, tgt)
                    self.lastSkill = nowT
                    self.lastAttempt = nowT
                    task.delay(0.10, function()
                        if not (self.run and self.alive) then return end
                        if not (tgt and tgt.model and tgt.model.Parent) then return end
                        self:_registerM1Attempt(tgt)
                        if self:_pressAction("M1", CFG.TapM) then
                            self.lastM1 = os.clock()
                        end
                    end)
                end
                self:tryDash("S", tgt.hrp, "off", tgt)
            else
                self:maybeDash(tgt)
            end
            self:setInput(0.95, (math.random()<0.5) and -1 or 1)
            self.lastMoveTime = nowT
            self.stillTimer = 0
        end
    else
        self.stillTimer = 0
    end


    self:aimAt(tgt.hrp)
    if not self.run then
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
    end


    if self.shouldPanic then if self:evasive("panic") then self.shouldPanic=false end end 
	if self:shouldEvasive(tgt) then if self:evasive("react") then self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S")); return end end

    local likelyBlk = (nowT-tgt.style.lastBlk)<0.30 or (tgt.style.def>6)
    if tgt.hp<=CFG.SnipeHP and not likelyBlk and tgt.dist<=CFG.SnipeRange and (nowT-self.lastSnipe>0.8) then
        if slotReady(SLOT.NP) then
            if self:_pressAction("NP") then
                self:_noteAction("NP", self:_ctxKey(tgt), tgt)
                self.lastSkill = nowT
                self.lastAttempt=nowT
            end
            self.lastSnipe=nowT; self:setInput(0.6,0)
            self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
            return
        end
    end


    local shouldBlockNow, blockReason
    if blockedOnDash then
        shouldBlockNow, blockReason = false, nil
    else
        shouldBlockNow, blockReason = self:shouldBlock(tgt)
    end
    if shouldBlockNow then
        if not self.blocking then
            self:block(self:blockDur(tgt), tgt, blockReason)
        end
        self:neutral(tgt)
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
    end

    local closeForCombo = tgt.dist <= (CFG.M1Range + 0.5)
    if closeForCombo and not self.blocking and not self.inDash and not self.actThread then
        local targetBlocking = self:_targetIsBlocking(tgt)
        if targetBlocking then
            if tgt.hrp and self:dashReady("S") and (nowT - (self.lastAttempt or 0)) > 0.25 then
                if self:tryDash("S", tgt.hrp, "off", tgt) then
                    self.lastAttempt = nowT
                end
            end
        elseif not self.isAttacking then
            local sinceM1 = nowT - (self.lastM1 or 0)
            if sinceM1 >= CFG.M1Min then
                self:_registerM1Attempt(tgt)
                if self:_pressAction("M1", CFG.TapS) then
                    self.lastM1 = nowT
                    self.lastAttempt = nowT
                    self.lastOffenseTime = nowT
                end
            end
        end
    end
    
    do
        local sinceM1 = nowT - (self.lastM1 or 0)
        if tgt and not self.inDash and not self.blocking
           and self.m1ChainCount >= 2
           and sinceM1 <= (CFG.M1MaxGap * 1.3)
           and not self:_hasRecentStun(tgt) then
            
            if self:dashReady("B") and tgt.dist <= (CFG.SpaceMin + 2.0) then
                self:tryDash("B", tgt.hrp, "off", tgt)
            elseif self:dashReady("S") then
                self:tryDash("S", tgt.hrp, "def", tgt) 
            else
                self:block(self:blockDur(tgt), tgt, "m1_fail_fallback")
            end
            self.m1ChainCount   = 0
            self.lastAttempt    = nowT
            self.lastOffenseTime= nowT
            self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
            return
        end
    end



    if nowT - self.lastAttempt > CFG.MaxNoAtk and tgt.dist<=CFG.CloseUseRange+2 then
        if (nowT - self.lastAttempt) > CFG.ForceAtk then
            local forceCtx = self:_ctxKey(tgt)
            if slotReady(SLOT.Shove) and math.random()<0.55 then
                if self:_pressAction("Shove") then
                    self:_noteAction("SHOVE", forceCtx, tgt)
                    self.lastSkill = nowT
                    task.delay(0.10, function()
                        if not (self.run and self.alive) then return end
                        if not (tgt and tgt.model and tgt.model.Parent) then return end
                        self:_registerM1Attempt(tgt)
                        if self:_pressAction("M1", CFG.TapM) then
                            self.lastM1 = os.clock()
                        end
                    end)
                end
            elseif slotReady(SLOT.CP) then
                if self:_pressAction("CP") then
                    self:_noteAction("CP", forceCtx, tgt)
                    self.lastSkill = nowT
                end
            end
            self.lastAttempt=nowT
        end
    end


    local canCombo = self:_shouldStartCombo(tgt)
    if canCombo then
        local c=self:_chooseCombo(tgt)
        if c then

            if c.id=="sai_upper_path" and math.random()<0.60 then

                c=nil
                for _,k in ipairs(LIB) do if k.id=="sai_m1cp_np" then c=k break end end
            end
        end
        if c then self:execCombo(c,tgt); self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S")); return end
    end


    self:neutral(tgt)
    self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
end


function AI.Init(opts)
    if getgenv().BattlegroundsBot and getgenv().BattlegroundsBot.destroy then
        pcall(function() getgenv().BattlegroundsBot:destroy() end)
    end
    local bot = Bot.new()
    getgenv().BattlegroundsBot = bot
    AI._bot = bot
    if opts and opts.autorun then bot:start() end
    return true
end



local function _num(v) return tonumber(v) end


function AI.Decide(input)
    local bot = AI._bot
    if not bot then return "idle" end

    local tgt = (input and input.target) or bot.currentTarget or bot:selectTarget()
    local ctx = bot:_ctxKey(tgt)
    local d   = (tgt and tgt.dist) or math.huge
    local nowT = os.clock()

    local candidates = {}
    local function add(c) table.insert(candidates, c) end

    
    if tgt and bot:dashReady("S") and d>=CFG.Gates.S.lo and d<=CFG.Gates.S.hi then
        add({name="S", bias=0.40, exec=function() return bot:tryDash("S", tgt.hrp, "off", tgt) end})
    end
    if tgt and bot:dashReady("B") and d>=CFG.Gates.B.lo and d<=CFG.Gates.B.hi then
        add({name="B", bias=0.20, exec=function() return bot:tryDash("B", tgt.hrp, "off", tgt) end})
    end
    if tgt and bot:dashReady("F")
       and d>=CFG.Gates.F.lo and d<=CFG.Gates.F.hi
       and (os.clock() - (bot.lastFDUser or -1e9) >= FORWARD_DASH_COOLDOWN) then
        add({name="F", bias=0.30, exec=function() return bot:tryDash("F", tgt.hrp, "off", tgt) end})
    end

    
    if tgt and d<=CFG.M1Range and (nowT - (bot.lastM1 or 0)) > CFG.M1Min and not bot:_targetRagdolled(tgt) then
        add({name="M1", bias=0.50, exec=function()
            bot:_registerM1Attempt(tgt)
            return bot:_pressAction("M1", CFG.TapS)
        end})
    end

    if tgt and d<=CFG.CloseUseRange and slotReady(SLOT.Shove) then
        add({name="SHOVE", bias=0.15, exec=function() return bot:_pressAction("Shove") end})
    end
    if slotReady(SLOT.CP) then
        add({name="CP", bias=0.00, exec=function() return bot:_pressAction("CP") end})
    end
    if slotReady(SLOT.NP) then
        local finBias = (tgt and tgt.hp and tgt.hp <= CFG.SnipeHP) and 0.40 or 0.00
        add({name="NP", bias=finBias, exec=function() return bot:_pressAction("NP") end})
    end
    if tgt and slotReady(SLOT.Upper) and bot:_upperUseOK(tgt) then
        add({name="UPPER", bias=0.10, exec=function() return bot:_pressAction("Upper") end})
    end

    if #candidates == 0 then return "idle", ctx end
    local pick = bot:choose_action(ctx, candidates, bot.bandit.epsilon)
    return pick and pick.name or "idle", ctx, pick and pick.exec or nil
end


function AI.Learn(input, output, reward)
    local bot = AI._bot
    if not bot then return end
    local ctx  = (type(input)=="table" and (input.ctx or input.context)) or input
    local dist = (type(input)=="table" and input.dist) or nil
    bot:update_ravg(ctx, output, reward, 1.0)
    bot.ls:moveAdd(output, reward, dist)
    bot:savePolicy()
end

do
    
    getgenv().AI = getgenv().AI or {}
    local GAI = getgenv().AI

    local function bot() return getgenv().BattlegroundsBot end

    
    function GAI.ToggleExternal(on)
        CFG.AI = CFG.AI or {}
        CFG.AI.external = (on ~= false)
        local b = bot()
        if b and b.gui and b.gui.rules then
            b.gui.rules.Text = string.format(
                "FDash[%g..%g] • ε=%.2f • AI=%s",
                CFG.Gates.F.lo, CFG.Gates.F.hi,
                b.bandit.epsilon or 0.15,
                (CFG.AI.external and "external" or "internal")
            )
        end
        return CFG.AI.external
    end

    
    function GAI.SetEpsilon(eps)
        local b = bot(); if not b then return false end
        b.bandit.epsilon = math.clamp(tonumber(eps) or b.bandit.epsilon or 0.15, 0.01, 0.60)
        if b.gui and b.gui.rules then
            b.gui.rules.Text = b.gui.rules.Text:gsub("ε=[%d%.]+", ("ε=%.2f"):format(b.bandit.epsilon))
        end
        return b.bandit.epsilon
    end

    
    function GAI.ExportPolicy(path)
        path = path or (CFG.Data.."/policy.export.json")
        local b = bot(); if not b then return false end
        local ok, blob = pcall(function()
            return HttpService:JSONEncode({policy=b.policy or {}, meta=b.bandit.meta or {}})
        end)
        if not ok then return false end
        wfile(path, blob)
        return path
    end

    function GAI.ImportPolicy(path)
        path = path or (CFG.Data.."/policy.export.json")
        local raw = rfile(path); if not raw then return false end
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok or typeof(data) ~= "table" then return false end
        local b = bot(); if not b then return false end
        b.policy = data.policy or {}
        b.bandit.meta = data.meta or b.bandit.meta
        b:savePolicy()
        return true
    end

    function GAI.ResetPolicy()
        local b = bot(); if not b then return false end
        b.policy = {}
        b.bandit.meta = {epsilon=b.bandit.epsilon, generation=0, tune=b.bandit.tune or {}}
        b:savePolicy()
        return true
    end

    
    
    
    

    
    if Bot and not Bot._logPatched then
        Bot._logPatched = true

        
        local _noteAction = Bot._noteAction
        function Bot:_noteAction(actionName, ctx, tgt)
            _noteAction(self, actionName, ctx, tgt)
            if self.bridge and self.bridge.log then
                pcall(self.bridge.log, {
                    type   = "action",
                    action = actionName,
                    ctx    = ctx,
                    target = tgt and tgt.model and tgt.model.Name or nil
                })
            end
        end

        
        local _upd = Bot.update_ravg
        function Bot:update_ravg(ctx, action, reward, weight)
            _upd(self, ctx, action, reward, weight)
            if self.bridge and self.bridge.log then
                pcall(self.bridge.log, {
                    type   = "reward",
                    ctx    = ctx,
                    action = action,
                    reward = reward,
                    w      = weight
                })
            end
        end

        
        local _save = Bot.savePolicy
        function Bot:savePolicy()
            _save(self)
            if self.kpiPath and self.bridge and self.bridge.log then
                pcall(self.bridge.log, {type="kpi", path=self.kpiPath})
            end
        end
    end

    
    task.defer(function()
        local b = bot()
        if b and b.gui and b.gui.rules then
            b.gui.rules.Text = string.format(
                "FDash[%g..%g] • ε=%.2f • AI=%s",
                CFG.Gates.F.lo, CFG.Gates.F.hi,
                b.bandit.epsilon or 0.15,
                (CFG.AI.external and "external" or "internal")
            )
        end
    end)
end


if getgenv and rawget(getgenv(),"JoeHub") then
    CFG.AI = CFG.AI or {}; CFG.AI.external = true
end


getgenv().AI = getgenv().AI or AI


function AI.OnEvent(eventType, data)
    local bot = AI._bot
    if not bot then return end
    data = data or {}

    if eventType == "damage_dealt" then
        bot:_recordDamageEvent(data.target, tonumber(data.amount) or 0, true, {dist=data.dist})

    elseif eventType == "damage_taken" then
        bot:_recordDamageEvent(nil, tonumber(data.amount) or 0, false, {dist=data.dist})

    elseif eventType == "kill" then
        bot.lifeStats.kills = (bot.lifeStats.kills or 0) + 1

    elseif eventType == "death" then
        bot:_endLife()

    elseif eventType == "stun" and data.target then
        local rec = bot.currentTarget
        if rec and rec.model and rec.model.Name == data.target then
            bot:_noteStun(rec, tostring(data.animTail or "manual"))
        end

    elseif eventType == "save" then
        bot:savePolicy()
        if bot.ls and bot.ls.flush then
            pcall(function()
                bot.ls:flush()
            end)
        end

    elseif eventType == "load" then
        bot:loadPolicy()
    end
end

function AI.Save()
    local b = AI._bot
    if not b then return end
    b:savePolicy()
    if b.ls and b.ls.flush then
        pcall(function()
            b.ls:flush()
        end)
    end
end

function AI.Load()
    local b = AI._bot
    if b then b:loadPolicy() end
end

function AI.Start()
    local b = AI._bot
    if b then b:start() end
end

function AI.Stop()
    local b = AI._bot
    if b then b:stop() end
end


function AI.ExportMemory()
    local b = AI._bot
    if not b then return "{}" end
    local pkt = {
        policy = b.policy,
        meta   = b.bandit.meta,
        combos = b.ls and b.ls.data and b.ls.data.combos or {}
    }
    return HttpService:JSONEncode(pkt)
end

AI.Init({autorun = true})
return AI
