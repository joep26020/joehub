

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VIM         = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

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
        F = 10.0,
        B =  10.0,
        S =  5.0,
    },

    M1Range  = 5,
    M1MaxGap = 0.7,
    InputTap = 0.10,
    TapS     = 0.05,
    TapM     = 0.25,
    M1Min    = 0.5,
    M1Rand   = 0.05,

    NPFinisherId  = "normal_punch",
    UPFinisherId  = "uppercut",


    EvasiveCD = 30,


    Gates = {
        F = { lo= 23.0, hi=33.0 },
        S = { lo= 7, hi=16 },
        B = { lo= 8, hi=35.0 },
    },






    Dash = {
        KeyQ        = Enum.KeyCode.Q,
        HoldQ       = 0.10,
        RefaceTail  = 0.60,

        FWindow     = 0.80,
        BWindow     = 1.2,
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
    Flush = 0.25,

    BlockAnimId = "rbxassetid://10470389827",
}


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

local function m1Gap()
    -- random spacing, but never exceed hard cap
    local w = CFG.M1Min + math.random() * CFG.M1Rand
    return math.min(w, CFG.M1MaxGap)
end



local function flat(v:Vector3) return Vector3.new(v.X,0,v.Z) end
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
function Bridge.new()
    local env=rawget(getgenv(),"joehub") or rawget(getgenv(),"JoeHub")
    local self=setmetatable({},Bridge)
    if typeof(env)=="table" then self.env=env end
    if self.env then self.aim = self.env.AimAt or self.env.AimTarget or self.env.AimStabilizer end
    return self
end
function Bridge:tryAim(rp,tp) if self.aim then local ok=pcall(self.aim,rp,tp); if ok then return true end end return false end


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
function LS:startSession() self.data.sessions+=1; self:_flag(); local id=os.date("%Y%m%d-%H%M%S"); local p=self.sdir.."/"..id..".jsonl"; wfile(p,""); self.cur=p; return p end
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
    c.att+=1
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
        c.succ+=1
        c.last=os.time()
        if dist then
            c.distSuccessSum=(c.distSuccessSum or 0)+dist
            c.distSuccessCount=(c.distSuccessCount or 0)+1
            c.distSuccessAvg=c.distSuccessSum/math.max(1,c.distSuccessCount)
            c.distLastSuccess=dist
        end
    end
    c.dmgt+=(dm>0 and dm or 0)
    if dist then c.distLast=dist end
    self:_flag()
end

local function getA(self,id) id=sid(id); local a=self.data.A[id]; if not a then a={seen=0,open=0,block=0,prevent=0,dealt=0}; self.data.A[id]=a end; return id,a end
function LS:seen(id,dur) local _,a=getA(self,id); a.seen+=1; self:_flag() end
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
    m.n+=1
    m.rsum+=reward
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
function LS:markEv(opt:boolean) self.data.ev.total+=1; if opt then self.data.ev.optimal+=1 else self.data.ev.subopt+=1 end; self:_flag() end


local GUI={}; GUI.__index=GUI
local function text(p,n,t,sz,pos,ts,bold)
    local l=Instance.new("TextLabel"); l.Name=n; l.Size=sz; l.Position=pos
    l.BackgroundColor3=Color3.fromRGB(24,24,24); l.BackgroundTransparency=0.35
    l.TextColor3=Color3.fromRGB(235,235,235); l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize=ts; l.Text=t; l.BorderSizePixel=0; l.TextXAlignment=Enum.TextXAlignment.Left; l.TextYAlignment=Enum.TextYAlignment.Center; l.Parent=p
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,10); pad.Parent=l; return l
end
local function btn(p,n,t,sz,pos,clr)
    local b=Instance.new("TextButton"); b.Name=n; b.Size=sz; b.Position=pos
    b.BackgroundColor3=clr or Color3.fromRGB(48,60,96)
    b.TextColor3=Color3.fromRGB(240,240,240); b.Font=Enum.Font.GothamBold; b.TextSize=18; b.Text=t; b.BorderSizePixel=0; b.AutoButtonColor=true
    local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(94,123,255); s.Thickness=1.4; s.Transparency=0.35; s.Parent=b; b.Parent=p; return b
end
local function drag(f:Frame)
    local g=false; local st,sp
    f.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then g=true; st=i.Position; sp=f.Position; i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then g=false end end) end end)
    f.InputChanged:Connect(function(i) if g and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-st; f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end
function GUI.new()
    local self=setmetatable({},GUI)
    local g=Instance.new("ScreenGui"); g.Name="BGBotUI"; g.ResetOnSpawn=false; g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; g.Parent=gethui and gethui() or game:GetService("CoreGui")
    local f=Instance.new("Frame"); f.Name="Main"; f.Size=UDim2.new(0,520,0,336); f.Position=UDim2.new(0,60,0,100); f.BackgroundColor3=Color3.fromRGB(17,18,26); f.BorderSizePixel=0; f.Parent=g; drag(f)
    local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(76,110,255); s.Thickness=1.5; s.Transparency=0.15; s.Parent=f

    local title=text(f,"T","Aggro Bot v6.0", UDim2.new(1,0,0,32),UDim2.new(0,0,0,0),20,true); title.BackgroundTransparency=1; title.TextColor3=Color3.fromRGB(205,214,255)
    self.status =text(f,"S","Status: idle", UDim2.new(1,-20,0,24),UDim2.new(0,10,0,34),18,false)
    self.target =text(f,"A","Target: none", UDim2.new(1,-20,0,24),UDim2.new(0,10,0,60),18,false)
    self.combo  =text(f,"C","Combo: none", UDim2.new(1,-20,0,24),UDim2.new(0,10,0,86),18,false)
    self.ev     =text(f,"E","Evasive: ready",UDim2.new(1,-20,0,24),UDim2.new(0,10,0,112),18,false)

    local startB=btn(f,"Start","Start", UDim2.new(0.33,-10,0,30), UDim2.new(0,10,0,148))
    local stopB =btn(f,"Stop","Stop",  UDim2.new(0.33,-10,0,30), UDim2.new(0.33,0,0,148), Color3.fromRGB(120,50,50))
    local exitB =btn(f,"Exit","Exit",  UDim2.new(0.33,-10,0,30), UDim2.new(0.66,10,0,148), Color3.fromRGB(80,30,30))

    self.moves = text(f,"M","Dash CDs: F=0.00 | B=0.00 | S=0.00", UDim2.new(1,-20,0,20), UDim2.new(0,10,0,182), 14, false)
    self.rules = text(f,"R","FDash[14..30] • SideOff relock≤3.5 • Still>5s→dash • Idle atk≤15s • M1 openers", UDim2.new(1,-20,0,20), UDim2.new(0,10,0,204), 12, false)

    local panel=Instance.new("Frame"); panel.Name="Combos"; panel.Size=UDim2.new(1,-20,1,-238); panel.Position=UDim2.new(0,10,0,238)
    panel.BackgroundColor3=Color3.fromRGB(20,22,30); panel.BorderSizePixel=0; panel.Parent=f
    local pst=Instance.new("UIStroke"); pst.Color=Color3.fromRGB(76,110,255); pst.Thickness=1; pst.Transparency=0.2; pst.Parent=panel

    self.ctitle = text(panel,"CT","Combo Tracker",UDim2.new(1,-10,0,22),UDim2.new(0,6,0,4),16,true); self.ctitle.BackgroundTransparency=1
    local list=Instance.new("ScrollingFrame"); list.Name="List"; list.Size=UDim2.new(1,-10,1,-30); list.Position=UDim2.new(0,5,0,26)
    list.CanvasSize=UDim2.new(0,0,0,0); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=4; list.Parent=panel
    local ul=Instance.new("UIListLayout"); ul.Padding=UDim.new(0,4); ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.Parent=list
    self.comboList=list; self.comboLayout=ul

    self.gui=g; self.frame=f; self.startB=startB; self.stopB=stopB; self.exitB=exitB
    return self
end
function GUI:setS(t) self.status.Text=t end
function GUI:setT(t) self.target.Text=t end
function GUI:setC(t) self.combo.Text=t end
function GUI:setE(t) self.ev.Text=t end
function GUI:updateCDs(f,b,s) self.moves.Text = string.format("Dash CDs: F=%.2f | B=%.2f | S=%.2f", math.max(0,f), math.max(0,b), math.max(0,s)) end
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
    if not (tHRP) then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local dir = tHRP.Position - camPos
    if dir.Magnitude < 1e-3 then return end
    cam.CFrame = CFrame.new(camPos, camPos + dir.Unit)
end

local function yawLook(from: Vector3, to: Vector3): CFrame?
    local flat = Vector3.new(to.X, from.Y, to.Z) - from
    if flat.Magnitude < 1e-3 then return nil end
    return CFrame.lookAt(from, from + flat.Unit)
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
    if self.dashOrientThread then
        pcall(task.cancel, self.dashOrientThread)
        self.dashOrientThread = nil
    end
end

function Bot:_stopBlocking()
    if self.blockThread then
        pcall(task.cancel, self.blockThread)
        self.blockThread = nil
    end
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


    self.enemies = {} :: {[Model]:Enemy}
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
    self.reconcileTask = nil
    self.savedCameraType = nil

    self.evReady=true; self.evTimer=0; self.shouldPanic=false
    self.lastRealDash = {F=-1e9, B=-1e9, S=-1e9}
    self.lastM1=0; self.lastSkill=0; self.lastSnipe=0
    self.lastAttacker=nil; self.lastAtkTime=0; self.lastDmg=0; self.lastHP=0

    self.blocking=false; self.blockUntil=0; self.blockThread=nil; self.lastBlockTime=0; self.blockCooldown=0
    self.blockStartTime=nil

    self.stunFollow=nil
    self.lastStunTarget=nil

    self.moveKeys={ [Enum.KeyCode.W]=false,[Enum.KeyCode.A]=false,[Enum.KeyCode.S]=false,[Enum.KeyCode.D]=false }
    self.strafe=0; self.lastStrafe=0

    self.live=workspace:WaitForChild("Live"); self.liveChar=self.live:FindFirstChild(LP.Name); self.liveConn=nil

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


    self.inDash=false
    self.dashOrientThread=nil
    self.dashPending = nil


    self.sticky=nil
    self.stickyT=0
    self.stickyHold=1.6
    self.switchMargin=25.0
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

    self:connectChar(LP.Character or LP.CharacterAdded:Wait())
    self:_trackConnection(LP.CharacterAdded:Connect(function(c) self:connectChar(c) end))

    self:attachLive(self.liveChar)
    for _,m in ipairs(self.live:GetChildren()) do self:addEnemy(m) end
    self:_trackConnection(self.live.ChildAdded:Connect(function(m)
        if m.Name==LP.Name then self:attachLive(m) else self:addEnemy(m) end
    end))
    self:_trackConnection(self.live.ChildRemoved:Connect(function(m)
        local r=self.enemies[m]; if r then for _,c in ipairs(r.cons) do pcall(function() c:Disconnect() end) end self.enemies[m]=nil end
        if m==self.liveChar then self:attachLive(nil) end
    end))

    -- Also watch Players so we prep enemy records fast
    self:_trackConnection(Players.PlayerAdded:Connect(function(p)
        self:_trackConnection(p.CharacterAdded:Connect(function(ch)
            task.defer(function()
                if self.destroyed then return end
                local live = workspace:FindFirstChild("Live")
                local mdl = live and live:FindFirstChild(p.Name)
                if mdl then self:addEnemy(mdl) end
            end)
        end))
    end))

    self:_trackConnection(Players.PlayerRemoving:Connect(function(p)
        for m,rec in pairs(self.enemies) do
            if rec.ply == p then
                for _,c in ipairs(rec.cons) do pcall(function() c:Disconnect() end) end
                self.enemies[m] = nil
            end
        end
    end))

    -- Lightweight reconciler in case Live hiccups
    self.reconcileTask = task.spawn(function()
        while not self.destroyed do
            task.wait(2.0)
            if self.destroyed then break end
            local live = workspace:FindFirstChild("Live")
            if live then
                -- add any missing
                for _,m in ipairs(live:GetChildren()) do
                    if m.Name ~= LP.Name and not self.enemies[m] then
                        self:addEnemy(m)
                    end
                end
                -- prune dead references
                for m,_ in pairs(self.enemies) do
                    if not m.Parent then self.enemies[m] = nil end
                end
            end
        end
        self.reconcileTask = nil
    end)

    self.hb=RunService.Heartbeat:Connect(function(dt) self:update(dt) end)
        -- Always-on aim lock when not in a dash sequence
    self.hardAimHB = RunService.RenderStepped:Connect(function()
        if not (self.rp and (self.run or self.blocking)) then return end
        if self.inDash then return end
        if self.hum and self.hum:GetState()==Enum.HumanoidStateType.FallingDown then return end
    
        local tgt = (self.currentTarget and self.currentTarget.hrp) or nil
        if not tgt then return end
    
        local cf = yawLook(self.rp.Position, tgt.Position)
        if not cf then return end
    
        self.hum.AutoRotate = false
        self.rp.CFrame = cf
    
        local cam = workspace.CurrentCamera
        if cam then
            local cp = cam.CFrame.Position
            local lv = cf.LookVector
            cam.CFrame = CFrame.new(cp, Vector3.new(cp.X + lv.X, cp.Y, cp.Z + lv.Z))
        end
    end)


    return self
end
function Bot:_autoResumeTick()
    -- If we’re spawned and healthy but not "running", auto-start
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
    if self.alwaysAimHB then self.alwaysAimHB:Disconnect() end
    if self.liveConn then self.liveConn:Disconnect() end
    self.hb = nil
    self.alwaysAimHB = nil
    self.liveConn = nil

    if self.reconcileTask then
        pcall(task.cancel, self.reconcileTask)
        self.reconcileTask = nil
    end

    for _,conn in ipairs(self.connections or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self.connections = {}

    for _,c in ipairs(self.myHumConns) do pcall(function() c:Disconnect() end) end
    self.myHumConns = {}

    for _,rec in pairs(self.enemies or {}) do
        for _,c in ipairs(rec.cons or {}) do pcall(function() c:Disconnect() end) end
    end
    self.enemies = {}

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
    if self.hum then self.hum.AutoRotate = false end

    local function alignCam()
        local cam = workspace.CurrentCamera
        if not(cam and self.rp) then return end
        local cp  = cam.CFrame.Position
        local fv  = self.rp.CFrame.LookVector
        local flat= Vector3.new(fv.X, 0, fv.Z)
        if flat.Magnitude < 1e-3 then return end
        local tgt = cp + flat.Unit
        cam.CFrame = CFrame.new(cp, Vector3.new(tgt.X, cp.Y, tgt.Z))
    end
    local function canTurn()
        if self.hum and self.hum:GetState()==Enum.HumanoidStateType.FallingDown then return false end
        return true
    end
    local function faceToward(pos:Vector3)
        if not canTurn() then return end
        local here=self.rp.Position
        local to  = Vector3.new(pos.X, here.Y, pos.Z) - here
        if to.Magnitude<1e-3 then return end
        self.rp.CFrame = CFrame.lookAt(here, here + to.Unit)
        alignCam()
    end
    local function faceAwayFrom(pos:Vector3)
        if not canTurn() then return end
        local here=self.rp.Position
        local to  = Vector3.new(pos.X, here.Y, pos.Z) - here
        if to.Magnitude<1e-3 then return end
        self.rp.CFrame = CFrame.lookAt(here, here - to.Unit)
        alignCam()
    end
    local function facePerp(toU:Vector3, cw:boolean)
        if not canTurn() then return end
        local perp = cw and Vector3.new(toU.Z,0,-toU.X) or Vector3.new(-toU.Z,0,toU.X)
        self.rp.CFrame = CFrame.lookAt(self.rp.Position, self.rp.Position + perp.Unit)
        alignCam()
    end

    local t0 = os.clock()
    local length = (tr.Length and tr.Length>0) and tr.Length
                  or (kind=="fdash" and CFG.Dash.FWindow)
                  or (kind=="bdash" and CFG.Dash.BWindow)
                  or CFG.Dash.SWindow
    local orbitCW, didOrbit, orbitStart = (math.random()<0.5), false, 0.0
    local stopped = false
    tr.Stopped:Connect(function() stopped = true end)

    self:_stopDashOrientation()
    self.dashOrientThread = task.spawn(function()
        while not stopped and os.clock()-t0 <= length do
            if not (self.run and self.hum and self.hum.Health>0 and self.rp) then break end
            local tgt = tHRP
            if not (tgt and tgt.Parent) then
                local pick = self:selectTarget()
                tgt = pick and pick.hrp or nil
            end
            if tgt then
                local to = Vector3.new(tgt.Position.X, self.rp.Position.Y, tgt.Position.Z) - self.rp.Position
                if to.Magnitude > 1e-3 then
                    local toU = to.Unit
                    if kind=="fdash" then
                        if style=="off" then
                            if not didOrbit then
                                faceToward(tgt.Position)
                                if to.Magnitude <= CFG.Dash.OrbitTrigger then
                                    didOrbit = true; orbitStart = os.clock()
                                end
                            else
                                local elapsed = os.clock() - orbitStart
                                if elapsed <= CFG.Dash.OrbitDur then facePerp(toU, orbitCW)
                                else faceToward(tgt.Position) end
                            end
                        else
                            faceAwayFrom(tgt.Position)
                        end
                    elseif kind=="bdash" then
                        if style=="off" then
                            local timeLeft = (t0 + length) - os.clock()
                            if to.Magnitude <= CFG.Dash.BackClose then facePerp(toU, orbitCW)
                            else faceAwayFrom(tgt.Position) end
                            if timeLeft <= CFG.Dash.PreEndBackFace then faceToward(tgt.Position) end
                        else
                            faceToward(tgt.Position)
                        end
                    else -- side
                        if style=="off" then
                            if to.Magnitude <= CFG.Dash.SideOffLock then faceToward(tgt.Position)
                            else facePerp(toU, orbitCW) end
                        else
                            facePerp(toU, orbitCW)
                        end
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end

        -- Hard re-lock after dash
        local pick = self:selectTarget()
        local t2   = (tHRP and tHRP.Parent) and tHRP or (pick and pick.hrp)
        if t2 and self.hum and self.hum.Health>0 and self.hum:GetState()~=Enum.HumanoidStateType.FallingDown then
            self.rp.CFrame = CFrame.lookAt(self.rp.Position, Vector3.new(t2.Position.X, self.rp.Position.Y, t2.Position.Z))
            alignCam()
        end

        local closeEnemy = enemy or pick
        if closeEnemy and closeEnemy.hrp and self.run and self.alive and not self.actThread then
            local dist = closeEnemy.dist or math.huge
            if dist==math.huge and self.rp then
                dist = (closeEnemy.hrp.Position - self.rp.Position).Magnitude
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

        -- log dash "reward"
        local scoreKind = (kind=="fdash" and "F") or (kind=="bdash" and "B") or "S"
        if scoreKind then
            local scoreTarget = enemy or pick
            if not scoreTarget and t2 and t2.Parent then
                scoreTarget = self:getEnemyByName(t2.Parent.Name)
            end
            self:_postDashScore(scoreKind, scoreTarget)
        end

        -- gate dash -> combo: only after Upper HIT or Shove→M1(HOLD) flag
        if pick and self:_hasRecentStun(pick) and (pick.dist or 99) <= CFG.CloseUseRange then
            if self.allowDashExtend and os.clock() < self.allowDashExtend then
                self:execBestCloseCombo(pick)
            end
        end
        self.allowDashExtend = nil

        self.inDash = false
        self.dashOrientThread = nil
    end)
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
                local rec=self:getEnemyByName(attacker)
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

    if (not self.liveChar) or (not self.liveChar.Parent) then
        local live = workspace:FindFirstChild("Live")
        local mdl = live and live:FindFirstChild(LP.Name) or nil
        if mdl and mdl ~= self.liveChar then
            self:attachLive(mdl)
        end
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
    if self.destroyed then return end
    if not tHRP or not self.rp then return end
    if self.inDash then return end
    if self.hum and self.hum:GetState()==Enum.HumanoidStateType.FallingDown then
        if self.hum then self.hum.AutoRotate=true end
        return
    end
    local aimed = self.bridge:tryAim(self.rp,tHRP)
    if not aimed then
        aimCFrame(self.rp,tHRP)
    else
        local to = tHRP.Position - self.rp.Position
        if to.Magnitude > 1e-3 then
            local look = self.rp.CFrame.LookVector
            if look:Dot(to.Unit) < 0.995 then
                aimCFrame(self.rp,tHRP)
            end
        end
    end

    if self.hum then self.hum.AutoRotate=false end
end


local function now() return os.clock() end
local function distOK(d:number, lo:number, hi:number) return d>=lo and d<=hi end
local FALL_STATES = {
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true,
}

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
    entry.n += w
end

function Bot:choose_action(ctx:string, candidates:{[number]:{name:string, bias:number?, exec:(()->boolean?)?, meta:any}}?, epsilon:number?)
    local list = candidates or {}
    local len = #list
    if len == 0 then return nil end
    local eps = epsilon or self.bandit.epsilon or 0.15
    if math.random() < eps then
        return list[math.random(1, len)]
    end
    local best, bestScore = list[1], -math.huge
    for _,cand in ipairs(list) do
        local entry = self:_getOrInit(ctx, cand.name)
        local score = entry.ravg + (cand.bias or 0)
        if score > bestScore then
            bestScore = score
            best = cand
        end
    end
    return best
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
                    act.damageDealt += amount
                    if act.isFinisher then act.keptAdvantage = true end
                    if act.targetBlocking then act.forcedUnblock = true end
                    if act.ragdolled then act.keptAdvantage = true end
                else
                    act.damageTaken += amount
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
    local reward = (act.damageDealt or 0) - 0.7 * (act.damageTaken or 0)
    local nowT = os.clock()
    if act.isFinisher and act.damageDealt > 0 then reward += 6 end
    if act.forcedUnblock then reward += 3 end
    local kept = act.keptAdvantage or (act.behindStart and act.damageTaken <= 0)
    if kept then reward += 2 end
    if act.firstDamageTaken and (act.damageDealt or 0) <= 0 and (act.firstDamageTaken - act.time) <= 0.8 then
        reward -= 5
    end
    if act.targetBlocking and (act.damageDealt or 0) <= 0 then reward -= 3 end
    if act.lostSpacing then reward -= 2 end

    self:update_ravg(act.ctx, act.action, reward * 0.7, 1.0)
    if act.prevCtx and act.prevAction then
        self:update_ravg(act.prevCtx, act.prevAction, reward * 0.3, 0.5)
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
            i += 1
        end
    end
end

function Bot:_averageReward(actionName:string, filters:{string}?)
    if not self.policy then return nil end
    local sum, count = 0.0, 0
    for ctx, actions in pairs(self.policy) do
        local ok = true
        if filters then
            for _,f in ipairs(filters) do
                if not string.find(ctx, f, 1, true) then ok=false break end
            end
        end
        if ok then
            local entry = actions[actionName]
            if entry and entry.n and entry.n > 0 then
                sum += entry.ravg or 0
                count += 1
            end
        end
    end
    if count == 0 then return nil end
    return sum / count
end

function Bot:_applyTune(tune:any)
    CFG.Cooldown.F = BASE_COOLDOWN.F
    CFG.Cooldown.S = BASE_COOLDOWN.S
    CFG.Cooldown.B = BASE_COOLDOWN.B
    CFG.Gates.F.lo = BASE_GATES.F.lo; CFG.Gates.F.hi = BASE_GATES.F.hi
    CFG.Gates.S.lo = BASE_GATES.S.lo; CFG.Gates.S.hi = BASE_GATES.S.hi
    CFG.Gates.B.lo = BASE_GATES.B.lo; CFG.Gates.B.hi = BASE_GATES.B.hi

    local tuneB = tune and tune.B
    if tuneB then
        CFG.Cooldown.B = math.clamp(BASE_COOLDOWN.B + (tuneB.cooldown or 0), 6.5, 12.0)
        CFG.Gates.B.lo = math.clamp(BASE_GATES.B.lo + (tuneB.gateLo or 0), 2.5, 6.5)
        CFG.Gates.B.hi = math.clamp(BASE_GATES.B.hi + (tuneB.gateHi or 0), 30.0, 40.0)
    end
end

function Bot:_applyGenerationKnobs(meta:any?)
    meta = meta or self.bandit.meta or {}
    local baseEps = meta.epsilon or self.bandit.epsilon or 0.15
    local newEps = baseEps
    local last = meta.lastLife
    if last then
        if last.reward and last.reward > 12 then newEps -= 0.02 end
        if last.reward and last.reward < -12 then newEps += 0.02 end
        if last.kd and last.kd > 1.2 then newEps -= 0.01 elseif last.kd and last.kd < 0.8 then newEps += 0.01 end
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

function Bot:_targetIsBlocking(r:Enemy?, window:number?):boolean
    if not r then return false end
    local nowT = os.clock()
    local limit = window or 0.35

    if r.model then
        local attr = r.model:GetAttribute("Blocking") or r.model:GetAttribute("IsBlocking") or r.model:GetAttribute("Block")
        if attrOn(attr) then return true end
    end

    if r.style and (nowT - (r.style.lastBlk or 0)) <= limit then
        return true
    end

    if r.active then
        local blockTail = CFG.BlockAnimId and CFG.BlockAnimId:match("(%d+)$")
        if blockTail then
            for _,slot in pairs(r.active) do
                if slot and slot.id == blockTail then
                    return true
                end
            end
        end
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
    -- Only dash-extend if a prior step armed the window (Shove->M1(HOLD) or Upper hit)
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
        local dist = (r.hrp.Position - self.rp.Position).Magnitude
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

function Bot:_requestSideDash(tHRP:BasePart?, style:string?, r:Enemy?)
    if not (self.rp and tHRP) then return end
    local g = CFG.Gates.S
    local dist = r and r.dist
    if not dist and self.rp then dist = (tHRP.Position - self.rp.Position).Magnitude end
    if not dist or not distOK(dist, g.lo, g.hi) then return end

    -- Ensure we're actually facing the target before picking a side
    self:aimAt(tHRP)

    local myPos   = self.rp.Position
    local tPos    = tHRP.Position
    local right   = flat(self.rp.CFrame.RightVector)
    if right.Magnitude < 1e-3 then right = Vector3.new(1,0,0) end
    right = right.Unit

    local sideLen = CFG.Dash.SideLen or 10.0
    local aPos    = myPos - right * sideLen -- A = left
    local dPos    = myPos + right * sideLen -- D = right

    local dA = (tPos - aPos).Magnitude
    local dD = (tPos - dPos).Magnitude

    local offensive = (style or "off") == "off"
    local sideKey
    if offensive then
        -- pick the side that REDUCES distance more
        sideKey = (dA < dD) and Enum.KeyCode.A or Enum.KeyCode.D
    else
        -- defensive: pick the side that INCREASES distance
        sideKey = (dA > dD) and Enum.KeyCode.A or Enum.KeyCode.D
    end

    -- Avoid diagonal turning this into F/B dash
    local wasW = self.moveKeys[Enum.KeyCode.W]
    local wasS = self.moveKeys[Enum.KeyCode.S]
    if wasW then self:setKey(Enum.KeyCode.W, false) end
    if wasS then self:setKey(Enum.KeyCode.S, false) end

    self.dashPending = {kind="side", style=(style or "off"), tHRP=tHRP, enemy=r}

    pressKey(sideKey, true)
    task.wait(0.02)
    pressKey(CFG.Dash.KeyQ, true); task.wait(CFG.Dash.HoldQ); pressKey(CFG.Dash.KeyQ, false)
    pressKey(sideKey, false)

    if wasW then self:setKey(Enum.KeyCode.W, true) end
    if wasS then self:setKey(Enum.KeyCode.S, true) end

    self.lastDashTime = os.clock() -- NEW: for “no Upper right after dash”
    self.lastMoveTime = os.clock()
end




function Bot:_requestForwardDash(r:Enemy)
    if not (self.rp and r and r.hrp) then return end
    -- NEW: user-intended global limiter (in addition to the real in-game CD)
    if (os.clock() - (self.lastFDUser or -1e9)) < 45.0 then return end

    local d = r.dist
    local g = CFG.Gates.F
    if not distOK(d, g.lo, g.hi) then return end
    if self:_cdLeft("F")>0 then return end

    self.lastFD=now()
    self.lastFDUser = os.clock()   -- NEW: record user limiter

    self.dashPending = {kind="fdash", style="off", tHRP=r.hrp}
    pressKey(Enum.KeyCode.W,true); task.wait(0.02); holdQ(CFG.Dash.HoldQ); pressKey(Enum.KeyCode.W,false)
    self.lastMoveTime = os.clock()
end


function Bot:_requestBackDash(tHRP:BasePart?, style:string?, r:Enemy?)
    if not (self.rp and tHRP) then return end
    local g = CFG.Gates.B
    local dist = r and r.dist
    if not dist and self.rp then dist = (tHRP.Position - self.rp.Position).Magnitude end
    if not dist or not distOK(dist, g.lo, g.hi) then return end

    -- release conflicting keys so S wins (no diagonal)
    local wasW = self.moveKeys[Enum.KeyCode.W]
    local wasA = self.moveKeys[Enum.KeyCode.A]
    local wasD = self.moveKeys[Enum.KeyCode.D]
    if wasW then self:setKey(Enum.KeyCode.W, false) end
    if wasA then self:setKey(Enum.KeyCode.A, false) end
    if wasD then self:setKey(Enum.KeyCode.D, false) end

    self.dashPending = {kind="bdash", style=(style or "off"), tHRP=tHRP, enemy=r}

    pressKey(Enum.KeyCode.S, true)
    task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)
    pressKey(Enum.KeyCode.S, false)

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

function Bot:tryDash(kind:string, tHRP:BasePart?, style:string?, r:Enemy?)
    if not tHRP or self.inDash then return false end
    if self.blocking then return false end
    style = style or "off"
    local executed=false
    if kind=="S" then
        if self:dashReady("S") then self:_requestSideDash(tHRP, style, r); executed=true end
    elseif kind=="F" then
        if self:dashReady("F") then self:_requestForwardDash(r); executed=true end
    elseif kind=="B" then
        if self:dashReady("B") then self:_requestBackDash(tHRP, style, r); executed=true end
    end
    if executed then
        local ctx=self:_ctxKey(r)
        self:_noteAction(kind, ctx, r)
        self.ls:log("dash",{kind=kind, enemy=r and r.model and r.model.Name or "none", dist=r and r.dist or nil, style=style})
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
        local blk = live:GetAttribute("Blocking") or live:GetAttribute("IsBlocking") or live:GetAttribute("Block")
        if attrOn(blk) then return true end
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
    if b and b.t=="Key" then
        VIM:SendKeyEvent(false,b.k,false,game)
    end
    self.blocking=false
    self.blockUntil=0
end
function Bot:block(dur:number?, target:Enemy?, reason:string?)
    if os.clock() < self.blockCooldown then return end
    local b=CFG.Bind.Block; if not b or b.t~="Key" then return end
    if self.blocking and self.blockThread then return end
    local hold = math.clamp(dur or 0.35, 0.25, 0.60)
    self.blocking=true
    self.blockStartTime=os.clock()
    self.blockUntil = self.blockStartTime + hold
    if target and target.model then
        local aid=self:_animId(target)
        local threat = aid and self.ls:threat(aid) or 0
        self.ls:log("block", {enemy=target.model.Name, anim=aid, threat=threat, dur=hold, reason=reason or "auto"})
    end
    self.blockThread = task.spawn(function()
        VIM:SendKeyEvent(true,b.k,false,game)
        local tEnd=os.clock()+hold
        while os.clock()<tEnd and self.run and self.alive and self.blocking do task.wait(0.03) end
        VIM:SendKeyEvent(false,b.k,false,game)
        self.blocking=false
        self.blockUntil=0
        self.blockThread=nil
        self.blockStartTime=nil
        self.lastBlockTime=os.clock()
        self.blockCooldown = self.lastBlockTime + 0.35
    end)
end


local function sidTail(id:string?):string if not id then return "unk" end local n=id:match("(%d+)$"); return n or id end

function Bot:addEnemy(m:Model)
    if m.Name==LP.Name then return end  -- allow NPCs/others; only skip self

    local r:Enemy = {
        model=m, hum=m:FindFirstChildOfClass("Humanoid"), hrp=m:FindFirstChild("HumanoidRootPart"),
        dist=math.huge, hasEv=true, lastEv=0, score=0, ply=Players:FindFirstChild(m.Name), hp=100,
        style={aggr=0,def=0,ev=0,lastAtk=0,lastBlk=0,lastDash=0}, recent=0, aRecent=0, active={}, cons={}, aggro=0,
        lastStunByMe=0,
    }

    if not (r.hum and r.hrp) then return end
    r.hp=r.hum.Health

    table.insert(r.cons, r.hum:GetPropertyChangedSignal("Health"):Connect(function()
    local nh = r.hum.Health
    local delta = math.max(0, (r.hp or nh) - nh)
    if delta > 0 then
        -- Determine if *I* caused this damage
        local wasMe = false
        local last = r.model:GetAttribute("LastHit") or r.model:GetAttribute("lastHit")
        if last == LP.Name then
            wasMe = true
        end
        if not wasMe then
            local creator = r.hum:FindFirstChild("creator")
            if creator and creator.Value == LP then wasMe = true end
        end
        if not wasMe then
            local dam = r.model:GetAttribute("LastDamager") or r.model:GetAttribute("lastDamager") or r.model:GetAttribute("LastDamagerName")
            if typeof(dam) == "Instance" and dam == LP then wasMe = true
            elseif typeof(dam) == "string" and dam == LP.Name then wasMe = true end
        end
    
        if wasMe then
            local myA = self:_myAnimId()
            if myA then self.ls:deal(myA, delta) end
            self.lifeStats.damageDealt = (self.lifeStats.damageDealt or 0) + delta
            self:_recordDamageEvent(r.model.Name, delta, true, {dist = r.dist})
            r.aRecent = (r.aRecent or 0)*0.5 + delta
    
            -- If that hit was from a close M1, allow a short dash-extend window
            if self.lastM1Target == r and os.clock() - (self.lastM1AttemptTime or 0) < 0.6 then
                self:onM1Hit(r)
            end
        end
    end
    r.hp = nh
    end))

    if r.hum then
        table.insert(r.cons, r.hum.Died:Connect(function()
            local last = r.model:GetAttribute("LastHit") or r.model:GetAttribute("lastHit")
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
    local an=r.hum:FindFirstChildOfClass("Animator")
    if an then hookAnimator(an)
    else table.insert(r.cons, r.hum.ChildAdded:Connect(function(ch) if ch:IsA("Animator") then hookAnimator(ch) end end)) end

    table.insert(r.cons, m.AncestryChanged:Connect(function(_,p)
        if p==nil then
            for _,c in ipairs(r.cons) do pcall(function() c:Disconnect() end) end
            if self.stunFollow and self.stunFollow.target == r then
                self.stunFollow = nil
            end
            self.enemies[m]=nil
        end
    end))

    self.enemies[m]=r
end


function Bot:getEnemyByName(n:string):Enemy? for _,r in pairs(self.enemies) do if r.model and r.model.Name==n then return r end end end

local function hasFreezeOnLive(name:string):boolean
    local live = workspace:FindFirstChild("Live")
    local m = live and live:FindFirstChild(name)
    if not m then return false end
    return (m:FindFirstChild("Freeze") ~= nil)
end

function Bot:_animId(rec:Enemy):string? local best,ts=nil,-1; for _,slot in pairs(rec.active) do if slot.start>ts then ts=slot.start; best=slot.id end end; return best end

function Bot:updateEnemies(dt:number)
    if not self.rp then return end
    local my=self.rp.Position; local nowT=os.clock()
    for m,r in pairs(self.enemies) do
        if not m.Parent then self.enemies[m]=nil
        else
            r.hrp = r.hrp or m:FindFirstChild("HumanoidRootPart")
            r.hum = r.hum or m:FindFirstChildOfClass("Humanoid")
            if r.stunScore then
                r.stunScore = math.max(0, r.stunScore - dt*0.7)
                if r.stunScore < 0.05 then r.stunScore = 0 end
            end
            r.dist = r.hrp and (r.hrp.Position - my).Magnitude or math.huge
            local st=r.style
            r.recent = (r.recent or 0)*math.clamp(1-dt*0.6,0,1)
            r.aRecent= (r.aRecent or 0)*math.clamp(1-dt*0.6,0,1)
            st.aggr=math.max(0, st.aggr - dt*0.35); st.def=math.max(0, st.def - dt*0.25); st.ev=math.max(0, st.ev - dt*0.25)
            if r.lastStunByMe and (nowT - r.lastStunByMe) > 1.2 then r.lastStunByMe = nil end
            if r.lastEv>0 then r.hasEv = (nowT - r.lastEv) >= CFG.EvasiveCD end
            if attrOn(m:GetAttribute("Attacking") or m:GetAttribute("Attack") or m:GetAttribute("isAttacking")) then st.aggr=math.clamp(st.aggr+dt*3.5,0,10); st.lastAtk=nowT end
            if attrOn(m:GetAttribute("Blocking") or m:GetAttribute("IsBlocking") or m:GetAttribute("Block")) then st.def=math.clamp(st.def+dt*3,0,10); st.lastBlk=nowT end
            if attrOn(m:GetAttribute("Dashing") or m:GetAttribute("IsDashing") or m:GetAttribute("Dash")) then st.ev=math.clamp(st.ev+dt*2.5,0,8); st.lastDash=nowT end
            if r.hum and r.hum.Health<=0 then
                r.score = -1e9
            else
                r.hp = (r.hum and r.hum.Health) or r.hp
                local hpF   = (100 - r.hp)
                local distF = math.clamp(40 - r.dist, -40, 40)
                local evF   = r.hasEv and -25 or 15
                local agF   = st.aggr*4
                local defP  = st.def*1.5
                local dmgF  = (r.recent or 0)*1.2
                local aid=self:_animId(r); local ath= aid and self.ls:threat(aid) or 0

                r.aggro = (r.recent*1.2 + r.aRecent*0.8) + (ath*2)
                local stunBias = (r.stunScore or 0)*45
                r.score = hpF + distF + evF + agF - defP + dmgF + math.clamp(ath*4, -8, 16) + math.min(40, r.aggro*0.5) + stunBias
                if self.lastAttacker and r.model.Name==self.lastAttacker then r.score+=120 end
                if hasFreezeOnLive(r.model.Name) then r.score = r.score + 60 end
            end
        end
    end
end

function Bot:selectTarget():Enemy?
    local nowT = os.clock()
    local reach = 50.0  -- until inside this, just go nearest

    -- 1) Pick nearest alive enemy first (for approach phase)
    local nearest, nd = nil, 1/0
    for _,r in pairs(self.enemies) do
        if r.model.Parent and r.hum and r.hum.Health>0 and r.dist and r.dist<nd then
            nearest, nd = r, r.dist
        end
    end
    if not nearest then return nil end

    -- If we don't have a sticky or we are still far, lock to nearest
    if (not self.sticky) or (not self.sticky.model.Parent) or ((self.sticky.dist or 999) > reach) then
        self.sticky, self.stickyT = nearest, nowT
        self.stickyHold = 3.0
        self.switchMargin = 40.0
        return self.sticky
    end

    -- 2) Once within reach, consider switching only if someone very close + much higher aggro
    local cur = self.sticky
    local best, bs, bestAgg = cur, (cur.score or -1e9), (cur.aggro or 0)
    for _,r in pairs(self.enemies) do
        if r.model.Parent and r.hum and r.hum.Health>0 then
            local w = (r.score or -1e9) + (r.aggro or 0) * 0.9
            if w > bs and (r.dist or 999) <= 20.0 then
                best, bs, bestAgg = r, w, (r.aggro or 0)
            end
        end
    end
    if best ~= cur then
        if (bestAgg > (cur.aggro or 0) + 30) or (bs > ((cur.score or -1e9) + 80)) then
            self.sticky, self.stickyT = best, nowT
        end
    end
    return self.sticky
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

function Bot:attemptEvasive(reason:string)
    if not self.evReady then return false end
    if self.blocking and self.blockThread then self:_forceUnblockNow(); task.wait(0.05) end
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


function Bot:_isUlted():boolean
    local t=os.clock()
    if t - self.lastUltCheck < 0.15 then return self.isUlt end
    self.lastUltCheck=t
    local live=workspace:FindFirstChild("Live")
    local me  = live and live:FindFirstChild(LP.Name)
    local flag = me and attrOn(me:GetAttribute("Ulted"))

    if not flag then
        local test = live and live:FindFirstChild("battlegroundaitest")
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
    if self.inDash or self.blocking or self.isM1ing then return end

    -- NEW: if in jab range and free to swing, DON'T dash—jab instead
    if r.dist and r.dist <= (CFG.M1Range + 0.4) and (os.clock() - (self.lastM1 or 0)) >= (CFG.M1Min * 0.7) and not self.isAttacking then
        return
    end

    local d = r.dist or 999
    local nowT = os.clock()
    local ctx = self:_ctxKey(r)

    local candidates = {}
    local canS = self:dashReady("S") and distOK(d, CFG.Gates.S.lo, CFG.Gates.S.hi)
    local canB = self:dashReady("B") and distOK(d, CFG.Gates.B.lo, CFG.Gates.B.hi)
    local canF = self:dashReady("F") and distOK(d, CFG.Gates.F.lo, CFG.Gates.F.hi) and ((nowT - (self.lastFDUser or -1e9)) >= 45.0)

    if canS then
        table.insert(candidates, {name = "S", bias = 0.55, exec = function()
            self:_requestSideDash(r.hrp, "off", r); return true
        end})
    end
    if canB then
        local bBias = 0.35
        if not canS then bBias += 0.35 end
        if r.style and r.style.aggr>6 and (nowT - (r.style.lastAtk or 0)) < 0.35 and d>=5 and d<=14 and not canS then
            bBias += 0.8
        end
        table.insert(candidates, {name = "B", bias = bBias, exec = function()
            self:_requestBackDash(r.hrp, "off", r); return true
        end})
    end
    if canF then
        local fBias = -0.60
        if d > 50 then fBias += 0.35 end
        table.insert(candidates, {name = "F", bias = fBias, exec = function()
            self:_requestForwardDash(r); return true
        end})
    end
    if #candidates == 0 then return end

    if self:_hasRecentStun(r) then
        for _,cand in ipairs(candidates) do
            if cand.name == "S" then cand.bias = (cand.bias or 0) + 0.8 end
        end
    end
    if d > 60 then
        for _,cand in ipairs(candidates) do
            if cand.name == "S" then cand.bias = (cand.bias or 0) + 0.5 end
        end
    end

    local pick = self:choose_action(ctx, candidates, self.bandit.epsilon)
    if pick and pick.exec then
        if pick.exec() ~= false then
            self.lastDashTime = os.clock() -- NEW
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
            if not self.run or not r.model.Parent then abort=true break end

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
                    w = math.min(w, CFG.M1MaxGap or 0.60) -- clamp gap
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

                    -- if close after SHOVE, arm dash-extend window (~0.60s)
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
                        -- arm longer dash-extend after a real Upper hit (combo confirm)
                        self.allowDashExtend = os.clock() + 0.90
                        -- prefer F/S only if gates make sense (unchanged)
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
                        -- whiffed Upper: do NOT chain into immediate Upper again; reposition lightly
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
                    -- handled by allowDashExtend gate at dash tail
                end
                task.wait(st.wait or CFG.InputTap)

            elseif st.kind=="wait" then
                task.wait(st.wait or CFG.InputTap)
            end
        end

        if abort or not self.run then
            self.gui:setC("Combo: none"); self.curCombo=nil; self.actThread=nil; return
        end

        -- opportunistic finisher on freeze (unchanged)
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

    -- Favor: ragdoll (≤8), or very close (≤ ~SpaceMin+1.5) with no evasive or behind
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
    strafe=self.strafe
    if r.dist<CFG.SpaceMin*0.5 then
        forward=-0.4
    elseif r.dist<CFG.SpaceMin then
        forward=0.65
    end
    self:setInput(forward,strafe)
    self:maybeDash(r)
end

function Bot:approachFarTarget(r:Enemy)
    if not self.run then return end
    if not (r and r.hrp and self.rp) then return end
    local d = r.dist or math.huge
    if d < 60 then return end

    -- Run straight with slight weave and keep hard aim while far
    self:aimAt(r.hrp)
    local t = os.clock()
    local weave = ((math.floor(t*3)%2)==0) and 0.55 or -0.55
    self:setInput(1, weave)

    -- Prefer Side(off) spam to close safely; F only on 30s limiter
    if self:dashReady("S") then
        self:tryDash("S", r.hrp, "off", r)
    elseif self:dashReady("F") and (t - (self.lastFDUser or -1e9) >= 45.0) then
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

    -- Allow combos if we just stunned them, or we recently tapped M1,
    -- or we’ve been idle a bit but are in range.
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
            if s.def>4 and hasTrait(c,"guardbreak") then sBias+=0.45 end
            if s.aggr>5 and hasTrait(c,"burst") then sBias+=0.25 end
            if s.aggr<3 and hasTrait(c,"pressure") then sBias+=0.20 end
            if s.ev>5 and not c.reqNoEv then sBias-=0.2 end

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
    if not tgt or not tgt.hrp then self:setInput(0,0); return end
    self:alignCam(); self:aimAt(tgt.hrp)
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
            forward = 0.85
        else
            forward = 0.25
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

    if d<=CFG.M1Range and nowT-self.lastM1>CFG.M1Min*0.75 and not ragdolled and not self.isAttacking and not self.blocking then
        table.insert(skillCandidates, {
            name = "M1",
            bias = 0.65, -- was ~0.4; higher = more jab priority
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
            if tgt.style and (nowT - (tgt.style.lastBlk or 0)) < 0.3 then bias += 0.5 end
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
            if tgt.hp <= CFG.SnipeHP then npBias += 0.4 end
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

        if slotReady(SLOT.Upper)
           and self:_upperUseOK(tgt)
           and (nowT - (self.lastDashTime or 0) >= 0.45)    -- NEW: no dash->upper
           and (self.m1ChainCount >= 1 or ragdolled)        -- NEW: prefer after at least one M1
        then
            local upBias = ragdolled and 0.50 or 0.08       -- lower default bias
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


function Bot:updateAttacker()
    if not self.liveChar then self.liveChar = self.live and self.live:FindFirstChild(LP.Name) or nil end
    if not self.liveChar then return end
    local a=self.liveChar:GetAttribute("LastHit") or self.liveChar:GetAttribute("lastHit")
    if typeof(a)=="string" and a~="" then self.lastAttacker=a end
end

function Bot:start()
    local h=self.hum
    if not h or h.Health<=0 then self.gui:setS("Status: waiting spawn"); return end
    if self.run then self.gui:setS("Status: running"); return end
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
    self.ls:flush()
    self:_ensureCharacterBindings()
    if not(self.char and self.hum and self.rp) then return end
    if self.hum.Health<=0 then self.run=false return end

    if not self.run then
        self:_autoResumeTick()
    end


    self:_finalizeActionRecords(false)


    if self.evTimer>0 then self.evTimer -= dt; if self.evTimer<=0 then self.evTimer=0; self.evReady=true end end
    self.gui:setE(self.evReady and "Evasive: ready" or ("Evasive: "..string.format("%.1fs",math.max(0,self.evTimer))))

    self:updateEnemies(dt); self:updateAttacker()
    local nowT=os.clock()
    if self.lastAttacker and nowT-self.lastAtkTime>3 then self.lastAttacker=nil; self.lastDmg=0 end

    local tgt=self:selectTarget()
    self.currentTarget = tgt
    self.lastTargetDist = tgt and tgt.dist or nil
    if tgt then
        self:approachFarTarget(tgt)
    end
    if not tgt then
        self.gui:setT("Target: none")
        if not self.run then self:clearMove() end
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
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


    if self.shouldPanic then if self:attemptEvasive("panic") then self.shouldPanic=false end end
    if self:shouldEvasive(tgt) then if self:attemptEvasive("react") then self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S")); return end end


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
    -- If we've tried 2 quick M1s and didn't secure a stun, bail out smartly.
    do
        local sinceM1 = nowT - (self.lastM1 or 0)
        if tgt and not self.inDash and not self.blocking
           and self.m1ChainCount >= 2
           and sinceM1 <= (CFG.M1MaxGap * 1.3)
           and not self:_hasRecentStun(tgt) then
            -- Prefer a backward disengage if very close; otherwise defensive side or block.
            if self:dashReady("B") and tgt.dist <= (CFG.SpaceMin + 2.0) then
                self:tryDash("B", tgt.hrp, "off", tgt)
            elseif self:dashReady("S") then
                self:tryDash("S", tgt.hrp, "def", tgt) -- defensive (perpendicular) side step
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



local AI = {
    version = "1.0",
    _bot = nil,
}


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


function AI.Decide(input)
    local bot = AI._bot
    if not bot then return "idle" end

    local tgt = (input and input.target) or bot.currentTarget or bot:selectTarget()
    local ctx = bot:_ctxKey(tgt)
    local d   = (tgt and tgt.dist) or math.huge
    local nowT = os.clock()

    local candidates = {}
    local function add(c) table.insert(candidates, c) end

    -- Dashes (gated by your CFG + CDs)
    if tgt and bot:dashReady("S") and d>=CFG.Gates.S.lo and d<=CFG.Gates.S.hi then
        add({name="S", bias=0.40, exec=function() return bot:tryDash("S", tgt.hrp, "off", tgt) end})
    end
    if tgt and bot:dashReady("B") and d>=CFG.Gates.B.lo and d<=CFG.Gates.B.hi then
        add({name="B", bias=0.20, exec=function() return bot:tryDash("B", tgt.hrp, "off", tgt) end})
    end
    if tgt and bot:dashReady("F")
       and d>=CFG.Gates.F.lo and d<=CFG.Gates.F.hi
       and (os.clock() - (bot.lastFDUser or -1e9) >= 45.0) then
        add({name="F", bias=-0.20, exec=function() return bot:tryDash("F", tgt.hrp, "off", tgt) end})
    end

    -- Skills/M1 (same gates you already use)
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


function AI.OnEvent(eventType, data)
    local bot = AI._bot
    if not bot then return end
    data = data or {}

    if eventType == "player_spotted" and typeof(data.model) == "Instance" then
        bot:addEnemy(data.model)

    elseif eventType == "damage_dealt" then
        bot:_recordDamageEvent(data.target, tonumber(data.amount) or 0, true, {dist=data.dist})

    elseif eventType == "damage_taken" then
        bot:_recordDamageEvent(nil, tonumber(data.amount) or 0, false, {dist=data.dist})

    elseif eventType == "kill" then
        bot.lifeStats.kills = (bot.lifeStats.kills or 0) + 1

    elseif eventType == "death" then
        bot:_endLife()

    elseif eventType == "stun" and data.target then
        local rec = bot:getEnemyByName(data.target)
        if rec then bot:_noteStun(rec, tostring(data.animTail or "manual")) end

    elseif eventType == "save" then
        bot:savePolicy(); bot.ls:flush()

    elseif eventType == "load" then
        bot:loadPolicy()
    end
end

function AI.Save() local b=AI._bot if b then b:savePolicy(); b.ls:flush() end end
function AI.Load() local b=AI._bot if b then b:loadPolicy() end end
function AI.Start() local b=AI._bot if b then b:start() end end
function AI.Stop()  local b=AI._bot if b then b:stop()  end end

-- For exporting the learned state (policy + meta + combo stats) as JSON
function AI.ExportMemory()
    local b = AI._bot
    if not b then return "{}" end
    local pkt = { policy=b.policy, meta=b.bandit.meta, combos=b.ls and b.ls.data and b.ls.data.combos or {} }
    return HttpService:JSONEncode(pkt)
end


AI.Init({autorun = false})
return AI

