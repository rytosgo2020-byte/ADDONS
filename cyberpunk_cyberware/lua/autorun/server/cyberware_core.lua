-- lua/autorun/server/sv_cyberware_core.lua
if CLIENT then return end

CYBERWARE = CYBERWARE or {}

util.AddNetworkString("Cyberware_OpenRipperdoc")
util.AddNetworkString("Cyberware_InstallOnPlayer")
util.AddNetworkString("Cyberware_ToggleQuickhack")
util.AddNetworkString("Cyberware_AdjustMaxHumanity")
util.AddNetworkString("Cyberware_UseQuickhack")
util.AddNetworkString("Cyberware_ScreenEffect")
util.AddNetworkString("Cyberware_TriggerHallucination")
util.AddNetworkString("Cyberware_Notify")

-- ================= СИСТЕМА АВТОСОХРАНЕНИЯ (SQLite) =================
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
    local maxH = self:GetMaxHumanity(ply)

    local slotsData = {}
    for slot, _ in pairs(self.Categories) do
        local raw = ply:GetNW2String("Cyber_Slot_" .. slot, "")
        if raw ~= "" then
            slotsData[slot] = raw
        end
    end

    local hacksData = { unlocked = {}, revoked = {} }
    for hackID, _ in pairs(self.Quickhacks) do
        if ply:GetNW2Bool("Cyber_Hack_" .. hackID, false) then
            hacksData.unlocked[hackID] = true
        end
        if ply:GetNW2Bool("Cyber_HackRevoked_" .. hackID, false) then
            hacksData.revoked[hackID] = true
        end
    end

    local slotsJSON = sql.SQLStr(util.TableToJSON(slotsData))
    local hacksJSON = sql.SQLStr(util.TableToJSON(hacksData))

    sql.Query(string.format(
        "REPLACE INTO cyberware_rp_saves (steamid, max_humanity, slots_json, hacks_json) VALUES (%s, %d, %s, %s)",
        sid, maxH, slotsJSON, hacksJSON
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
    for slot, _ in pairs(self.Categories) do
        ply:SetNW2String("Cyber_Slot_" .. slot, slotsData[slot] or "")
    end

    local hacksData = util.JSONToTable(row.hacks_json or "{}") or {}
    if hacksData.unlocked then
        for hackID, val in pairs(hacksData.unlocked) do
            ply:SetNW2Bool("Cyber_Hack_" .. hackID, val == true)
        end
    end
    if hacksData.revoked then
        for hackID, val in pairs(hacksData.revoked) do
            ply:SetNW2Bool("Cyber_HackRevoked_" .. hackID, val == true)
        end
    end
end

local function Notify(ply, msg, isErr)
    net.Start("Cyberware_Notify")
    net.WriteString(msg)
    net.WriteBool(isErr or false)
    net.Send(ply)
end

-- Пересчет скорости и максимального здоровья (Кожа + Скелет + Нервная система)
function CYBERWARE:UpdatePlayerStats(ply)
    if not IsValid(ply) then return end
    ply.Cyber_BaseRun = ply.Cyber_BaseRun or ply:GetRunSpeed()
    ply.Cyber_BaseWalk = ply.Cyber_BaseWalk or ply:GetWalkSpeed()
    ply.Cyber_BaseMaxHP = ply.Cyber_BaseMaxHP or 100

    local bonusHP = 0
    for _, item in ipairs(self:GetEquippedList(ply, "INTEGUMENTARY")) do
        bonusHP = bonusHP + (item.data.bonusHP or 0)
    end
    for _, item in ipairs(self:GetEquippedList(ply, "SKELETON")) do
        bonusHP = bonusHP + (item.data.skelHP or 0)
    end

    local newMaxHP = ply.Cyber_BaseMaxHP + bonusHP
    local oldMaxHP = ply:GetMaxHealth()

    if newMaxHP ~= oldMaxHP then
        local diff = newMaxHP - oldMaxHP
        ply:SetMaxHealth(newMaxHP)
        if ply:Alive() then
            if diff > 0 then
                ply:SetHealth(math.min(newMaxHP, ply:Health() + diff))
            else
                ply:SetHealth(math.min(newMaxHP, ply:Health()))
            end
        end
    end

    if ply:GetNW2Float("Cyber_Crippled_Until", 0) > CurTime() then
        ply:SetWalkSpeed(ply.Cyber_BaseWalk * 0.45)
        ply:SetRunSpeed(ply.Cyber_BaseWalk * 0.45)
        return
    end

    local mult = 1.0
    for _, item in ipairs(self:GetEquippedList(ply, "SKELETON")) do
        if item.data.speedPassive then
            mult = mult + item.data.speedPassive
        end
    end
    for _, item in ipairs(self:GetEquippedList(ply, "NERVOUS")) do
        if item.data.nervousSpeed then
            mult = mult + item.data.nervousSpeed
        end
    end

    if ply:GetNW2Bool("Cyber_Sandevistan_Active", false) then
        local osImp = self:GetEquippedInSlot(ply, "OS")
        mult = mult + ((osImp and osImp.speedBonus) or 0.65)
    end

    if ply:GetNW2Float("Cyber_Exhausted", 0) > CurTime() then
        mult = mult - 0.20
    end

    ply:SetWalkSpeed(ply.Cyber_BaseWalk * mult)
    ply:SetRunSpeed(ply.Cyber_BaseRun * mult)
end

hook.Add("PlayerInitialSpawn", "Cyberware_LoadSavedProfile", function(ply)
    timer.Simple(0.5, function()
        if IsValid(ply) then
            CYBERWARE:LoadPlayerData(ply)
            CYBERWARE:UpdatePlayerStats(ply)
        end
    end)
end)

hook.Add("PlayerSpawn", "Cyberware_ResetOnSpawn", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        ply.Cyber_BaseRun = ply:GetRunSpeed()
        ply.Cyber_BaseWalk = ply:GetWalkSpeed()
        ply.Cyber_BaseMaxHP = 100

        if not ply.Cyber_DataLoaded then
            ply.Cyber_DataLoaded = true
            CYBERWARE:LoadPlayerData(ply)
        end

        ply:SetNW2Bool("Cyber_Sandevistan_Active", false)
        ply:SetNW2Bool("Cyber_Berserk_Active", false)
        ply:SetNW2Float("Cyber_Exhausted", 0)
        ply:SetNW2Float("Cyber_EMP_Until", 0)
        ply:SetNW2Float("Cyber_Crippled_Until", 0)
        ply:SetNW2Float("Cyber_JumpCharge", 0)
        CYBERWARE:UpdatePlayerStats(ply)
    end)
end)

net.Receive("Cyberware_AdjustMaxHumanity", function(len, ply)
    if not CYBERWARE:IsAdmin(ply) then
        Notify(ply, "ОТКАЗАНО В ДОСТУПЕ: Терминал Риппердока доступен только администраторам!", true)
        return
    end

    local target = net.ReadEntity()
    local delta = net.ReadInt(16)
    local isReset = net.ReadBool()

    if not IsValid(target) or not target:IsPlayer() then return end

    if isReset then
        target:SetNW2Int("Cyber_MaxHumanity", CYBERWARE.Config.DefaultMaxHumanity)
        Notify(ply, "Лимит человечности " .. target:Nick() .. " сброшен до " .. CYBERWARE.Config.DefaultMaxHumanity, false)
    else
        local curMax = CYBERWARE:GetMaxHumanity(target)
        local newMax = math.Clamp(curMax + delta, 0, CYBERWARE.Config.MaxHumanityCap)
        target:SetNW2Int("Cyber_MaxHumanity", newMax)
        Notify(ply, "Макс. человечность " .. target:Nick() .. " изменена: " .. newMax .. " ед.", false)
    end

    CYBERWARE:SavePlayerData(target)
end)

net.Receive("Cyberware_InstallOnPlayer", function(len, ply)
    if not CYBERWARE:IsAdmin(ply) then
        Notify(ply, "ОТКАЗАНО В ДОСТУПЕ: Только администратор может управлять имплантами!", true)
        return
    end

    local target = net.ReadEntity()
    local implantID = net.ReadString()
    local implant = CYBERWARE.Implants[implantID]
    if not IsValid(target) or not target:IsPlayer() or not implant then return end

    local slot = implant.slot
    local catData = CYBERWARE.Categories[slot]
    local maxSlots = (catData and catData.maxSlots) or 1
    local slotKey = "Cyber_Slot_" .. slot

    local equippedList = CYBERWARE:GetEquippedList(target, slot)
    local newIDs = {}
    local wasRemoved = false

    for _, item in ipairs(equippedList) do
        if item.id == implantID then
            wasRemoved = true
        else
            table.insert(newIDs, item.id)
        end
    end

    if wasRemoved then
        target:SetNW2String(slotKey, table.concat(newIDs, ","))
        target:EmitSound("items/suitchargeok1.wav", 70, 95)
        Notify(ply, "Имплант [" .. implant.name .. "] снят с " .. target:Nick(), false)
        CYBERWARE:UpdatePlayerStats(target)
        CYBERWARE:SavePlayerData(target)
        return
    end

    if maxSlots == 1 then
        newIDs = { implantID }
    else
        if #newIDs >= maxSlots then
            Notify(ply, "Все слоты категории «" .. catData.name .. "» (" .. maxSlots .. "/" .. maxSlots .. ") заняты! Сначала снимите один.", true)
            return
        end
        table.insert(newIDs, implantID)
    end

    target:SetNW2String(slotKey, table.concat(newIDs, ","))
    target:EmitSound("weapons/cguard/charging.wav", 75, 120)
    Notify(ply, "Установлен [" .. implant.name .. "] (" .. #newIDs .. "/" .. maxSlots .. ") пациенту " .. target:Nick(), false)
    if target ~= ply then
        Notify(target, "Вам установлен имплант: " .. implant.name, false)
    end
    CYBERWARE:UpdatePlayerStats(target)
    CYBERWARE:SavePlayerData(target)
end)

net.Receive("Cyberware_ToggleQuickhack", function(len, ply)
    if not CYBERWARE:IsAdmin(ply) then
        Notify(ply, "ОТКАЗАНО В ДОСТУПЕ: Только администратор может выдавать скрипты!", true)
        return
    end

    local target = net.ReadEntity()
    local hackID = net.ReadString()
    local hack = CYBERWARE.Quickhacks[hackID]
    if not IsValid(target) or not target:IsPlayer() or not hack then return end

    if CYBERWARE:HasQuickhack(target, hackID) then
        target:SetNW2Bool("Cyber_Hack_" .. hackID, false)
        target:SetNW2Bool("Cyber_HackRevoked_" .. hackID, true)
        Notify(ply, "Скрипт [" .. hack.name .. "] изъят у " .. target:Nick(), true)
    else
        target:SetNW2Bool("Cyber_Hack_" .. hackID, true)
        target:SetNW2Bool("Cyber_HackRevoked_" .. hackID, false)
        target:EmitSound("buttons/button9.wav", 65, 120)
        Notify(ply, "Скрипт [" .. hack.name .. "] выдан " .. target:Nick(), false)
    end

    CYBERWARE:SavePlayerData(target)
end)

concommand.Add("cyber_activate_os", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if (ply.Cyber_LastOSToggle or 0) > CurTime() then return end

    local implant, osID = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if not implant or implant.hackRange then return end

    local steamID = ply:SteamID64() or ply:SteamID()
    local isSandy = (implant.speedBonus ~= nil)

    if isSandy and ply:GetNW2Bool("Cyber_Sandevistan_Active", false) then
        local elapsedSinceStart = CurTime() - (ply.Cyber_SandyStartTime or 0)
        if elapsedSinceStart < 0.65 then return end

        ply.Cyber_LastOSToggle = CurTime() + 0.45
        ply:SetNW2Bool("Cyber_Sandevistan_Active", false)
        timer.Remove("Cyber_OS_" .. steamID)

        local elapsed = math.Clamp(elapsedSinceStart, 0.5, implant.duration)
        local dynamicCD = math.max(3, math.Round(implant.cooldown * (elapsed / implant.duration), 1))

        ply:SetNW2Float("Cyber_NextOS", CurTime() + dynamicCD)
        ply:EmitSound("weapons/physcannon/physcannon_drop.wav", 75, 115)
        CYBERWARE:UpdatePlayerStats(ply)

        net.Start("Cyberware_ScreenEffect")
        net.WriteString("clear")
        net.WriteFloat(0)
        net.Send(ply)

        Notify(ply, "Сандевистан отключен (КД: " .. math.ceil(dynamicCD) .. "с)", false)
        return
    end

    if ply:GetNW2Bool("Cyber_Berserk_Active", false) then return end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then
        Notify(ply, "СБОЙ: Импланты заблокированы ЭМИ!", true)
        return
    end

    local nextUse = ply:GetNW2Float("Cyber_NextOS", 0)
    if nextUse > CurTime() then
        Notify(ply, "Перезарядка ОС: " .. math.ceil(nextUse - CurTime()) .. "с", true)
        return
    end

    ply.Cyber_LastOSToggle = CurTime() + 0.65

    if isSandy then
        ply.Cyber_SandyStartTime = CurTime()
        ply:SetNW2Bool("Cyber_Sandevistan_Active", true)
        ply:SetNW2Float("Cyber_NextOS", CurTime() + implant.cooldown)

        ply:EmitSound("ambient/machines/teleport1.wav", 80, 140)
        ply:EmitSound("weapons/physcannon/physcannon_charge.wav", 75, 130)
        CYBERWARE:UpdatePlayerStats(ply)

        net.Start("Cyberware_ScreenEffect")
        net.WriteString("sandevistan")
        net.WriteFloat(implant.duration)
        net.Send(ply)

        timer.Create("Cyber_OS_" .. steamID, implant.duration, 1, function()
            if not IsValid(ply) or not ply:GetNW2Bool("Cyber_Sandevistan_Active", false) then return end
            ply:SetNW2Bool("Cyber_Sandevistan_Active", false)
            ply:SetNW2Float("Cyber_Exhausted", CurTime() + 2.0)
            ply:SetNW2Float("Cyber_NextOS", CurTime() + implant.cooldown)
            ply:EmitSound("ambient/energy/zap2.wav", 70, 90)
            CYBERWARE:UpdatePlayerStats(ply)
            timer.Simple(2.1, function()
                if IsValid(ply) then CYBERWARE:UpdatePlayerStats(ply) end
            end)
        end)
    else
        ply:SetNW2Bool("Cyber_Berserk_Active", true)
        ply:SetNW2Float("Cyber_NextOS", CurTime() + implant.cooldown)
        ply:EmitSound("npc/antlion_guard/angry1.wav", 85, 110)

        net.Start("Cyberware_ScreenEffect")
        net.WriteString("berserk")
        net.WriteFloat(implant.duration)
        net.Send(ply)

        timer.Create("Cyber_OS_" .. steamID, implant.duration, 1, function()
            if not IsValid(ply) then return end
            ply:SetNW2Bool("Cyber_Berserk_Active", false)
        end)
    end
end)

concommand.Add("cyber_dash", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local nervImp = nil
    for _, item in ipairs(CYBERWARE:GetEquippedList(ply, "NERVOUS")) do
        if item.data.dashPower and (not nervImp or item.data.dashPower > nervImp.dashPower) then
            nervImp = item.data
        end
    end
    if not nervImp then return end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() or ply:GetNW2Float("Cyber_Crippled_Until", 0) > CurTime() then
        Notify(ply, "Сервоприводы заблокированы!", true)
        return
    end

    if ply:GetNW2Float("Cyber_NextDash", 0) > CurTime() then return end

    ply:SetNW2Float("Cyber_NextDash", CurTime() + nervImp.cooldown)
    ply:SetNW2Float("Cyber_Dodging", CurTime() + (nervImp.dodgeTime or 0.4))

    local eyeAngles = ply:EyeAngles()
    eyeAngles.pitch = 0

    local moveDir = ply:GetVelocity()
    moveDir.z = 0
    if moveDir:Length2D() < 20 then
        moveDir = eyeAngles:Forward()
    else
        moveDir:Normalize()
    end

    ply:SetGroundEntity(NULL)
    ply:SetLocalVelocity(moveDir * nervImp.dashPower + Vector(0, 0, 235))
    ply:EmitSound("weapons/fx/nearmiss/bulletLtoR03.wav", 75, 125)
end)

concommand.Add("cyber_activate_kiroshi", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local ocuImp = CYBERWARE:GetEquippedInSlot(ply, "OCULAR")
    if not ocuImp then return end
    if ply:GetNW2Float("Cyber_NextKiroshi", 0) > CurTime() then return end

    ply:SetNW2Float("Cyber_NextKiroshi", CurTime() + ocuImp.cooldown)
    ply:SetNW2Float("Cyber_Kiroshi_Active", CurTime() + ocuImp.duration)
    ply:EmitSound("npc/scanner/scanner_scan2.wav", 65, 120)

    net.Start("Cyberware_ScreenEffect")
    net.WriteString("kiroshi")
    net.WriteFloat(ocuImp.duration)
    net.Send(ply)
end)

net.Receive("Cyberware_UseQuickhack", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local deckImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if not deckImp or not deckImp.hackRange then return end
    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then return end

    local hackID = net.ReadString()
    local target = net.ReadEntity()
    local hack = CYBERWARE.Quickhacks[hackID]

    if not hack or not CYBERWARE:HasQuickhack(ply, hackID) then return end
    if not IsValid(target) or not (target:IsPlayer() or target:IsNPC()) or target == ply then return end

    if ply:GetNW2Float("Cyber_NextHack", 0) > CurTime() then
        Notify(ply, "Кибердека перезаряжается!", true)
        return
    end

    local maxRange = deckImp.hackRange or 950
    if ply:GetPos():DistToSqr(target:GetPos()) > (maxRange * maxRange) then
        Notify(ply, "Цель вне зоны досягаемости Кибердеки!", true)
        return
    end

    local cdMult = deckImp.cdMult or 1.0
    local dmgMult = deckImp.hackDmgMult or 1.0

    ply:SetNW2Float("Cyber_NextHack", CurTime() + math.Round(hack.cooldown * cdMult, 1))
    ply:EmitSound("buttons/combine_button7.wav", 75, 115)
    target:EmitSound("ambient/energy/weld2.wav", 75, 130)

    local targetName = target:IsPlayer() and target:Nick() or target:GetClass()
    Notify(ply, "Скрипт [" .. hack.name .. "] загружен в " .. targetName, false)

    if hackID == "short_circuit" then
        local dmg = DamageInfo()
        dmg:SetDamage(40 * dmgMult)
        dmg:SetAttacker(ply)
        dmg:SetDamageType(DMG_SHOCK)
        target:TakeDamageInfo(dmg)

    elseif hackID == "optics_reboot" and target:IsPlayer() then
        net.Start("Cyberware_ScreenEffect")
        net.WriteString("optics_glitch")
        net.WriteFloat(4.5)
        net.Send(target)

    elseif hackID == "cripple_movement" and target:IsPlayer() then
        target:SetNW2Bool("Cyber_Sandevistan_Active", false)
        timer.Remove("Cyber_OS_" .. (target:SteamID64() or target:SteamID()))
        target:SetNW2Float("Cyber_Crippled_Until", CurTime() + 5.0)
        CYBERWARE:UpdatePlayerStats(target)
        timer.Simple(5.1, function() if IsValid(target) then CYBERWARE:UpdatePlayerStats(target) end end)

    elseif hackID == "synapse_burn" then
        local missingHPRatio = 1.0 - (target:Health() / math.max(1, target:GetMaxHealth()))
        local dmg = DamageInfo()
        dmg:SetDamage((60 + missingHPRatio * 50) * dmgMult)
        dmg:SetAttacker(ply)
        dmg:SetDamageType(DMG_SHOCK)
        target:TakeDamageInfo(dmg)

    elseif hackID == "cyberware_malfunction" and target:IsPlayer() then
        target:SetNW2Bool("Cyber_Sandevistan_Active", false)
        target:SetNW2Bool("Cyber_Berserk_Active", false)
        target:SetNW2Float("Cyber_EMP_Until", CurTime() + 7.0)
        timer.Remove("Cyber_OS_" .. (target:SteamID64() or target:SteamID()))
        CYBERWARE:UpdatePlayerStats(target)

        local dmg = DamageInfo()
        dmg:SetDamage(45 * dmgMult)
        dmg:SetAttacker(ply)
        dmg:SetDamageType(DMG_BLAST)
        target:TakeDamageInfo(dmg)

    elseif hackID == "weapon_glitch" and target:IsPlayer() then
        local wep = target:GetActiveWeapon()
        if IsValid(wep) and wep:Clip1() > 0 then
            target:GiveAmmo(wep:Clip1(), wep:GetPrimaryAmmoType(), true)
            wep:SetClip1(0)
        end
        target:ViewPunch(Angle(-14, math.Rand(-12, 12), 0))

    elseif hackID == "contagion" then
        for _, ent in pairs(ents.FindInSphere(target:GetPos(), 300)) do
            if IsValid(ent) and ent ~= ply and (ent:IsPlayer() or ent:IsNPC()) then
                timer.Create("Cyber_Contagion_" .. ent:EntIndex(), 1, 5, function()
                    if IsValid(ent) and ent:Health() > 0 then
                        local d = DamageInfo()
                        d:SetDamage(12 * dmgMult)
                        d:SetAttacker(ply)
                        d:SetDamageType(DMG_POISON)
                        ent:TakeDamageInfo(d)
                    end
                end)
            end
        end

    elseif hackID == "detonate_grenade" then
        local effectdata = EffectData()
        effectdata:SetOrigin(target:GetPos())
        util.Effect("Explosion", effectdata, true, true)

        local dmg = DamageInfo()
        dmg:SetDamage(80 * dmgMult)
        dmg:SetAttacker(ply)
        dmg:SetDamageType(DMG_BLAST)
        target:TakeDamageInfo(dmg)
        target:SetGroundEntity(NULL)
        target:SetVelocity(Vector(0, 0, 420))
    end
end)

-- Расчет боевого урона со всеми новыми имплантами 1-5 уровней
hook.Add("EntityTakeDamage", "Cyberware_CombatOverhaul", function(target, dmginfo)
    local attacker = dmginfo:GetAttacker()

    if IsValid(attacker) and attacker:IsPlayer() then
        local wep = attacker:GetActiveWeapon()
        local isMelee = dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH) or (IsValid(wep) and (wep:GetClass() == "weapon_crowbar" or wep:GetClass() == "weapon_fists"))

        local totalMeleeBoost = 1.0
        local totalGunBoost = 1.0
        local maxKnockback = 0
        local bonusShock = 0

        for _, item in ipairs(CYBERWARE:GetEquippedList(attacker, "ARMS")) do
            local imp = item.data
            if (imp.meleeBoost or 1) > 1 then totalMeleeBoost = totalMeleeBoost + (imp.meleeBoost - 1) end
            if (imp.gunBoost or 1) > 1 then totalGunBoost = totalGunBoost + (imp.gunBoost - 1) end
            if (imp.knockback or 0) > maxKnockback then maxKnockback = imp.knockback end
            if imp.shockDmg then bonusShock = bonusShock + imp.shockDmg end
        end

        for _, item in ipairs(CYBERWARE:GetEquippedList(attacker, "SKELETON")) do
            if item.data.meleeDmgSkel then
                totalMeleeBoost = totalMeleeBoost + item.data.meleeDmgSkel
            end
        end

        if isMelee and totalMeleeBoost > 1.0 then
            dmginfo:ScaleDamage(totalMeleeBoost)
            target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 80, 95)
            if maxKnockback > 0 and IsValid(target) and (target:IsPlayer() or target:IsNPC()) then
                target:SetGroundEntity(NULL)
                local push = (target:GetPos() - attacker:GetPos()):GetNormalized() * maxKnockback + Vector(0, 0, 170)
                target:SetVelocity(push)
            end
        elseif dmginfo:IsBulletDamage() and totalGunBoost > 1.0 then
            dmginfo:ScaleDamage(totalGunBoost)
        end

        if bonusShock > 0 then
            dmginfo:AddDamage(bonusShock)
        end

        if attacker:GetNW2Bool("Cyber_Berserk_Active", false) and isMelee then
            local osImp = CYBERWARE:GetEquippedInSlot(attacker, "OS")
            dmginfo:ScaleDamage((osImp and osImp.meleeMult) or 1.8)
        end

        -- Активный и пассивный бонус урона в голову от Оптики Кироши
        local ocuImp = CYBERWARE:GetEquippedInSlot(attacker, "OCULAR")
        if ocuImp and target:IsPlayer() and target:LastHitGroup() == HITGROUP_HEAD then
            if attacker:GetNW2Float("Cyber_Kiroshi_Active", 0) > CurTime() then
                dmginfo:ScaleDamage(ocuImp.headMult or 1.3)
            elseif ocuImp.passiveHead then
                dmginfo:ScaleDamage(1.0 + ocuImp.passiveHead)
            end
        end

        -- Суммирование активного и пассивного вампиризма
        local vampRatio = 0
        if attacker:GetNW2Float("Cyber_Vamp_Until", 0) > CurTime() then
            vampRatio = vampRatio + 0.30
        end
        for _, item in ipairs(CYBERWARE:GetEquippedList(attacker, "CIRCULATORY")) do
            if item.data.passiveVamp then
                vampRatio = vampRatio + item.data.passiveVamp
            end
        end
        if vampRatio > 0 then
            local heal = math.Round(dmginfo:GetDamage() * math.min(0.50, vampRatio))
            if heal > 0 then attacker:SetHealth(math.min(attacker:GetMaxHealth(), attacker:Health() + heal)) end
        end

        -- Награды за убийство от имплантов кровообращения (Адреналиновый стимулятор, Конвертер, Биопроводник)
        if dmginfo:GetDamage() >= target:Health() then
            local totalKillHeal = 0
            local totalCDRefund = 0
            for _, item in ipairs(CYBERWARE:GetEquippedList(attacker, "CIRCULATORY")) do
                totalKillHeal = totalKillHeal + (item.data.killHeal or 0)
                totalCDRefund = totalCDRefund + (item.data.cdRefund or 0)
            end
            if totalKillHeal > 0 then
                attacker:SetHealth(math.min(attacker:GetMaxHealth(), attacker:Health() + totalKillHeal))
            end
            if totalCDRefund > 0 then
                local nextOS = attacker:GetNW2Float("Cyber_NextOS", 0)
                if nextOS > CurTime() then
                    attacker:SetNW2Float("Cyber_NextOS", math.max(CurTime(), nextOS - totalCDRefund))
                end
            end
        end
    end

    if not IsValid(target) or not target:IsPlayer() then return end

    -- Защитные бонусы СКЕЛЕТА
    local bestFallMult = 1.0
    local meleeResist = 0
    local skelArmor = 0
    for _, item in ipairs(CYBERWARE:GetEquippedList(target, "SKELETON")) do
        if item.data.fallMult ~= nil then
            bestFallMult = math.min(bestFallMult, item.data.fallMult)
        end
        if item.data.meleeResist then
            meleeResist = meleeResist + item.data.meleeResist
        end
        if item.data.skelArmor then
            skelArmor = skelArmor + item.data.skelArmor
        end
    end

    if dmginfo:IsFallDamage() and bestFallMult < 1.0 then
        dmginfo:ScaleDamage(bestFallMult)
        return
    end

    if (dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH)) and meleeResist > 0 then
        dmginfo:ScaleDamage(math.max(0.2, 1.0 - meleeResist))
    end

    if skelArmor > 0 then
        dmginfo:ScaleDamage(math.max(0.4, 1.0 - skelArmor))
    end

    -- Уклонение НЕРВНОЙ СИСТЕМЫ и рикошет КОЖИ
    if dmginfo:IsBulletDamage() then
        if target:GetNW2Float("Cyber_Dodging", 0) > CurTime() then
            dmginfo:ScaleDamage(0)
            target:EmitSound("weapons/fx/rics/ric2.wav", 70, 130)
            return
        end

        local passiveDodgeChance = 0
        for _, item in ipairs(CYBERWARE:GetEquippedList(target, "NERVOUS")) do
            if item.data.passiveDodge then
                passiveDodgeChance = math.min(0.45, passiveDodgeChance + item.data.passiveDodge)
            end
        end
        for _, item in ipairs(CYBERWARE:GetEquippedList(target, "INTEGUMENTARY")) do
            if item.data.reflectChance then
                passiveDodgeChance = math.min(0.50, passiveDodgeChance + item.data.reflectChance)
            end
        end
        if passiveDodgeChance > 0 and math.random() < passiveDodgeChance then
            dmginfo:ScaleDamage(0)
            target:EmitSound("weapons/fx/rics/ric4.wav", 65, 135)
            return
        end
    end

    -- Броня и иммунитеты КОЖИ
    local combinedArmorMult = 1.0
    local fireImmune = false
    local shockResist = false
    for _, item in ipairs(CYBERWARE:GetEquippedList(target, "INTEGUMENTARY")) do
        if item.data.fireImmune then fireImmune = true end
        if item.data.shockResist then shockResist = true end
        if item.data.armorMult then
            combinedArmorMult = combinedArmorMult * item.data.armorMult
        end
    end

    if fireImmune and dmginfo:IsDamageType(DMG_BURN) then
        dmginfo:ScaleDamage(0)
        return
    end
    if shockResist and dmginfo:IsDamageType(DMG_SHOCK) then
        dmginfo:ScaleDamage(0.5)
    end
    if combinedArmorMult < 1.0 then
        dmginfo:ScaleDamage(math.max(0.35, combinedArmorMult))
    end

    if target:GetNW2Bool("Cyber_Sandevistan_Active", false) and target:GetVelocity():Length2D() > 180 then
        local osImp = CYBERWARE:GetEquippedInSlot(target, "OS")
        local dodge = (osImp and osImp.dmgDodge) or 0.40
        dmginfo:ScaleDamage(1.0 - dodge)
    end

    if target:GetNW2Bool("Cyber_Berserk_Active", false) and dmginfo:GetDamage() >= target:Health() then
        dmginfo:SetDamage(math.max(0, target:Health() - 1))
    end

    -- Авто-исцеление от Кровавых насосов и Биомониторов
    local postHP = target:Health() - dmginfo:GetDamage()

    if CYBERWARE:HasImplant(target, "blood_pump_shock") and postHP <= (target:GetMaxHealth() * 0.50) and target:GetNW2Float("Cyber_NextBloodPump", 0) < CurTime() then
        local pumpImp = CYBERWARE.Implants["blood_pump_shock"]
        target:SetNW2Float("Cyber_NextBloodPump", CurTime() + pumpImp.cooldown)
        target:SetNW2Float("Cyber_Vamp_Until", CurTime() + 6.0)
        if dmginfo:GetDamage() >= target:Health() then
            dmginfo:SetDamage(0)
            target:SetHealth(math.min(target:GetMaxHealth(), 75))
        else
            target:SetHealth(math.min(target:GetMaxHealth(), target:Health() + 75))
        end
        target:EmitSound("weapons/physcannon/superphys_small_zap1.wav", 85, 110)
        for _, ent in pairs(ents.FindInSphere(target:GetPos(), 260)) do
            if IsValid(ent) and ent ~= target and (ent:IsPlayer() or ent:IsNPC()) then
                local zap = DamageInfo()
                zap:SetDamage(35)
                zap:SetAttacker(target)
                zap:SetDamageType(DMG_SHOCK)
                ent:TakeDamageInfo(zap)
            end
        end
        Notify(target, "КРОВАВЫЙ НАСОС МК.5: +75 HP, электро-разряд и вампиризм!", false)

    elseif CYBERWARE:HasImplant(target, "blood_pump_t2") and postHP <= (target:GetMaxHealth() * 0.45) and target:GetNW2Float("Cyber_NextBloodPumpT2", 0) < CurTime() then
        local pumpImp = CYBERWARE.Implants["blood_pump_t2"]
        target:SetNW2Float("Cyber_NextBloodPumpT2", CurTime() + pumpImp.cooldown)
        target:SetHealth(math.min(target:GetMaxHealth(), target:Health() + pumpImp.healAmount))
        target:EmitSound("items/smallmedkit1.wav", 75, 110)
        Notify(target, "КРОВАВЫЙ НАСОС МК.2: Впрыск плазмы (+55 HP)", false)

    elseif CYBERWARE:HasImplant(target, "biomonitor_t1") and postHP <= (target:GetMaxHealth() * 0.40) and target:GetNW2Float("Cyber_NextBiomon", 0) < CurTime() then
        local bioImp = CYBERWARE.Implants["biomonitor_t1"]
        target:SetNW2Float("Cyber_NextBiomon", CurTime() + bioImp.cooldown)
        target:SetHealth(math.min(target:GetMaxHealth(), target:Health() + bioImp.healAmount))
        target:EmitSound("items/smallmedkit1.wav", 75, 110)
        Notify(target, "БИОМОНИТОР: Авто-инъекция (+40 HP)", false)
    end
end)

hook.Add("EntityFireBullets", "Cyberware_GunControl", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    local spreadMult = 1.0
    for _, item in ipairs(CYBERWARE:GetEquippedList(ent, "ARMS")) do
        if item.data.spreadMult then
            spreadMult = spreadMult * item.data.spreadMult
        end
    end
    if spreadMult < 1.0 then
        data.Spread = data.Spread * math.max(0.15, spreadMult)
    end
end)

timer.Create("Cyberware_PassiveAndPsychosisTick", 1.5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            local totalRegen = 0
            for _, item in ipairs(CYBERWARE:GetEquippedList(ply, "INTEGUMENTARY")) do
                totalRegen = totalRegen + (item.data.regen or 0)
            end
            for _, item in ipairs(CYBERWARE:GetEquippedList(ply, "CIRCULATORY")) do
                totalRegen = totalRegen + (item.data.bonusRegen or 0)
            end

            if totalRegen > 0 and ply:Health() < ply:GetMaxHealth() then
                ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + totalRegen))
            end

            local hum = CYBERWARE:GetHumanity(ply)
            if hum < CYBERWARE.Config.PsychosisStart then
                local severity = math.Clamp((CYBERWARE.Config.PsychosisStart - hum) / 85, 0.05, 1.0)
                if math.random() < (severity * 0.55) then
                    net.Start("Cyberware_TriggerHallucination")
                    net.WriteFloat(severity)
                    net.Send(ply)
                end

                if hum <= CYBERWARE.Config.PsychosisTerminal and math.random() < (severity * 0.25) then
                    ply:ViewPunch(Angle(math.Rand(-8, 8), math.Rand(-10, 10), math.Rand(-4, 4)))
                end
            end
        end
    end
end)

hook.Add("OnPlayerHitGround", "Cyberware_BerserkSlam", function(ply, inWater, onFloater, speed)
    if not IsValid(ply) or not ply:GetNW2Bool("Cyber_Berserk_Active", false) then return end
    local osImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if not osImp or not osImp.slamWave or speed < 380 then return end

    local pos = ply:GetPos()
    ply:EmitSound("physics/concrete/boulder_impact_hard4.wav", 85, 95)
    util.ScreenShake(pos, 8, 120, 1.5, 600)

    for _, ent in pairs(ents.FindInSphere(pos, 320)) do
        if IsValid(ent) and ent ~= ply and (ent:IsPlayer() or ent:IsNPC()) then
            local dmg = DamageInfo()
            dmg:SetDamage(math.Clamp(speed * 0.14, 45, 120))
            dmg:SetAttacker(ply)
            dmg:SetDamageType(DMG_CRUSH)
            ent:TakeDamageInfo(dmg)
            ent:SetGroundEntity(NULL)
            ent:SetVelocity(((ent:GetPos() - pos):GetNormalized() + Vector(0, 0, 0.45)) * 480)
        end
    end
end)

hook.Add("PlayerSay", "Cyberware_Commands", function(ply, text)
    if string.lower(string.Trim(text)) == "/ripperdoc" then
        if not CYBERWARE:IsAdmin(ply) then
            Notify(ply, "Терминал Риппердока доступен только администраторам (ваш ранг: " .. tostring(ply:GetUserGroup()) .. ")! Свои импланты: F8", true)
            return ""
        end
        net.Start("Cyberware_OpenRipperdoc")
        net.Send(ply)
        return ""
    end
end)