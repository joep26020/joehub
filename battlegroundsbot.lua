

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VIM         = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()


local CFG = {
    CharKey = "saitama",


    ComboDist      = 7.8,
    SpaceMin       = 5.2,
    SpaceMax       = 9.5,
    CloseUseRange  = 8.0,
    SnipeRange     = 60.0,
    SnipeHP        = 10,


    InputTap = 0.045,
    TapS     = 0.12,
    TapM     = 0.22,
    M1Min    = 0.25,
    M1Rand   = 0.10,
    M1Range  = 5.0,


    Cooldown = { FDash=3.0, BDash=5.0, Side=0.80 },
    EvasiveCD = 30,


    Gates = {
        F = { lo=18.0, hi=34.0 },
        S = { lo= 5.0, hi=20.0 },
        B = { lo= 5.0, hi=40.0 },
    },


    Dash = {
        KeyQ        = Enum.KeyCode.Q,
        HoldQ       = 0.12,
        RefaceTail  = 0.50,

        FWindow     = 0.80,
        BWindow     = 1.25,
        SWindow     = 0.50,

        OrbitTrigger   = 2.0,
        OrbitDur       = 0.30,
        BackClose      = 4.0,
        SideOffLock    = 3.5,
        PreEndBackFace = 0.25,


        Anim = {
            fdash = { "10479335397" },
            bdash = { "10491993682" },
            side  = { "10480796021", "10480793962" },
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


    MaxNoAtk = 1.6,
    ForceAtk = 3.0,
    CloseGain = 3.0, CloseWindow = 5.0, FarChase = 50.0,


    Data  = "bgbot",
    Flush = 2.0,

    BlockAnimId = "rbxassetid://10470389827",
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

local function m1Gap() return CFG.M1Min + math.random() * CFG.M1Rand end


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
    self.rules = text(f,"R","FDash[18..34] • SideOff relock≤3.5 • OB bias • Block>5s→force-unblock • M1 chain≈0.25–0.35s", UDim2.new(1,-20,0,20), UDim2.new(0,10,0,204), 12, false)

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
        name="M1(1-2)->Shove->Side(off)->M1(HOLD)",
        min=0, max=10, risk=0.25,
        steps={
            {kind="aim"},
            {kind="press",action="Shove",wait=0.10},
            {kind="dash",action="side",dir="off",wait=0.06},
            {kind="press",action="M1HOLD",hold=CFG.TapM,wait=m1Gap()},
        },
        traits={"pressure","guardbreak"}
    },

    {
        id="sai_m1cp_np",
        name="M1x2>CP>M1>NP",
        min=0, max=8, risk=0.35,
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
}


local Bot={}; Bot.__index=Bot
type Enemy = {
    model:Model, hum:Humanoid?, hrp:BasePart?, dist:number,
    hasEv:boolean, lastEv:number, score:number, ply:Player?, hp:number,
    style:{aggr:number, def:number, ev:number, lastAtk:number, lastBlk:number, lastDash:number},
    recent:number,
    aRecent:number,
    active:{[AnimationTrack]:{id:string,start:number,wasBlk:boolean,hit:boolean}},
    cons:{RBXScriptConnection},
    aggro:number,
}

function Bot.new()
    local self=setmetatable({},Bot)


    self.gui=GUI.new()
    self.ls=LS.new()
    self.bridge=Bridge.new()


    self.enemies = {} :: {[Model]:Enemy}
    self.run=false; self.state="idle"; self.actThread=nil
    self.char=nil; self.hum=nil; self.rp=nil; self.alive=false

    self.evReady=true; self.evTimer=0; self.shouldPanic=false
    self.lastFD=0; self.lastBD=0; self.lastSide=0
    self.lastM1=0; self.lastSkill=0; self.lastSnipe=0
    self.lastAttacker=nil; self.lastAtkTime=0; self.lastDmg=0; self.lastHP=0

    self.blocking=false; self.blockUntil=0; self.blockThread=nil; self.lastBlockTime=0; self.blockCooldown=0
    self.blockStartTime=nil

    self.moveKeys={ [Enum.KeyCode.W]=false,[Enum.KeyCode.A]=false,[Enum.KeyCode.S]=false,[Enum.KeyCode.D]=false }
    self.strafe=0; self.lastStrafe=0

    self.live=workspace:WaitForChild("Live"); self.liveChar=self.live:FindFirstChild(LP.Name); self.liveConn=nil


    self.myAnims={}; self.myHumConns={}
    self.attackActive={}
    self.isAttacking=false
    self.isM1ing=false
    self.m1ChainCount=0
    self.lastM1Target=nil
    self.lastM1AttemptTime=0

    self.lastAttempt=os.clock(); self.urgency=0
    self.arcUntil=0; self.closeT=os.clock(); self.closeD=math.huge
    self.pendingResume=false


    self.inDash=false
    self.dashOrientThread=nil
    self.dashPending = nil


    self.sticky=nil
    self.stickyT=0
    self.stickyHold=1.6
    self.switchMargin=25.0
    self.lastStunTarget=nil


    self.stillTimer=0


    self.isUlt=false
    self.lastUltCheck=0

    self.gui.startB.MouseButton1Click:Connect(function() if getgenv().BattlegroundsBot then getgenv().BattlegroundsBot:start() end end)
    self.gui.stopB.MouseButton1Click:Connect(function() if getgenv().BattlegroundsBot then getgenv().BattlegroundsBot:stop() end end)
    self.gui.exitB.MouseButton1Click:Connect(function() if getgenv().BattlegroundsBot then getgenv().BattlegroundsBot:exit() end end)

    self.gui:setS("Status: idle"); self.gui:setT("Target: none"); self.gui:setC("Combo: none"); self.gui:setE("Evasive: unknown")
    self.gui:updateCombos(self.ls.data); self.gui:updateCDs(0,0,0)

    self:connectChar(LP.Character or LP.CharacterAdded:Wait())
    LP.CharacterAdded:Connect(function(c) self:connectChar(c) end)

    self:attachLive(self.liveChar)
    for _,m in ipairs(self.live:GetChildren()) do self:addEnemy(m) end
    self.live.ChildAdded:Connect(function(m) if m.Name==LP.Name then self:attachLive(m) else self:addEnemy(m) end end)
    self.live.ChildRemoved:Connect(function(m)
        local r=self.enemies[m]; if r then for _,c in ipairs(r.cons) do pcall(function() c:Disconnect() end) end self.enemies[m]=nil end
        if m==self.liveChar then self:attachLive(nil) end
    end)

    self.hb=RunService.Heartbeat:Connect(function(dt) self:update(dt) end)
    return self
end

function Bot:destroy()
    if self.hb then self.hb:Disconnect() end
    if self.liveConn then self.liveConn:Disconnect() end
    for _,c in ipairs(self.myHumConns) do pcall(function() c:Disconnect() end) end
    self:clearMove()
    if self.gui then self.gui:destroy() end
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

function Bot:_beginDashOrientation(kind:string, tr:AnimationTrack, style:("off"|"def"), tHRP:BasePart?)
    if self.inDash or not self.hum or not self.rp then return end
    self.inDash=true

    local function canTurn()
        if self.hum and self.hum:GetState()==Enum.HumanoidStateType.FallingDown then return false end
        return true
    end
    local function faceToward(pos:Vector3)
        if not canTurn() then return end
        local here=self.rp.Position; local to=flat(pos-here); if to.Magnitude<1e-3 then return end
        self.rp.CFrame=CFrame.lookAt(here, here+to.Unit)
    end
    local function faceAwayFrom(pos:Vector3)
        if not canTurn() then return end
        local here=self.rp.Position; local to=flat(pos-here); if to.Magnitude<1e-3 then return end
        self.rp.CFrame=CFrame.lookAt(here, here+(-to.Unit))
    end
    local function facePerp(toU:Vector3, cw:boolean)
        if not canTurn() then return end
        local perp = cw and Vector3.new(toU.Z,0,-toU.X) or Vector3.new(-toU.Z,0,toU.X)
        self.rp.CFrame = CFrame.lookAt(self.rp.Position, self.rp.Position + perp.Unit)
    end

    local t0=os.clock()
    local length = (tr.Length and tr.Length>0) and tr.Length or (
        kind=="fdash" and CFG.Dash.FWindow or kind=="bdash" and CFG.Dash.BWindow or CFG.Dash.SWindow
    )
    local orbitCW = (math.random()<0.5)
    local didOrbit=false
    local orbitStart=0.0

    local stopped=false
    tr.Stopped:Connect(function() stopped=true end)

    self.dashOrientThread = task.spawn(function()
        while not stopped and os.clock()-t0 <= length do
            if not (self.run and self.hum and self.hum.Health>0 and self.rp) then break end
            local tgt = tHRP
            if not tgt or not tgt.Parent then
                local pick=self:selectTarget()
                tgt = pick and pick.hrp or nil
            end
            if tgt then
                local to = flat(tgt.Position - self.rp.Position)
                if to.Magnitude>1e-3 then
                    local toU = to.Unit
                    if kind=="fdash" then
                        if style=="off" then
                            if (not didOrbit) then
                                faceToward(tgt.Position)
                                if to.Magnitude <= CFG.Dash.OrbitTrigger then
                                    didOrbit=true; orbitStart=os.clock()
                                end
                            else
                                local elapsed = os.clock()-orbitStart
                                if elapsed <= CFG.Dash.OrbitDur then facePerp(toU, orbitCW)
                                else faceToward(tgt.Position) end
                            end
                        else
                            faceAwayFrom(tgt.Position)
                        end
                    elseif kind=="bdash" then
                        if style=="off" then
                            local timeLeft = (t0+length) - os.clock()
                            if to.Magnitude <= CFG.Dash.BackClose then
                                facePerp(toU, orbitCW)
                            else
                                faceAwayFrom(tgt.Position)
                            end
                            if timeLeft <= CFG.Dash.PreEndBackFace then faceToward(tgt.Position) end
                        else
                            faceToward(tgt.Position)
                        end
                    else
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
        local pick=self:selectTarget()
        local tHRP2 = (tHRP and tHRP.Parent) and tHRP or (pick and pick.hrp)
        if tHRP2 then
            if self.hum and self.hum.Health>0 and self.hum:GetState()~=Enum.HumanoidStateType.FallingDown then
                self.rp.CFrame = CFrame.lookAt(self.rp.Position, Vector3.new(tHRP2.Position.X, self.rp.Position.Y, tHRP2.Position.Z))
            end
        end
        self.inDash=false
        self.dashOrientThread=nil
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
                if self.dashPending and self.dashPending.kind==kind then
                    style = self.dashPending.style
                    tHRP  = self.dashPending.tHRP
                    self.dashPending = nil
                else
                    local tgt = self:selectTarget()
                    tHRP = tgt and tgt.hrp or nil
                    style = "off"
                end
                self:_beginDashOrientation(kind, tr, style, tHRP)
            end


            if isAttackTail(tail) then
                self.attackActive[tr]=true
                self.isAttacking=true
                self.lastAttackTime=os.clock()
                if isM1Tail(tail) then

                    if os.clock() - self.lastM1 > 0.8 then
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
    self.char=char; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5); if not hum then return end
    self.hum=hum; self.rp=char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5)
    self.alive=hum.Health>0; self.lastHP=hum.Health; self:_hookMine(hum)

    hum.Died:Connect(function()
        self.alive=false; self.gui:setS("Status: dead"); self.gui:setT("Target: none"); self.run=false; self.pendingResume=true
        task.spawn(function()
            local liveModel:Model? = nil
            while liveModel==nil do local lf=workspace:FindFirstChild("Live"); if lf then liveModel=lf:FindFirstChild(LP.Name) end; task.wait(0.25) end
            local ch=LP.Character or LP.CharacterAdded:Wait()
            local h2=ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid",5)
            if h2 then repeat task.wait(0.15) until h2.Health>0; if self.pendingResume then self.pendingResume=false; self:start() end end
        end)
    end)

    hum.HealthChanged:Connect(function(hp)
        local dmg=self.lastHP - hp
        if dmg>0 then
            self.lastDmg=dmg; self.lastAtkTime=os.clock(); self:updateAttacker()
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
    if self.liveConn then self.liveConn:Disconnect() end; self.liveChar=model; if not model then return end
    local function chk(d:Instance) if d.Name=="RagdollCancel" then self:onSelfEvasive() end end
    for _,d in ipairs(model:GetDescendants()) do chk(d) end
    self.liveConn=model.DescendantAdded:Connect(chk)
end


function Bot:setKey(k:Enum.KeyCode,down:boolean)
    if self.moveKeys[k]==down then return end
    self.moveKeys[k]=down; VIM:SendKeyEvent(down,k,false,game)
end
function Bot:clearMove() for k,down in pairs(self.moveKeys) do if down then VIM:SendKeyEvent(false,k,false,game); self.moveKeys[k]=false end end end
function Bot:setInput(f:number?,r:number?) local th=0.15; f=f or 0; r=r or 0
    self:setKey(Enum.KeyCode.W, f>th); self:setKey(Enum.KeyCode.S, f<-th); self:setKey(Enum.KeyCode.D, r>th); self:setKey(Enum.KeyCode.A, r<-th)
end
function Bot:alignCam()
    local cam=workspace.CurrentCamera; if not(cam and self.rp) then return end
    local cp=cam.CFrame.Position; local look=self.rp.CFrame.LookVector; local flatv=Vector3.new(look.X,0,look.Z); if flatv.Magnitude<1e-3 then return end
    local tgt=cp+flatv.Unit; cam.CFrame=CFrame.new(cp, Vector3.new(tgt.X,cp.Y,tgt.Z))
end


function Bot:aimAt(tHRP:BasePart?)
    if not tHRP or not self.rp then return end
    if self.inDash then return end
    if self.hum and self.hum:GetState()==Enum.HumanoidStateType.FallingDown then
        if self.hum then self.hum.AutoRotate=true end
        return
    end
    if not self.bridge:tryAim(self.rp,tHRP) then aimCFrame(self.rp,tHRP) end
    if self.hum then self.hum.AutoRotate=false end
end


local function now() return os.clock() end
local function distOK(d:number, lo:number, hi:number) return d>=lo and d<=hi end
local FALL_STATES = {
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true,
}

function Bot:_targetRagdolled(r:Enemy?):boolean
    if not r or not r.hum then return false end
    local state = r.hum:GetState()
    if FALL_STATES[state] then return true end
    return false
end

function Bot:_registerM1Attempt(r:Enemy?)
    self.lastM1Target = r
    self.lastM1AttemptTime = os.clock()
end

function Bot:_noteStun(r:Enemy, tail:string)
    local nowT = os.clock()
    r.lastStun = nowT
    local byMe = (self.lastM1Target==r) and ((nowT - (self.lastM1AttemptTime or 0)) <= 0.7)
    local gain = byMe and 0.85 or 0.35
    r.stunScore = math.min(1.6, (r.stunScore or 0) + gain)
    r.lastStunAnim = tail
    self.lastStunTarget = r
    self.ls:log("stun_detected", {enemy = r.model.Name, anim = tail, score = r.stunScore, byMe = byMe})
end

function Bot:_hasRecentStun(r:Enemy?):boolean
    if not r then return false end
    local last = r.lastStun or 0
    if last == 0 then return false end
    return (os.clock() - last) <= 0.75 and (r.stunScore or 0) >= 0.35
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
    local t = now()
    if which=="F" then return math.max(0, CFG.Cooldown.FDash - (t - self.lastFD)) end
    if which=="B" then return math.max(0, CFG.Cooldown.BDash - (t - self.lastBD)) end
    return math.max(0, CFG.Cooldown.Side - (t - self.lastSide))
end


local function holdQ(d:number?) pressKey(CFG.Dash.KeyQ,true); task.wait(d or CFG.Dash.HoldQ); pressKey(CFG.Dash.KeyQ,false) end

function Bot:_requestSideDash(r:Enemy)
    if not (self.rp and r and r.hrp) then return end
    local d = r.dist
    local g = CFG.Gates.S
    if not distOK(d, g.lo, g.hi) then return end
    if self:_cdLeft("S")>0 then return end
    self.lastSide=now()

    local to = flat(r.hrp.Position - self.rp.Position)
    if to.Magnitude<1e-3 then to = flat(self.rp.CFrame.LookVector) end
    local toU = to.Unit
    local right = flat(self.rp.CFrame.RightVector).Unit
    local dot = right.X*toU.X + right.Z*toU.Z
    local towardKey = (dot >= 0) and Enum.KeyCode.D or Enum.KeyCode.A

    self.dashPending = {kind="side", style="off", tHRP=r.hrp}
    self:aimAt(r.hrp)
    local wState=self.moveKeys[Enum.KeyCode.W]
    local sideState=self.moveKeys[towardKey]
    pressKey(Enum.KeyCode.W,true)
    pressKey(towardKey,true)
    task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)
    pressKey(towardKey,false)
    pressKey(Enum.KeyCode.W,false)
    self.moveKeys[Enum.KeyCode.W]=false
    self.moveKeys[towardKey]=false
    if wState then self:setKey(Enum.KeyCode.W,true) end
    if sideState then self:setKey(towardKey,true) end
end

function Bot:_requestForwardDash(r:Enemy)
    if not (self.rp and r and r.hrp) then return end
    local d = r.dist
    local g = CFG.Gates.F
    if not distOK(d, g.lo, g.hi) then return end
    if self:_cdLeft("F")>0 then return end
    self.lastFD=now()

    self.dashPending = {kind="fdash", style="off", tHRP=r.hrp}
    pressKey(Enum.KeyCode.W,true); task.wait(0.02); holdQ(CFG.Dash.HoldQ); pressKey(Enum.KeyCode.W,false)
end

function Bot:_requestBackDash(r:Enemy)
    if not (self.rp and r and r.hrp) then return end
    local d = r.dist
    local g = CFG.Gates.B
    if not distOK(d, g.lo, g.hi) then return end
    if self:_cdLeft("B")>0 then return end
    self.lastBD=now()

    self.dashPending = {kind="bdash", style="off", tHRP=r.hrp}
    pressKey(Enum.KeyCode.S,true); task.wait(0.02); holdQ(CFG.Dash.HoldQ); pressKey(Enum.KeyCode.S,false)
end


function Bot:_forceUnblockNow()
    local b=CFG.Bind.Block; if not b or b.t~="Key" then return end
    VIM:SendKeyEvent(false,b.k,false,game); task.wait(0.02)
    local live=self.liveChar
    for _=1,2 do
        if not live then break end
        local blk=live:GetAttribute("Blocking") or live:GetAttribute("IsBlocking") or live:GetAttribute("Block")
        if not attrOn(blk) then break end
        VIM:SendKeyEvent(true,b.k,false,game); task.wait(0.04); VIM:SendKeyEvent(false,b.k,false,game); task.wait(0.02)
    end
end
function Bot:block(dur:number?, target:Enemy?)
    if os.clock() < self.blockCooldown then return end
    local b=CFG.Bind.Block; if not b or b.t~="Key" then return end
    local hold = math.clamp(dur or 0.35, 0.20, 0.55)
    if self.blocking and self.blockThread then return end
    self.blocking=true
    self.blockStartTime=os.clock()
    if target and target.model then
        local aid=self:_animId(target)
        local threat = aid and self.ls:threat(aid) or 0
        self.ls:log("block", {enemy=target.model.Name, anim=aid, threat=threat, dur=hold})
    end
    self.blockThread = task.spawn(function()
        VIM:SendKeyEvent(true,b.k,false,game)
        local tEnd=os.clock()+hold
        while os.clock()<tEnd and self.run and self.alive do task.wait(0.03) end
        VIM:SendKeyEvent(false,b.k,false,game)
        self:_forceUnblockNow()
        self.blocking=false; self.blockThread=nil
        self.blockStartTime=nil
        self.lastBlockTime=os.clock()
        self.blockCooldown = self.lastBlockTime + 0.35
    end)
end


local function sidTail(id:string?):string if not id then return "unk" end local n=id:match("(%d+)$"); return n or id end

function Bot:addEnemy(m:Model)
    if m:GetAttribute("NPC") or m.Name==LP.Name then return end
    local r:Enemy = {
        model=m, hum=m:FindFirstChildOfClass("Humanoid"), hrp=m:FindFirstChild("HumanoidRootPart"),
        dist=math.huge, hasEv=true, lastEv=0, score=0, ply=Players:FindFirstChild(m.Name), hp=100,
        style={aggr=0,def=0,ev=0,lastAtk=0,lastBlk=0,lastDash=0}, recent=0, aRecent=0, active={}, cons={}, aggro=0
    }
    if r.hum then
        r.hp=r.hum.Health
        table.insert(r.cons, r.hum:GetPropertyChangedSignal("Health"):Connect(function()
            if not r.hum then return end
            local nh=r.hum.Health; local delta=math.max(0,(r.hp or nh)-nh)
            if delta>0 then
                local lh = r.model:GetAttribute("LastHit") or r.model:GetAttribute("lastHit")
                if lh==LP.Name then
                    local myA=self:_myAnimId()
                    if myA then self.ls:deal(myA, delta) end
                    r.aRecent = (r.aRecent or 0)*0.5 + delta
                end
            end
            r.hp=nh
        end))
    end
    local function onDesc(d:Instance) if d.Name=="RagdollCancel" then r.lastEv=os.clock(); r.hasEv=false; r.style.ev=math.clamp(r.style.ev+2,0,8); r.style.lastDash=os.clock() end end
    for _,d in ipairs(m:GetDescendants()) do onDesc(d) end
    table.insert(r.cons, m.DescendantAdded:Connect(onDesc))
    local function hookAnimator(an:Animator)
        table.insert(r.cons, an.AnimationPlayed:Connect(function(tr)
            local id=tr.Animation and tostring(tr.Animation.AnimationId) or "unknown"
            local tail=sidTail(id)
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
    if r.hum then
        local an=r.hum:FindFirstChildOfClass("Animator")
        if an then hookAnimator(an) else
            table.insert(r.cons, r.hum.ChildAdded:Connect(function(ch) if ch:IsA("Animator") then hookAnimator(ch) end end))
        end
    end
    table.insert(r.cons, m.AncestryChanged:Connect(function(_,p)
        if p==nil then for _,c in ipairs(r.cons) do pcall(function() c:Disconnect() end) end self.enemies[m]=nil end
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

    local best,bs=nil,-1e9
    for _,r in pairs(self.enemies) do
        if r.model.Parent and r.hum and r.hum.Health>0 then
            if r.score>bs then bs=r.score; best=r end
        end
    end
    if not best then return nil end
    local nowT=os.clock()
    if self.sticky and self.sticky.model.Parent and (nowT - self.stickyT) < self.stickyHold then

        return self.sticky
    end
    if self.sticky and self.sticky.model.Parent then
        local curScore = self.sticky.score or -1e9
        if bs > (curScore + self.switchMargin) then
            self.sticky = best; self.stickyT = nowT; return best
        else
            return self.sticky
        end
    else
        self.sticky = best; self.stickyT = nowT; return best
    end
end


function Bot:blockDur(r:Enemy?):number
    local base=0.35
    if not r then return base end
    local st=r.style; if st.aggr>6 then base+=0.12 end
    if self.lastAttacker==r.model.Name and os.clock()-self.lastAtkTime<0.55 then base+=0.12 end
    local aid=nil; local best=-1; for _,slot in pairs(r.active) do if slot.start>best then best=slot.start; aid=slot.id end end
    if aid then local th=self.ls:threat(aid); if th>1.0 then base+=0.10 end; if th>2.0 then base+=0.10 end end
    return math.clamp(base,0.25,0.55)
end

function Bot:shouldBlock(r:Enemy?):boolean
    if not r then return false end
    if self.blocking then return true end
    if self.isAttacking then return false end
    if self:_hasRecentStun(r) then return false end
    local nowT=os.clock()
    if nowT<self.blockCooldown then return false end
    if nowT-self.lastBlockTime<0.22 then return false end
    if r.dist>CFG.ComboDist+4 then return false end
    local aid=nil; local best=-1; for _,slot in pairs(r.active) do if slot.start>best then best=slot.start; aid=slot.id end end
    if aid then
        local threat=self.ls:threat(aid)
        if threat>=1.5 then return true end
        if threat>=1.0 and nowT-(r.style.lastAtk or 0)<0.65 then return true end
    end
    local st=r.style
    if st.aggr>6 and nowT-st.lastAtk<0.50 then return true end
    if st.aggr>4 and nowT-st.lastAtk<0.70 and r.dist<=CFG.ComboDist then return true end
    if self.lastAttacker==r.model.Name and nowT-self.lastAtkTime<0.75 then return true end
    if st.lastAtk>0 and nowT-st.lastAtk<0.30 and r.dist<CFG.ComboDist then return true end
    if st.def>4 and nowT-st.lastBlk>1.0 and r.dist<=CFG.ComboDist then return true end
    return false
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
    if self.blocking and self.blockThread then self.blockUntil=os.clock(); task.wait(0.05) end
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

    if name=="M1" or name=="M1HOLD" then
        pressMouse(Enum.UserInputType.MouseButton1, hold or CFG.InputTap)
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
            return true
        end
        return false
    end
    return false
end


function Bot:maybeDash(r:Enemy)
    if not r or not r.hrp then return end
    if self.inDash then return end

    local d = r.dist
    local gF,gS,gB = CFG.Gates.F, CFG.Gates.S, CFG.Gates.B
    local canF = distOK(d,gF.lo,gF.hi) and (self:_cdLeft("F")==0)
    local canS = distOK(d,gS.lo,gS.hi) and (self:_cdLeft("S")==0)
    local canB = distOK(d,gB.lo,gB.hi) and (self:_cdLeft("B")==0)

    if canS and math.random()<0.75 then self:_requestSideDash(r); return end
    if canF and math.random()<0.55 then self:_requestForwardDash(r); return end
    if canB and math.random()<0.35 then self:_requestBackDash(r); return end

    if canS then self:_requestSideDash(r); return end
    if canF then self:_requestForwardDash(r); return end
    if canB then self:_requestBackDash(r); return end
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
                    self.lastM1=os.clock()
                    task.wait(st.wait or m1Gap())
                    waitForStun=true
                elseif st.action=="M1HOLD" then
                    if self:_targetRagdolled(r) then abort=true break end
                    if (r.dist or math.huge) > CFG.M1Range then
                        if not self:_waitForRange(r, CFG.M1Range, 0.45) then abort=true break end
                    end
                    self:_registerM1Attempt(r)
                    self:_pressAction("M1HOLD", st.hold)
                    self.lastM1=os.clock()
                    task.wait(st.wait or m1Gap())
                    waitForStun=true
                elseif st.action=="Upper" then
                    local y0 = (r.hrp and r.hrp.Position.Y) or 0

                    local ok = true
                    if slotReady(SLOT.Upper) then
                        if (r.dist<=CFG.CloseUseRange+1.0) or (self:_upperUseOK(r)) then
                            self:_pressAction("Upper", st.hold)
                        else
                            ok=false
                        end
                    else ok=false end
                    task.wait(st.wait or 0.26)
                    if ok and self:_upperSucceeded(r, y0) then
                        local fired=false
                        if distOK(r.dist, CFG.Gates.F.lo, CFG.Gates.F.hi) and probTake(0.60) then
                            self:_requestForwardDash(r); fired=true
                        end
                        if not fired and distOK(r.dist, CFG.Gates.S.lo, CFG.Gates.S.hi) and probTake(0.25) then
                            self:_requestSideDash(r); fired=true
                        end
                        if not fired and distOK(r.dist, CFG.Gates.B.lo, CFG.Gates.B.hi) then
                            self:_requestBackDash(r)
                        end
                    else

                        if distOK(r.dist, CFG.Gates.S.lo, CFG.Gates.S.hi) then
                            self:_requestSideDash(r)
                        elseif distOK(r.dist, CFG.Gates.B.lo, CFG.Gates.B.hi) then
                            self:_requestBackDash(r)
                        end
                    end
                else

                    self:_pressAction(st.action, st.hold)
                    task.wait(st.wait or CFG.InputTap)
                end
            elseif st.kind=="dash" and st.action then
                if st.action=="side" then
                    self:_requestSideDash(r)
                elseif st.action=="fdash" then
                    self:_requestForwardDash(r)
                elseif st.action=="bdash" then
                    self:_requestBackDash(r)
                elseif st.action=="auto_after_upper" then

                end
                task.wait(st.wait or CFG.InputTap)
            elseif st.kind=="wait" then
                task.wait(st.wait or CFG.InputTap)
            end
        end

        if abort or not self.run then self.gui:setC("Combo: none"); self.curCombo=nil; self.actThread=nil; return end


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

function Bot:_upperUseOK(r:Enemy):boolean

    local closeOK = r.dist <= (CFG.SpaceMin + 2.0)
    local noEv    = not r.hasEv
    local ragdoll = r.hum and (r.hum:GetState()==Enum.HumanoidStateType.FallingDown or r.hum:GetState()==Enum.HumanoidStateType.PlatformStanding)
    return closeOK and (noEv or ragdoll)
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

function Bot:_shouldStartCombo(tgt:Enemy):boolean
    if not tgt or not tgt.hrp then return false end
    if os.clock() - (self.lastComboTry or 0) < 0.50 then return false end
    if tgt.dist > CFG.ComboDist then return false end
    if self.blocking then return false end
    if tgt.style.lastBlk>0 and os.clock()-tgt.style.lastBlk<0.28 then return false end
    if not self.hum or self.hum.MoveDirection.Magnitude>0.9 then return false end
    if self:_targetRagdolled(tgt) then return false end
    if self.lastM1Target~=tgt or (os.clock()-self.lastM1AttemptTime)>0.7 then return false end
    if not self:_hasRecentStun(tgt) then return false end
    return true
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


    if self:_maybeUltActions(tgt) then
        self:setInput(forward,strafe)
        return
    end


    if d<=CFG.M1Range and nowT-self.lastM1>CFG.M1Min*0.9 then
        if not self:_targetRagdolled(tgt) then
            self:_registerM1Attempt(tgt)
            self:_pressAction("M1", CFG.TapS)
            self.lastM1=nowT
            self.lastAttempt=nowT
        end
    end


    if d<=CFG.CloseUseRange and (nowT - self.lastSkill)>0.28 then
        local roll=math.random()
        if roll<0.30 and slotReady(SLOT.Shove) then self:_pressAction("Shove")
        elseif roll<0.58 and slotReady(SLOT.CP) then self:_pressAction("CP")
        elseif roll<0.75 and slotReady(SLOT.NP) then self:_pressAction("NP")
        elseif roll<0.86 and slotReady(SLOT.Upper) and self:_upperUseOK(tgt) then self:_pressAction("Upper")
        end
        self.lastSkill=nowT; self.lastAttempt=nowT
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
    self.gui:setS("Status: idle"); self.gui:setC("Combo: none"); self.ls:log("session_stop",{dur=os.clock()-self.since})
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
    self.ls:flush()
    if not(self.char and self.hum and self.rp) then return end
    if self.hum.Health<=0 then self.run=false return end


    if self.evTimer>0 then self.evTimer -= dt; if self.evTimer<=0 then self.evTimer=0; self.evReady=true end end
    self.gui:setE(self.evReady and "Evasive: ready" or ("Evasive: "..string.format("%.1fs",math.max(0,self.evTimer))))

    self:updateEnemies(dt); self:updateAttacker()
    if self.lastAttacker and os.clock()-self.lastAtkTime>3 then self.lastAttacker=nil; self.lastDmg=0 end

    local tgt=self:selectTarget()
    if not tgt then
        self.gui:setT("Target: none")
        if not self.run then self:clearMove() end
        self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
        return
    end
    self.gui:setT(("Target: %s (%.0f hp)"):format(tgt.model.Name, tgt.hp))


    if self.blocking and self.blockStartTime and (os.clock()-self.blockStartTime)>5.0 then
        self:_forceUnblockNow()
        self.blocking=false
        self.blockStartTime=nil
        self:maybeDash(tgt)
    end


    local md = self.hum.MoveDirection.Magnitude
    local idleCond = (md<0.10) and (not self.inDash) and (not self.isAttacking) and (not self.blocking)
    if idleCond then
        self.stillTimer = self.stillTimer + dt
        if self.stillTimer > 1.6 then
            if distOK(tgt.dist, CFG.Gates.S.lo, CFG.Gates.S.hi) and math.random()<0.65 then
                self:_pressAction("Shove", CFG.TapS); self:_requestSideDash(tgt)
            else
                self:maybeDash(tgt)
            end
            self:setInput(0.95, (math.random()<0.5) and -1 or 1)
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


    local likelyBlk = (os.clock()-tgt.style.lastBlk)<0.30 or (tgt.style.def>6)
    if tgt.hp<=CFG.SnipeHP and not likelyBlk and tgt.dist<=CFG.SnipeRange and (os.clock()-self.lastSnipe>0.8) then
        if slotReady(SLOT.NP) then
            self:_pressAction("NP"); self.lastSnipe=os.clock(); self.lastAttempt=os.clock(); self:setInput(0.6,0)
            self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S"))
            return
        end
    end


    if self:shouldBlock(tgt) then self:block(self:blockDur(tgt), tgt); self:neutral(tgt); self.gui:updateCDs(self:_cdLeft("F"), self:_cdLeft("B"), self:_cdLeft("S")); return end


    local nowT=os.clock()
    if nowT - self.lastAttempt > CFG.MaxNoAtk and tgt.dist<=CFG.CloseUseRange+2 then
        if (nowT - self.lastAttempt) > CFG.ForceAtk then
            if slotReady(SLOT.Shove) and math.random()<0.55 then self:_pressAction("Shove") elseif slotReady(SLOT.CP) then self:_pressAction("CP") end
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


if getgenv().BattlegroundsBot and getgenv().BattlegroundsBot.destroy then pcall(function() getgenv().BattlegroundsBot:destroy() end) end
local bot=Bot.new(); getgenv().BattlegroundsBot=bot; return bot

