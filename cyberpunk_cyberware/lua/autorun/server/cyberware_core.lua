-- lua/autorun/server/cyberware_core.lua
if CLIENT then return end

CYBERWARE = CYBERWARE or {}

for _, name in ipairs({
    "Cyberware_OpenRipperdoc", "Cyberware_InstallOnPlayer", "Cyberware_ToggleQuickhack",
    "Cyberware_AdjustMaxHumanity", "Cyberware_SetMaxHumanity", "Cyberware_ClearImplants",
    "Cyberware_UseQuickhack", "Cyberware_ScreenEffect", "Cyberware_TriggerHallucination",
    "Cyberware_Notify", "Cyberware_FX", "Cyberware_Ping",
    "Cyberware_PurgeBlackwall", "Cyberware_StageChange", "Cyberware_Episode",
}) do
    util.AddNetworkString(name)
end

-- ================= СОХРАНЕНИЕ (SQLite) =================
sql.Query([[
    CREATE TABLE IF NOT EXISTS cyberware_rp_saves (
        steamid TEXT PRIMARY KEY,
        max_humanity INTEGER,
        slots_json TEXT,
        hacks_json TEXT
    )
]])

function CYBERWARE:SavePlayerData(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    local sid = sql.SQLStr(ply:SteamID64() or ply:SteamID())

    local slotsData = {}
    for slot, _ in pairs(self.Categories) do
        local raw = ply:GetNW2String("Cyber_Slot_" .. slot, "")
        if raw ~= "" then slotsData[slot] = raw end
    end

    local hacksData = { unlocked = {}, revoked = {} }
    for hackID, _ in pairs(self.Quickhacks) do
        if ply:GetNW2Bool("Cyber_Hack_" .. hackID, false) then hacksData.unlocked[hackID] = true end
        if ply:GetNW2Bool("Cyber_HackRevoked_" .. hackID, false) then hacksData.revoked[hackID] = true end
    end

    sql.Query(string.format(
        "REPLACE INTO cyberware_rp_saves (steamid, max_humanity, slots_json, hacks_json) VALUES (%s, %d, %s, %s)",
        sid, self:GetMaxHumanity(ply), sql.SQLStr(util.TableToJSON(slotsData)), sql.SQLStr(util.TableToJSON(hacksData))
    ))
end

function CYBERWARE:LoadPlayerData(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    local sid = sql.SQLStr(ply:SteamID64() or ply:SteamID())
    local row = sql.QueryRow("SELECT * FROM cyberware_rp_saves WHERE steamid = " .. sid)

    if not row then
        ply:SetNW2Int("Cyber_MaxHumanity", self.Config.DefaultMaxHumanity)
        return
    end

    ply:SetNW2Int("Cyber_MaxHumanity", tonumber(row.max_humanity) or self.Config.DefaultMaxHumanity)

    local slotsData = util.JSONToTable(row.slots_json or "{}") or {}
    for slot, cat in pairs(self.Categories) do
        -- Отбрасываем удалённые импланты и лишние слоты из старых сохранений
        local valid = {}
        for _, id in ipairs(string.Explode(",", slotsData[slot] or "")) do
            local imp = self.Implants[id]
            if imp and imp.slot == slot and #valid < (cat.maxSlots or 1) then valid[#valid + 1] = id end
        end
        ply:SetNW2String("Cyber_Slot_" .. slot, table.concat(valid, ","))
    end

    local hacksData = util.JSONToTable(row.hacks_json or "{}") or {}
    for hackID, val in pairs(hacksData.unlocked or {}) do
        ply:SetNW2Bool("Cyber_Hack_" .. hackID, val == true)
    end
    for hackID, val in pairs(hacksData.revoked or {}) do
        ply:SetNW2Bool("Cyber_HackRevoked_" .. hackID, val == true)
    end
end

-- ================= УТИЛИТЫ =================
local NOTIFY_KINDS = { info = 0, error = 1, success = 2, warn = 3 }

function CYBERWARE:Notify(ply, msg, kind)
    if not IsValid(ply) then return end
    if kind == true then kind = "error" elseif kind == false or kind == nil then kind = "info" end
    net.Start("Cyberware_Notify")
    net.WriteString(msg)
    net.WriteUInt(NOTIFY_KINDS[kind] or 0, 2)
    net.Send(ply)
end

local function Notify(ply, msg, kind) CYBERWARE:Notify(ply, msg, kind) end

-- Экранный эффект у конкретного игрока; dur <= 0 снимает эффект
function CYBERWARE:ScreenFX(ply, name, dur)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    net.Start("Cyberware_ScreenEffect")
    net.WriteString(name)
    net.WriteFloat(dur or 0)
    net.Send(ply)
end

-- Мировой эффект для всех рядом (лучи взлома, разряды, волны)
function CYBERWARE:WorldFX(kind, entA, entB, pos)
    pos = pos or (IsValid(entB) and entB:WorldSpaceCenter()) or (IsValid(entA) and entA:WorldSpaceCenter()) or vector_origin
    net.Start("Cyberware_FX")
    net.WriteString(kind)
    net.WriteEntity(IsValid(entA) and entA or NULL)
    net.WriteEntity(IsValid(entB) and entB or NULL)
    net.WriteVector(pos)
    net.SendPVS(pos)
end

local function SID(ply) return ply:SteamID64() or ply:SteamID() or tostring(ply:EntIndex()) end

local function IsLivingTarget(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() then return ent:Alive() end
    return (ent:IsNPC() or ent:IsNextBot()) and ent:Health() > 0
end

-- Урон от самого аддона (скрипты, разряды, кровотечение) не должен повторно усиливаться имплантами атакующего
local internalDamage = 0
local function DealDamage(target, attacker, amount, dtype)
    if not IsValid(target) or amount <= 0 then return end
    local d = DamageInfo()
    local att = IsValid(attacker) and attacker or game.GetWorld()
    d:SetDamage(amount)
    d:SetAttacker(att)
    d:SetInflictor(att)
    d:SetDamageType(dtype or DMG_GENERIC)
    d:SetDamagePosition(target:WorldSpaceCenter())
    internalDamage = internalDamage + 1
    local ok, err = pcall(target.TakeDamageInfo, target, d)
    internalDamage = internalDamage - 1
    if not ok then ErrorNoHalt("[Cyberware] " .. tostring(err) .. "\n") end
end

local function InternalBlast(attacker, pos, radius, dmg)
    internalDamage = internalDamage + 1
    local ok, err = pcall(util.BlastDamage, attacker, attacker, pos, radius, dmg)
    internalDamage = internalDamage - 1
    if not ok then ErrorNoHalt("[Cyberware] " .. tostring(err) .. "\n") end
end

local function Heal(ply, amount)
    if amount <= 0 or not IsValid(ply) or not ply:Alive() then return end
    ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + math.Round(amount)))
end

-- ================= ХАРАКТЕРИСТИКИ =================
function CYBERWARE:UpdatePlayerStats(ply)
    if not IsValid(ply) then return end
    ply.Cyber_BaseRun = ply.Cyber_BaseRun or ply:GetRunSpeed()
    ply.Cyber_BaseWalk = ply.Cyber_BaseWalk or ply:GetWalkSpeed()
    ply.Cyber_BaseMaxHP = ply.Cyber_BaseMaxHP or 100

    local st = self:GetStats(ply)
    local newMaxHP = ply.Cyber_BaseMaxHP + st.bonusHP
    local oldMaxHP = ply:GetMaxHealth()

    if newMaxHP ~= oldMaxHP then
        local diff = newMaxHP - oldMaxHP
        ply:SetMaxHealth(newMaxHP)
        if ply:Alive() then
            ply:SetHealth(math.Clamp(ply:Health() + math.max(0, diff), 1, newMaxHP))
        end
    end

    local now = CurTime()
    if ply:GetNW2Float("Cyber_Crippled_Until", 0) > now then
        ply:SetWalkSpeed(ply.Cyber_BaseWalk * 0.45)
        ply:SetRunSpeed(ply.Cyber_BaseWalk * 0.45)
        return
    end

    local mult = 1.0 + st.speed
    if ply:GetNW2Bool("Cyber_Sandevistan_Active", false) then
        local osImp = self:GetEquippedInSlot(ply, "OS")
        mult = mult + ((osImp and osImp.speedBonus) or 0.45)
    end
    if ply:GetNW2Float("Cyber_Exhausted", 0) > now then mult = mult - 0.20 end
    if ply:GetNW2Float("Cyber_Episode_Until", 0) > now then mult = mult + self.Config.Psychosis.EpisodeSpeed end
    if ply:GetNW2Float("Cyber_Slowed_Until", 0) > now then mult = mult * 0.70 end

    ply:SetWalkSpeed(ply.Cyber_BaseWalk * mult)
    ply:SetRunSpeed(ply.Cyber_BaseRun * mult)
end

-- Повторно пересчитать статы, когда временный эффект закончится
local function RefreshAfter(ply, delay)
    timer.Simple(delay + 0.05, function()
        if IsValid(ply) then CYBERWARE:UpdatePlayerStats(ply) end
    end)
end

-- ================= ОС: САНДЕВИСТАН / БЕРСЕРК =================
function CYBERWARE:StopSandevistan(ply, early)
    if not ply:GetNW2Bool("Cyber_Sandevistan_Active", false) then return end
    local implant = self:GetEquippedInSlot(ply, "OS")
    timer.Remove("Cyber_OS_" .. SID(ply))
    ply:SetNW2Bool("Cyber_Sandevistan_Active", false)
    ply:SetNW2Float("Cyber_OS_ActiveUntil", 0)

    local cd = (implant and implant.cooldown) or 20
    if early and implant then
        -- Досрочное отключение: перезарядка пропорциональна использованному времени
        local elapsed = math.Clamp(CurTime() - (ply.Cyber_SandyStartTime or 0), 0.5, implant.duration)
        cd = math.max(3, math.Round(implant.cooldown * (elapsed / implant.duration), 1))
        Notify(ply, "Сандевистан отключён (перезарядка " .. math.ceil(cd) .. " с)", "info")
    else
        ply:SetNW2Float("Cyber_Exhausted", CurTime() + 2.0)
        RefreshAfter(ply, 2.0)
    end

    ply:SetNW2Float("Cyber_NextOS", CurTime() + cd)
    ply:SetNW2Float("Cyber_NextOS_Total", cd)
    self:PlaySound(ply, "sandy_off")
    self:ScreenFX(ply, "sandevistan", 0)
    self:UpdatePlayerStats(ply)
end

function CYBERWARE:StopBerserk(ply)
    if not ply:GetNW2Bool("Cyber_Berserk_Active", false) then return end
    timer.Remove("Cyber_OS_" .. SID(ply))
    ply:SetNW2Bool("Cyber_Berserk_Active", false)
    ply:SetNW2Float("Cyber_OS_ActiveUntil", 0)
    self:PlaySound(ply, "berserk_off")
    self:ScreenFX(ply, "berserk", 0)
end

local function StartSandyTimer(ply, remaining)
    ply:SetNW2Float("Cyber_OS_ActiveUntil", CurTime() + remaining)
    timer.Create("Cyber_OS_" .. SID(ply), remaining, 1, function()
        if IsValid(ply) then CYBERWARE:StopSandevistan(ply, false) end
    end)
end

concommand.Add("cyber_activate_os", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if (ply.Cyber_LastOSToggle or 0) > CurTime() then return end

    local implant = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if not implant or implant.hackRange then return end
    local isSandy = implant.speedBonus ~= nil

    if isSandy and ply:GetNW2Bool("Cyber_Sandevistan_Active", false) then
        if CurTime() - (ply.Cyber_SandyStartTime or 0) < 0.65 then return end
        ply.Cyber_LastOSToggle = CurTime() + 0.45
        CYBERWARE:StopSandevistan(ply, true)
        return
    end

    if ply:GetNW2Bool("Cyber_Berserk_Active", false) then return end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then
        Notify(ply, "СБОЙ: импланты заблокированы ЭМИ!", "error")
        CYBERWARE:PlaySound(ply, "denied")
        return
    end

    local nextUse = ply:GetNW2Float("Cyber_NextOS", 0)
    if nextUse > CurTime() then
        Notify(ply, "Перезарядка ОС: " .. math.ceil(nextUse - CurTime()) .. " с", "error")
        return
    end

    ply.Cyber_LastOSToggle = CurTime() + 0.65

    if isSandy then
        ply.Cyber_SandyStartTime = CurTime()
        ply:SetNW2Bool("Cyber_Sandevistan_Active", true)
        ply:SetNW2Float("Cyber_NextOS", CurTime() + implant.duration + implant.cooldown)
        ply:SetNW2Float("Cyber_NextOS_Total", implant.duration + implant.cooldown)
        CYBERWARE:PlaySound(ply, "sandy_on")
        CYBERWARE:ScreenFX(ply, "sandevistan", implant.duration)
        CYBERWARE:UpdatePlayerStats(ply)
        StartSandyTimer(ply, implant.duration)
    else
        ply:SetNW2Bool("Cyber_Berserk_Active", true)
        ply:SetNW2Float("Cyber_OS_ActiveUntil", CurTime() + implant.duration)
        ply:SetNW2Float("Cyber_NextOS", CurTime() + implant.duration + implant.cooldown)
        ply:SetNW2Float("Cyber_NextOS_Total", implant.duration + implant.cooldown)
        CYBERWARE:PlaySound(ply, "berserk_on")
        CYBERWARE:ScreenFX(ply, "berserk", implant.duration)
        CYBERWARE:WorldFX("pulse", ply, NULL, ply:GetPos())

        timer.Create("Cyber_OS_" .. SID(ply), implant.duration, 1, function()
            if IsValid(ply) then CYBERWARE:StopBerserk(ply) end
        end)
    end
end)

-- ================= РЫВОК КЕРЕНЗИКОВА =================
concommand.Add("cyber_dash", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local nervImp = CYBERWARE:GetBestWith(ply, "NERVOUS", "dashPower")
    if not nervImp then return end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() or ply:GetNW2Float("Cyber_Crippled_Until", 0) > CurTime() then
        Notify(ply, "Сервоприводы заблокированы!", "error")
        CYBERWARE:PlaySound(ply, "denied")
        return
    end
    if ply:GetNW2Float("Cyber_NextDash", 0) > CurTime() then return end

    ply:SetNW2Float("Cyber_NextDash", CurTime() + nervImp.cooldown)
    ply:SetNW2Float("Cyber_NextDash_Total", nervImp.cooldown)
    ply:SetNW2Float("Cyber_Dodging", CurTime() + (nervImp.dodgeTime or 0.3))

    local flat = ply:EyeAngles()
    flat.pitch = 0
    local moveDir = ply:GetVelocity()
    moveDir.z = 0
    if moveDir:Length2D() < 20 then
        moveDir = flat:Forward()
    else
        moveDir:Normalize()
    end

    ply:SetGroundEntity(NULL)
    ply:SetLocalVelocity(moveDir * nervImp.dashPower + Vector(0, 0, 200))
    CYBERWARE:PlaySound(ply, "dash")
    CYBERWARE:WorldFX("dash", ply, NULL, ply:GetPos())
end)

-- ================= ОПТИКА КИРОШИ =================
concommand.Add("cyber_activate_kiroshi", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local ocuImp = CYBERWARE:GetEquippedInSlot(ply, "OCULAR")
    if not ocuImp then return end
    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then
        CYBERWARE:PlaySound(ply, "denied")
        return
    end
    if ply:GetNW2Float("Cyber_NextKiroshi", 0) > CurTime() then return end

    ply:SetNW2Float("Cyber_NextKiroshi", CurTime() + ocuImp.duration + ocuImp.cooldown)
    ply:SetNW2Float("Cyber_NextKiroshi_Total", ocuImp.duration + ocuImp.cooldown)
    ply:SetNW2Float("Cyber_Kiroshi_Active", CurTime() + ocuImp.duration)
    CYBERWARE:PlaySound(ply, "kiroshi")
    CYBERWARE:ScreenFX(ply, "kiroshi", ocuImp.duration)
end)

-- ================= РАКЕТНАЯ СИСТЕМА РУК =================
concommand.Add("cyber_arms_ability", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local imp = CYBERWARE:GetBestWith(ply, "ARMS", "launcherDmg")
    if not imp then return end
    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then
        CYBERWARE:PlaySound(ply, "denied")
        return
    end
    if ply:GetNW2Float("Cyber_NextArms", 0) > CurTime() then return end

    ply:SetNW2Float("Cyber_NextArms", CurTime() + imp.cooldown)
    ply:SetNW2Float("Cyber_NextArms_Total", imp.cooldown)
    CYBERWARE:StopCamo(ply)

    local start = ply:GetShootPos()
    local tr = util.TraceLine({
        start = start,
        endpos = start + ply:GetAimVector() * 4000,
        filter = ply,
        mask = MASK_SHOT,
    })
    local hitPos = tr.HitPos - ply:GetAimVector() * 4

    CYBERWARE:PlaySound(ply, "launcher")
    CYBERWARE:WorldFX("rocket", ply, NULL, hitPos)

    local travel = math.Clamp(start:Distance(hitPos) / 3000, 0.05, 1.4)
    timer.Simple(travel, function()
        local ed = EffectData()
        ed:SetOrigin(hitPos)
        ed:SetMagnitude(1)
        ed:SetScale(1)
        util.Effect("Explosion", ed, true, true)
        InternalBlast(IsValid(ply) and ply or game.GetWorld(), hitPos, imp.launcherRadius, imp.launcherDmg)
    end)
end)

-- ================= ОПТИЧЕСКИЙ КАМУФЛЯЖ =================
local function SetCamoVisual(ply, on)
    local alpha = on and 18 or 255
    local mode = on and RENDERMODE_TRANSALPHA or RENDERMODE_NORMAL
    ply:SetRenderMode(mode)
    ply:SetColor(ColorAlpha(ply:GetColor(), alpha))
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then
            wep:SetRenderMode(mode)
            wep:SetColor(ColorAlpha(wep:GetColor(), alpha))
        end
    end
end

function CYBERWARE:StartCamo(ply, imp)
    ply:SetNW2Float("Cyber_Camo_Until", CurTime() + imp.duration)
    SetCamoVisual(ply, true)
    ply:SetNoTarget(true)
    for _, npc in ipairs(ents.GetAll()) do
        if IsValid(npc) and npc:IsNPC() and npc:GetEnemy() == ply then
            npc:SetEnemy(NULL)
            npc:ClearEnemyMemory(ply)
        end
    end
    self:PlaySound(ply, "camo_on")
    self:ScreenFX(ply, "camo", imp.duration)
    self:WorldFX("camo", ply, NULL, ply:GetPos())

    timer.Create("Cyber_Camo_" .. SID(ply), imp.duration, 1, function()
        if IsValid(ply) then CYBERWARE:StopCamo(ply) end
    end)
end

function CYBERWARE:StopCamo(ply)
    if not IsValid(ply) or ply:GetNW2Float("Cyber_Camo_Until", 0) <= 0 then return end
    timer.Remove("Cyber_Camo_" .. SID(ply))
    ply:SetNW2Float("Cyber_Camo_Until", 0)
    SetCamoVisual(ply, false)
    ply:SetNoTarget(false)
    self:PlaySound(ply, "camo_off")
    self:ScreenFX(ply, "camo", 0)
end

concommand.Add("cyber_activate_camo", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local imp = CYBERWARE:GetBestWith(ply, "INTEGUMENTARY", "camo")
    if not imp then return end

    if ply:GetNW2Float("Cyber_Camo_Until", 0) > CurTime() then
        CYBERWARE:StopCamo(ply)
        return
    end
    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then
        CYBERWARE:PlaySound(ply, "denied")
        return
    end
    if ply:GetNW2Float("Cyber_NextCamo", 0) > CurTime() then return end

    ply:SetNW2Float("Cyber_NextCamo", CurTime() + imp.duration + imp.cooldown)
    ply:SetNW2Float("Cyber_NextCamo_Total", imp.duration + imp.cooldown)
    CYBERWARE:StartCamo(ply, imp)
end)

hook.Add("PlayerSwitchWeapon", "Cyberware_CamoWeapon", function(ply, old, new)
    if ply:GetNW2Float("Cyber_Camo_Until", 0) > CurTime() and IsValid(new) then
        new:SetRenderMode(RENDERMODE_TRANSALPHA)
        new:SetColor(ColorAlpha(new:GetColor(), 18))
    end
end)

-- ================= ЭМИ / ОТКЛЮЧЕНИЕ ИМПЛАНТОВ =================
function CYBERWARE:ApplyEMP(ply, dur)
    self:StopSandevistan(ply, false)
    self:StopBerserk(ply)
    self:StopCamo(ply)
    ply:SetNW2Float("Cyber_EMP_Until", CurTime() + dur)
    ply:SetNW2Float("Cyber_Kiroshi_Active", 0)
    self:ScreenFX(ply, "emp", dur)
    self:UpdatePlayerStats(ply)
end

-- ================= АДМИН-УПРАВЛЕНИЕ =================
local function AdminOnly(ply, what)
    if CYBERWARE:IsAdmin(ply) then return true end
    Notify(ply, "ОТКАЗАНО В ДОСТУПЕ: " .. what .. " доступно только администраторам.", "error")
    return false
end

local function WarnHumanity(target)
    local hum = CYBERWARE:GetHumanity(target)
    local stage = CYBERWARE:GetPsychosisStage(hum)
    if stage >= 1 then
        Notify(target, "ВНИМАНИЕ: человечность " .. hum .. " — " .. CYBERWARE.StageNames[stage] .. "!", "warn")
    end
end

net.Receive("Cyberware_AdjustMaxHumanity", function(len, ply)
    if not AdminOnly(ply, "изменение человечности") then return end
    local target = net.ReadEntity()
    local delta = net.ReadInt(16)
    local isReset = net.ReadBool()
    if not IsValid(target) or not target:IsPlayer() then return end

    if isReset then
        target:SetNW2Int("Cyber_MaxHumanity", CYBERWARE.Config.DefaultMaxHumanity)
        Notify(ply, "Лимит человечности " .. target:Nick() .. " сброшен до " .. CYBERWARE.Config.DefaultMaxHumanity, "success")
    else
        local newMax = math.Clamp(CYBERWARE:GetMaxHumanity(target) + delta, 0, CYBERWARE.Config.MaxHumanityCap)
        target:SetNW2Int("Cyber_MaxHumanity", newMax)
        Notify(ply, "Макс. человечность " .. target:Nick() .. ": " .. newMax, "success")
    end
    CYBERWARE:SavePlayerData(target)
end)

net.Receive("Cyberware_SetMaxHumanity", function(len, ply)
    if not AdminOnly(ply, "изменение человечности") then return end
    local target = net.ReadEntity()
    local value = net.ReadInt(16)
    if not IsValid(target) or not target:IsPlayer() then return end

    local newMax = math.Clamp(value, 0, CYBERWARE.Config.MaxHumanityCap)
    target:SetNW2Int("Cyber_MaxHumanity", newMax)
    Notify(ply, "Макс. человечность " .. target:Nick() .. " установлена: " .. newMax, "success")
    CYBERWARE:SavePlayerData(target)
end)

-- Сбросить активные эффекты, если сняли отвечающий за них имплант
local function OnImplantRemoved(target, implant)
    if implant.slot == "OS" then
        CYBERWARE:StopSandevistan(target, false)
        CYBERWARE:StopBerserk(target)
    elseif implant.camo then
        CYBERWARE:StopCamo(target)
    end
end

net.Receive("Cyberware_InstallOnPlayer", function(len, ply)
    if not AdminOnly(ply, "управление имплантами") then return end

    local target = net.ReadEntity()
    local implantID = net.ReadString()
    local implant = CYBERWARE.Implants[implantID]
    if not IsValid(target) or not target:IsPlayer() or not implant then return end

    local slot = implant.slot
    local catData = CYBERWARE.Categories[slot]
    local maxSlots = (catData and catData.maxSlots) or 1
    local slotKey = "Cyber_Slot_" .. slot

    local newIDs, wasRemoved = {}, false
    for _, item in ipairs(CYBERWARE:GetEquippedList(target, slot)) do
        if item.id == implantID then
            wasRemoved = true
        else
            newIDs[#newIDs + 1] = item.id
        end
    end

    if wasRemoved then
        target:SetNW2String(slotKey, table.concat(newIDs, ","))
        OnImplantRemoved(target, implant)
        CYBERWARE:PlaySound(target, "uninstall")
        Notify(ply, "Имплант [" .. implant.name .. "] снят с " .. target:Nick(), "info")
        if target ~= ply then Notify(target, "Имплант удалён: " .. implant.name, "info") end
        CYBERWARE:UpdatePlayerStats(target)
        CYBERWARE:SavePlayerData(target)
        return
    end

    if maxSlots == 1 then
        local old = CYBERWARE:GetEquippedInSlot(target, slot)
        if old then OnImplantRemoved(target, old) end
        newIDs = { implantID }
    else
        if #newIDs >= maxSlots then
            Notify(ply, "Все слоты «" .. catData.name .. "» (" .. maxSlots .. "/" .. maxSlots .. ") заняты. Сначала снимите один имплант.", "error")
            return
        end
        newIDs[#newIDs + 1] = implantID
    end

    target:SetNW2String(slotKey, table.concat(newIDs, ","))
    if implant.ram then
        target:SetNW2Float("Cyber_RAM", implant.ram)
        target:SetNW2Float("Cyber_RAMStamp", CurTime())
    end
    CYBERWARE:PlaySound(target, "install")
    CYBERWARE:ScreenFX(target, "install", 1.2)
    Notify(ply, "Установлен [" .. implant.name .. "] (" .. #newIDs .. "/" .. maxSlots .. ") → " .. target:Nick(), "success")
    if target ~= ply then Notify(target, "Вам установлен имплант: " .. implant.name, "success") end
    CYBERWARE:UpdatePlayerStats(target)
    CYBERWARE:SavePlayerData(target)
    WarnHumanity(target)
    CYBERWARE:CheckStage(target)
end)

net.Receive("Cyberware_ClearImplants", function(len, ply)
    if not AdminOnly(ply, "управление имплантами") then return end
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end

    CYBERWARE:StopSandevistan(target, false)
    CYBERWARE:StopBerserk(target)
    CYBERWARE:StopCamo(target)
    for slot, _ in pairs(CYBERWARE.Categories) do
        target:SetNW2String("Cyber_Slot_" .. slot, "")
    end
    CYBERWARE:PlaySound(target, "uninstall")
    Notify(ply, "Все импланты сняты с " .. target:Nick(), "success")
    if target ~= ply then Notify(target, "Риппердок удалил все ваши импланты", "info") end
    CYBERWARE:UpdatePlayerStats(target)
    CYBERWARE:SavePlayerData(target)
end)

net.Receive("Cyberware_ToggleQuickhack", function(len, ply)
    if not AdminOnly(ply, "выдача скриптов") then return end
    local target = net.ReadEntity()
    local hackID = net.ReadString()
    local hack = CYBERWARE.Quickhacks[hackID]
    if not IsValid(target) or not target:IsPlayer() or not hack then return end

    if CYBERWARE:HasQuickhack(target, hackID) then
        target:SetNW2Bool("Cyber_Hack_" .. hackID, false)
        target:SetNW2Bool("Cyber_HackRevoked_" .. hackID, true)
        Notify(ply, "Скрипт [" .. hack.name .. "] изъят у " .. target:Nick(), "info")
    else
        target:SetNW2Bool("Cyber_Hack_" .. hackID, true)
        target:SetNW2Bool("Cyber_HackRevoked_" .. hackID, false)
        CYBERWARE:PlaySound(target, "hack_upload")
        Notify(ply, "Скрипт [" .. hack.name .. "] выдан " .. target:Nick(), "success")
        if target ~= ply then Notify(target, "Получен скрипт кибердеки: " .. hack.name, "success") end
    end
    CYBERWARE:SavePlayerData(target)
end)

-- ================= СКРИПТЫ КИБЕРДЕКИ =================
local function HasLineOfSight(ply, target)
    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = target:WorldSpaceCenter(),
        filter = { ply, target },
        mask = MASK_SHOT,
    })
    return not tr.Hit or tr.Entity == target
end

local function TrySelfIce(attacker, target, hack)
    if not target:IsPlayer() then return false end
    local ice, iceID = CYBERWARE:GetBestWith(target, "NERVOUS", "selfIce")
    if not ice then return false end
    local key = "Cyber_CD_" .. iceID
    if target:GetNW2Float(key, 0) > CurTime() then return false end

    target:SetNW2Float(key, CurTime() + ice.cooldown)
    CYBERWARE:PlaySound(target, "self_ice")
    CYBERWARE:WorldFX("ice", target, attacker, target:WorldSpaceCenter())
    Notify(target, "САМО-ЛЁД: заблокирован скрипт «" .. hack.name .. "» от " .. attacker:Nick(), "success")
    Notify(attacker, "Атака отражена: у цели активен Само-ЛЁД", "error")
    return true
end

local HACK_EFFECTS = {}

HACK_EFFECTS.ping = function(ply, target, mult)
    local list = { target }
    for _, ent in ipairs(ents.FindInSphere(target:GetPos(), 700)) do
        if ent ~= target and ent ~= ply and IsLivingTarget(ent) then list[#list + 1] = ent end
    end
    net.Start("Cyberware_Ping")
    net.WriteFloat(8)
    net.WriteUInt(math.min(#list, 64), 7)
    for i = 1, math.min(#list, 64) do net.WriteEntity(list[i]) end
    net.Send(ply)
end

HACK_EFFECTS.short_circuit = function(ply, target, mult, hack)
    DealDamage(target, ply, hack.damage * mult, DMG_SHOCK)
    CYBERWARE:PlaySound(target, "shock")
    if target:IsPlayer() then
        target:SetNW2Float("Cyber_Slowed_Until", CurTime() + 2.5)
        CYBERWARE:UpdatePlayerStats(target)
        RefreshAfter(target, 2.5)
    end
end

HACK_EFFECTS.optics_reboot = function(ply, target)
    if target:IsPlayer() then
        CYBERWARE:ScreenFX(target, "optics_glitch", 4)
    elseif target:IsNPC() then
        target:SetEnemy(NULL)
        target:ClearEnemyMemory()
        target:SetSchedule(SCHED_IDLE_STAND)
    end
end

HACK_EFFECTS.memory_wipe = function(ply, target)
    if not target:IsNPC() then return end
    local prev = target:Disposition(ply)
    target:SetEnemy(NULL)
    target:ClearEnemyMemory()
    target:AddEntityRelationship(ply, D_NU, 99)
    target:SetSchedule(SCHED_IDLE_STAND)
    timer.Simple(6, function()
        if IsValid(target) and IsValid(ply) then target:AddEntityRelationship(ply, prev, 0) end
    end)
end

HACK_EFFECTS.cripple_movement = function(ply, target)
    CYBERWARE:StopSandevistan(target, false)
    target:SetNW2Float("Cyber_Crippled_Until", CurTime() + 4)
    CYBERWARE:ScreenFX(target, "crippled", 4)
    CYBERWARE:UpdatePlayerStats(target)
    RefreshAfter(target, 4)
end

HACK_EFFECTS.weapon_glitch = function(ply, target)
    local wep = target:GetActiveWeapon()
    if IsValid(wep) and wep:Clip1() > 0 then
        target:GiveAmmo(wep:Clip1(), wep:GetPrimaryAmmoType(), true)
        wep:SetClip1(0)
    end
    target:ViewPunch(Angle(-6, math.Rand(-5, 5), 0))
    CYBERWARE:ScreenFX(target, "hacked", 0.8)
end

HACK_EFFECTS.overheat = function(ply, target, mult, hack)
    DealDamage(target, ply, hack.damage * mult, DMG_BURN)
    if IsValid(target) then target:Ignite(5) end
end

HACK_EFFECTS.synapse_burn = function(ply, target, mult, hack)
    local missing = 1 - math.Clamp(target:Health() / math.max(1, target:GetMaxHealth()), 0, 1)
    DealDamage(target, ply, (hack.damage + missing * 45) * mult, DMG_SHOCK)
end

HACK_EFFECTS.contagion = function(ply, target, mult, hack)
    for _, ent in ipairs(ents.FindInSphere(target:GetPos(), 300)) do
        if ent ~= ply and IsLivingTarget(ent) then
            if ent ~= target then CYBERWARE:WorldFX("chain", target, ent) end
            timer.Create("Cyber_Contagion_" .. SID(ply) .. "_" .. ent:EntIndex(), 1, 5, function()
                if IsLivingTarget(ent) then DealDamage(ent, ply, hack.damage * mult, DMG_POISON) end
            end)
        end
    end
end

HACK_EFFECTS.cyberware_malfunction = function(ply, target, mult, hack)
    if target:IsPlayer() then CYBERWARE:ApplyEMP(target, 6) end
    CYBERWARE:PlaySound(target, "emp")
    CYBERWARE:WorldFX("emp", target, NULL, target:WorldSpaceCenter())
    DealDamage(target, ply, hack.damage * mult, DMG_SHOCK)
end

HACK_EFFECTS.detonate_grenade = function(ply, target, mult, hack)
    local ed = EffectData()
    ed:SetOrigin(target:GetPos())
    util.Effect("Explosion", ed, true, true)
    DealDamage(target, ply, hack.damage * mult, DMG_BLAST)
    if IsValid(target) then
        target:SetGroundEntity(NULL)
        target:SetVelocity(Vector(0, 0, 380))
    end
end

HACK_EFFECTS.system_reset = function(ply, target, mult, hack)
    CYBERWARE:WorldFX("emp", target, NULL, target:WorldSpaceCenter())
    CYBERWARE:PlaySound(target, "emp")
    if target:IsPlayer() then
        CYBERWARE:ApplyEMP(target, 3)
        CYBERWARE:ScreenFX(target, "optics_glitch", 2)
        DealDamage(target, ply, 60 * mult, DMG_SHOCK)
    elseif target:Health() <= hack.damage * mult then
        DealDamage(target, ply, target:Health() + 50, DMG_SHOCK)
    else
        DealDamage(target, ply, hack.damage * mult, DMG_SHOCK)
    end
end

HACK_EFFECTS.blackwall_whisper = function(ply, target, mult, hack)
    CYBERWARE:AddBlackwall(target, hack.targetCorruption)
    CYBERWARE:ScreenFX(target, "blackwall", 5)
    CYBERWARE:ScreenFX(target, "optics_glitch", 1.5)
    CYBERWARE:PlaySound(target, "blackwall")
    net.Start("Cyberware_TriggerHallucination")
    net.WriteFloat(1)
    net.Send(target)
end

HACK_EFFECTS.blackwall_breach = function(ply, target, mult, hack)
    local deck = CYBERWARE:GetDeck(ply)
    if deck and deck.blackwallMult then mult = mult * 1.15 end
    CYBERWARE:PlaySound(target, "blackwall")
    CYBERWARE:WorldFX("blackwall", target, NULL, target:WorldSpaceCenter())
    for _, ent in ipairs(ents.FindInSphere(target:GetPos(), 260)) do
        if ent ~= ply and ent ~= target and IsLivingTarget(ent) then
            CYBERWARE:WorldFX("bwchain", target, ent)
            DealDamage(ent, ply, hack.splash * mult, DMG_SHOCK)
        end
    end
    if target:IsPlayer() then CYBERWARE:ScreenFX(target, "blackwall", 3) end
    DealDamage(target, ply, hack.damage * mult, DMG_SHOCK)
end

-- ================= ЧЁРНЫЙ ЗАСЛОН: ПОРЧА =================
function CYBERWARE:AddBlackwall(ply, amount)
    if not IsValid(ply) or not ply:IsPlayer() or amount <= 0 then return end
    local cfg = self.Config.Blackwall
    local value = self:GetBlackwall(ply) + amount
    local overload = value >= cfg.Max

    ply:SetNW2Float("Cyber_BW", overload and cfg.OverloadResetTo or value)
    ply:SetNW2Float("Cyber_BWStamp", CurTime())
    self:ScreenFX(ply, "blackwall", 2)

    if overload then
        self:PlaySound(ply, "bw_overload")
        self:WorldFX("blackwall", ply, NULL, ply:WorldSpaceCenter())
        self:ApplyEMP(ply, cfg.OverloadEMP)
        DealDamage(ply, game.GetWorld(), cfg.OverloadDamage, DMG_SHOCK)
        self:ScreenFX(ply, "bw_overload", 3)
        Notify(ply, "ПЕРЕГРУЗКА ЧЁРНОГО ЗАСЛОНА: нейросеть выжжена, импланты отключены!", "error")
    elseif value >= cfg.Max * 0.7 then
        Notify(ply, "Порча Чёрного заслона " .. math.floor(value) .. "/" .. cfg.Max .. " — близко к перегрузке!", "warn")
    end
end

net.Receive("Cyberware_PurgeBlackwall", function(len, ply)
    if not CYBERWARE:IsAdmin(ply) then return end
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end
    target:SetNW2Float("Cyber_BW", 0)
    target:SetNW2Float("Cyber_BWStamp", 0)
    Notify(ply, "Порча Чёрного заслона очищена у " .. target:Nick(), "success")
    if target ~= ply then Notify(target, "Риппердок очистил вашу нейросеть от порчи Заслона", "success") end
end)

net.Receive("Cyberware_UseQuickhack", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local hackID = net.ReadString()
    local target = net.ReadEntity()

    local deck = CYBERWARE:GetDeck(ply)
    local hack = CYBERWARE.Quickhacks[hackID]
    if not deck or not hack or not CYBERWARE:HasQuickhack(ply, hackID) then return end
    if (ply.Cyber_NextHackAny or 0) > CurTime() then return end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then
        Notify(ply, "Кибердека заблокирована ЭМИ!", "error")
        return
    end
    if not IsLivingTarget(target) or target == ply then return end
    if hack.playersOnly and not target:IsPlayer() then
        Notify(ply, "Скрипт работает только против игроков", "error")
        return
    end
    if hack.npcOnly and not target:IsNPC() then
        Notify(ply, "Скрипт работает только против NPC", "error")
        return
    end

    local cd = CYBERWARE:GetHackCooldown(ply, hackID)
    if cd > 0 then
        Notify(ply, hack.name .. ": перезарядка " .. math.ceil(cd) .. " с", "error")
        return
    end

    local ram = CYBERWARE:GetRAM(ply)
    if ram < hack.ram then
        Notify(ply, "Недостаточно ОЗУ (" .. math.floor(ram) .. "/" .. hack.ram .. ")", "error")
        CYBERWARE:PlaySound(ply, "denied")
        return
    end

    local maxRange = deck.hackRange or 950
    if ply:GetShootPos():DistToSqr(target:WorldSpaceCenter()) > maxRange * maxRange then
        Notify(ply, "Цель вне зоны досягаемости кибердеки!", "error")
        return
    end
    if not HasLineOfSight(ply, target) then
        Notify(ply, "Нет прямой видимости цели", "error")
        return
    end

    ply.Cyber_NextHackAny = CurTime() + CYBERWARE.Config.HackGlobalDelay
    ply:SetNW2Float("Cyber_RAM", ram - hack.ram)
    ply:SetNW2Float("Cyber_RAMStamp", CurTime())
    local hackCD = math.Round(hack.cooldown * (deck.cdMult or 1), 1)
    ply:SetNW2Float("Cyber_HackCD_" .. hackID, CurTime() + hackCD)
    ply:SetNW2Float("Cyber_HackCDTotal_" .. hackID, hackCD)

    CYBERWARE:PlaySound(ply, "hack_upload")
    CYBERWARE:WorldFX(hack.kind == "blackwall" and "bwhack" or "hack", ply, target)

    if hack.corruption then
        CYBERWARE:PlaySound(ply, "blackwall", 0.5)
        CYBERWARE:AddBlackwall(ply, hack.corruption * (deck.blackwallMult or 1))
    end

    if TrySelfIce(ply, target, hack) then return end

    CYBERWARE:PlaySound(target, "hack_hit")
    if target:IsPlayer() then
        CYBERWARE:ScreenFX(target, "hacked", 0.6)
        Notify(target, "ВЗЛОМ: на вас загружен скрипт «" .. hack.name .. "»", "error")
    end

    local targetName = target:IsPlayer() and target:Nick() or target:GetClass()
    Notify(ply, "Скрипт «" .. hack.name .. "» загружен → " .. targetName, "success")

    local fn = HACK_EFFECTS[hackID]
    if fn then fn(ply, target, deck.hackDmgMult or 1, hack) end
end)

-- ================= БОЕВАЯ СИСТЕМА =================
local MELEE_HOLDTYPES = { melee = true, melee2 = true, knife = true, fist = true }
local MELEE_CLASSES = { weapon_crowbar = true, weapon_fists = true, weapon_stunstick = true }

local function IsMeleeHit(dmginfo, attacker)
    if dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH) then return true end
    if dmginfo:IsBulletDamage() or dmginfo:IsExplosionDamage() then return false end
    local wep = attacker:GetActiveWeapon()
    if not IsValid(wep) then return false end
    if MELEE_CLASSES[wep:GetClass()] then return true end
    local ht = wep.GetHoldType and wep:GetHoldType()
    return ht and MELEE_HOLDTYPES[ht] or false
end

local function ApplyBleed(attacker, target, dps, dur)
    local name = "Cyber_Bleed_" .. target:EntIndex()
    local ticks = math.max(1, math.floor(dur / 0.5))
    timer.Create(name, 0.5, ticks, function()
        if IsLivingTarget(target) then
            DealDamage(target, attacker, dps * 0.5, DMG_SLASH)
            local ed = EffectData()
            ed:SetOrigin(target:WorldSpaceCenter() + VectorRand() * 8)
            util.Effect("BloodImpact", ed, true, true)
        else
            timer.Remove(name)
        end
    end)
end

local function ApplyChain(attacker, target, damage, frac, count)
    local origin = target:WorldSpaceCenter()
    local cands = {}
    for _, ent in ipairs(ents.FindInSphere(origin, 260)) do
        if ent ~= attacker and ent ~= target and IsLivingTarget(ent) then
            cands[#cands + 1] = { ent = ent, d = ent:GetPos():DistToSqr(origin) }
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    for i = 1, math.min(count, #cands) do
        local ent = cands[i].ent
        CYBERWARE:WorldFX("chain", target, ent)
        DealDamage(ent, attacker, damage * frac, DMG_SHOCK)
    end
    if #cands > 0 then CYBERWARE:PlaySound(target, "shock", 0.6) end
end

-- Бонус Кироши к урону в голову (игроки и NPC)
local function KiroshiHeadshot(attacker, hitgroup, dmginfo)
    if hitgroup ~= HITGROUP_HEAD or not IsValid(attacker) or not attacker:IsPlayer() then return end
    local ocu = CYBERWARE:GetEquippedInSlot(attacker, "OCULAR")
    if not ocu then return end
    if attacker:GetNW2Float("Cyber_Kiroshi_Active", 0) > CurTime() then
        dmginfo:ScaleDamage(ocu.headMult or 1.15)
    elseif ocu.headPassive then
        dmginfo:ScaleDamage(1 + ocu.headPassive)
    end
end

hook.Add("ScalePlayerDamage", "Cyberware_Kiroshi", function(ply, hitgroup, dmginfo)
    KiroshiHeadshot(dmginfo:GetAttacker(), hitgroup, dmginfo)
end)
hook.Add("ScaleNPCDamage", "Cyberware_Kiroshi", function(npc, hitgroup, dmginfo)
    KiroshiHeadshot(dmginfo:GetAttacker(), hitgroup, dmginfo)
end)

local function OffensiveBonuses(target, dmginfo, attacker)
    local st = CYBERWARE:GetStats(attacker)
    local melee = IsMeleeHit(dmginfo, attacker)
    local bullet = dmginfo:IsBulletDamage()

    if melee or bullet then CYBERWARE:StopCamo(attacker) end

    local mult = 1
    if melee then
        mult = mult + st.melee
        if attacker:GetNW2Bool("Cyber_Berserk_Active", false) then
            local osImp = CYBERWARE:GetEquippedInSlot(attacker, "OS")
            mult = mult * ((osImp and osImp.meleeMult) or 1.3)
        end
    elseif bullet then
        mult = mult + st.gun
    end

    -- Киберпсихоз: ярость усиливает любой урон, приступ — ещё и ближний бой
    local pcfg = CYBERWARE.Config.Psychosis
    if CYBERWARE:GetPsychosisStage(CYBERWARE:GetHumanity(attacker)) >= 2 then mult = mult * (1 + pcfg.DamageBonus) end
    if melee and attacker:GetNW2Float("Cyber_Episode_Until", 0) > CurTime() then mult = mult * (1 + pcfg.EpisodeMelee) end

    if mult ~= 1 then dmginfo:ScaleDamage(mult) end

    if st.shockDmg > 0 and (melee or bullet) then dmginfo:AddDamage(st.shockDmg) end

    if melee then
        if st.knockback > 0 then
            target:SetGroundEntity(NULL)
            target:SetVelocity((target:GetPos() - attacker:GetPos()):GetNormalized() * st.knockback + Vector(0, 0, 160))
            target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 80, math.random(85, 100))
        end
        if st.bleedDps > 0 then ApplyBleed(attacker, target, st.bleedDps, st.bleedTime) end
        if st.chainShock > 0 then ApplyChain(attacker, target, dmginfo:GetDamage(), st.chainShock, st.chainTargets) end
    end
end

local function DefensiveBonuses(target, dmginfo)
    local st = CYBERWARE:GetStats(target)
    local now = CurTime()

    if dmginfo:IsFallDamage() then
        if st.fallMult <= 0 then return true end
        dmginfo:ScaleDamage(st.fallMult)
        return
    end

    if dmginfo:IsDamageType(DMG_BURN) or dmginfo:IsDamageType(DMG_SLOWBURN) then
        if st.fireResist >= 1 then return true end
        dmginfo:ScaleDamage(1 - st.fireResist)
    end
    if dmginfo:IsDamageType(DMG_SHOCK) and st.shockResist > 0 then
        dmginfo:ScaleDamage(1 - st.shockResist)
    end

    if dmginfo:IsBulletDamage() then
        if target:GetNW2Float("Cyber_Dodging", 0) > now then
            CYBERWARE:PlaySound(target, "dodge")
            return true
        end
        if st.dodge > 0 and math.random() < st.dodge then
            CYBERWARE:PlaySound(target, "reflect")
            local ed = EffectData()
            ed:SetOrigin(dmginfo:GetDamagePosition())
            ed:SetNormal(VectorRand())
            util.Effect("MetalSpark", ed, true, true)
            return true
        end
    end

    if (dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH)) and st.meleeResist > 0 then
        dmginfo:ScaleDamage(1 - st.meleeResist)
    end

    local armor = st.armor
    if target:GetNW2Bool("Cyber_Berserk_Active", false) then
        local osImp = CYBERWARE:GetEquippedInSlot(target, "OS")
        armor = armor + ((osImp and osImp.berserkArmor) or 0)
    end
    if target:GetNW2Float("Cyber_Episode_Until", 0) > now then
        armor = armor + CYBERWARE.Config.Psychosis.EpisodeArmor
    end
    if armor > 0 then
        dmginfo:ScaleDamage(1 - math.min(armor, CYBERWARE.Config.Caps.Armor + 0.15))
    end

    if target:GetNW2Bool("Cyber_Sandevistan_Active", false) and target:GetVelocity():Length2D() > 180 then
        local osImp = CYBERWARE:GetEquippedInSlot(target, "OS")
        dmginfo:ScaleDamage(1 - ((osImp and osImp.dmgDodge) or 0.25))
    end

    local dmg = dmginfo:GetDamage()
    if dmg <= 0 then return end
    target.Cyber_LastHurt = now

    local lethal = dmg >= target:Health()

    if lethal and target:GetNW2Bool("Cyber_Berserk_Active", false) then
        dmginfo:SetDamage(math.max(0, target:Health() - 1))
        return
    end

    if lethal then
        local heart, heartID = CYBERWARE:GetBestWith(target, "CIRCULATORY", "secondHeart")
        if heart and target:GetNW2Float("Cyber_CD_" .. heartID, 0) < now then
            target:SetNW2Float("Cyber_CD_" .. heartID, now + heart.cooldown)
            target:SetHealth(target:GetMaxHealth())
            CYBERWARE:PlaySound(target, "second_heart")
            CYBERWARE:ScreenFX(target, "secondheart", 1.5)
            CYBERWARE:WorldFX("pulse", target, NULL, target:GetPos())
            Notify(target, "ВТОРОЕ СЕРДЦЕ: реанимация выполнена!", "success")
            return true
        end
    end

    -- Авто-лечение: срабатывает лучший готовый имплант кровообращения
    local postFrac = (target:Health() - dmg) / math.max(1, target:GetMaxHealth())
    local best, bestID
    for _, item in ipairs(CYBERWARE:GetEquippedList(target, "CIRCULATORY")) do
        local d = item.data
        if d.healThreshold and postFrac <= d.healThreshold and target:GetNW2Float("Cyber_CD_" .. item.id, 0) < now then
            if not best or (d.tier or 1) > (best.tier or 1) then best, bestID = d, item.id end
        end
    end
    if not best then return end

    target:SetNW2Float("Cyber_CD_" .. bestID, now + best.cooldown)
    if lethal then
        dmginfo:SetDamage(0)
        target:SetHealth(math.min(target:GetMaxHealth(), best.healAmount))
    else
        Heal(target, best.healAmount)
    end

    if best.pumpShock then
        CYBERWARE:PlaySound(target, "pump_shock")
        CYBERWARE:WorldFX("pulse", target, NULL, target:GetPos())
        for _, ent in ipairs(ents.FindInSphere(target:GetPos(), 240)) do
            if ent ~= target and IsLivingTarget(ent) then
                CYBERWARE:WorldFX("chain", target, ent)
                DealDamage(ent, target, best.pumpShock, DMG_SHOCK)
            end
        end
        if best.vampBurst then target:SetNW2Float("Cyber_Vamp_Until", now + best.vampBurst) end
    else
        CYBERWARE:PlaySound(target, "heal")
    end
    CYBERWARE:ScreenFX(target, "heal", 0.8)
    Notify(target, string.upper(best.name) .. ": +" .. best.healAmount .. " HP", "success")
    if lethal then return true end
end

hook.Add("EntityTakeDamage", "Cyberware_CombatOverhaul", function(target, dmginfo)
    local attacker = dmginfo:GetAttacker()

    if internalDamage == 0 and IsValid(attacker) and attacker:IsPlayer() and attacker ~= target and IsLivingTarget(target) then
        OffensiveBonuses(target, dmginfo, attacker)
    end

    if IsValid(target) and target:IsPlayer() and target:Alive() then
        return DefensiveBonuses(target, dmginfo)
    end
end)

-- Вампиризм считается от фактически нанесённого урона
hook.Add("PostEntityTakeDamage", "Cyberware_Vampirism", function(target, dmginfo, took)
    if not took or internalDamage > 0 then return end
    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == target or not attacker:Alive() then return end
    if not (target:IsPlayer() or target:IsNPC() or target:IsNextBot()) then return end

    local vamp = CYBERWARE:GetStats(attacker).vamp
    if attacker:GetNW2Float("Cyber_Vamp_Until", 0) > CurTime() then vamp = vamp + 0.15 end
    vamp = math.min(vamp, CYBERWARE.Config.Caps.Vamp + 0.15)
    if vamp > 0 then Heal(attacker, dmginfo:GetDamage() * vamp) end
end)

-- ================= НАГРАДЫ ЗА УБИЙСТВО =================
function CYBERWARE:HandleKill(attacker, victim)
    if not IsValid(attacker) or not attacker:IsPlayer() or not attacker:Alive() or attacker == victim then return end
    local st = self:GetStats(attacker)

    if st.killHeal > 0 then Heal(attacker, st.killHeal) end
    if st.cdRefund > 0 and not attacker:GetNW2Bool("Cyber_Sandevistan_Active", false) then
        local nextOS = attacker:GetNW2Float("Cyber_NextOS", 0)
        if nextOS > CurTime() then
            attacker:SetNW2Float("Cyber_NextOS", math.max(CurTime(), nextOS - st.cdRefund))
        end
    end

    if attacker:GetNW2Bool("Cyber_Sandevistan_Active", false) then
        local osImp = self:GetEquippedInSlot(attacker, "OS")
        if osImp and osImp.killExtend then
            local remaining = math.max(0, attacker:GetNW2Float("Cyber_OS_ActiveUntil", 0) - CurTime()) + osImp.killExtend
            StartSandyTimer(attacker, remaining)
            attacker:SetNW2Float("Cyber_NextOS", CurTime() + remaining + osImp.cooldown)
            attacker:SetNW2Float("Cyber_NextOS_Total", remaining + osImp.cooldown)
            self:ScreenFX(attacker, "sandevistan", remaining)
            self:PlaySound(attacker, "sandy_extend")
        end
        if osImp and osImp.sandyKillHeal then Heal(attacker, attacker:GetMaxHealth() * osImp.sandyKillHeal) end
    end
end

hook.Add("OnNPCKilled", "Cyberware_KillRewards", function(npc, attacker)
    CYBERWARE:HandleKill(attacker, npc)
end)

hook.Add("PlayerDeath", "Cyberware_KillRewards", function(victim, inflictor, attacker)
    CYBERWARE:HandleKill(attacker, victim)
    CYBERWARE:StopSandevistan(victim, false)
    CYBERWARE:StopBerserk(victim)
    CYBERWARE:StopCamo(victim)
end)

-- ================= ОРУЖИЕ =================
hook.Add("EntityFireBullets", "Cyberware_GunControl", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    CYBERWARE:StopCamo(ent)
    local st = CYBERWARE:GetStats(ent)
    local spread = st.spreadMult
    if CYBERWARE:GetPsychosisStage(CYBERWARE:GetHumanity(ent)) >= 2 then
        spread = spread * CYBERWARE.Config.Psychosis.SpreadPenalty
    end
    if spread ~= 1 then
        data.Spread = data.Spread * spread
        return true
    end
end)

-- ================= СПАВН / ЗАГРУЗКА =================
hook.Add("PlayerInitialSpawn", "Cyberware_LoadSavedProfile", function(ply)
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        ply.Cyber_DataLoaded = true
        CYBERWARE:LoadPlayerData(ply)
        CYBERWARE:UpdatePlayerStats(ply)
    end)
end)

hook.Add("PlayerSpawn", "Cyberware_ResetOnSpawn", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        if not ply.Cyber_DataLoaded then
            ply.Cyber_DataLoaded = true
            CYBERWARE:LoadPlayerData(ply)
        end

        timer.Remove("Cyber_OS_" .. SID(ply))
        timer.Remove("Cyber_Camo_" .. SID(ply))
        if ply:GetNW2Float("Cyber_Camo_Until", 0) > 0 then
            SetCamoVisual(ply, false)
            ply:SetNoTarget(false)
        end
        ply:SetNW2Bool("Cyber_Sandevistan_Active", false)
        ply:SetNW2Bool("Cyber_Berserk_Active", false)
        ply:SetNW2Float("Cyber_OS_ActiveUntil", 0)
        for _, key in ipairs({ "Cyber_Exhausted", "Cyber_EMP_Until", "Cyber_Crippled_Until", "Cyber_Slowed_Until",
                               "Cyber_JumpCharge", "Cyber_Camo_Until", "Cyber_Kiroshi_Active", "Cyber_Vamp_Until",
                               "Cyber_Episode_Until" }) do
            ply:SetNW2Float(key, 0)
        end
        local deck = CYBERWARE:GetDeck(ply)
        ply:SetNW2Float("Cyber_RAM", deck and deck.ram or 0)
        ply:SetNW2Float("Cyber_RAMStamp", CurTime())

        -- Базовые значения берутся после того, как гейммод (DarkRP и т.п.) выставил свои
        ply.Cyber_BaseRun = ply:GetRunSpeed()
        ply.Cyber_BaseWalk = ply:GetWalkSpeed()
        ply.Cyber_BaseMaxHP = ply:GetMaxHealth()
        CYBERWARE:UpdatePlayerStats(ply)
    end)
end)

hook.Add("PlayerDisconnected", "Cyberware_SaveOnLeave", function(ply)
    CYBERWARE:SavePlayerData(ply)
    timer.Remove("Cyber_OS_" .. SID(ply))
    timer.Remove("Cyber_Camo_" .. SID(ply))
end)

-- ================= СТАДИИ ПСИХОЗА И ПРИСТУПЫ =================
-- Сообщает игроку о пересечении порога человечности (в обе стороны)
function CYBERWARE:CheckStage(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local stage = self:GetPsychosisStage(self:GetHumanity(ply))
    local old = ply.Cyber_LastStage
    ply.Cyber_LastStage = stage
    if old == nil or old == stage then return end
    net.Start("Cyberware_StageChange")
    net.WriteUInt(stage, 2)
    net.WriteUInt(old, 2)
    net.Send(ply)
end

function CYBERWARE:StartEpisode(ply)
    local pcfg = self.Config.Psychosis
    ply:SetNW2Float("Cyber_Episode_Until", CurTime() + pcfg.EpisodeDuration)
    ply.Cyber_NextEpisode = CurTime() + pcfg.EpisodeDuration + pcfg.EpisodeCooldown
    self:PlaySound(ply, "episode")
    self:ScreenFX(ply, "episode", pcfg.EpisodeDuration)
    self:WorldFX("episode", ply, NULL, ply:GetPos())
    self:UpdatePlayerStats(ply)
    RefreshAfter(ply, pcfg.EpisodeDuration)

    -- Окружающие видят приступ — РП-подсказка, что человек на грани
    local witnesses = {}
    for _, other in ipairs(player.GetAll()) do
        if other ~= ply and other:GetPos():DistToSqr(ply:GetPos()) < pcfg.WitnessRadius ^ 2 then
            witnesses[#witnesses + 1] = other
        end
    end
    net.Start("Cyberware_Episode")
    net.WriteEntity(ply)
    net.WriteFloat(pcfg.EpisodeDuration)
    net.Send(witnesses)
    Notify(ply, "ПРИСТУП КИБЕРПСИХОЗА: вы теряете контроль!", "error")
end

-- ================= ПАССИВНЫЙ ТИК: РЕГЕНЕРАЦИЯ И ПСИХОЗ =================
timer.Create("Cyberware_PassiveAndPsychosisTick", CYBERWARE.Config.RegenTick, 0, function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            local st = CYBERWARE:GetStats(ply)
            if st.regen > 0 and ply:Health() < ply:GetMaxHealth()
                and now - (ply.Cyber_LastHurt or 0) > CYBERWARE.Config.RegenCombatDelay then
                Heal(ply, st.regen)
            end

            CYBERWARE:CheckStage(ply)

            -- Без тряски камеры: только галлюцинации на клиенте
            local hum = CYBERWARE:GetHumanity(ply)
            local severity = CYBERWARE:GetPsychosisSeverity(hum)
            if severity > 0 and math.random() < 0.08 + severity * 0.35 then
                net.Start("Cyberware_TriggerHallucination")
                net.WriteFloat(severity)
                net.Send(ply)
            end

            if CYBERWARE:GetPsychosisStage(hum) >= 3 and now > (ply.Cyber_NextEpisode or 0)
                and ply:GetNW2Float("Cyber_Episode_Until", 0) < now
                and math.random() < CYBERWARE.Config.Psychosis.EpisodeChance then
                CYBERWARE:StartEpisode(ply)
            end
        end
    end
end)

-- ================= ВОЛНА БЕРСЕРКА =================
hook.Add("OnPlayerHitGround", "Cyberware_BerserkSlam", function(ply, inWater, onFloater, speed)
    if not IsValid(ply) or not ply:GetNW2Bool("Cyber_Berserk_Active", false) then return end
    local osImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if not osImp or not osImp.slamWave or speed < 380 then return end

    local pos = ply:GetPos()
    CYBERWARE:PlaySound(ply, "slam")
    CYBERWARE:WorldFX("slam", ply, NULL, pos)
    util.ScreenShake(pos, 4, 60, 0.6, 500)

    for _, ent in ipairs(ents.FindInSphere(pos, 320)) do
        if ent ~= ply and IsLivingTarget(ent) then
            DealDamage(ent, ply, math.Clamp(speed * 0.12, 35, 100), DMG_CRUSH)
            ent:SetGroundEntity(NULL)
            ent:SetVelocity(((ent:GetPos() - pos):GetNormalized() + Vector(0, 0, 0.45)) * 420)
        end
    end
end)

-- ================= ЧАТ-КОМАНДЫ =================
hook.Add("PlayerSay", "Cyberware_Commands", function(ply, text)
    local cmd = string.lower(string.Trim(text))
    if cmd == "/ripperdoc" or cmd == "!ripperdoc" then
        if not CYBERWARE:IsAdmin(ply) then
            Notify(ply, "Терминал риппердока доступен только администраторам (ваш ранг: " .. tostring(ply:GetUserGroup()) .. "). Свои импланты: F8", "error")
            return ""
        end
        net.Start("Cyberware_OpenRipperdoc")
        net.Send(ply)
        return ""
    elseif cmd == "/implants" or cmd == "!implants" or cmd == "/cyber" then
        ply:ConCommand("cyber_my_implants")
        return ""
    end
end)
