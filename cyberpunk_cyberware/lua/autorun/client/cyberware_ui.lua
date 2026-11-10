-- lua/autorun/client/cl_cyberware_ui.lua
if SERVER then return end

CYBERWARE = CYBERWARE or {}

hook.Remove("PlayerButtonDown", "Cyberware_NativeKeybinds")

local activeEffect = nil
local effectEndTime = 0
local notifications = {}
local sandevistanGhosts = {}
local cyberMirages = {}
local psychoFlashTime = 0
local psychoGlitchText = ""
local keyStates = {}

local CP_YELLOW = Color(254, 211, 48)
local CP_CYAN   = Color(0, 240, 255)
local CP_RED    = Color(255, 30, 86)
local CP_GREEN  = Color(80, 255, 130)
local CP_DARK   = Color(10, 12, 18, 252)
local CP_CARD   = Color(18, 22, 32, 240)

surface.CreateFont("CP_BigTitle", { font = "Impact", size = 24, weight = 800, antialias = true })
surface.CreateFont("CP_Tab",      { font = "Roboto", size = 15, weight = 700, antialias = true })
surface.CreateFont("CP_Title",    { font = "Roboto", size = 17, weight = 700, antialias = true })
surface.CreateFont("CP_Desc",     { font = "Roboto", size = 13, weight = 400, antialias = true })
surface.CreateFont("CP_Small",    { font = "Roboto", size = 11, weight = 600, antialias = true })
surface.CreateFont("CP_Glitch",   { font = "Roboto", size = 22, weight = 900, antialias = true })

local PSYCHO_MESSAGES = {
    "КРИТИЧЕСКИЙ СБОЙ // НЕЙРОСЕТЬ ПОВРЕЖДЕНА",
    "ОНИ СМОТРЯТ НА ТЕБЯ // УБЕЙ ИХ ВСЕХ",
    "SYSTEM_ERR: CYBERPSYCHOSIS_OVERFLOW_0x9F",
    "ПАМЯТЬ ПЕРЕЗАПИСАНА // ТЫ БОЛЬШЕ НЕ ЧЕЛОВЕК",
    "ВНИМАНИЕ: ОТКАЗ ЛОБНЫХ ДОЛЕЙ КОРЫ МОЗГА",
}

local MIRAGE_MODELS = {
    "models/player/corpse1.mdl",
    "models/player/charple.mdl",
    "models/player/zombie_fast.mdl",
    "models/player/combine_super_soldier.mdl"
}

local function AddLocalNotice(msg, isErr)
    table.insert(notifications, { text = msg, err = isErr, time = CurTime() + 4.5 })
    surface.PlaySound(isErr and "buttons/button11.wav" or "buttons/button14.wav")
end

local function DrawWrappedText(text, font, x, y, maxWidth, color)
    surface.SetFont(font)
    local words = string.Explode(" ", text or "")
    local lines = {}
    local curLine = ""

    for _, word in ipairs(words) do
        local testLine = (curLine == "") and word or (curLine .. " " .. word)
        local w, _ = surface.GetTextSize(testLine)
        if w > maxWidth then
            table.insert(lines, curLine)
            curLine = word
        else
            curLine = testLine
        end
    end
    if curLine ~= "" then table.insert(lines, curLine) end

    for i, line in ipairs(lines) do
        draw.SimpleText(line, font, x, y + (i - 1) * 15, color)
    end
end

local function DrawCircleOutline(cx, cy, radius, segments, color)
    surface.SetDrawColor(color)
    local prevX, prevY
    for i = 0, segments do
        local a = math.rad((i / segments) * 360)
        local x = cx + math.cos(a) * radius
        local y = cy + math.sin(a) * radius
        if i > 0 then
            surface.DrawLine(prevX, prevY, x, y)
        end
        prevX, prevY = x, y
    end
end

local function DrawCyberCorners(x, y, w, h, len, col)
    surface.SetDrawColor(col)
    surface.DrawLine(x, y, x + len, y)
    surface.DrawLine(x, y, x, y + len)
    surface.DrawLine(x + w - len, y, x + w, y)
    surface.DrawLine(x + w, y, x + w, y + len)
    surface.DrawLine(x, y + h - len, x, y + h)
    surface.DrawLine(x, y + h, x + len, y + h)
    surface.DrawLine(x + w - len, y + h, x + w, y + h)
    surface.DrawLine(x + w, y + h - len, x + w, y + h)
end

net.Receive("Cyberware_Notify", function()
    local msg = net.ReadString()
    local isErr = net.ReadBool()
    AddLocalNotice(msg, isErr)
end)

net.Receive("Cyberware_ScreenEffect", function()
    local eff = net.ReadString()
    if eff == "clear" then
        activeEffect = nil
        effectEndTime = 0
        return
    end
    activeEffect = eff
    effectEndTime = CurTime() + net.ReadFloat()
end)

net.Receive("Cyberware_TriggerHallucination", function()
    local severity = net.ReadFloat()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    psychoFlashTime = CurTime() + math.Rand(0.25, 0.65) * (0.5 + severity)
    psychoGlitchText = table.Random(PSYCHO_MESSAGES)

    if math.random() < 0.7 then
        surface.PlaySound("ambient/voices/whisper" .. math.random(1, 3) .. ".wav")
    else
        surface.PlaySound("ambient/energy/zap" .. math.random(1, 3) .. ".wav")
    end

    local count = (severity > 0.6) and 2 or 1
    for i = 1, count do
        local ang = Angle(0, ply:EyeAngles().yaw + math.Rand(-75, 75), 0)
        local spawnPos = ply:GetPos() + ang:Forward() * math.Rand(220, 420)
        local mdl = table.Random(MIRAGE_MODELS)

        local phantom = ClientsideModel(mdl, RENDERGROUP_TRANSLUCENT)
        if IsValid(phantom) then
            phantom:SetPos(spawnPos)
            phantom:SetAngles((ply:GetPos() - spawnPos):Angle())
            phantom:SetSequence(phantom:LookupSequence("run_all_01") or 1)
            phantom:SetNoDraw(true)

            table.insert(cyberMirages, {
                ent = phantom,
                pos = spawnPos,
                dieTime = CurTime() + math.Rand(1.2, 2.6),
                speed = math.Rand(240, 380)
            })
        end
    end
end)

-- ================= ИСПРАВЛЕННЫЙ ШЛЕЙФ САНДЕВИСТАНА (НЕ ПЕРЕКРЫВАЕТ КАМЕРУ ОТ 1-ГО ЛИЦА) =================
hook.Add("PostDrawTranslucentRenderables", "Cyberware_3DEffects", function()
    local cur = CurTime()
    local localPly = LocalPlayer()

    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() and ply:GetNW2Bool("Cyber_Sandevistan_Active", false) and ply:GetVelocity():Length2D() > 140 then
            ply.Cyber_NextGhost = ply.Cyber_NextGhost or 0
            if ply.Cyber_NextGhost < cur then
                ply.Cyber_NextGhost = cur + 0.06

                -- Спавним фантом со смещением назад по вектору движения, чтобы игрок не забегал внутрь него
                local velDir = ply:GetVelocity()
                velDir.z = 0
                velDir:Normalize()
                local ghostPos = ply:GetPos() - velDir * 22

                local ghost = ClientsideModel(ply:GetModel(), RENDERGROUP_TRANSLUCENT)
                if IsValid(ghost) then
                    ghost:SetPos(ghostPos)
                    ghost:SetAngles(Angle(0, ply:EyeAngles().yaw, 0))
                    ghost:SetSequence(ply:GetSequence())
                    ghost:SetCycle(ply:GetCycle())
                    ghost:SetNoDraw(true)
                    for i = 0, ply:GetNumPoseParameters() - 1 do
                        local pName = ply:GetPoseParameterName(i)
                        if pName then ghost:SetPoseParameter(pName, ply:GetPoseParameter(pName)) end
                    end
                    ghost:SetupBones()
                    table.insert(sandevistanGhosts, {
                        ent = ghost,
                        owner = ply,
                        pos = ghostPos,
                        dieTime = cur + 0.50
                    })
                end
            end
        end
    end

    for i = #sandevistanGhosts, 1, -1 do
        local g = sandevistanGhosts[i]
        if g.dieTime < cur or not IsValid(g.ent) then
            if IsValid(g.ent) then g.ent:Remove() end
            table.remove(sandevistanGhosts, i)
        else
            -- Если игрок играет от 1-го лица, скрываем его собственные клоны вблизи камеры, чтобы ничего не мешало перед глазами!
            local shouldDraw = true
            if g.owner == localPly and IsValid(localPly) and not localPly:ShouldDrawLocalPlayer() then
                if g.pos:DistToSqr(localPly:GetPos()) < (85 * 85) then
                    shouldDraw = false
                end
            end

            if shouldDraw then
                local fade = (g.dieTime - cur) / 0.50
                render.SetColorModulation(0, 0.9, 1.0)
                render.SetBlend(fade * 0.45)
                g.ent:DrawModel()
            end
        end
    end

    for i = #cyberMirages, 1, -1 do
        local m = cyberMirages[i]
        if m.dieTime < cur or not IsValid(m.ent) or not IsValid(localPly) then
            if IsValid(m.ent) then m.ent:Remove() end
            table.remove(cyberMirages, i)
        else
            local dir = (localPly:GetPos() - m.pos):GetNormalized()
            m.pos = m.pos + dir * m.speed * FrameTime()
            m.ent:SetPos(m.pos + Vector(0, 0, math.sin(cur * 25) * 4))
            m.ent:SetAngles(Angle(0, dir:Angle().yaw, 0))
            m.ent:SetCycle((cur * 1.5) % 1)
            m.ent:SetupBones()

            if math.random() < 0.7 then
                render.SetColorModulation(1.0, 0.05, 0.25)
            else
                render.SetColorModulation(0.0, 0.95, 1.0)
            end
            render.SetBlend(math.Rand(0.35, 0.85))
            m.ent:DrawModel()

            if m.pos:DistToSqr(localPly:GetPos()) < (85 * 85) then
                psychoFlashTime = cur + 0.35
                surface.PlaySound("ambient/energy/zap1.wav")
                m.ent:Remove()
                table.remove(cyberMirages, i)
            end
        end
    end

    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1.0)
end)

function CYBERWARE:FindSmartHackTarget()
    local ply = LocalPlayer()
    local deckImp = self:GetEquippedInSlot(ply, "OS")
    local maxRange = (deckImp and deckImp.hackRange) or 950
    local shootPos = ply:GetShootPos()
    local aimVec = ply:GetAimVector()
    local bestTarget = nil
    local bestDot = 0.82

    for _, ent in ipairs(ents.GetAll()) do
        if ent ~= ply and (ent:IsPlayer() or ent:IsNPC()) and ent:Health() > 0 then
            local targetPos = ent:WorldSpaceCenter()
            if shootPos:DistToSqr(targetPos) <= (maxRange * maxRange) then
                local dot = aimVec:Dot((targetPos - shootPos):GetNormalized())
                if dot > bestDot then
                    local tr = util.TraceLine({ start = shootPos, endpos = targetPos, filter = ply })
                    if not tr.HitWorld then
                        bestDot = dot
                        bestTarget = ent
                    end
                end
            end
        end
    end
    return bestTarget
end

hook.Add("RenderScreenspaceEffects", "Cyberware_FX", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local cur = CurTime()
    local hum = CYBERWARE:GetHumanity(ply)

    if activeEffect == "sandevistan" and effectEndTime > cur then
        DrawColorModify({
            ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.06, ["$pp_colour_addb"] = 0.14,
            ["$pp_colour_contrast"] = 1.25, ["$pp_colour_colour"] = 1.35,
        })
    elseif activeEffect == "berserk" and effectEndTime > cur then
        DrawColorModify({
            ["$pp_colour_addr"] = 0.18, ["$pp_colour_contrast"] = 1.35, ["$pp_colour_colour"] = 0.75,
        })
        DrawSharpen(1.8, 1.8)
    elseif activeEffect == "optics_glitch" and effectEndTime > cur then
        DrawMotionBlur(0.08, 0.92, 0.03)
        DrawSharpen(4.5, 2.5)
        DrawColorModify({
            ["$pp_colour_addr"] = math.Rand(0.1, 0.35), ["$pp_colour_addg"] = math.Rand(0.1, 0.35),
            ["$pp_colour_addb"] = math.Rand(0.1, 0.35), ["$pp_colour_brightness"] = 0.15,
            ["$pp_colour_contrast"] = 0.5, ["$pp_colour_colour"] = 0.1
        })
    end

    if hum < CYBERWARE.Config.PsychosisStart then
        local severity = math.Clamp((CYBERWARE.Config.PsychosisStart - hum) / 85, 0.05, 1.0)
        local pulse = math.abs(math.sin(cur * (2 + severity * 6))) * severity

        DrawColorModify({
            ["$pp_colour_addr"] = pulse * 0.22,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = pulse * 0.08,
            ["$pp_colour_contrast"] = 1.0 + (severity * 0.35),
            ["$pp_colour_colour"] = math.max(0.2, 1.0 - severity * 0.55),
        })

        if severity > 0.35 then
            DrawMotionBlur(0.12, severity * 0.75, 0.02)
        end

        if psychoFlashTime > cur or (math.random() < severity * 0.14) then
            DrawSharpen(2.5 + severity * 3, 2.0)
            DrawColorModify({
                ["$pp_colour_addr"] = math.Rand(0.25, 0.65) * severity,
                ["$pp_colour_addg"] = math.Rand(0, 0.25) * severity,
                ["$pp_colour_addb"] = math.Rand(0.2, 0.55) * severity,
                ["$pp_colour_brightness"] = math.Rand(-0.08, 0.18),
                ["$pp_colour_contrast"] = 1.5,
            })
        end
    end
end)

hook.Add("CalcView", "Cyberware_PsychosisCamera", function(ply, pos, angles, fov)
    if not IsValid(ply) or not ply:Alive() then return end
    local hum = CYBERWARE:GetHumanity(ply)
    if hum < CYBERWARE.Config.PsychosisStage2 then
        local severity = math.Clamp((CYBERWARE.Config.PsychosisStage2 - hum) / 60, 0, 1)
        local view = {}
        view.origin = pos
        view.angles = angles + Angle(
            math.sin(CurTime() * 8) * severity * 1.8,
            math.cos(CurTime() * 6) * severity * 1.8,
            math.sin(CurTime() * 4) * severity * 4.5
        )
        view.fov = fov + math.sin(CurTime() * 12) * severity * 3
        return view
    end
end)

hook.Add("PreDrawHalos", "Cyberware_KiroshiHalos", function()
    local ply = LocalPlayer()
    if ply:GetNW2Float("Cyber_Kiroshi_Active", 0) > CurTime() then
        local targets = {}
        for _, ent in ipairs(player.GetAll()) do
            if ent ~= ply and ent:Alive() then table.insert(targets, ent) end
        end
        halo.Add(targets, CP_CYAN, 3, 3, 2, true, true)
    end
end)

local function CheckKeyPressed(key)
    if not key then return false end
    local isDown = input.IsKeyDown(key)
    if isDown and not keyStates[key] then
        keyStates[key] = true
        return true
    elseif not isDown and keyStates[key] then
        keyStates[key] = false
    end
    return false
end

hook.Add("Think", "Cyberware_UniversalKeybinds", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not CYBERWARE.Config then return end
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() or ply:IsTyping() then return end

    local keys = CYBERWARE.Config.DefaultKeys or {}

    if CheckKeyPressed(keys.PlayerMenu or KEY_F8) then
        CYBERWARE:OpenPersonalMenu()
        return
    end

    if CheckKeyPressed(keys.AdminMenu or KEY_F6) then
        CYBERWARE:OpenRipperdocMenu()
        return
    end

    if vgui.CursorVisible() then return end

    if CheckKeyPressed(keys.OS or KEY_Z) then
        RunConsoleCommand("cyber_activate_os")
    elseif CheckKeyPressed(keys.Quickhack or KEY_X) then
        RunConsoleCommand("cyber_quickhack_menu")
    elseif CheckKeyPressed(keys.Kerenzikov or KEY_V) then
        RunConsoleCommand("cyber_dash")
    elseif CheckKeyPressed(keys.Kiroshi or KEY_F) then
        RunConsoleCommand("cyber_activate_kiroshi")
    end
end)

-- ================= ЧИСТЫЙ МИНИМАЛИСТИЧНЫЙ HUD (ТОЛЬКО ЧЕЛОВЕЧНОСТЬ) =================
hook.Add("HUDPaint", "Cyberware_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local scrW, scrH = ScrW(), ScrH()
    local cur = CurTime()
    local hum = CYBERWARE:GetHumanity(ply)
    local maxHum = CYBERWARE:GetMaxHumanity(ply)

    if hum < CYBERWARE.Config.PsychosisStart then
        local severity = math.Clamp((CYBERWARE.Config.PsychosisStart - hum) / 85, 0.05, 1.0)
        if psychoFlashTime > cur or (math.random() < severity * 0.22) then
            local barCount = math.ceil(severity * 10)
            for i = 1, barCount do
                local gy = math.random(0, scrH)
                local gh = math.random(4, 28)
                surface.SetDrawColor(math.random() < 0.5 and Color(255, 20, 70, 140) or Color(0, 240, 255, 120))
                surface.DrawRect(0, gy, scrW, gh)
            end
            if psychoGlitchText ~= "" then
                draw.SimpleText(psychoGlitchText, "CP_Glitch", scrW / 2 + math.random(-12, 12), scrH * 0.28 + math.random(-8, 8), CP_RED, TEXT_ALIGN_CENTER)
            end
        end
    end

    local x, y = 25, scrH - 225
    local humColor = (hum <= CYBERWARE.Config.PsychosisStage2) and CP_RED or CP_CYAN

    draw.RoundedBox(0, x, y, 255, 52, CP_DARK)
    surface.SetDrawColor(humColor)
    surface.DrawOutlinedRect(x, y, 255, 52, 2)

    local barW = math.Clamp(math.Remap(hum, 0, math.max(1, maxHum), 0, 225), 0, 225)
    draw.RoundedBox(0, x + 15, y + 32, 225, 8, Color(40, 45, 60))
    draw.RoundedBox(0, x + 15, y + 32, barW, 8, humColor)

    draw.SimpleText("ЧЕЛОВЕЧНОСТЬ: " .. hum .. " / " .. maxHum, "CP_Desc", x + 15, y + 11, humColor)

    local jumpCharge = ply:GetNW2Float("Cyber_JumpCharge", 0)
    if jumpCharge > 0.05 then
        local bw, bh = 220, 14
        local bx, by = scrW / 2 - bw / 2, scrH - 140
        draw.RoundedBox(0, bx, by, bw, bh, CP_DARK)
        draw.RoundedBox(0, bx + 2, by + 2, (bw - 4) * jumpCharge, bh - 4, CP_YELLOW)
        surface.SetDrawColor(CP_CYAN)
        surface.DrawOutlinedRect(bx, by, bw, bh, 1)
        draw.SimpleText("ЗАРЯД ГИДРАВЛИКИ ПРЫЖКА", "CP_Desc", scrW / 2, by - 16, CP_YELLOW, TEXT_ALIGN_CENTER)
    end

    local deckImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if deckImp and deckImp.hackRange then
        local smartTarget = CYBERWARE:FindSmartHackTarget()
        if IsValid(smartTarget) then
            local pos = smartTarget:WorldSpaceCenter():ToScreen()
            if pos.visible then
                surface.SetDrawColor(CP_RED)
                surface.DrawOutlinedRect(pos.x - 35, pos.y - 45, 70, 90, 2)
                local tName = smartTarget:IsPlayer() and smartTarget:Nick() or "ЦЕЛЬ"
                draw.SimpleText("[X] ВЗЛОМ: " .. tName, "CP_Desc", pos.x, pos.y - 60, CP_YELLOW, TEXT_ALIGN_CENTER)
            end
        end
    end

    for i = #notifications, 1, -1 do
        local n = notifications[i]
        if n.time < cur then
            table.remove(notifications, i)
        else
            local ny = 80 + (i * 36)
            local col = n.err and CP_RED or CP_CYAN
            draw.RoundedBox(0, scrW / 2 - 250, ny, 500, 30, CP_DARK)
            surface.SetDrawColor(col)
            surface.DrawOutlinedRect(scrW / 2 - 250, ny, 500, 30, 1)
            draw.SimpleText(n.text, "CP_Title", scrW / 2, ny + 15, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

-- ================= ЛИЧНОЕ МЕНЮ АНАТОМИИ И ИМПЛАНТОВ (F8 — БЕЗ 3D МОДЕЛИ И БЕЗ ПЕРЕСЕЧЕНИЙ ТЕКСТА) =================
function CYBERWARE:OpenPersonalMenu()
    if (self.LastPersonalToggle or 0) > CurTime() then return end
    self.LastPersonalToggle = CurTime() + 0.25

    if IsValid(self.PersonalFrame) then
        self.PersonalFrame:Remove()
        surface.PlaySound("buttons/combine_button2.wav")
        return
    end

    surface.PlaySound("buttons/combine_button1.wav")
    local ply = LocalPlayer()
    local hoveredImplant = nil

    local frame = vgui.Create("DFrame")
    self.PersonalFrame = frame
    frame:SetSize(1100, 720)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()

    local bonusHP, dmgReduction, speedBonus, meleeBonus, gunBonus, dodgeBonus = 0, 0, 0, 0, 0, 0
    for _, item in ipairs(self:GetEquippedList(ply, "INTEGUMENTARY")) do
        bonusHP = bonusHP + (item.data.bonusHP or 0)
        if item.data.armorMult then
            dmgReduction = dmgReduction + math.Round((1 - item.data.armorMult) * 100)
        end
        if item.data.reflectChance then
            dodgeBonus = dodgeBonus + math.Round(item.data.reflectChance * 100)
        end
    end
    for _, item in ipairs(self:GetEquippedList(ply, "SKELETON")) do
        bonusHP = bonusHP + (item.data.skelHP or 0)
        dmgReduction = dmgReduction + math.Round((item.data.skelArmor or 0) * 100)
        speedBonus = speedBonus + math.Round((item.data.speedPassive or 0) * 100)
        meleeBonus = meleeBonus + math.Round((item.data.meleeDmgSkel or 0) * 100)
    end
    for _, item in ipairs(self:GetEquippedList(ply, "ARMS")) do
        if (item.data.meleeBoost or 1) > 1 then meleeBonus = meleeBonus + math.Round((item.data.meleeBoost - 1) * 100) end
        if (item.data.gunBoost or 1) > 1 then gunBonus = gunBonus + math.Round((item.data.gunBoost - 1) * 100) end
    end
    for _, item in ipairs(self:GetEquippedList(ply, "NERVOUS")) do
        dodgeBonus = dodgeBonus + math.Round((item.data.passiveDodge or 0) * 100)
        speedBonus = speedBonus + math.Round((item.data.nervousSpeed or 0) * 100)
    end

    local cx, cy = 550, 295
    local bodyNodes = {
        ["OS"]             = { x = cx,      y = cy - 175, boxX = 25,  boxY = 70,  side = "left" },
        ["OCULAR"]         = { x = cx - 12, y = cy - 150, boxX = 25,  boxY = 165, side = "left" },
        ["ARMS"]           = { x = cx - 82, y = cy - 22,  boxX = 25,  boxY = 260, side = "left" },
        ["SKELETON"]       = { x = cx,      y = cy + 18,  boxX = 25,  boxY = 385, side = "left" },
        ["NERVOUS"]        = { x = cx + 10, y = cy - 115, boxX = 755, boxY = 70,  side = "right" },
        ["CIRCULATORY"]    = { x = cx + 18, y = cy - 62,  boxX = 755, boxY = 195, side = "right" },
        ["INTEGUMENTARY"]  = { x = cx + 48, y = cy - 10,  boxX = 755, boxY = 350, side = "right" },
    }

    frame.Paint = function(self, w, h)
        local cur = CurTime()
        draw.RoundedBox(0, 0, 0, w, h, CP_DARK)
        surface.SetDrawColor(CP_CYAN)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        DrawCyberCorners(4, 4, w - 8, h - 8, 18, CP_YELLOW)

        -- Верхняя шапка (исправлена верстка, чтобы заголовки никогда не пересекались!)
        draw.RoundedBox(0, 2, 2, w - 4, 50, Color(16, 20, 30, 255))
        surface.SetDrawColor(CP_YELLOW)
        surface.DrawLine(2, 52, w - 2, 52)
        draw.SimpleText("NEURO-SCANNER v4.07 // СХЕМА КИБЕРИМПЛАНТОВ", "CP_BigTitle", 22, 13, CP_YELLOW)

        local hum = CYBERWARE:GetHumanity(ply)
        local maxHum = CYBERWARE:GetMaxHumanity(ply)
        local humCol = (hum <= CYBERWARE.Config.PsychosisStage2) and CP_RED or CP_CYAN
        draw.SimpleText("ЧЕЛОВЕЧНОСТЬ: " .. hum .. " / " .. maxHum .. "  |  СТАТУС: " .. (hum <= 10 and "КРИТИЧЕСКИЙ" or "СТАБИЛЬНЫЙ"), "CP_Tab", w - 65, 18, humCol, TEXT_ALIGN_RIGHT)

        -- Центральная капсула 2D голографического чертежа анатомии
        draw.RoundedBox(0, 370, 68, 360, 470, Color(11, 16, 25, 245))
        surface.SetDrawColor(Color(0, 240, 255, 16))
        for gx = 385, 715, 25 do surface.DrawLine(gx, 68, gx, 538) end
        for gy = 80, 525, 25 do surface.DrawLine(370, gy, 730, gy) end
        surface.SetDrawColor(Color(0, 240, 255, 85))
        surface.DrawOutlinedRect(370, 68, 360, 470, 1)
        DrawCyberCorners(370, 68, 360, 470, 14, CP_CYAN)

        -- Фоновые диагностические кольца
        DrawCircleOutline(cx, cy - 155, 42, 28, Color(0, 240, 255, 35))
        DrawCircleOutline(cx, cy - 35, 115, 36, Color(0, 240, 255, 22))
        DrawCircleOutline(cx, cy - 35, 85, 28, Color(254, 211, 48, 18))

        -- ================= ДЕТАЛИЗИРОВАННЫЙ 2D ЧЕРТЕЖ СТРОЕНИЯ ЧЕЛОВЕКА =================
        local bodyOutline = Color(0, 195, 255, 95)
        local boneWire    = Color(0, 240, 255, 185)
        local spineWire   = Color(254, 211, 48, 175)
        local heartWire   = Color(255, 30, 86, 190)

        -- 1. Череп, полушария мозга и оптический визор
        DrawCircleOutline(cx, cy - 158, 28, 24, boneWire)
        DrawCircleOutline(cx, cy - 164, 18, 16, spineWire) -- Нейрокортекс
        surface.SetDrawColor(CP_YELLOW)
        surface.DrawLine(cx - 16, cy - 150, cx + 16, cy - 150) -- Линия оптики Кироши
        surface.DrawOutlinedRect(cx - 18, cy - 154, 14, 7, 1)
        surface.DrawOutlinedRect(cx + 4, cy - 154, 14, 7, 1)

        -- 2. Контур шеи, трапеций и торса
        surface.SetDrawColor(bodyOutline)
        surface.DrawLine(cx - 12, cy - 132, cx - 16, cy - 112)
        surface.DrawLine(cx + 12, cy - 132, cx + 16, cy - 112)
        surface.DrawLine(cx - 16, cy - 112, cx - 64, cy - 104) -- Левое плечо
        surface.DrawLine(cx + 16, cy - 112, cx + 64, cy - 104) -- Правое плечо
        surface.DrawLine(cx - 56, cy - 92, cx - 38, cy + 40)   -- Левый бок торса
        surface.DrawLine(cx + 56, cy - 92, cx + 38, cy + 40)   -- Правый бок торса

        -- 3. Позвоночный столб и межпозвоночные диски
        surface.SetDrawColor(spineWire)
        surface.DrawLine(cx, cy - 130, cx, cy + 42)
        for sy = cy - 122, cy + 34, 10 do
            surface.DrawLine(cx - 7, sy, cx + 7, sy)
        end

        -- 4. Грудная клетка (ключицы, ребра) и контур Сердца
        surface.SetDrawColor(boneWire)
        surface.DrawLine(cx - 60, cy - 104, cx + 60, cy - 104)
        for r = 0, 4 do
            local ry = cy - 88 + r * 16
            local rw = 48 - r * 4
            surface.DrawLine(cx - rw, ry, cx - 8, ry + 5)
            surface.DrawLine(cx - rw, ry, cx - rw + 5, ry + 10)
            surface.DrawLine(cx + rw, ry, cx + 8, ry + 5)
            surface.DrawLine(cx + rw, ry, cx + rw - 5, ry + 10)
        end
        -- Пульсирующий узел сердца и аорты
        DrawCircleOutline(cx + 18, cy - 62, 11 + math.sin(cur * 6) * 2, 14, heartWire)
        surface.SetDrawColor(heartWire)
        surface.DrawLine(cx + 18, cy - 73, cx, cy - 95)

        -- 5. Тазовый каркас
        surface.SetDrawColor(boneWire)
        surface.DrawLine(cx - 38, cy + 40, cx + 38, cy + 40)
        surface.DrawLine(cx - 38, cy + 40, cx - 28, cy + 62)
        surface.DrawLine(cx + 38, cy + 40, cx + 28, cy + 62)
        surface.DrawLine(cx - 28, cy + 62, cx + 28, cy + 62)

        -- 6. Верхние конечности (плечевые суставы, кости предплечий, кисти)
        DrawCircleOutline(cx - 62, cy - 102, 7, 12, CP_CYAN)
        DrawCircleOutline(cx + 62, cy - 102, 7, 12, CP_CYAN)

        surface.SetDrawColor(boneWire)
        -- Правая и левая рука на схеме
        surface.DrawLine(cx - 62, cy - 95, cx - 78, cy - 35)
        DrawCircleOutline(cx - 78, cy - 35, 6, 10, CP_YELLOW) -- Локоть
        surface.DrawLine(cx - 80, cy - 29, cx - 92, cy + 32)
        surface.DrawLine(cx - 75, cy - 29, cx - 86, cy + 32)
        DrawCircleOutline(cx - 89, cy + 36, 7, 10, CP_CYAN)   -- Кисть

        surface.DrawLine(cx + 62, cy - 95, cx + 78, cy - 35)
        DrawCircleOutline(cx + 78, cy - 35, 6, 10, CP_YELLOW) -- Локоть
        surface.DrawLine(cx + 80, cy - 29, cx + 92, cy + 32)
        surface.DrawLine(cx + 75, cy - 29, cx + 86, cy + 32)
        DrawCircleOutline(cx + 89, cy + 36, 7, 10, CP_CYAN)   -- Кисть

        -- 7. Нижние конечности (бедренные кости, коленные чашечки, голени, гидравлика стоп)
        DrawCircleOutline(cx - 30, cy + 58, 6, 10, CP_CYAN)
        DrawCircleOutline(cx + 30, cy + 58, 6, 10, CP_CYAN)

        surface.SetDrawColor(boneWire)
        surface.DrawLine(cx - 30, cy + 64, cx - 35, cy + 135)
        DrawCircleOutline(cx - 35, cy + 135, 7, 12, CP_YELLOW) -- Колено
        surface.DrawLine(cx - 37, cy + 142, cx - 40, cy + 208)
        surface.DrawLine(cx - 33, cy + 142, cx - 36, cy + 208)
        surface.DrawOutlinedRect(cx - 48, cy + 208, 18, 8, 1)  -- Лодыжка

        surface.DrawLine(cx + 30, cy + 64, cx + 35, cy + 135)
        DrawCircleOutline(cx + 35, cy + 135, 7, 12, CP_YELLOW) -- Колено
        surface.DrawLine(cx + 37, cy + 142, cx + 40, cy + 208)
        surface.DrawLine(cx + 33, cy + 142, cx + 36, cy + 208)
        surface.DrawOutlinedRect(cx + 30, cy + 208, 18, 8, 1)  -- Лодыжка

        -- Бегущий лазерный луч био-сканера
        local scanY = 75 + ((math.sin(cur * 1.4) + 1) * 0.5) * 455
        surface.SetDrawColor(Color(0, 240, 255, 190))
        surface.DrawLine(372, scanY, 728, scanY)
        draw.RoundedBox(0, 372, scanY - 6, 356, 12, Color(0, 240, 255, 22))

        -- Анатомические узлы и линии связи со слотами
        for slotKey, node in pairs(bodyNodes) do
            local eqList = CYBERWARE:GetEquippedList(ply, slotKey)
            local hasAny = (#eqList > 0)
            local pulseRadius = 7 + math.abs(math.sin(cur * 4)) * 4
            local nodeCol = hasAny and CP_YELLOW or Color(0, 240, 255, 140)

            draw.RoundedBox(6, node.x - 5, node.y - 5, 10, 10, nodeCol)
            DrawCircleOutline(node.x, node.y, pulseRadius, 12, nodeCol)

            surface.SetDrawColor(nodeCol)
            if node.side == "left" then
                local targetX = node.boxX + 320
                local targetY = node.boxY + 20
                local midX = targetX + 22
                surface.DrawLine(node.x, node.y, midX, targetY)
                surface.DrawLine(midX, targetY, targetX, targetY)

                local t = (cur * 1.8) % 1
                local px = Lerp(t, node.x, midX)
                local py = Lerp(t, node.y, targetY)
                if hasAny then draw.RoundedBox(4, px - 3, py - 3, 6, 6, CP_CYAN) end
            else
                local targetX = node.boxX
                local targetY = node.boxY + 20
                local midX = targetX - 22
                surface.DrawLine(node.x, node.y, midX, targetY)
                surface.DrawLine(midX, targetY, targetX, targetY)

                local t = (cur * 1.8) % 1
                local px = Lerp(t, node.x, midX)
                local py = Lerp(t, node.y, targetY)
                if hasAny then draw.RoundedBox(4, px - 3, py - 3, 6, 6, CP_CYAN) end
            end
        end

        -- Нижняя панель инспектора
        draw.RoundedBox(0, 25, 550, 710, 148, Color(15, 19, 28, 250))
        surface.SetDrawColor(CP_YELLOW)
        surface.DrawOutlinedRect(25, 550, 710, 148, 1)
        DrawCyberCorners(25, 550, 710, 148, 10, CP_YELLOW)

        if hoveredImplant then
            local tCol = CYBERWARE.TierColors[hoveredImplant.tier or 1] or CP_YELLOW
            draw.SimpleText("[УРОВЕНЬ " .. (hoveredImplant.tier or 1) .. "] " .. hoveredImplant.name, "CP_Title", 40, 562, tCol)
            draw.SimpleText("НАГРУЗКА НА НЕЙРОСЕТЬ: -" .. (hoveredImplant.humanity or 0) .. " ЕД.", "CP_Desc", 720, 564, CP_RED, TEXT_ALIGN_RIGHT)
            DrawWrappedText(hoveredImplant.desc, "CP_Desc", 40, 590, 680, Color(230, 230, 230))
        else
            draw.SimpleText("НЕЙРО-ИНСПЕКТОР // НАВЕДИТЕ КУРСОР НА ЛЮБОЙ СЛОТ ДЛЯ АНАЛИЗА", "CP_Title", 40, 560, CP_CYAN)
            draw.SimpleText("Управление: [Z] — ОС (Сандевистан/Берсерк)  |  [X] — Взлом Кибердеки  |  [V] — Рывок Керензикова  |  [F] — Оптика Кироши", "CP_Desc", 40, 586, Color(200, 205, 215))

            draw.SimpleText("АКТИВНЫЕ ПРОТОКОЛЫ КИБЕРДЕКИ:", "CP_Small", 40, 614, CP_YELLOW)
            local chipX = 40
            for hackID, hack in pairs(CYBERWARE.Quickhacks) do
                if CYBERWARE:HasQuickhack(ply, hackID) then
                    surface.SetFont("CP_Small")
                    local tw, _ = surface.GetTextSize(hack.name)
                    local cw = tw + 16
                    if chipX + cw < 720 then
                        draw.RoundedBox(0, chipX, 632, cw, 22, Color(20, 45, 55, 240))
                        surface.SetDrawColor(CP_CYAN)
                        surface.DrawOutlinedRect(chipX, 632, cw, 22, 1)
                        draw.SimpleText(hack.name, "CP_Small", chipX + 8, 643, Color(240, 240, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        chipX = chipX + cw + 6
                    end
                end
            end
        end

        -- Нижняя правая панель телеметрии
        draw.RoundedBox(0, 755, 550, 320, 148, Color(15, 19, 28, 250))
        surface.SetDrawColor(CP_CYAN)
        surface.DrawOutlinedRect(755, 550, 320, 148, 1)
        DrawCyberCorners(755, 550, 320, 148, 10, CP_CYAN)

        draw.SimpleText("СВОДКА БИО-ТЕЛЕМЕТРИИ", "CP_Title", 770, 558, CP_YELLOW)
        draw.SimpleText("• Бонус макс. здоровья: +" .. bonusHP .. " HP", "CP_Desc", 770, 582, CP_GREEN)
        draw.SimpleText("• Поглощение урона: " .. dmgReduction .. "%", "CP_Desc", 770, 600, Color(220, 220, 220))
        draw.SimpleText("• Пассивная скорость: +" .. speedBonus .. "%", "CP_Desc", 770, 618, Color(220, 220, 220))
        draw.SimpleText("• Урон ближнего боя: +" .. meleeBonus .. "%", "CP_Desc", 770, 636, Color(220, 220, 220))
        draw.SimpleText("• Урон огнестрела: +" .. gunBonus .. "%", "CP_Desc", 770, 654, Color(220, 220, 220))
        draw.SimpleText("• Уклонение / Рикошет: " .. dodgeBonus .. "%", "CP_Desc", 770, 672, CP_CYAN)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(42, 32)
    closeBtn:SetPos(1048, 10)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and CP_RED or Color(40, 20, 30))
        surface.SetDrawColor(CP_RED)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("X", "CP_Title", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Close() end

    for slotKey, node in pairs(bodyNodes) do
        local catData = CYBERWARE.Categories[slotKey]
        local maxSlots = catData.maxSlots or 1
        local eqList = CYBERWARE:GetEquippedList(ply, slotKey)
        local panelH = 32 + (maxSlots * 28)

        local catPnl = vgui.Create("DPanel", frame)
        catPnl:SetPos(node.boxX, node.boxY)
        catPnl:SetSize(320, panelH)
        catPnl.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(16, 20, 30, 240))
            surface.SetDrawColor(#eqList > 0 and CP_CYAN or Color(50, 58, 75))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            DrawCyberCorners(0, 0, w, h, 6, #eqList > 0 and CP_YELLOW or Color(70, 80, 100))

            draw.SimpleText(catData.name, "CP_Tab", 10, 6, CP_YELLOW)
            draw.SimpleText("СЛОТЫ: " .. #eqList .. "/" .. maxSlots, "CP_Small", w - 10, 9, CP_CYAN, TEXT_ALIGN_RIGHT)
        end

        for s = 1, maxSlots do
            local eqItem = eqList[s]
            local slotBtn = vgui.Create("DButton", catPnl)
            slotBtn:SetPos(8, 28 + (s - 1) * 27)
            slotBtn:SetSize(304, 24)
            slotBtn:SetText("")

            slotBtn.Paint = function(self, w, h)
                if eqItem then
                    local tCol = CYBERWARE.TierColors[eqItem.data.tier or 1] or CP_CYAN
                    draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(32, 52, 68) or Color(22, 30, 44))
                    draw.RoundedBox(0, 0, 0, 5, h, tCol)
                    surface.SetDrawColor(tCol)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText("[МК." .. (eqItem.data.tier or 1) .. "] " .. eqItem.data.name, "CP_Desc", 12, h / 2, Color(245, 245, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("-" .. eqItem.data.humanity, "CP_Small", w - 8, h / 2, CP_RED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                else
                    draw.RoundedBox(0, 0, 0, w, h, Color(12, 14, 20))
                    surface.SetDrawColor(Color(38, 42, 55))
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText("— СВОБОДНЫЙ РАЗЪЕМ —", "CP_Small", 12, h / 2, Color(90, 98, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end

            slotBtn.OnCursorEntered = function()
                if eqItem then
                    hoveredImplant = eqItem.data
                    surface.PlaySound("buttons/lightswitch2.wav")
                end
            end
        end
    end
end

concommand.Add("cyber_my_implants", function() CYBERWARE:OpenPersonalMenu() end)

-- ================= АДМИН-ТЕРМИНАЛ РИППЕРДОКА (F6) =================
function CYBERWARE:OpenRipperdocMenu()
    if (self.LastRipperToggle or 0) > CurTime() then return end
    self.LastRipperToggle = CurTime() + 0.30

    local localPly = LocalPlayer()
    if not self:IsAdmin(localPly) then
        AddLocalNotice("ДОСТУП ЗАПРЕЩЕН: Нужны права администратора (ваш ранг: " .. tostring(localPly:GetUserGroup()) .. ")", true)
        return
    end

    if IsValid(self.RipperFrame) then
        self.RipperFrame:Remove()
        surface.PlaySound("buttons/combine_button2.wav")
        return
    end

    surface.PlaySound("buttons/combine_button1.wav")
    local selectedPatient = localPly
    local currentTab = "OS"

    local frame = vgui.Create("DFrame")
    self.RipperFrame = frame
    frame:SetSize(980, 660)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()

    frame.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, CP_DARK)
        surface.SetDrawColor(CP_YELLOW)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        draw.RoundedBox(0, 2, 2, w - 4, 46, Color(18, 22, 32, 255))
        surface.SetDrawColor(Color(50, 55, 70))
        surface.DrawLine(2, 48, w - 2, 48)
        draw.SimpleText("ТЕРМИНАЛ РИППЕРДОКА [АДМИН + АВТОСОХРАНЕНИЕ]", "CP_BigTitle", 20, 10, CP_YELLOW)

        if IsValid(selectedPatient) then
            local hum = CYBERWARE:GetHumanity(selectedPatient)
            local maxHum = CYBERWARE:GetMaxHumanity(selectedPatient)
            local humCol = (hum <= CYBERWARE.Config.PsychosisStage2) and CP_RED or CP_CYAN
            draw.SimpleText("ЧЕЛОВЕЧНОСТЬ ПАЦИЕНТА: " .. hum .. " / " .. maxHum .. " ЕД.", "CP_Title", 325, 62, humCol)
        end
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(42, 32)
    closeBtn:SetPos(928, 8)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and CP_RED or Color(40, 20, 30))
        surface.SetDrawColor(CP_RED)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("X", "CP_Title", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Close() end

    local targetCombo = vgui.Create("DComboBox", frame)
    targetCombo:SetPos(20, 58)
    targetCombo:SetSize(285, 28)
    targetCombo:SetValue("Пациент: " .. localPly:Nick() .. " (Вы)")

    for _, p in ipairs(player.GetAll()) do
        targetCombo:AddChoice(p:Nick(), p)
    end

    local humButtons = {
        { label = "-50", delta = -50, reset = false, w = 48 },
        { label = "-10", delta = -10, reset = false, w = 48 },
        { label = "+10", delta = 10,  reset = false, w = 48 },
        { label = "+50", delta = 50,  reset = false, w = 48 },
        { label = "СБРОС (100)", delta = 0, reset = true, w = 100 },
    }

    local bx = 640
    for _, bData in ipairs(humButtons) do
        local hBtn = vgui.Create("DButton", frame)
        hBtn:SetPos(bx, 58)
        hBtn:SetSize(bData.w, 28)
        hBtn:SetText("")
        hBtn.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(35, 55, 75) or Color(22, 28, 40))
            surface.SetDrawColor(bData.delta < 0 and CP_RED or CP_CYAN)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(bData.label, "CP_Desc", w / 2, h / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        hBtn.DoClick = function()
            if not IsValid(selectedPatient) then return end
            net.Start("Cyberware_AdjustMaxHumanity")
            net.WriteEntity(selectedPatient)
            net.WriteInt(bData.delta, 16)
            net.WriteBool(bData.reset)
            net.SendToServer()
        end
        bx = bx + bData.w + 6
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(240, 100)
    scroll:SetSize(720, 540)

    local function RefreshContent()
        scroll:Clear()
        if not IsValid(selectedPatient) then selectedPatient = localPly end

        if currentTab == "SCRIPTS" then
            for hackID, hack in pairs(CYBERWARE.Quickhacks) do
                local card = scroll:Add("DPanel")
                card:SetTall(96)
                card:Dock(TOP)
                card:DockMargin(0, 0, 8, 10)

                card.Paint = function(self, w, h)
                    local unlocked = CYBERWARE:HasQuickhack(selectedPatient, hackID)
                    draw.RoundedBox(0, 0, 0, w, h, unlocked and Color(20, 48, 45, 240) or CP_CARD)
                    surface.SetDrawColor(unlocked and CP_GREEN or Color(60, 65, 80))
                    surface.DrawOutlinedRect(0, 0, w, h, 1)

                    draw.SimpleText(hack.name .. " [КД: " .. hack.cooldown .. "с]", "CP_Title", 15, 10, CP_YELLOW)
                    DrawWrappedText(hack.desc, "CP_Desc", 15, 36, w - 185, Color(220, 220, 220))
                end

                local btn = vgui.Create("DButton", card)
                btn:SetSize(145, 40)
                btn:SetPos(540, 28)
                btn:SetText("")
                btn.Paint = function(self, w, h)
                    local unlocked = CYBERWARE:HasQuickhack(selectedPatient, hackID)
                    draw.RoundedBox(0, 0, 0, w, h, unlocked and CP_RED or CP_GREEN)
                    draw.SimpleText(unlocked and "ИЗЪЯТЬ СКРИПТ" or "ВЫДАТЬ СКРИПТ", "CP_Tab", w / 2, h / 2, Color(10, 10, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btn.DoClick = function()
                    net.Start("Cyberware_ToggleQuickhack")
                    net.WriteEntity(selectedPatient)
                    net.WriteString(hackID)
                    net.SendToServer()
                    timer.Simple(0.1, RefreshContent)
                end
            end
            return
        end

        local list = {}
        for id, imp in pairs(CYBERWARE.Implants) do
            if imp.slot == currentTab then
                table.insert(list, { id = id, data = imp })
            end
        end
        table.sort(list, function(a, b)
            if (a.data.tier or 1) == (b.data.tier or 1) then
                return a.data.name < b.data.name
            end
            return (a.data.tier or 1) < (b.data.tier or 1)
        end)

        for _, item in ipairs(list) do
            local id, imp = item.id, item.data
            local tierCol = CYBERWARE.TierColors[imp.tier or 1] or CP_YELLOW

            local card = scroll:Add("DPanel")
            card:SetTall(106)
            card:Dock(TOP)
            card:DockMargin(0, 0, 8, 10)

            card.Paint = function(self, w, h)
                local equipped = CYBERWARE:HasImplant(selectedPatient, id)
                draw.RoundedBox(0, 0, 0, w, h, equipped and Color(25, 45, 55, 245) or CP_CARD)
                surface.SetDrawColor(equipped and CP_CYAN or tierCol)
                surface.DrawOutlinedRect(0, 0, w, h, equipped and 2 or 1)
                draw.RoundedBox(0, 0, 0, 6, h, tierCol)

                draw.SimpleText("[УР. " .. (imp.tier or 1) .. "] " .. imp.name, "CP_Title", 16, 10, tierCol)
                draw.SimpleText("Нагрузка на психику: -" .. imp.humanity .. " ед.", "CP_Desc", 16, 32, CP_RED)
                DrawWrappedText(imp.desc, "CP_Desc", 16, 52, w - 185, Color(220, 220, 220))
            end

            local btn = vgui.Create("DButton", card)
            btn:SetSize(140, 42)
            btn:SetPos(545, 32)
            btn:SetText("")
            btn.Paint = function(self, w, h)
                local equipped = CYBERWARE:HasImplant(selectedPatient, id)
                draw.RoundedBox(0, 0, 0, w, h, equipped and CP_RED or CP_CYAN)
                draw.SimpleText(equipped and "ДЕМОНТАЖ" or "ВЖИВИТЬ", "CP_Tab", w / 2, h / 2, Color(10, 10, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function()
                net.Start("Cyberware_InstallOnPlayer")
                net.WriteEntity(selectedPatient)
                net.WriteString(id)
                net.SendToServer()
                timer.Simple(0.1, RefreshContent)
            end
        end
    end

    targetCombo.OnSelect = function(self, idx, val, data)
        selectedPatient = data
        RefreshContent()
    end

    local tabY = 100
    for catKey, catData in SortedPairsByMemberValue(CYBERWARE.Categories, "order") do
        local tabBtn = vgui.Create("DButton", frame)
        tabBtn:SetPos(20, tabY)
        tabBtn:SetSize(205, 42)
        tabBtn:SetText("")
        tabBtn.Paint = function(self, w, h)
            local isActive = (currentTab == catKey)
            local eqCount = IsValid(selectedPatient) and #CYBERWARE:GetEquippedList(selectedPatient, catKey) or 0
            local maxS = catData.maxSlots or 1
            draw.RoundedBox(0, 0, 0, w, h, isActive and CP_YELLOW or Color(18, 22, 30))
            surface.SetDrawColor(isActive and CP_YELLOW or Color(60, 65, 80))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(catData.name .. " [" .. eqCount .. "/" .. maxS .. "]", "CP_Tab", w / 2, h / 2, isActive and Color(15, 15, 20) or Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tabBtn.DoClick = function()
            currentTab = catKey
            RefreshContent()
        end
        tabY = tabY + 48
    end

    local scriptTabBtn = vgui.Create("DButton", frame)
    scriptTabBtn:SetPos(20, tabY + 10)
    scriptTabBtn:SetSize(205, 46)
    scriptTabBtn:SetText("")
    scriptTabBtn.Paint = function(self, w, h)
        local isActive = (currentTab == "SCRIPTS")
        draw.RoundedBox(0, 0, 0, w, h, isActive and CP_CYAN or Color(18, 35, 42))
        surface.SetDrawColor(CP_CYAN)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText("СКРИПТЫ ДЕКИ (ВЫДАЧА)", "CP_Tab", w / 2, h / 2, isActive and Color(10, 10, 15) or CP_CYAN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    scriptTabBtn.DoClick = function()
        currentTab = "SCRIPTS"
        RefreshContent()
    end

    RefreshContent()
end

net.Receive("Cyberware_OpenRipperdoc", function() CYBERWARE:OpenRipperdocMenu() end)
concommand.Add("cyber_ripperdoc", function() CYBERWARE:OpenRipperdocMenu() end)

-- Меню быстрого взлома Кибердеки
concommand.Add("cyber_quickhack_menu", function()
    local ply = LocalPlayer()
    local deckImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if not deckImp or not deckImp.hackRange then return end

    local target = CYBERWARE:FindSmartHackTarget()
    if not IsValid(target) then
        AddLocalNotice("В зоне видимости Кибердеки нет целей!", true)
        return
    end

    local menu = vgui.Create("DFrame")
    menu:SetSize(480, 420)
    menu:Center()
    menu:SetTitle("")
    menu:MakePopup()

    local tName = target:IsPlayer() and target:Nick() or target:GetClass()
    menu.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, CP_DARK)
        surface.SetDrawColor(CP_RED)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText("ЦЕЛЬ ЗАХВАЧЕНА: " .. tName, "CP_Title", 15, 12, CP_RED)
    end

    local scroll = vgui.Create("DScrollPanel", menu)
    scroll:SetPos(15, 45)
    scroll:SetSize(450, 360)

    for id, hack in pairs(CYBERWARE.Quickhacks) do
        if CYBERWARE:HasQuickhack(ply, id) then
            local btn = scroll:Add("DButton")
            btn:SetTall(68)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 6, 8)
            btn:SetText("")
            btn.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(35, 48, 65) or CP_CARD)
                surface.SetDrawColor(CP_CYAN)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(hack.name .. " [КД: " .. hack.cooldown .. "с]", "CP_Title", 10, 6, CP_YELLOW)
                DrawWrappedText(hack.desc, "CP_Desc", 10, 28, w - 20, Color(210, 210, 210))
            end
            btn.DoClick = function()
                if IsValid(target) then
                    net.Start("Cyberware_UseQuickhack")
                    net.WriteString(id)
                    net.WriteEntity(target)
                    net.SendToServer()
                end
                menu:Close()
            end
        end
    end
end)