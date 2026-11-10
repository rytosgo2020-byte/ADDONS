-- lua/autorun/client/cyberware_ui.lua
if SERVER then return end

CYBERWARE = CYBERWARE or {}

-- ================= НАСТРОЙКИ КЛИЕНТА =================
local KEY_ACTIONS = { "OS", "Quickhack", "Kerenzikov", "Kiroshi", "Arms", "Camo", "PlayerMenu", "AdminMenu" }
for _, action in ipairs(KEY_ACTIONS) do
    CreateClientConVar("cyber_key_" .. string.lower(action), tostring(CYBERWARE.Config.DefaultKeys[action] or 0), true, false)
end
local cvHUD      = CreateClientConVar("cyber_hud", "1", true, false, "Показывать HUD имплантов")
local cvPsychoFX = CreateClientConVar("cyber_psycho_fx", "1", true, false, "Интенсивность визуальных эффектов психоза (0-1)", 0, 1)
local cvGhosts   = CreateClientConVar("cyber_ghosts", "1", true, false, "Шлейф остаточных образов Сандевистана")
local cvUISounds = CreateClientConVar("cyber_ui_sounds", "1", true, false, "Звуки интерфейса")

local function KeyCode(action)
    local cv = GetConVar("cyber_key_" .. string.lower(action))
    return cv and cv:GetInt() or CYBERWARE.Config.DefaultKeys[action]
end

-- ================= ПАЛИТРА И МАСШТАБ =================
local C = {
    yellow = Color(252, 226, 5),
    cyan   = Color(94, 246, 255),
    red    = Color(255, 72, 72),
    pink   = Color(255, 20, 100),
    green  = Color(40, 255, 150),
    orange = Color(255, 140, 40),
    white  = Color(232, 238, 245),
    dim    = Color(150, 160, 175),
    dark   = Color(80, 88, 105),
    bg     = Color(6, 8, 13, 246),
    panel  = Color(12, 15, 23, 240),
    panel2 = Color(18, 22, 33, 245),
    line   = Color(38, 46, 62),
}
local NOTICE_COLORS = { [0] = C.cyan, [1] = C.red, [2] = C.green, [3] = C.yellow }
local NOTICE_TAGS = { [0] = "SYS", [1] = "ERR", [2] = "OK", [3] = "WARN" }

local function A(col, a) return Color(col.r, col.g, col.b, a) end
local function LerpColor(t, a, b)
    return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a or 255, b.a or 255))
end

local UIS = 1
local function S(v) return math.max(1, math.Round(v * UIS)) end

local wrapCache = {}

local function BuildFonts()
    UIS = math.Clamp(math.min(ScrW() / 1600, ScrH() / 900), 0.72, 1.6)
    wrapCache = {}
    local function F(name, font, size, weight)
        surface.CreateFont(name, { font = font, size = S(size), weight = weight, antialias = true, extended = true })
    end
    F("CW_Huge",   "Impact", 36, 500)
    F("CW_Title",  "Impact", 26, 500)
    F("CW_Sub",    "Impact", 20, 500)
    F("CW_HudNum", "Impact", 22, 500)
    F("CW_Head",   "Roboto", 17, 800)
    F("CW_Body",   "Roboto", 15, 500)
    F("CW_BodyB",  "Roboto", 15, 700)
    F("CW_Small",  "Roboto", 13, 600)
    F("CW_Tiny",   "Roboto", 11, 700)
    F("CW_Key",    "Roboto", 17, 900)
    F("CW_Glitch", "Impact", 30, 500)
end
BuildFonts()
hook.Add("OnScreenSizeChanged", "Cyberware_Fonts", BuildFonts)

-- ================= ГРАФИЧЕСКИЕ ПРИМИТИВЫ =================
local matBlur   = Material("pp/blurscreen")
local matGradL  = Material("vgui/gradient-l")
local matGradR  = Material("vgui/gradient-r")
local matGradU  = Material("vgui/gradient-u")
local matGradD  = Material("vgui/gradient-d")
local matBeam   = Material("trails/laser")
local matBolt   = Material("trails/electric")
local matGlow   = Material("sprites/light_glow02_add")

local function ChamferPoly(x, y, w, h, c)
    return {
        { x = x + c, y = y }, { x = x + w, y = y }, { x = x + w, y = y + h - c },
        { x = x + w - c, y = y + h }, { x = x, y = y + h }, { x = x, y = y + c },
    }
end

local function DrawChamfer(x, y, w, h, c, col)
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly(ChamferPoly(x, y, w, h, c))
end

local function DrawChamferOutline(x, y, w, h, c, col, th)
    surface.SetDrawColor(col)
    for t = 0, (th or 1) - 1 do
        local p = ChamferPoly(x + t, y + t, w - 1 - t * 2, h - 1 - t * 2, math.max(0, c - t))
        for i = 1, #p do
            local a, b = p[i], p[i % #p + 1]
            surface.DrawLine(a.x, a.y, b.x, b.y)
        end
    end
end

local function DrawCorners(x, y, w, h, len, col, th)
    surface.SetDrawColor(col)
    th = th or 1
    surface.DrawRect(x, y, len, th)                 surface.DrawRect(x, y, th, len)
    surface.DrawRect(x + w - len, y, len, th)       surface.DrawRect(x + w - th, y, th, len)
    surface.DrawRect(x, y + h - th, len, th)        surface.DrawRect(x, y + h - len, th, len)
    surface.DrawRect(x + w - len, y + h - th, len, th) surface.DrawRect(x + w - th, y + h - len, th, len)
end

local function DrawCircle(cx, cy, r, seg, col)
    surface.SetDrawColor(col)
    local px, py
    for i = 0, seg do
        local a = math.rad(i / seg * 360)
        local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        if px then surface.DrawLine(px, py, x, y) end
        px, py = x, y
    end
end

local function DrawBlur(pnl, amount)
    local x, y = pnl:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(matBlur)
    for i = 1, 3 do
        matBlur:SetFloat("$blur", (i / 3) * (amount or 4))
        matBlur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

local function DrawScanlines(x, y, w, h, alpha, step)
    surface.SetDrawColor(0, 0, 0, alpha)
    for yy = y, y + h, step or 3 do surface.DrawRect(x, yy, w, 1) end
end

-- Края экрана (виньетка) заданного цвета
local function DrawEdges(col, size)
    local w, h = ScrW(), ScrH()
    size = size or S(220)
    surface.SetDrawColor(col)
    surface.SetMaterial(matGradL) surface.DrawTexturedRect(0, 0, size, h)
    surface.SetMaterial(matGradR) surface.DrawTexturedRect(w - size, 0, size, h)
    surface.SetMaterial(matGradU) surface.DrawTexturedRect(0, 0, w, size * 0.7)
    surface.SetMaterial(matGradD) surface.DrawTexturedRect(0, h - size * 0.7, w, size * 0.7)
end

-- Текст с хроматическим сдвигом (статичным — без дрожания)
local function GlitchText(text, font, x, y, col, ax, ay, off)
    off = off or S(2)
    draw.SimpleText(text, font, x - off, y, A(C.pink, col.a * 0.55), ax, ay)
    draw.SimpleText(text, font, x + off, y, A(C.cyan, col.a * 0.55), ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

local function WrapText(text, font, maxW)
    local key = font .. "|" .. maxW .. "|" .. (text or "")
    if wrapCache[key] then return wrapCache[key] end
    surface.SetFont(font)
    local lines, cur = {}, ""
    for _, word in ipairs(string.Explode(" ", text or "")) do
        local test = cur == "" and word or (cur .. " " .. word)
        if surface.GetTextSize(test) > maxW and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = test
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    wrapCache[key] = lines
    return lines
end

local function DrawWrapped(text, font, x, y, maxW, col, lineH, maxLines)
    local lines = WrapText(text, font, maxW)
    lineH = lineH or S(16)
    for i, line in ipairs(lines) do
        if maxLines and i > maxLines then break end
        draw.SimpleText(line, font, x, y + (i - 1) * lineH, col)
    end
    return math.min(#lines, maxLines or #lines) * lineH
end

-- Сегментированная полоса
local function DrawSegBar(x, y, w, h, frac, col, segs, gap)
    segs = segs or 20
    gap = gap or S(2)
    local sw = (w - gap * (segs - 1)) / segs
    frac = math.Clamp(frac, 0, 1)
    for i = 0, segs - 1 do
        local sx = x + i * (sw + gap)
        local fill = math.Clamp(frac * segs - i, 0, 1)
        surface.SetDrawColor(A(col, 28))
        surface.DrawRect(sx, y, sw, h)
        if fill > 0 then
            surface.SetDrawColor(col)
            surface.DrawRect(sx, y, sw * fill, h)
        end
    end
end

-- ================= ЗВУКИ ИНТЕРФЕЙСА =================
local UI_SOUNDS = {
    hover   = { "garrysmod/ui_hover.wav", 100, 0.35 },
    click   = { "garrysmod/ui_click.wav", 110, 0.6 },
    tab     = { "buttons/button16.wav", 130, 0.35 },
    open    = { "buttons/combine_button1.wav", 120, 0.5 },
    close   = { "buttons/combine_button2.wav", 120, 0.4 },
    notify  = { "buttons/blip1.wav", 120, 0.35 },
    success = { "buttons/button17.wav", 120, 0.4 },
    warn    = { "buttons/button18.wav", 110, 0.45 },
    error   = { "buttons/combine_button_locked.wav", 120, 0.4 },
    hack    = { "npc/scanner/scanner_blip1.wav", 130, 0.45 },
    lock    = { "npc/turret_floor/ping.wav", 140, 0.3 },
}
local lastHover = 0
local function UISound(kind)
    if not cvUISounds:GetBool() then return end
    if kind == "hover" then
        if RealTime() - lastHover < 0.05 then return end
        lastHover = RealTime()
    end
    local s = UI_SOUNDS[kind]
    local ply = LocalPlayer()
    if not s then return end
    if IsValid(ply) then
        ply:EmitSound(s[1], 75, s[2], s[3], CHAN_STATIC)
    else
        surface.PlaySound(s[1])
    end
end

-- ================= УВЕДОМЛЕНИЯ =================
local notices = {}

local function AddNotice(text, kind)
    kind = kind or 0
    table.insert(notices, 1, { text = text, kind = kind, born = RealTime(), life = 4.5, y = nil })
    while #notices > 6 do table.remove(notices) end
    UISound(kind == 1 and "error" or kind == 2 and "success" or kind == 3 and "warn" or "notify")
end
CYBERWARE.AddNotice = AddNotice

net.Receive("Cyberware_Notify", function()
    local msg = net.ReadString()
    AddNotice(msg, net.ReadUInt(2))
end)

local function DrawNotices()
    local now = RealTime()
    local w = S(440)
    local h = S(38)
    local baseY = S(110)
    for i = #notices, 1, -1 do
        if now - notices[i].born > notices[i].life then table.remove(notices, i) end
    end
    for i, n in ipairs(notices) do
        local age = now - n.born
        local targetY = baseY + (i - 1) * (h + S(6))
        n.y = n.y and Lerp(FrameTime() * 12, n.y, targetY) or targetY
        local slide = 1 - math.Clamp(age / 0.22, 0, 1)
        local fade = math.Clamp((n.life - age) / 0.4, 0, 1)
        local x = ScrW() - w - S(20) + slide * slide * S(120)
        local col = NOTICE_COLORS[n.kind] or C.cyan
        local alpha = fade * 255

        DrawChamfer(x, n.y, w, h, S(8), Color(8, 10, 16, 230 * fade))
        DrawChamferOutline(x, n.y, w, h, S(8), A(col, 160 * fade))
        surface.SetDrawColor(A(col, 50 * fade))
        surface.SetMaterial(matGradL)
        surface.DrawTexturedRect(x, n.y, w * 0.35, h)

        local tagW = S(48)
        DrawChamfer(x + S(6), n.y + S(7), tagW, h - S(14), S(4), A(col, 230 * fade))
        draw.SimpleText(NOTICE_TAGS[n.kind] or "SYS", "CW_Tiny", x + S(6) + tagW / 2, n.y + h / 2, Color(10, 10, 14, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local tx = x + tagW + S(16)
        local lines = WrapText(n.text, "CW_Small", w - tagW - S(28))
        if #lines > 1 then
            draw.SimpleText(lines[1], "CW_Small", tx, n.y + h / 2 - S(8), A(C.white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(lines[2] .. (#lines > 2 and "…" or ""), "CW_Small", tx, n.y + h / 2 + S(8), A(C.white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(n.text, "CW_BodyB", tx, n.y + h / 2, A(C.white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- полоска оставшегося времени
        surface.SetDrawColor(A(col, 200 * fade))
        surface.DrawRect(x + S(8), n.y + h - S(3), (w - S(16)) * (1 - age / n.life), S(2))
    end
end

-- ================= ЭКРАННЫЕ ЭФФЕКТЫ (состояние) =================
local fx = {}

net.Receive("Cyberware_ScreenEffect", function()
    local name = net.ReadString()
    local dur = net.ReadFloat()
    local now = CurTime()
    if dur <= 0 then
        if fx[name] then fx[name].finish = math.min(fx[name].finish, now) end
        return
    end
    local cur = fx[name]
    if cur and cur.finish > now then
        cur.finish = now + dur -- продление (например, убийство под Сандевистаном)
    else
        fx[name] = { start = now, finish = now + dur, seed = math.random(1, 100000) }
    end
end)

-- Интенсивность эффекта 0..1 с плавным появлением/исчезновением
local function FxAmount(name, fadeIn, fadeOut)
    local f = fx[name]
    if not f then return 0 end
    local now = CurTime()
    fadeIn, fadeOut = fadeIn or 0.25, fadeOut or 0.45
    if now > f.finish + fadeOut then
        fx[name] = nil
        return 0
    end
    local a = math.Clamp((now - f.start) / fadeIn, 0, 1)
    if now > f.finish then a = a * (1 - (now - f.finish) / fadeOut) end
    return a
end

local function FxRemaining(name)
    local f = fx[name]
    return f and math.max(0, f.finish - CurTime()) or 0
end

-- ================= ПСИХОЗ: ГАЛЛЮЦИНАЦИИ (без тряски камеры) =================
local PSYCHO_MESSAGES = {
    "КРИТИЧЕСКИЙ СБОЙ // НЕЙРОСЕТЬ ПОВРЕЖДЕНА",
    "ОНИ СМОТРЯТ НА ТЕБЯ",
    "SYSTEM_ERR: CYBERPSYCHOSIS_OVERFLOW_0x9F",
    "ПАМЯТЬ ПЕРЕЗАПИСАНА // ТЫ БОЛЬШЕ НЕ ЧЕЛОВЕК",
    "ВНИМАНИЕ: ОТКАЗ ЛОБНЫХ ДОЛЕЙ",
    "ХРОМ ГОВОРИТ С ТОБОЙ",
    "ЛИЧНОСТЬ НЕ НАЙДЕНА // 404",
    "ТЕЛО — ЭТО ПРОСТО МЯСО",
}
local PSYCHO_SOUNDS_LIGHT = { "ambient/energy/zap1.wav", "ambient/energy/zap2.wav", "ambient/levels/prison/radio_random3.wav", "ambient/levels/prison/radio_random9.wav" }
local PSYCHO_SOUNDS_HEAVY = { "ambient/levels/citadel/strange_talk3.wav", "ambient/levels/citadel/strange_talk5.wav", "ambient/levels/citadel/strange_talk8.wav", "npc/stalker/breathing3.wav" }
local MIRAGE_MODELS = {
    "models/player/corpse1.mdl",
    "models/player/charple.mdl",
    "models/player/zombie_fast.mdl",
    "models/player/combine_super_soldier.mdl",
}

local psycho = { flashStart = 0, flashEnd = 0, text = "", slices = {}, textX = 0.5, textY = 0.3 }
local mirages = {}

net.Receive("Cyberware_TriggerHallucination", function()
    local severity = net.ReadFloat()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local fxMul = cvPsychoFX:GetFloat()

    local now = CurTime()
    psycho.flashStart = now
    psycho.flashEnd = now + math.Rand(0.35, 0.7) * (0.6 + severity)
    psycho.text = PSYCHO_MESSAGES[math.random(#PSYCHO_MESSAGES)]
    psycho.textX = math.Rand(0.35, 0.65)
    psycho.textY = math.Rand(0.22, 0.4)
    psycho.slices = {}
    for i = 1, math.ceil(severity * 8) do
        psycho.slices[i] = {
            y = math.Rand(0, 1), h = math.Rand(0.004, 0.025),
            off = math.Rand(-1, 1) * severity * 40, red = math.random() < 0.6,
        }
    end

    local pool = severity > 0.45 and PSYCHO_SOUNDS_HEAVY or PSYCHO_SOUNDS_LIGHT
    ply:EmitSound(pool[math.random(#pool)], 70, math.random(85, 105), 0.35 + severity * 0.35, CHAN_STATIC)

    if severity < 0.4 or fxMul <= 0 then return end
    for _ = 1, (severity > 0.75 and 2 or 1) do
        local ang = Angle(0, ply:EyeAngles().yaw + math.Rand(-70, 70), 0)
        local spawnPos = ply:GetPos() + ang:Forward() * math.Rand(260, 460)
        local phantom = ClientsideModel(MIRAGE_MODELS[math.random(#MIRAGE_MODELS)], RENDERGROUP_TRANSLUCENT)
        if IsValid(phantom) then
            phantom:SetPos(spawnPos)
            phantom:SetNoDraw(true)
            local seq = phantom:LookupSequence("run_all_01")
            phantom:ResetSequence(seq and seq > 0 and seq or 1)
            mirages[#mirages + 1] = {
                ent = phantom, pos = spawnPos, born = now, life = math.Rand(1.6, 2.8),
                speed = math.Rand(180, 300), red = math.random() < 0.7,
            }
        end
    end
end)

-- ================= МИРОВЫЕ ЭФФЕКТЫ =================
local worldFx = {}
local pinged = {}       -- [ent] = until
local ghosts = {}

local function SpawnGhost(ply, col, life, alpha)
    if #ghosts >= 48 or not IsValid(ply) then return end
    local ghost = ClientsideModel(ply:GetModel(), RENDERGROUP_TRANSLUCENT)
    if not IsValid(ghost) then return end
    ghost:SetNoDraw(true)
    ghost:SetPos(ply:GetPos())
    ghost:SetAngles(Angle(0, ply:EyeAngles().yaw, 0))
    ghost:SetSkin(ply:GetSkin())
    for _, bg in ipairs(ply:GetBodyGroups() or {}) do ghost:SetBodygroup(bg.id, ply:GetBodygroup(bg.id)) end
    ghost:SetSequence(ply:GetSequence())
    ghost:SetCycle(ply:GetCycle())
    for i = 0, ply:GetNumPoseParameters() - 1 do
        local name = ply:GetPoseParameterName(i)
        if name then ghost:SetPoseParameter(name, ply:GetPoseParameter(name)) end
    end
    ghost:SetupBones()
    ghosts[#ghosts + 1] = { ent = ghost, owner = ply, pos = ply:GetPos(), col = col, born = CurTime(), life = life, alpha = alpha or 0.5 }
end

local FX_LIFE = { hack = 0.45, chain = 0.3, emp = 0.7, pulse = 0.7, slam = 0.8, dash = 0.4, camo = 0.6, ice = 0.6, rocket = 1.5 }

net.Receive("Cyberware_FX", function()
    local kind = net.ReadString()
    local a = net.ReadEntity()
    local b = net.ReadEntity()
    local pos = net.ReadVector()
    local e = { kind = kind, a = a, b = b, pos = pos, born = CurTime(), life = FX_LIFE[kind] or 0.5 }

    if kind == "rocket" and IsValid(a) then
        e.from = a:GetShootPos() - Vector(0, 0, 8) + a:GetRight() * 8
        e.life = math.Clamp(e.from:Distance(pos) / 3000, 0.05, 1.4)
    elseif kind == "dash" and IsValid(a) then
        for i = 0, 3 do
            timer.Simple(i * 0.04, function()
                if IsValid(a) then SpawnGhost(a, Color(94, 246, 255), 0.35, 0.45) end
            end)
        end
    elseif kind == "slam" then
        local ed = EffectData()
        ed:SetOrigin(pos)
        ed:SetScale(1.5)
        util.Effect("ThumperDust", ed)
    elseif kind == "emp" or kind == "chain" then
        local ed = EffectData()
        ed:SetOrigin(IsValid(b) and b:WorldSpaceCenter() or pos)
        ed:SetMagnitude(2)
        ed:SetScale(1)
        ed:SetRadius(4)
        util.Effect("Sparks", ed)
    end
    worldFx[#worldFx + 1] = e
end)

net.Receive("Cyberware_Ping", function()
    local dur = net.ReadFloat()
    local n = net.ReadUInt(7)
    local untilT = CurTime() + dur
    for _ = 1, n do
        local ent = net.ReadEntity()
        if IsValid(ent) then pinged[ent] = untilT end
    end
    UISound("lock")
end)

-- Ломаная молния между точками (перегенерация 20 раз в секунду)
local function DrawBolt(from, to, col, width, segs, jitter)
    segs = segs or 8
    local dir = to - from
    render.SetMaterial(matBolt)
    render.StartBeam(segs + 1)
    local seed = math.floor(CurTime() * 20)
    for i = 0, segs do
        local t = i / segs
        local p = from + dir * t
        if i > 0 and i < segs then
            p = p + Vector(util.SharedRandom("cwb" .. i, -1, 1, seed), util.SharedRandom("cwb2" .. i, -1, 1, seed), util.SharedRandom("cwb3" .. i, -1, 1, seed)) * (jitter or 10)
        end
        render.AddBeam(p, width, t * 3, col)
    end
    render.EndBeam()
end

local function DrawRing(pos, radius, col, width, segs)
    segs = segs or 32
    render.SetMaterial(matBeam)
    render.StartBeam(segs + 1)
    for i = 0, segs do
        local ang = i / segs * math.pi * 2
        render.AddBeam(pos + Vector(math.cos(ang) * radius, math.sin(ang) * radius, 2), width, i / segs * 4, col)
    end
    render.EndBeam()
end

local function EntOrigin(ent, fallback)
    if not IsValid(ent) then return fallback end
    if ent == LocalPlayer() and not ent:ShouldDrawLocalPlayer() then
        return ent:GetShootPos() - Vector(0, 0, 14) + ent:GetAimVector() * 20 + ent:GetRight() * 10
    end
    return ent:WorldSpaceCenter()
end

hook.Add("PostDrawTranslucentRenderables", "Cyberware_3DEffects", function(depth, skybox)
    if depth or skybox then return end
    local now = CurTime()
    local localPly = LocalPlayer()

    -- Шлейф Сандевистана: остаточные образы с плавной сменой оттенка
    if cvGhosts:GetBool() then
        for _, ply in ipairs(player.GetAll()) do
            if ply:Alive() and ply:GetNW2Bool("Cyber_Sandevistan_Active", false) and ply:GetVelocity():Length2D() > 140 then
                if (ply.Cyber_NextGhost or 0) < now then
                    ply.Cyber_NextGhost = now + 0.055
                    SpawnGhost(ply, HSVToColor((now * 220 + ply:EntIndex() * 40) % 360, 0.75, 1), 0.55, 0.5)
                end
            end
        end
    end

    render.SuppressEngineLighting(true)
    for i = #ghosts, 1, -1 do
        local g = ghosts[i]
        local age = now - g.born
        if age > g.life or not IsValid(g.ent) then
            if IsValid(g.ent) then g.ent:Remove() end
            table.remove(ghosts, i)
        else
            local hide = g.owner == localPly and not localPly:ShouldDrawLocalPlayer()
                and g.pos:DistToSqr(localPly:GetPos()) < 90 * 90
            if not hide then
                render.SetColorModulation(g.col.r / 255, g.col.g / 255, g.col.b / 255)
                render.SetBlend((1 - age / g.life) * g.alpha)
                g.ent:DrawModel()
            end
        end
    end

    -- Галлюцинации: фантомы медленно приближаются и растворяются
    for i = #mirages, 1, -1 do
        local m = mirages[i]
        local age = now - m.born
        if age > m.life or not IsValid(m.ent) or not IsValid(localPly) then
            if IsValid(m.ent) then m.ent:Remove() end
            table.remove(mirages, i)
        else
            local dir = (localPly:GetPos() - m.pos)
            dir.z = 0
            dir:Normalize()
            m.pos = m.pos + dir * m.speed * FrameTime()
            m.ent:SetPos(m.pos)
            m.ent:SetAngles(Angle(0, dir:Angle().yaw, 0))
            m.ent:SetCycle((now * 1.2) % 1)
            m.ent:SetupBones()

            local alpha = math.min(age / 0.4, 1, (m.life - age) / 0.5) * 0.6 * cvPsychoFX:GetFloat()
            if m.red then render.SetColorModulation(1, 0.08, 0.25) else render.SetColorModulation(0.1, 0.9, 1) end
            render.SetBlend(alpha)
            m.ent:DrawModel()

            if m.pos:DistToSqr(localPly:GetPos()) < 90 * 90 then
                psycho.flashStart = now
                psycho.flashEnd = now + 0.3
                localPly:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 60, 90, 0.4, CHAN_STATIC)
                m.ent:Remove()
                table.remove(mirages, i)
            end
        end
    end
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)
    render.SuppressEngineLighting(false)

    -- Лучи, разряды, волны
    for i = #worldFx, 1, -1 do
        local e = worldFx[i]
        local t = (now - e.born) / e.life
        if t >= 1 then
            table.remove(worldFx, i)
        else
            local fade = 1 - t
            if e.kind == "hack" and IsValid(e.a) and IsValid(e.b) then
                DrawBolt(EntOrigin(e.a), e.b:WorldSpaceCenter(), Color(60, 255, 200, 255 * fade), 6, 10, 8)
                render.SetMaterial(matGlow)
                render.DrawSprite(e.b:WorldSpaceCenter(), 60 * fade + 20, 60 * fade + 20, Color(60, 255, 200, 200 * fade))
            elseif e.kind == "chain" and IsValid(e.a) and IsValid(e.b) then
                DrawBolt(e.a:WorldSpaceCenter(), e.b:WorldSpaceCenter(), Color(120, 200, 255, 255 * fade), 8, 8, 14)
            elseif e.kind == "ice" and IsValid(e.a) then
                render.SetMaterial(matGlow)
                render.DrawSprite(e.a:WorldSpaceCenter(), 120 * (0.6 + t), 160 * (0.6 + t), Color(94, 246, 255, 220 * fade))
                DrawRing(e.a:GetPos() + Vector(0, 0, 40), 30 + t * 30, Color(94, 246, 255, 255 * fade), 3, 6)
            elseif e.kind == "emp" then
                DrawRing(e.pos - Vector(0, 0, 30), 20 + t * 220, Color(90, 160, 255, 255 * fade), 10)
            elseif e.kind == "pulse" then
                DrawRing(e.pos, 20 + t * 240, Color(255, 120, 60, 255 * fade), 8)
            elseif e.kind == "slam" then
                DrawRing(e.pos, 30 + t * 320, Color(255, 170, 40, 255 * fade), 14)
                DrawRing(e.pos, 10 + t * 200, Color(255, 80, 40, 200 * fade), 8)
            elseif e.kind == "camo" and IsValid(e.a) then
                render.SetMaterial(matGlow)
                render.DrawSprite(e.a:WorldSpaceCenter(), 90, 140, Color(120, 200, 255, 160 * fade))
            elseif e.kind == "rocket" and e.from then
                local p = LerpVector(t, e.from, e.pos)
                local tail = LerpVector(math.max(0, t - 0.25), e.from, e.pos)
                render.SetMaterial(matBeam)
                render.DrawBeam(tail, p, 10, 0, 1, Color(255, 150, 60, 230))
                render.SetMaterial(matGlow)
                render.DrawSprite(p, 40, 40, Color(255, 200, 120, 255))
            end
        end
    end
end)

-- ================= ЦЕЛЕУКАЗАНИЕ КИБЕРДЕКИ =================
local hackTarget, hackTargetNext, hackTargetSince = nil, 0, 0

function CYBERWARE:FindSmartHackTarget()
    local ply = LocalPlayer()
    local deck = self:GetDeck(ply)
    if not deck then return nil end
    local maxRange = deck.hackRange or 950
    local shootPos = ply:GetShootPos()
    local aimVec = ply:GetAimVector()
    local best, bestDot = nil, 0.86

    for _, ent in ipairs(ents.GetAll()) do
        if ent ~= ply and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) and ent:Health() > 0 and not ent:IsDormant() then
            local pos = ent:WorldSpaceCenter()
            if shootPos:DistToSqr(pos) <= maxRange * maxRange then
                local dot = aimVec:Dot((pos - shootPos):GetNormalized())
                if dot > bestDot then
                    local tr = util.TraceLine({ start = shootPos, endpos = pos, filter = ply, mask = MASK_SHOT })
                    if not tr.Hit or tr.Entity == ent then
                        bestDot, best = dot, ent
                    end
                end
            end
        end
    end
    return best
end

local function UpdateHackTarget()
    if CurTime() < hackTargetNext then return hackTarget end
    hackTargetNext = CurTime() + 0.1
    local t = CYBERWARE:FindSmartHackTarget()
    if t ~= hackTarget then
        hackTarget = t
        hackTargetSince = CurTime()
        if IsValid(t) then UISound("lock") end
    end
    return hackTarget
end

local function EntDisplayName(ent)
    if not IsValid(ent) then return "?" end
    if ent:IsPlayer() then return ent:Nick() end
    local phrase = language.GetPhrase(ent:GetClass())
    return string.upper(phrase or ent:GetClass())
end

-- ================= СКАНИРОВАНИЕ: ХАЛО =================
local kiroshiCache, kiroshiCacheTime = {}, 0
local function KiroshiTargets(ply)
    if CurTime() - kiroshiCacheTime < 0.2 then return kiroshiCache end
    kiroshiCacheTime = CurTime()
    local ocu = CYBERWARE:GetEquippedInSlot(ply, "OCULAR")
    local range = (ocu and ocu.scanRange) or 1500
    local list = {}
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
        if ent ~= ply and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) and ent:Health() > 0 then
            list[#list + 1] = ent
        end
    end
    kiroshiCache = list
    return list
end

hook.Add("PreDrawHalos", "Cyberware_Halos", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local now = CurTime()

    if ply:GetNW2Float("Cyber_Kiroshi_Active", 0) > now then
        local players, npcs = {}, {}
        for _, ent in ipairs(KiroshiTargets(ply)) do
            if ent:IsPlayer() then players[#players + 1] = ent else npcs[#npcs + 1] = ent end
        end
        if #players > 0 then halo.Add(players, C.yellow, 2, 2, 2, true, true) end
        if #npcs > 0 then halo.Add(npcs, C.red, 2, 2, 2, true, true) end
    end

    local pl = {}
    for ent, untilT in pairs(pinged) do
        if untilT < now or not IsValid(ent) or ent:Health() <= 0 then
            pinged[ent] = nil
        else
            pl[#pl + 1] = ent
        end
    end
    if #pl > 0 then halo.Add(pl, C.pink, 2, 2, 1, true, true) end

    if cvHUD:GetBool() and IsValid(hackTarget) and CYBERWARE:GetDeck(ply) then
        halo.Add({ hackTarget }, C.green, 1, 1, 1, true, false)
    end
end)

-- ================= ПОСТ-ОБРАБОТКА ЭКРАНА =================
hook.Add("RenderScreenspaceEffects", "Cyberware_FX", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local sandy = FxAmount("sandevistan")
    if sandy > 0 then
        DrawColorModify({
            ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.03 * sandy, ["$pp_colour_addb"] = 0.07 * sandy,
            ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1 + 0.15 * sandy,
            ["$pp_colour_colour"] = 1 - 0.35 * sandy,
            ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
        })
        DrawBloom(0.7, 1.4 * sandy, 6, 6, 1, 1, 0.4, 0.9, 1)
    end

    local berserk = FxAmount("berserk")
    if berserk > 0 then
        DrawColorModify({
            ["$pp_colour_addr"] = 0.08 * berserk, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -0.02 * berserk, ["$pp_colour_contrast"] = 1 + 0.25 * berserk,
            ["$pp_colour_colour"] = 1 - 0.3 * berserk,
            ["$pp_colour_mulr"] = 0.3 * berserk, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
        })
    end

    local camo = FxAmount("camo")
    if camo > 0 then
        DrawColorModify({
            ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.02 * camo, ["$pp_colour_addb"] = 0.06 * camo,
            ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1,
            ["$pp_colour_colour"] = 1 - 0.5 * camo,
            ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
        })
    end

    local blind = FxAmount("optics_glitch", 0.1, 0.8)
    if blind > 0 then
        DrawColorModify({
            ["$pp_colour_addr"] = 0.1 * blind, ["$pp_colour_addg"] = 0.12 * blind, ["$pp_colour_addb"] = 0.15 * blind,
            ["$pp_colour_brightness"] = 0.25 * blind, ["$pp_colour_contrast"] = 1 - 0.55 * blind,
            ["$pp_colour_colour"] = 1 - 0.9 * blind,
            ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
        })
    end

    -- Психоз: плавная смена цветов без движения камеры
    local sev = CYBERWARE:GetPsychosisSeverity(CYBERWARE:GetHumanity(ply)) * cvPsychoFX:GetFloat()
    if sev > 0 then
        local pulse = (math.sin(CurTime() * 1.6) + 1) * 0.5
        DrawColorModify({
            ["$pp_colour_addr"] = 0.04 * sev + 0.03 * sev * pulse, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0.02 * sev,
            ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1 + 0.15 * sev,
            ["$pp_colour_colour"] = 1 - 0.45 * sev,
            ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
        })
        if CurTime() < psycho.flashEnd then
            local k = 1 - (CurTime() - psycho.flashStart) / math.max(0.01, psycho.flashEnd - psycho.flashStart)
            DrawColorModify({
                ["$pp_colour_addr"] = 0.12 * sev * k, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0.08 * sev * k,
                ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1 + 0.3 * sev * k,
                ["$pp_colour_colour"] = 1,
                ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
            })
        end
    end
end)

-- Полупрозрачная модель оружия в камуфляже
hook.Add("PreDrawViewModel", "Cyberware_CamoViewModel", function(vm, ply)
    if IsValid(ply) and ply:GetNW2Float("Cyber_Camo_Until", 0) > CurTime() then
        render.SetBlend(0.25)
        render.SetColorModulation(0.6, 0.85, 1)
    end
end)
hook.Add("PostDrawViewModel", "Cyberware_CamoViewModel", function(vm, ply)
    if IsValid(ply) and ply:GetNW2Float("Cyber_Camo_Until", 0) > CurTime() then
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    end
end)

-- ================= ЗВУКОВЫЕ ПЕТЛИ =================
local loops = {}
local function ManageLoop(name, active, path, vol, pitch)
    local ply = LocalPlayer()
    local snd = loops[name]
    if active then
        if not snd then
            snd = CreateSound(ply, path)
            loops[name] = snd
        end
        if not snd:IsPlaying() then snd:PlayEx(0, pitch) end
        snd:ChangeVolume(vol, 0.3)
    elseif snd and snd:IsPlaying() then
        snd:FadeOut(0.5)
        loops[name] = nil
    end
end

local nextBeat = 0
hook.Add("Think", "Cyberware_SoundLoops", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local alive = ply:Alive()
    ManageLoop("sandy", alive and FxAmount("sandevistan") > 0.05, "ambient/levels/labs/machine_ring_resonance_loop1.wav", 0.22, 165)
    ManageLoop("camo", alive and FxAmount("camo") > 0.05, "ambient/energy/force_field_loop1.wav", 0.12, 150)

    if not alive then return end
    local now = CurTime()
    local stage = CYBERWARE:GetPsychosisStage(CYBERWARE:GetHumanity(ply))
    local berserk = FxAmount("berserk") > 0.05
    if (berserk or stage >= 3) and now > nextBeat then
        nextBeat = now + (berserk and 0.7 or 1.15)
        ply:EmitSound("player/heartbeat1.wav", 70, berserk and 110 or 90, berserk and 0.6 or 0.35, CHAN_STATIC)
    end
end)

-- ================= ГОРЯЧИЕ КЛАВИШИ =================
local keyStates = {}
local function KeyPressed(code)
    if not code or code <= 0 then return false end
    local down = input.IsKeyDown(code)
    local was = keyStates[code]
    keyStates[code] = down
    return down and not was
end

hook.Add("Think", "Cyberware_UniversalKeybinds", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() or ply:IsTyping() then return end

    if KeyPressed(KeyCode("PlayerMenu")) then
        CYBERWARE:OpenPersonalMenu()
        return
    end
    if KeyPressed(KeyCode("AdminMenu")) then
        CYBERWARE:OpenRipperdocMenu()
        return
    end

    -- Пока открыто меню (курсор), способности не срабатывают; состояния клавиш всё равно обновляем
    local blocked = vgui.CursorVisible()
    local actions = {
        { "OS", "cyber_activate_os" }, { "Quickhack", "cyber_quickhack_menu" }, { "Kerenzikov", "cyber_dash" },
        { "Kiroshi", "cyber_activate_kiroshi" }, { "Arms", "cyber_arms_ability" }, { "Camo", "cyber_activate_camo" },
    }
    for _, a in ipairs(actions) do
        if KeyPressed(KeyCode(a[1])) and not blocked then
            RunConsoleCommand(a[2])
            return
        end
    end
end)

-- ================= HUD =================
local function GetAbilities(ply)
    local list = {}
    local now = CurTime()

    local function cd(nextKey, totalKey)
        local rem = math.max(0, ply:GetNW2Float(nextKey, 0) - now)
        return rem, math.max(0.01, ply:GetNW2Float(totalKey, 1))
    end

    local osImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    if osImp then
        if osImp.hackRange then
            list[#list + 1] = { key = "Quickhack", label = "ВЗЛОМ", rem = 0, total = 1 }
        else
            local rem, total = cd("Cyber_NextOS", "Cyber_NextOS_Total")
            local activeUntil = ply:GetNW2Float("Cyber_OS_ActiveUntil", 0)
            list[#list + 1] = {
                key = "OS", label = osImp.speedBonus and "САНДИ" or "БЕРСЕРК", rem = rem, total = total,
                active = activeUntil > now and (activeUntil - now) / osImp.duration or nil,
            }
        end
    end

    local ocu = CYBERWARE:GetEquippedInSlot(ply, "OCULAR")
    if ocu then
        local rem, total = cd("Cyber_NextKiroshi", "Cyber_NextKiroshi_Total")
        local act = ply:GetNW2Float("Cyber_Kiroshi_Active", 0)
        list[#list + 1] = { key = "Kiroshi", label = "СКАН", rem = rem, total = total, active = act > now and (act - now) / ocu.duration or nil }
    end

    if CYBERWARE:GetBestWith(ply, "NERVOUS", "dashPower") then
        local rem, total = cd("Cyber_NextDash", "Cyber_NextDash_Total")
        list[#list + 1] = { key = "Kerenzikov", label = "РЫВОК", rem = rem, total = total }
    end
    if CYBERWARE:GetBestWith(ply, "ARMS", "launcherDmg") then
        local rem, total = cd("Cyber_NextArms", "Cyber_NextArms_Total")
        list[#list + 1] = { key = "Arms", label = "РАКЕТА", rem = rem, total = total }
    end
    local camo = CYBERWARE:GetBestWith(ply, "INTEGUMENTARY", "camo")
    if camo then
        local rem, total = cd("Cyber_NextCamo", "Cyber_NextCamo_Total")
        local act = ply:GetNW2Float("Cyber_Camo_Until", 0)
        list[#list + 1] = { key = "Camo", label = "КАМО", rem = rem, total = total, active = act > now and (act - now) / camo.duration or nil }
    end

    -- Пассивные импланты с перезарядкой
    local passives = {}
    for _, slot in ipairs({ "NERVOUS", "CIRCULATORY" }) do
        for _, item in ipairs(CYBERWARE:GetEquippedList(ply, slot)) do
            local d = item.data
            if d.selfIce or d.secondHeart or d.healThreshold then
                local label = d.selfIce and "ЛЁД" or d.secondHeart and "СЕРДЦЕ" or "ЛЕЧЕНИЕ"
                passives[#passives + 1] = {
                    label = label, rem = math.max(0, ply:GetNW2Float("Cyber_CD_" .. item.id, 0) - now),
                    total = d.cooldown or 1, tier = d.tier,
                }
            end
        end
    end
    return list, passives
end

local function DrawAbilityChip(x, y, size, ab, emp)
    local ready = ab.rem <= 0 and not emp
    local col = ab.active and C.yellow or (ready and C.cyan or C.dark)
    if emp then col = C.red end

    DrawChamfer(x, y, size, size, S(8), Color(8, 10, 16, 225))
    if ab.rem > 0 and not ab.active then
        local frac = math.Clamp(ab.rem / ab.total, 0, 1)
        surface.SetDrawColor(A(C.cyan, 22))
        surface.DrawRect(x + 1, y + size * frac, size - 2, size * (1 - frac) - 1)
    end
    if ab.active then
        local glow = 120 + math.sin(CurTime() * 8) * 60
        DrawChamferOutline(x, y, size, size, S(8), A(C.yellow, glow), 2)
        surface.SetDrawColor(C.yellow)
        surface.DrawRect(x + S(4), y + size - S(5), (size - S(8)) * math.Clamp(ab.active, 0, 1), S(3))
    else
        DrawChamferOutline(x, y, size, size, S(8), A(col, ready and 220 or 120), 1)
    end

    if emp then
        draw.SimpleText("ЭМИ", "CW_Key", x + size / 2, y + size * 0.42, C.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    elseif ab.rem > 0 and not ab.active then
        draw.SimpleText(ab.rem >= 10 and tostring(math.ceil(ab.rem)) or string.format("%.1f", ab.rem), "CW_Key", x + size / 2, y + size * 0.42, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText(CYBERWARE:GetKeyName(ab.key), "CW_Key", x + size / 2, y + size * 0.42, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    draw.SimpleText(ab.label, "CW_Tiny", x + size / 2, y + size - S(12), A(C.dim, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawMainHUD(ply)
    local now = CurTime()
    local hum = CYBERWARE:GetHumanity(ply)
    local maxHum = CYBERWARE:GetMaxHumanity(ply)
    local stage = CYBERWARE:GetPsychosisStage(hum)
    local stageCol = CYBERWARE.StageColors[stage]
    local emp = ply:GetNW2Float("Cyber_EMP_Until", 0) > now

    local deck = CYBERWARE:GetDeck(ply)
    local w = S(330)
    local h = deck and S(96) or S(70)
    local x = S(24)
    local y = ScrH() - S(140) - h

    -- Способности над основной панелью
    local abilities, passives = GetAbilities(ply)
    local chip = S(52)
    local cx = x
    for _, ab in ipairs(abilities) do
        DrawAbilityChip(cx, y - chip - S(8), chip, ab, emp)
        cx = cx + chip + S(6)
    end
    for i, p in ipairs(passives) do
        local pw, ph = S(64), S(22)
        local py = y - chip - S(8) - ph - S(6)
        local px = x + (i - 1) * (pw + S(4))
        local ready = p.rem <= 0
        DrawChamfer(px, py, pw, ph, S(5), Color(8, 10, 16, 220))
        if not ready then
            surface.SetDrawColor(A(C.green, 40))
            surface.DrawRect(px + 1, py + 1, (pw - 2) * (1 - p.rem / p.total), ph - 2)
        end
        DrawChamferOutline(px, py, pw, ph, S(5), A(ready and C.green or C.dark, 200))
        draw.SimpleText(ready and p.label or (p.label .. " " .. math.ceil(p.rem)), "CW_Tiny", px + pw / 2, py + ph / 2, ready and C.green or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Панель человечности
    DrawChamfer(x, y, w, h, S(12), Color(7, 9, 14, 215))
    surface.SetDrawColor(A(stageCol, 35))
    surface.SetMaterial(matGradL)
    surface.DrawTexturedRect(x, y, w * 0.5, h)
    DrawChamferOutline(x, y, w, h, S(12), A(stageCol, 170))
    surface.SetDrawColor(stageCol)
    surface.DrawRect(x + S(12), y, S(60), S(2))

    draw.SimpleText("ЧЕЛОВЕЧНОСТЬ", "CW_Tiny", x + S(14), y + S(10), C.dim)
    draw.SimpleText(hum .. " / " .. maxHum, "CW_HudNum", x + w - S(14), y + S(4), stageCol, TEXT_ALIGN_RIGHT)

    local barY = y + S(32)
    local barW = w - S(28)
    DrawSegBar(x + S(14), barY, barW, S(8), hum / math.max(1, maxHum), stageCol, 25)
    local markX = x + S(14) + barW * math.Clamp(CYBERWARE.Config.PsychosisStart / math.max(1, maxHum), 0, 1)
    surface.SetDrawColor(C.yellow)
    surface.DrawRect(markX, barY - S(3), S(2), S(14))

    local stageText = CYBERWARE.StageNames[stage]
    if stage >= 2 then
        GlitchText(stageText, "CW_Small", x + S(14), barY + S(14), stageCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, S(1))
    else
        draw.SimpleText(stageText, "CW_Small", x + S(14), barY + S(14), stageCol)
    end
    if emp then
        draw.SimpleText("ИМПЛАНТЫ ЗАБЛОКИРОВАНЫ ЭМИ", "CW_Tiny", x + w - S(14), barY + S(16), C.red, TEXT_ALIGN_RIGHT)
    end

    if deck then
        local ram, maxRam = CYBERWARE:GetRAM(ply)
        local ry = y + h - S(24)
        draw.SimpleText("ОЗУ", "CW_Tiny", x + S(14), ry + S(5), C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(math.floor(ram) .. "/" .. maxRam, "CW_Tiny", x + w - S(14), ry + S(5), C.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        DrawSegBar(x + S(44), ry, w - S(100), S(10), ram / math.max(1, maxRam), C.green, maxRam, S(3))
    end
end

-- Баннеры активных состояний вверху экрана
local function DrawStatusBanners(ply)
    local now = CurTime()
    local list = {}
    local osImp = CYBERWARE:GetEquippedInSlot(ply, "OS")
    local function add(label, rem, total, col)
        if rem > 0 then list[#list + 1] = { label = label, frac = math.Clamp(rem / math.max(0.01, total), 0, 1), rem = rem, col = col } end
    end

    if ply:GetNW2Bool("Cyber_Sandevistan_Active", false) and osImp then
        add("САНДЕВИСТАН", ply:GetNW2Float("Cyber_OS_ActiveUntil", 0) - now, osImp.duration, C.cyan)
    end
    if ply:GetNW2Bool("Cyber_Berserk_Active", false) and osImp then
        add("БЕРСЕРК", ply:GetNW2Float("Cyber_OS_ActiveUntil", 0) - now, osImp.duration, C.red)
    end
    local ocu = CYBERWARE:GetEquippedInSlot(ply, "OCULAR")
    if ocu then add("СКАНИРОВАНИЕ КИРОШИ", ply:GetNW2Float("Cyber_Kiroshi_Active", 0) - now, ocu.duration, C.yellow) end
    local camo = CYBERWARE:GetBestWith(ply, "INTEGUMENTARY", "camo")
    if camo then add("ОПТИЧЕСКИЙ КАМУФЛЯЖ", ply:GetNW2Float("Cyber_Camo_Until", 0) - now, camo.duration, Color(120, 200, 255)) end
    add("ЭМИ: ИМПЛАНТЫ ОТКЛЮЧЕНЫ", ply:GetNW2Float("Cyber_EMP_Until", 0) - now, 6, C.red)
    add("ПАРАЛИЧ СУСТАВОВ", ply:GetNW2Float("Cyber_Crippled_Until", 0) - now, 4, C.orange)
    add("ЗАМЕДЛЕНИЕ", ply:GetNW2Float("Cyber_Slowed_Until", 0) - now, 2.5, C.orange)
    add("ПЕРЕГРУЗКА НЕЙРОСЕТИ", ply:GetNW2Float("Cyber_Exhausted", 0) - now, 2, C.dim)
    if fx.optics_glitch then add("СБОЙ ОПТИКИ", FxRemaining("optics_glitch"), 4, C.red) end

    local bw, bh = S(300), S(26)
    local y = S(14)
    for _, b in ipairs(list) do
        local x = ScrW() / 2 - bw / 2
        DrawChamfer(x, y, bw, bh, S(7), Color(7, 9, 14, 210))
        DrawChamferOutline(x, y, bw, bh, S(7), A(b.col, 170))
        surface.SetDrawColor(A(b.col, 60))
        surface.DrawRect(x + S(2), y + S(2), (bw - S(4)) * b.frac, bh - S(4))
        surface.SetDrawColor(b.col)
        surface.DrawRect(x + S(2), y + bh - S(4), (bw - S(4)) * b.frac, S(2))
        draw.SimpleText(b.label, "CW_Small", x + S(12), y + bh / 2, C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.format("%.1f", b.rem), "CW_Small", x + bw - S(12), y + bh / 2, b.col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        y = y + bh + S(4)
    end
end

local function DrawJumpCharge(ply)
    local charge = ply:GetNW2Float("Cyber_JumpCharge", 0)
    if charge <= 0.05 then return end
    local bw, bh = S(260), S(10)
    local x, y = ScrW() / 2 - bw / 2, ScrH() * 0.72
    local col = charge >= 0.99 and C.yellow or C.cyan
    draw.SimpleText("ГИДРАВЛИКА " .. math.Round(charge * 100) .. "%", "CW_Tiny", ScrW() / 2, y - S(14), col, TEXT_ALIGN_CENTER)
    DrawChamfer(x - S(4), y - S(4), bw + S(8), bh + S(8), S(5), Color(7, 9, 14, 200))
    DrawSegBar(x, y, bw, bh, charge, col, 16)
end

-- Проекция габаритов сущности на экран
local function ScreenBounds(ent)
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    local anyVisible = false
    for i = 0, 7 do
        local corner = Vector(bit.band(i, 1) > 0 and maxs.x or mins.x, bit.band(i, 2) > 0 and maxs.y or mins.y, bit.band(i, 4) > 0 and maxs.z or mins.z)
        local sp = ent:LocalToWorld(corner):ToScreen()
        if sp.visible then anyVisible = true end
        x1, y1 = math.min(x1, sp.x), math.min(y1, sp.y)
        x2, y2 = math.max(x2, sp.x), math.max(y2, sp.y)
    end
    if not anyVisible then return nil end
    return x1, y1, x2, y2
end

local function DrawHackReticle(ply)
    local deck = CYBERWARE:GetDeck(ply)
    if not deck or IsValid(CYBERWARE.HackMenu) then return end
    local target = UpdateHackTarget()
    if not IsValid(target) then return end

    local x1, y1, x2, y2 = ScreenBounds(target)
    if not x1 then return end
    local lock = math.Clamp((CurTime() - hackTargetSince) / 0.25, 0, 1)
    local pad = S(8) + (1 - lock) * S(30)
    x1, y1, x2, y2 = x1 - pad, y1 - pad, x2 + pad, y2 + pad
    DrawCorners(x1, y1, x2 - x1, y2 - y1, S(14), A(C.green, 120 + lock * 135), S(2))

    local name = EntDisplayName(target)
    local dist = math.Round(ply:GetPos():Distance(target:GetPos()) * 0.01905, 1)
    local tagW = math.max(S(170), x2 - x1)
    local tx = (x1 + x2) / 2 - tagW / 2
    local ty = y1 - S(44)
    DrawChamfer(tx, ty, tagW, S(38), S(6), Color(6, 10, 10, 210))
    DrawChamferOutline(tx, ty, tagW, S(38), S(6), A(C.green, 180))
    draw.SimpleText(name, "CW_Small", tx + S(8), ty + S(4), C.white)
    draw.SimpleText(dist .. " м", "CW_Tiny", tx + tagW - S(8), ty + S(6), C.green, TEXT_ALIGN_RIGHT)
    local hpFrac = math.Clamp(target:Health() / math.max(1, target:GetMaxHealth()), 0, 1)
    surface.SetDrawColor(A(C.red, 50))
    surface.DrawRect(tx + S(8), ty + S(24), tagW - S(16), S(5))
    surface.SetDrawColor(C.red)
    surface.DrawRect(tx + S(8), ty + S(24), (tagW - S(16)) * hpFrac, S(5))
    draw.SimpleText("[" .. CYBERWARE:GetKeyName("Quickhack") .. "] ВЗЛОМ", "CW_Tiny", (x1 + x2) / 2, y2 + S(6), C.green, TEXT_ALIGN_CENTER)
end

-- Метки над целями при сканировании Кироши и «Пинге»
local function DrawScanTags(ply)
    local now = CurTime()
    local set = {}
    if ply:GetNW2Float("Cyber_Kiroshi_Active", 0) > now then
        for _, ent in ipairs(KiroshiTargets(ply)) do set[ent] = true end
    end
    for ent, untilT in pairs(pinged) do
        if untilT > now and IsValid(ent) then set[ent] = true end
    end

    local drawn = 0
    for ent in pairs(set) do
        if drawn >= 24 then break end
        if IsValid(ent) and ent:Health() > 0 then
            local top = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 12)
            local sp = top:ToScreen()
            if sp.visible then
                drawn = drawn + 1
                local col = ent:IsPlayer() and C.yellow or C.red
                local w = S(120)
                local x, y = sp.x - w / 2, sp.y - S(30)
                DrawChamfer(x, y, w, S(26), S(5), Color(7, 9, 14, 190))
                surface.SetDrawColor(col)
                surface.DrawRect(x, y, S(2), S(26))
                draw.SimpleText(EntDisplayName(ent), "CW_Tiny", x + S(6), y + S(3), C.white)
                draw.SimpleText(math.Round(ply:GetPos():Distance(ent:GetPos()) * 0.01905) .. "м", "CW_Tiny", x + w - S(4), y + S(3), col, TEXT_ALIGN_RIGHT)
                local frac = math.Clamp(ent:Health() / math.max(1, ent:GetMaxHealth()), 0, 1)
                surface.SetDrawColor(A(col, 50))
                surface.DrawRect(x + S(6), y + S(17), w - S(12), S(4))
                surface.SetDrawColor(col)
                surface.DrawRect(x + S(6), y + S(17), (w - S(12)) * frac, S(4))
            end
        end
    end
end

-- Наложения поверх экрана: края, вспышки, психоз
local function DrawOverlays(ply)
    local now = CurTime()
    local scrW, scrH = ScrW(), ScrH()

    local sandy = FxAmount("sandevistan")
    if sandy > 0 then DrawEdges(A(C.cyan, 70 * sandy)) end

    local berserk = FxAmount("berserk")
    if berserk > 0 then DrawEdges(A(C.red, (70 + math.sin(now * 9) * 25) * berserk), S(260)) end

    local camo = FxAmount("camo")
    if camo > 0 then
        DrawEdges(Color(120, 200, 255, 50 * camo), S(160))
        DrawScanlines(0, 0, scrW, scrH, 25 * camo, 4)
    end

    local kiroshi = FxAmount("kiroshi")
    if kiroshi > 0 then
        DrawEdges(A(C.yellow, 35 * kiroshi), S(180))
        local f = fx.kiroshi
        if f then
            local t = (now - f.start) / 0.7
            if t < 1 then
                local sy = scrH * t
                surface.SetDrawColor(A(C.yellow, 160 * (1 - t)))
                surface.DrawRect(0, sy, scrW, S(2))
                surface.SetMaterial(matGradD)
                surface.SetDrawColor(A(C.yellow, 40 * (1 - t)))
                surface.DrawTexturedRect(0, sy - S(80), scrW, S(80))
            end
        end
    end

    local install = FxAmount("install", 0.05, 0.4)
    if install > 0 then
        local f = fx.install
        local t = f and math.Clamp((now - f.start) / 1.2, 0, 1) or 1
        DrawEdges(A(C.cyan, 60 * install))
        surface.SetDrawColor(A(C.cyan, 140 * install))
        surface.DrawRect(0, scrH * t, scrW, S(2))
        GlitchText("СИНХРОНИЗАЦИЯ ИМПЛАНТА…", "CW_Sub", scrW / 2, scrH * 0.32, A(C.cyan, 220 * install), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local heal = FxAmount("heal", 0.05, 0.6)
    if heal > 0 then DrawEdges(A(C.green, 60 * heal), S(200)) end

    local heart = FxAmount("secondheart", 0.05, 1.2)
    if heart > 0 then
        surface.SetDrawColor(255, 240, 240, 120 * heart)
        surface.DrawRect(0, 0, scrW, scrH)
        DrawEdges(A(C.red, 120 * heart), S(300))
        GlitchText("ВТОРОЕ СЕРДЦЕ // РЕАНИМАЦИЯ", "CW_Title", scrW / 2, scrH * 0.3, A(C.white, 255 * heart), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, S(3))
    end

    local emp = FxAmount("emp", 0.05, 0.5)
    if emp > 0 then
        DrawEdges(Color(90, 160, 255, 60 * emp), S(220))
        DrawScanlines(0, 0, scrW, scrH, 30 * emp, 3)
    end

    local crippled = FxAmount("crippled")
    if crippled > 0 then DrawEdges(A(C.orange, 50 * crippled), S(180)) end

    -- Вспышка взлома / сбой оптики: статичные помехи, меняются 10 раз в секунду
    local hacked = FxAmount("hacked", 0.02, 0.4)
    local blind = FxAmount("optics_glitch", 0.1, 0.8)
    local noise = math.max(hacked * 0.7, blind)
    if noise > 0 then
        local seed = math.floor(now * 10)
        for i = 1, 14 do
            local ry = util.SharedRandom("cwn_y" .. i, 0, 1, seed) * scrH
            local rh = util.SharedRandom("cwn_h" .. i, 2, 30, seed) * UIS
            local rx = util.SharedRandom("cwn_x" .. i, -0.2, 0.6, seed) * scrW
            local rw = util.SharedRandom("cwn_w" .. i, 0.1, 0.8, seed) * scrW
            surface.SetDrawColor((i % 2 == 0) and A(C.pink, 90 * noise) or A(C.cyan, 70 * noise))
            surface.DrawRect(rx, ry, rw, rh)
        end
        if blind > 0 then
            surface.SetDrawColor(200, 210, 220, 150 * blind)
            surface.DrawRect(0, 0, scrW, scrH)
            GlitchText("ОПТИКА ПЕРЕЗАГРУЖАЕТСЯ", "CW_Title", scrW / 2, scrH / 2, A(C.red, 255 * blind), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, S(3))
        end
    end

    -- Психоз: плавная красная виньетка и редкие статичные помехи (без тряски)
    local fxMul = cvPsychoFX:GetFloat()
    local sev = CYBERWARE:GetPsychosisSeverity(CYBERWARE:GetHumanity(ply)) * fxMul
    if sev > 0 then
        local pulse = (math.sin(now * 1.6) + 1) * 0.5
        DrawEdges(A(C.red, (25 + 45 * pulse) * sev), S(280))

        if now < psycho.flashEnd then
            local k = 1 - (now - psycho.flashStart) / math.max(0.01, psycho.flashEnd - psycho.flashStart)
            for _, s in ipairs(psycho.slices) do
                surface.SetDrawColor(s.red and A(C.pink, 110 * k) or A(C.cyan, 90 * k))
                surface.DrawRect(s.off * UIS, s.y * scrH, scrW, s.h * scrH)
            end
            GlitchText(psycho.text, "CW_Glitch", scrW * psycho.textX, scrH * psycho.textY, A(C.red, 255 * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, S(3))
        end
    end
end

hook.Add("HUDPaint", "Cyberware_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:Alive() then
        DrawOverlays(ply)
        DrawScanTags(ply)
        if cvHUD:GetBool() then
            DrawMainHUD(ply)
            DrawStatusBanners(ply)
            DrawJumpCharge(ply)
            DrawHackReticle(ply)
        end
    end
    DrawNotices()
end)

-- ================= БАЗОВЫЕ ЭЛЕМЕНТЫ ИНТЕРФЕЙСА =================
local function CyberButton(parent, text, col, onClick, font)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.cText = text
    b.cCol = col or C.cyan
    b.hl = 0
    b.Paint = function(self, w, h)
        local hov = self:IsHovered() and not self:GetDisabled()
        self.hl = Lerp(FrameTime() * 14, self.hl, hov and 1 or 0)
        local c = self:GetDisabled() and C.dark or (isfunction(self.cCol) and self.cCol() or self.cCol)
        local cut = math.min(S(7), h / 3)
        DrawChamfer(0, 0, w, h, cut, A(c, 22 + 70 * self.hl))
        DrawChamferOutline(0, 0, w, h, cut, A(c, 140 + 115 * self.hl))
        if self.hl > 0.02 then
            surface.SetDrawColor(A(c, 255 * self.hl))
            surface.DrawRect(0, cut, S(3), h - cut)
        end
        local label = isfunction(self.cText) and self.cText() or self.cText
        draw.SimpleText(label, font or "CW_BodyB", w / 2, h / 2, LerpColor(self.hl, A(c, 255), C.white), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.OnCursorEntered = function(self) if not self:GetDisabled() then UISound("hover") end end
    b.DoClick = function(self)
        UISound("click")
        if onClick then onClick(self) end
    end
    return b
end

-- Общая рамка меню: размытие, сетка, шапка с глитч-заголовком, плавное появление
local function CreateCyberFrame(bw, bh, title, subtitle, accent)
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(S(bw), ScrW() - 20), math.min(S(bh), ScrH() - 20))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.18, 0)
    frame.born = RealTime()
    frame.accent = accent or C.yellow

    frame.Paint = function(self, w, h)
        DrawBlur(self, 5)
        local cut = S(22)
        DrawChamfer(0, 0, w, h, cut, C.bg)

        surface.SetDrawColor(A(self.accent, 7))
        for gx = 0, w, S(32) do surface.DrawRect(gx, 0, 1, h) end
        for gy = 0, h, S(32) do surface.DrawRect(0, gy, w, 1) end

        surface.SetDrawColor(A(self.accent, 18))
        surface.SetMaterial(matGradD)
        surface.DrawTexturedRect(0, 0, w, S(64))
        surface.SetDrawColor(A(self.accent, 220))
        surface.DrawRect(cut, S(62), w - cut * 2, 1)

        DrawChamferOutline(0, 0, w, h, cut, A(self.accent, 200), 2)
        surface.SetDrawColor(self.accent)
        surface.DrawRect(cut + S(6), 0, S(120), S(4))
        surface.DrawRect(w - S(150), h - S(4), S(120), S(4))

        -- однократный «глитч» при открытии
        local age = RealTime() - self.born
        local off = age < 0.35 and S(6) * (1 - age / 0.35) or S(2)
        GlitchText(title, "CW_Title", S(30), S(12), self.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, off)
        if subtitle then
            draw.SimpleText(isfunction(subtitle) and subtitle() or subtitle, "CW_Tiny", S(32), S(42), C.dim)
        end
        draw.SimpleText("CYBERWARE OS v" .. (CYBERWARE.Version or "2.0") .. " // NC-NET", "CW_Tiny", S(28), h - S(18), A(C.dim, 140))
        DrawScanlines(0, 0, w, h, 18, 3)
    end

    local close = CyberButton(frame, "X", C.red, function() frame:Close() end, "CW_Head")
    close:SetSize(S(40), S(32))
    close:SetPos(frame:GetWide() - S(56), S(14))

    local oldClose = frame.Close
    frame.Close = function(self)
        if self.closing then return end
        self.closing = true
        UISound("close")
        self:AlphaTo(0, 0.12, 0, function() oldClose(self) end)
    end
    frame.Think = function(self)
        if input.IsKeyDown(KEY_ESCAPE) and not self.closing then
            gui.HideGameUI()
            self:Close()
        end
    end

    UISound("open")
    return frame
end

local function CyberScroll(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    local bar = scroll:GetVBar()
    bar:SetWide(S(6))
    bar:SetHideButtons(true)
    bar.Paint = function(_, w, h) surface.SetDrawColor(18, 22, 32) surface.DrawRect(0, 0, w, h) end
    bar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(A(C.cyan, 160)) surface.DrawRect(0, 0, w, h) end
    return scroll
end

-- Тиражная плашка «МК.N»
local function DrawTierBadge(x, y, tier, font)
    local col = CYBERWARE.TierColors[tier or 1] or C.white
    local text = "МК." .. (tier or 1)
    surface.SetFont(font or "CW_Tiny")
    local tw, th = surface.GetTextSize(text)
    DrawChamfer(x, y, tw + S(12), th + S(4), S(4), A(col, 230))
    draw.SimpleText(text, font or "CW_Tiny", x + S(6), y + S(2), Color(10, 10, 14))
    return tw + S(12)
end

local STAT_KIND_COLORS = { pos = C.green, neg = C.red, info = C.dim, active = C.yellow }

local function DrawStatLines(lines, x, y, colW, lineH, cols, maxRows)
    cols = cols or 2
    local rows = math.ceil(#lines / cols)
    if maxRows then rows = math.min(rows, maxRows) end
    for i, line in ipairs(lines) do
        local col = math.floor((i - 1) / rows)
        local row = (i - 1) % rows
        if col < cols then
            local lx, ly = x + col * colW, y + row * lineH
            local c = STAT_KIND_COLORS[line[2]] or C.white
            surface.SetDrawColor(c)
            surface.DrawRect(lx, ly + lineH / 2 - S(2), S(4), S(4))
            draw.SimpleText(line[1], "CW_Small", lx + S(10), ly + lineH / 2, line[2] == "info" and C.dim or C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    return rows * lineH
end

-- ================= СХЕМА ТЕЛА =================
local function DrawBodySchematic(cx, cy, k, now, highlight)
    local function P(x, y) return cx + x * k, cy + y * k end
    local function L(x1, y1, x2, y2) local a, b = P(x1, y1) local c, d = P(x2, y2) surface.DrawLine(a, b, c, d) end
    local bone = A(C.cyan, 170)
    local spine = A(C.yellow, 170)
    local heart = A(C.pink, 200)
    local hl = function(slot, base) return highlight == slot and C.white or base end

    -- голова
    local hx, hy = P(0, -158)
    DrawCircle(hx, hy, 28 * k, 28, hl("OCULAR", bone))
    local bx, by = P(0, -164)
    DrawCircle(bx, by, 17 * k, 20, hl("OS", spine))
    surface.SetDrawColor(hl("OCULAR", C.yellow))
    L(-16, -150, 16, -150)
    local ex, ey = P(-18, -154) surface.DrawOutlinedRect(ex, ey, 14 * k, 7 * k, 1)
    ex, ey = P(4, -154) surface.DrawOutlinedRect(ex, ey, 14 * k, 7 * k, 1)

    -- контур торса
    surface.SetDrawColor(hl("INTEGUMENTARY", A(C.cyan, 90)))
    L(-12, -132, -16, -112) L(12, -132, 16, -112)
    L(-16, -112, -64, -104) L(16, -112, 64, -104)
    L(-58, -96, -40, 40) L(58, -96, 40, 40)

    -- позвоночник
    surface.SetDrawColor(hl("NERVOUS", spine))
    L(0, -130, 0, 42)
    for sy = -122, 34, 10 do L(-6, sy, 6, sy) end

    -- рёбра
    surface.SetDrawColor(hl("SKELETON", bone))
    L(-60, -104, 60, -104)
    for r = 0, 4 do
        local ry, rw = -88 + r * 16, 48 - r * 4
        L(-rw, ry, -8, ry + 5) L(rw, ry, 8, ry + 5)
    end

    -- сердце
    local hrx, hry = P(18, -62)
    DrawCircle(hrx, hry, (10 + math.sin(now * 6) * 2) * k, 16, hl("CIRCULATORY", heart))
    surface.SetDrawColor(hl("CIRCULATORY", heart))
    L(18, -73, 0, -95)
    L(18, -51, 10, -20)

    -- таз
    surface.SetDrawColor(hl("SKELETON", bone))
    L(-38, 40, 38, 40) L(-38, 40, -28, 62) L(38, 40, 28, 62) L(-28, 62, 28, 62)

    -- руки
    surface.SetDrawColor(hl("ARMS", bone))
    for _, s in ipairs({ -1, 1 }) do
        L(62 * s, -95, 78 * s, -35)
        L(80 * s, -29, 92 * s, 32) L(75 * s, -29, 86 * s, 32)
        local jx, jy = P(78 * s, -35) DrawCircle(jx, jy, 6 * k, 10, hl("ARMS", C.yellow))
        jx, jy = P(89 * s, 38) DrawCircle(jx, jy, 7 * k, 10, hl("ARMS", C.cyan))
        jx, jy = P(62 * s, -102) DrawCircle(jx, jy, 7 * k, 12, hl("ARMS", C.cyan))
        surface.SetDrawColor(hl("ARMS", bone))
    end

    -- ноги
    for _, s in ipairs({ -1, 1 }) do
        surface.SetDrawColor(hl("SKELETON", bone))
        L(30 * s, 64, 35 * s, 135)
        L(37 * s, 142, 40 * s, 208) L(33 * s, 142, 36 * s, 208)
        local jx, jy = P(35 * s, 135) DrawCircle(jx, jy, 7 * k, 12, hl("SKELETON", C.yellow))
        jx, jy = P(30 * s, 58) DrawCircle(jx, jy, 6 * k, 10, hl("SKELETON", C.cyan))
        local fx1, fy1 = P(s < 0 and -48 or 30, 208)
        surface.SetDrawColor(hl("SKELETON", bone))
        surface.DrawOutlinedRect(fx1, fy1, 18 * k, 8 * k, 1)
    end
end

-- ================= ЛИЧНОЕ МЕНЮ (F8) =================
local function BuildSchematicTab(content, ply)
    local cw, ch = content:GetWide(), content:GetTall()
    local colW = S(330)
    local inspectorH = S(200)
    local state = { hovered = nil, hoverSlot = nil }

    local layout = {
        OS = "left", OCULAR = "left", ARMS = "left", SKELETON = "left",
        NERVOUS = "right", CIRCULATORY = "right", INTEGUMENTARY = "right",
    }
    local nodeOffsets = {
        OS = { 0, -168 }, OCULAR = { -12, -150 }, ARMS = { -86, 10 }, SKELETON = { 32, 135 },
        NERVOUS = { 0, -30 }, CIRCULATORY = { 18, -62 }, INTEGUMENTARY = { 50, -10 },
    }
    local panels = {}

    local areaH = ch - inspectorH - S(12)
    local bodyK = math.min(areaH / 470, (cw - colW * 2 - S(40)) / 260)
    local bodyCX, bodyCY = cw / 2, areaH / 2 + S(10)

    content.Paint = function(self, w, h)
        local now = CurTime()
        local ax, aw = colW + S(16), w - colW * 2 - S(32)
        DrawChamfer(ax, 0, aw, areaH, S(14), Color(9, 13, 21, 230))
        surface.SetDrawColor(A(C.cyan, 10))
        for gx = ax, ax + aw, S(24) do surface.DrawRect(gx, 0, 1, areaH) end
        for gy = 0, areaH, S(24) do surface.DrawRect(ax, gy, aw, 1) end
        DrawChamferOutline(ax, 0, aw, areaH, S(14), A(C.cyan, 70))
        DrawCorners(ax + S(6), S(6), aw - S(12), areaH - S(12), S(14), A(C.cyan, 160))

        DrawCircle(bodyCX, bodyCY - 35 * bodyK, 120 * bodyK, 48, A(C.cyan, 22))
        DrawCircle(bodyCX, bodyCY - 35 * bodyK, 90 * bodyK, 40, A(C.yellow, 16))
        DrawBodySchematic(bodyCX, bodyCY, bodyK, now, state.hoverSlot)

        -- линия сканера
        local scanY = S(8) + ((math.sin(now * 1.2) + 1) * 0.5) * (areaH - S(16))
        surface.SetDrawColor(A(C.cyan, 150))
        surface.DrawRect(ax + S(2), scanY, aw - S(4), 1)
        surface.SetMaterial(matGradU)
        surface.SetDrawColor(A(C.cyan, 25))
        surface.DrawTexturedRect(ax + S(2), scanY, aw - S(4), S(24))

        -- узлы и линии к панелям
        for slot, side in pairs(layout) do
            local pnl = panels[slot]
            if IsValid(pnl) then
                local off = nodeOffsets[slot]
                local nx, ny = bodyCX + off[1] * bodyK, bodyCY + off[2] * bodyK
                local has = #CYBERWARE:GetEquippedList(ply, slot) > 0
                local hot = state.hoverSlot == slot
                local col = hot and C.white or (has and C.yellow or A(C.cyan, 110))
                local px, py = pnl:GetPos()
                local tx = side == "left" and (px + pnl:GetWide()) or px
                local ty = py + S(15)
                local mx = side == "left" and tx + S(20) or tx - S(20)

                surface.SetDrawColor(A(col, hot and 255 or 140))
                surface.DrawLine(nx, ny, mx, ty)
                surface.DrawLine(mx, ty, tx, ty)
                draw.RoundedBox(S(4), nx - S(4), ny - S(4), S(8), S(8), col)
                DrawCircle(nx, ny, S(7) + math.abs(math.sin(now * 3 + nx)) * S(4), 14, A(col, 160))
                if has then
                    local t = (now * 0.8 + (side == "left" and 0 or 0.5)) % 1
                    local dx, dy = Lerp(t, nx, mx), Lerp(t, ny, ty)
                    surface.SetDrawColor(C.cyan)
                    surface.DrawRect(dx - S(2), dy - S(2), S(4), S(4))
                end
            end
        end
    end

    -- панели слотов
    local leftY, rightY = 0, 0
    for _, slot in ipairs(CYBERWARE.SlotOrder) do
        local cat = CYBERWARE.Categories[slot]
        local maxSlots = cat.maxSlots or 1
        local side = layout[slot]
        local ph = S(32) + maxSlots * S(30)

        local pnl = vgui.Create("DPanel", content)
        pnl:SetSize(colW, ph)
        if side == "left" then
            pnl:SetPos(0, leftY)
            leftY = leftY + ph + S(10)
        else
            pnl:SetPos(cw - colW, rightY)
            rightY = rightY + ph + S(10)
        end
        panels[slot] = pnl

        pnl.Paint = function(self, w, h)
            local list = CYBERWARE:GetEquippedList(ply, slot)
            local hot = state.hoverSlot == slot
            DrawChamfer(0, 0, w, h, S(10), Color(13, 17, 26, 240))
            DrawChamferOutline(0, 0, w, h, S(10), hot and A(C.white, 200) or (#list > 0 and A(C.yellow, 150) or A(C.line, 255)))
            draw.SimpleText(string.upper(cat.name), "CW_BodyB", S(12), S(7), #list > 0 and C.yellow or C.dim)
            draw.SimpleText(#list .. "/" .. maxSlots, "CW_Small", w - S(12), S(8), C.cyan, TEXT_ALIGN_RIGHT)
        end
        pnl.OnCursorEntered = function() state.hoverSlot = slot end

        for s = 1, maxSlots do
            local btn = vgui.Create("DButton", pnl)
            btn:SetPos(S(8), S(28) + (s - 1) * S(30))
            btn:SetSize(colW - S(16), S(26))
            btn:SetText("")
            btn.hl = 0
            btn.Paint = function(self, w, h)
                local item = CYBERWARE:GetEquippedList(ply, slot)[s]
                self.hl = Lerp(FrameTime() * 14, self.hl, self:IsHovered() and 1 or 0)
                if item then
                    local tc = CYBERWARE.TierColors[item.data.tier or 1]
                    DrawChamfer(0, 0, w, h, S(5), LerpColor(self.hl, Color(20, 27, 40), Color(30, 44, 60)))
                    surface.SetDrawColor(tc)
                    surface.DrawRect(0, S(5), S(4), h - S(5))
                    DrawChamferOutline(0, 0, w, h, S(5), A(tc, 110 + 120 * self.hl))
                    local name = item.data.name
                    surface.SetFont("CW_Small")
                    if surface.GetTextSize(name) > w - S(60) then name = string.sub(name, 1, 40) .. "…" end
                    draw.SimpleText(name, "CW_Small", S(12), h / 2, C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("−" .. item.data.humanity, "CW_Small", w - S(8), h / 2, C.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                else
                    DrawChamfer(0, 0, w, h, S(5), Color(10, 12, 18))
                    DrawChamferOutline(0, 0, w, h, S(5), A(C.line, 255))
                    draw.SimpleText("— свободный разъём —", "CW_Tiny", S(12), h / 2, C.dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
            btn.OnCursorEntered = function()
                state.hoverSlot = slot
                local item = CYBERWARE:GetEquippedList(ply, slot)[s]
                if item then
                    state.hovered = item.data
                    UISound("hover")
                end
            end
        end
    end

    -- инспектор
    local insp = vgui.Create("DPanel", content)
    insp:SetPos(0, ch - inspectorH)
    insp:SetSize(cw, inspectorH)
    insp.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(14), Color(11, 14, 22, 245))
        DrawChamferOutline(0, 0, w, h, S(14), A(C.yellow, 130))
        local d = state.hovered
        if d then
            local tc = CYBERWARE.TierColors[d.tier or 1]
            surface.SetDrawColor(tc)
            surface.DrawRect(0, S(14), S(4), h - S(28))
            local bw = DrawTierBadge(S(18), S(14), d.tier, "CW_Small")
            draw.SimpleText(CYBERWARE.TierNames[d.tier or 1] or "", "CW_Tiny", S(26) + bw, S(17), tc)
            draw.SimpleText(d.name, "CW_Sub", S(18), S(38), C.white)
            draw.SimpleText(CYBERWARE.Categories[d.slot].name, "CW_Small", S(18), S(66), C.dim)
            DrawWrapped(d.desc, "CW_Body", S(18), S(90), w * 0.36, A(C.white, 210), S(18), 5)
            DrawStatLines(CYBERWARE:GetImplantStatLines(d), w * 0.4, S(16), w * 0.3, S(19), 2, 9)
        else
            draw.SimpleText("НЕЙРО-ИНСПЕКТОР", "CW_Sub", S(18), S(14), C.cyan)
            draw.SimpleText("Наведите курсор на установленный имплант, чтобы увидеть его параметры.", "CW_Body", S(18), S(44), C.dim)
            local keys = {}
            for _, a in ipairs({ "OS", "Quickhack", "Kerenzikov", "Kiroshi", "Arms", "Camo" }) do
                keys[#keys + 1] = "[" .. CYBERWARE:GetKeyName(a) .. "] " .. CYBERWARE.ActionNames[a]
            end
            draw.SimpleText(table.concat(keys, "    "), "CW_Small", S(18), S(74), C.white)
            draw.SimpleText("Клавиши можно изменить во вкладке «Настройки».", "CW_Tiny", S(18), S(96), C.dim)

            draw.SimpleText("СКРИПТЫ КИБЕРДЕКИ", "CW_Tiny", S(18), S(124), C.yellow)
            local x = S(18)
            for hackID, item in SortedPairsByMemberValue(CYBERWARE.Quickhacks, "order") do
                if CYBERWARE:HasQuickhack(ply, hackID) then
                    surface.SetFont("CW_Tiny")
                    local tw = surface.GetTextSize(item.name) + S(16)
                    if x + tw > w - S(18) then break end
                    local kc = CYBERWARE.HackKindColors[item.kind] or C.cyan
                    DrawChamfer(x, S(142), tw, S(22), S(4), A(kc, 30))
                    DrawChamferOutline(x, S(142), tw, S(22), S(4), A(kc, 180))
                    draw.SimpleText(item.name, "CW_Tiny", x + S(8), S(153), C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    x = x + tw + S(6)
                end
            end
        end
    end
end

local function StatRow(parent, label, getValue, getFrac, col, getCapped)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, S(8), S(6))
    row:SetTall(S(40))
    row.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(6), Color(14, 18, 27, 235))
        draw.SimpleText(label, "CW_Small", S(12), S(5), C.dim)
        local capped = getCapped and getCapped()
        draw.SimpleText(getValue() .. (capped and "  [ПРЕДЕЛ]" or ""), "CW_BodyB", w - S(12), S(4), capped and C.yellow or col, TEXT_ALIGN_RIGHT)
        DrawSegBar(S(12), h - S(14), w - S(24), S(6), getFrac(), col, 30, S(2))
    end
end

local function BuildStatsTab(content, ply)
    local cw, ch = content:GetWide(), content:GetTall()
    local leftW = math.floor(cw * 0.42)
    local caps = CYBERWARE.Config.Caps

    local left = vgui.Create("DPanel", content)
    left:SetPos(0, 0)
    left:SetSize(leftW, ch)
    left.Paint = function(self, w, h)
        local cfg = CYBERWARE.Config
        local hum = CYBERWARE:GetHumanity(ply)
        local maxHum = CYBERWARE:GetMaxHumanity(ply)
        local stage = CYBERWARE:GetPsychosisStage(hum)
        local sc = CYBERWARE.StageColors[stage]

        DrawChamfer(0, 0, w, h, S(14), Color(11, 14, 22, 245))
        DrawChamferOutline(0, 0, w, h, S(14), A(sc, 140))
        draw.SimpleText("НЕЙРОСТАБИЛЬНОСТЬ", "CW_Sub", S(18), S(14), C.yellow)
        GlitchText(tostring(hum), "CW_Huge", S(18), S(44), sc, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, S(2))
        draw.SimpleText("из " .. maxHum .. "  •  " .. CYBERWARE.StageNames[stage], "CW_BodyB", S(18) + S(90), S(58), sc)

        -- шкала стадий
        local lo = math.min(cfg.PsychosisTerminal - 30, hum)
        local hi = math.max(maxHum, 1)
        local bx, by, bw, bh = S(18), S(106), w - S(36), S(16)
        local function X(v) return bx + (v - lo) / (hi - lo) * bw end
        local zones = {
            { lo, cfg.PsychosisTerminal, CYBERWARE.StageColors[3] },
            { cfg.PsychosisTerminal, cfg.PsychosisStage2, CYBERWARE.StageColors[2] },
            { cfg.PsychosisStage2, cfg.PsychosisStart, CYBERWARE.StageColors[1] },
            { cfg.PsychosisStart, hi, CYBERWARE.StageColors[0] },
        }
        for _, z in ipairs(zones) do
            surface.SetDrawColor(A(z[3], 70))
            surface.DrawRect(X(z[1]), by, math.max(0, X(z[2]) - X(z[1])), bh)
        end
        local mx = X(math.Clamp(hum, lo, hi))
        surface.SetDrawColor(C.white)
        surface.DrawRect(mx - S(1), by - S(6), S(3), bh + S(12))
        draw.SimpleText(tostring(cfg.PsychosisTerminal), "CW_Tiny", X(cfg.PsychosisTerminal), by + bh + S(4), C.dim, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(cfg.PsychosisStage2), "CW_Tiny", X(cfg.PsychosisStage2), by + bh + S(4), C.dim, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(cfg.PsychosisStart), "CW_Tiny", X(cfg.PsychosisStart), by + bh + S(4), C.dim, TEXT_ALIGN_CENTER)

        -- нагрузка по категориям
        draw.SimpleText("НАГРУЗКА ПО СИСТЕМАМ", "CW_BodyB", S(18), S(150), C.cyan)
        local y = S(176)
        local total = math.max(1, maxHum)
        for _, slot in ipairs(CYBERWARE.SlotOrder) do
            local used = 0
            for _, item in ipairs(CYBERWARE:GetEquippedList(ply, slot)) do used = used + item.data.humanity end
            draw.SimpleText(CYBERWARE.Categories[slot].name, "CW_Small", S(18), y, used > 0 and C.white or C.dark)
            draw.SimpleText("−" .. used, "CW_Small", w - S(18), y, used > 0 and C.red or C.dark, TEXT_ALIGN_RIGHT)
            surface.SetDrawColor(A(C.red, 30))
            surface.DrawRect(S(18), y + S(18), w - S(36), S(4))
            surface.SetDrawColor(C.red)
            surface.DrawRect(S(18), y + S(18), (w - S(36)) * math.min(1, used / total * 3), S(4))
            y = y + S(32)
        end

        draw.SimpleText("Ниже " .. cfg.PsychosisStart .. " — галлюцинации, ниже " .. cfg.PsychosisStage2 .. " — киберпсихоз,", "CW_Tiny", S(18), h - S(40), C.dim)
        draw.SimpleText("ниже " .. cfg.PsychosisTerminal .. " — терминальная стадия. Лимит повышает риппердок.", "CW_Tiny", S(18), h - S(24), C.dim)
    end

    local right = CyberScroll(content)
    right:SetPos(leftW + S(14), 0)
    right:SetSize(cw - leftW - S(14), ch)

    local function st() return CYBERWARE:GetStats(ply) end
    local function pct(v) return math.Round(v * 100) .. "%" end
    local rows = {
        { "Бонус к макс. здоровью", function() return "+" .. st().bonusHP end, function() return st().bonusHP / caps.BonusHP end, C.green, function() return st().raw.bonusHP > caps.BonusHP end },
        { "Снижение входящего урона", function() return pct(st().armor) end, function() return st().armor / caps.Armor end, C.cyan, function() return st().raw.armor > caps.Armor end },
        { "Защита от ближнего боя", function() return pct(st().meleeResist) end, function() return st().meleeResist / caps.MeleeResist end, C.cyan, function() return st().raw.meleeResist > caps.MeleeResist end },
        { "Уклонение / рикошет пуль", function() return pct(st().dodge) end, function() return st().dodge / caps.Dodge end, C.cyan, function() return st().raw.dodge > caps.Dodge end },
        { "Скорость передвижения", function() return "+" .. pct(st().speed) end, function() return st().speed / caps.Speed end, C.yellow, function() return st().raw.speed > caps.Speed end },
        { "Урон в ближнем бою", function() return "+" .. pct(st().melee) end, function() return st().melee / caps.Melee end, C.red, function() return st().raw.melee > caps.Melee end },
        { "Урон огнестрельного оружия", function() return "+" .. pct(st().gun) end, function() return st().gun / caps.Gun end, C.red, function() return st().raw.gun > caps.Gun end },
        { "Стабилизация разброса", function() return "−" .. pct(1 - st().spreadMult) end, function() return (1 - st().spreadMult) / (1 - caps.SpreadMin) end, C.red },
        { "Регенерация вне боя (за тик)", function() return "+" .. st().regen .. " HP" end, function() return st().regen / caps.Regen end, C.green, function() return st().raw.regen > caps.Regen end },
        { "Вампиризм", function() return pct(st().vamp) end, function() return st().vamp / caps.Vamp end, C.green, function() return st().raw.vamp > caps.Vamp end },
        { "Лечение за убийство", function() return "+" .. st().killHeal .. " HP" end, function() return st().killHeal / caps.KillHeal end, C.green, function() return st().raw.killHeal > caps.KillHeal end },
        { "Сопротивление огню", function() return pct(st().fireResist) end, function() return st().fireResist end, C.orange },
        { "Сопротивление электричеству", function() return pct(st().shockResist) end, function() return st().shockResist end, C.orange },
        { "Урон от падения", function() return pct(st().fallMult) end, function() return 1 - st().fallMult end, C.yellow },
    }
    for _, r in ipairs(rows) do StatRow(right, r[1], r[2], r[3], r[4], r[5]) end

    local flags = vgui.Create("DPanel", right)
    flags:Dock(TOP)
    flags:DockMargin(0, S(4), S(8), S(6))
    flags:SetTall(S(70))
    flags.Paint = function(self, w, h)
        local s = st()
        local list = {}
        if s.jumpCharge then list[#list + 1] = "Заряженный прыжок" end
        if s.doubleJump then list[#list + 1] = "Двойной прыжок" end
        if s.silentSteps then list[#list + 1] = "Бесшумные шаги" end
        if s.bleedDps > 0 then list[#list + 1] = "Кровотечение " .. s.bleedDps .. "/с" end
        if s.chainShock > 0 then list[#list + 1] = "Цепной разряд" end
        if s.shockDmg > 0 then list[#list + 1] = "Электроурон +" .. s.shockDmg end
        if s.knockback > 0 then list[#list + 1] = "Отбрасывание " .. s.knockback end
        DrawChamfer(0, 0, w, h, S(6), Color(14, 18, 27, 235))
        draw.SimpleText("ОСОБЫЕ СВОЙСТВА", "CW_Small", S(12), S(5), C.dim)
        local x = S(12)
        if #list == 0 then draw.SimpleText("нет", "CW_Small", x, S(32), C.dark) end
        for _, t in ipairs(list) do
            surface.SetFont("CW_Tiny")
            local tw = surface.GetTextSize(t) + S(14)
            if x + tw > w then break end
            DrawChamfer(x, S(30), tw, S(24), S(4), A(C.yellow, 30))
            DrawChamferOutline(x, S(30), tw, S(24), S(4), A(C.yellow, 160))
            draw.SimpleText(t, "CW_Tiny", x + S(7), S(42), C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            x = x + tw + S(6)
        end
    end
end

local function HackCard(parent, hackID, hack, ply, opts)
    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP)
    card:DockMargin(0, 0, S(8), S(8))
    card:SetTall(S(78))
    card.Paint = function(self, w, h)
        local target = opts and opts.target
        local owned = target and CYBERWARE:HasQuickhack(target, hackID) or (not target and CYBERWARE:HasQuickhack(ply, hackID))
        local kc = CYBERWARE.HackKindColors[hack.kind] or C.cyan
        DrawChamfer(0, 0, w, h, S(8), owned and Color(14, 22, 26, 240) or Color(12, 14, 20, 230))
        DrawChamferOutline(0, 0, w, h, S(8), owned and A(kc, 170) or A(C.line, 255))
        surface.SetDrawColor(owned and kc or C.dark)
        surface.DrawRect(0, S(8), S(4), h - S(8))

        draw.SimpleText(hack.name, "CW_Head", S(16), S(8), owned and C.white or C.dim)
        local info = "ОЗУ " .. hack.ram .. "  •  КД " .. hack.cooldown .. " с"
        if hack.playersOnly then info = info .. "  •  только игроки" end
        if hack.npcOnly then info = info .. "  •  только NPC" end
        draw.SimpleText(info, "CW_Tiny", S(16), S(30), kc)
        local rightPad = opts and opts.rightPad or S(16)
        DrawWrapped(hack.desc, "CW_Small", S(16), S(46), w - S(32) - rightPad, owned and A(C.white, 200) or C.dark, S(15), 2)
        if not target and not owned then
            draw.SimpleText("ЗАБЛОКИРОВАН", "CW_Tiny", w - S(14), S(10), C.red, TEXT_ALIGN_RIGHT)
        end
        for i = 1, hack.ram do
            surface.SetDrawColor(owned and C.green or C.dark)
            surface.DrawRect(w - rightPad - S(4) - i * S(9), S(30), S(6), S(10))
        end
    end
    return card
end

local function BuildScriptsTab(content, ply)
    local cw, ch = content:GetWide(), content:GetTall()
    local head = vgui.Create("DPanel", content)
    head:SetPos(0, 0)
    head:SetSize(cw, S(80))
    head.Paint = function(self, w, h)
        local deck = CYBERWARE:GetDeck(ply)
        DrawChamfer(0, 0, w, h, S(12), Color(11, 14, 22, 245))
        DrawChamferOutline(0, 0, w, h, S(12), A(deck and C.green or C.line, 160))
        if deck then
            draw.SimpleText(deck.name, "CW_Sub", S(18), S(12), CYBERWARE.TierColors[deck.tier])
            local ram, maxRam = CYBERWARE:GetRAM(ply)
            draw.SimpleText("ОЗУ " .. math.floor(ram) .. "/" .. maxRam .. "  •  дальность " .. deck.hackRange .. "  •  урон +" .. math.Round((deck.hackDmgMult - 1) * 100) .. "%  •  перезарядка −" .. math.Round((1 - deck.cdMult) * 100) .. "%", "CW_Small", S(18), S(42), C.dim)
            DrawSegBar(w * 0.62, S(46), w * 0.35, S(10), ram / maxRam, C.green, maxRam, S(3))
        else
            draw.SimpleText("КИБЕРДЕКА НЕ УСТАНОВЛЕНА", "CW_Sub", S(18), S(12), C.red)
            draw.SimpleText("Скрипты можно использовать только с кибердекой в слоте ОС.", "CW_Small", S(18), S(44), C.dim)
        end
    end

    local scroll = CyberScroll(content)
    scroll:SetPos(0, S(92))
    scroll:SetSize(cw, ch - S(92))
    for id, hack in SortedPairsByMemberValue(CYBERWARE.Quickhacks, "order") do
        HackCard(scroll, id, hack, ply)
    end
end

-- Привязка клавиш
local function KeyBindRow(parent, action, label)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, S(8), S(6))
    row:SetTall(S(40))
    row.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(6), Color(14, 18, 27, 235))
        draw.SimpleText(label, "CW_Body", S(14), h / 2, C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local binder = vgui.Create("DBinder", row)
    binder:Dock(RIGHT)
    binder:DockMargin(0, S(5), S(6), S(5))
    binder:SetWide(S(150))
    binder:SetValue(KeyCode(action))
    binder:SetTextColor(Color(0, 0, 0, 0))
    binder.OnChange = function(self, code)
        RunConsoleCommand("cyber_key_" .. string.lower(action), tostring(code))
        UISound("success")
    end
    binder.Paint = function(self, w, h)
        local trapping = self.Trapping
        local col = trapping and C.yellow or (self:IsHovered() and C.white or C.cyan)
        DrawChamfer(0, 0, w, h, S(5), A(col, trapping and 50 or 20))
        DrawChamferOutline(0, 0, w, h, S(5), A(col, 200))
        local name = trapping and "НАЖМИТЕ…" or string.upper(input.GetKeyName(self:GetValue()) or "НЕТ")
        draw.SimpleText(name, "CW_BodyB", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    row.binder = binder
    return row
end

local function ToggleRow(parent, label, cvar)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(TOP)
    btn:DockMargin(0, 0, S(8), S(6))
    btn:SetTall(S(40))
    btn:SetText("")
    btn.Paint = function(self, w, h)
        local on = GetConVar(cvar):GetBool()
        DrawChamfer(0, 0, w, h, S(6), Color(14, 18, 27, 235))
        draw.SimpleText(label, "CW_Body", S(14), h / 2, self:IsHovered() and C.white or A(C.white, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local tw, th = S(56), S(22)
        local tx, ty = w - tw - S(12), h / 2 - th / 2
        DrawChamfer(tx, ty, tw, th, S(4), on and A(C.green, 60) or Color(30, 30, 40))
        DrawChamferOutline(tx, ty, tw, th, S(4), on and C.green or C.dark)
        draw.SimpleText(on and "ВКЛ" or "ВЫКЛ", "CW_Tiny", tx + tw / 2, h / 2, on and C.green or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.OnCursorEntered = function() UISound("hover") end
    btn.DoClick = function()
        RunConsoleCommand(cvar, GetConVar(cvar):GetBool() and "0" or "1")
        UISound("click")
    end
end

local function SliderRow(parent, label, cvar)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, S(8), S(6))
    row:SetTall(S(48))
    row:SetCursor("hand")
    local function barRect(w, h) return S(14), h - S(16), w - S(28), S(8) end
    row.Paint = function(self, w, h)
        local v = GetConVar(cvar):GetFloat()
        DrawChamfer(0, 0, w, h, S(6), Color(14, 18, 27, 235))
        draw.SimpleText(label, "CW_Body", S(14), S(6), C.white)
        draw.SimpleText(math.Round(v * 100) .. "%", "CW_BodyB", w - S(14), S(6), C.yellow, TEXT_ALIGN_RIGHT)
        local bx, by, bw, bh = barRect(w, h)
        DrawSegBar(bx, by, bw, bh, v, C.yellow, 20)
    end
    row.OnMousePressed = function(self) self.dragging = true UISound("click") end
    row.OnMouseReleased = function(self) self.dragging = false end
    row.Think = function(self)
        if self.dragging then
            if not input.IsMouseDown(MOUSE_LEFT) then self.dragging = false return end
            local bx, _, bw = barRect(self:GetWide(), self:GetTall())
            local mx = self:CursorPos()
            local v = math.Clamp((mx - bx) / bw, 0, 1)
            RunConsoleCommand(cvar, string.format("%.2f", v))
        end
    end
end

local function BuildSettingsTab(content)
    local cw, ch = content:GetWide(), content:GetTall()
    local half = math.floor(cw / 2) - S(8)

    local function Header(parent, text)
        local p = vgui.Create("DPanel", parent)
        p:Dock(TOP)
        p:DockMargin(0, 0, S(8), S(8))
        p:SetTall(S(30))
        p.Paint = function(self, w, h)
            draw.SimpleText(text, "CW_Sub", 0, h / 2, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(A(C.yellow, 80))
            surface.DrawRect(0, h - 1, w, 1)
        end
    end

    local left = CyberScroll(content)
    left:SetPos(0, 0)
    left:SetSize(half, ch)
    Header(left, "ГОРЯЧИЕ КЛАВИШИ")
    local binders = {}
    for _, action in ipairs(KEY_ACTIONS) do
        local label = ({
            OS = "Операционная система (Сандевистан / Берсерк)", Quickhack = "Кибердека: меню взлома",
            Kerenzikov = "Рывок Керензикова", Kiroshi = "Сканер Кироши", Arms = "Ракетная система рук",
            Camo = "Оптический камуфляж", PlayerMenu = "Личное меню имплантов", AdminMenu = "Терминал риппердока (админ)",
        })[action]
        binders[#binders + 1] = { action, KeyBindRow(left, action, label) }
    end
    local reset = CyberButton(left, "СБРОСИТЬ КЛАВИШИ ПО УМОЛЧАНИЮ", C.red, function()
        for _, b in ipairs(binders) do
            local def = CYBERWARE.Config.DefaultKeys[b[1]] or 0
            RunConsoleCommand("cyber_key_" .. string.lower(b[1]), tostring(def))
            b[2].binder:SetValue(def)
        end
    end)
    reset:Dock(TOP)
    reset:DockMargin(0, S(6), S(8), 0)
    reset:SetTall(S(36))

    local right = CyberScroll(content)
    right:SetPos(half + S(16), 0)
    right:SetSize(cw - half - S(16), ch)
    Header(right, "ИНТЕРФЕЙС И ЭФФЕКТЫ")
    ToggleRow(right, "Показывать HUD имплантов", "cyber_hud")
    ToggleRow(right, "Шлейф остаточных образов Сандевистана", "cyber_ghosts")
    ToggleRow(right, "Звуки интерфейса", "cyber_ui_sounds")
    SliderRow(right, "Интенсивность визуальных эффектов психоза", "cyber_psycho_fx")

    local note = vgui.Create("DPanel", right)
    note:Dock(TOP)
    note:DockMargin(0, S(10), S(8), 0)
    note:SetTall(S(90))
    note.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(8), Color(14, 18, 27, 200))
        DrawWrapped("Психоз больше не трясёт камеру: эффекты ограничены цветом, виньеткой и редкими помехами. Если они мешают, уменьшите интенсивность ползунком выше.", "CW_Small", S(14), S(10), w - S(28), C.dim, S(16), 5)
    end
end

function CYBERWARE:OpenPersonalMenu()
    if (self.LastPersonalToggle or 0) > RealTime() then return end
    self.LastPersonalToggle = RealTime() + 0.25

    if IsValid(self.PersonalFrame) then
        self.PersonalFrame:Close()
        return
    end

    local ply = LocalPlayer()
    local frame = CreateCyberFrame(1180, 780, "NEURO-SCANNER // КИБЕРСХЕМА", function()
        return string.upper(ply:Nick()) .. "  •  УСТАНОВЛЕНО ИМПЛАНТОВ: " .. (function()
            local n = 0
            for _, slot in ipairs(CYBERWARE.SlotOrder) do n = n + #CYBERWARE:GetEquippedList(ply, slot) end
            return n
        end)()
    end, C.yellow)
    self.PersonalFrame = frame

    -- Человечность в шапке
    local humPnl = vgui.Create("DPanel", frame)
    humPnl:SetSize(S(320), S(40))
    humPnl:SetPos(frame:GetWide() - S(390), S(12))
    humPnl.Paint = function(self, w, h)
        local hum = CYBERWARE:GetHumanity(ply)
        local maxHum = CYBERWARE:GetMaxHumanity(ply)
        local stage = CYBERWARE:GetPsychosisStage(hum)
        local sc = CYBERWARE.StageColors[stage]
        draw.SimpleText("ЧЕЛОВЕЧНОСТЬ " .. hum .. "/" .. maxHum, "CW_BodyB", 0, S(2), sc)
        draw.SimpleText(CYBERWARE.StageNames[stage], "CW_Tiny", w, S(5), sc, TEXT_ALIGN_RIGHT)
        DrawSegBar(0, S(24), w, S(8), hum / math.max(1, maxHum), sc, 30)
    end

    local tabs = {
        { "СХЕМА ТЕЛА", BuildSchematicTab },
        { "ХАРАКТЕРИСТИКИ", BuildStatsTab },
        { "СКРИПТЫ", BuildScriptsTab },
        { "НАСТРОЙКИ", function(c) BuildSettingsTab(c) end },
    }

    local content = vgui.Create("DPanel", frame)
    content:SetPos(S(24), S(122))
    content:SetSize(frame:GetWide() - S(48), frame:GetTall() - S(152))

    local current = 1
    local function Switch(i)
        current = i
        content:Clear()
        content.Paint = function() end
        content:SetAlpha(0)
        content:AlphaTo(255, 0.15, 0)
        tabs[i][2](content, ply)
    end

    local tabW = S(190)
    for i, t in ipairs(tabs) do
        local b = CyberButton(frame, t[1], C.cyan, function() Switch(i) UISound("tab") end, "CW_BodyB")
        b:SetPos(S(24) + (i - 1) * (tabW + S(6)), S(76))
        b:SetSize(tabW, S(34))
        b.cCol = function() return current == i and C.yellow or C.cyan end
        local basePaint = b.Paint
        b.Paint = function(self, w, h)
            if current == i then
                DrawChamfer(0, 0, w, h, S(7), A(C.yellow, 40))
                surface.SetDrawColor(C.yellow)
                surface.DrawRect(0, h - S(3), w, S(3))
            end
            basePaint(self, w, h)
        end
    end

    Switch(1)
end

concommand.Add("cyber_my_implants", function() CYBERWARE:OpenPersonalMenu() end)

-- ================= ТЕРМИНАЛ РИППЕРДОКА (АДМИН) =================
function CYBERWARE:OpenRipperdocMenu()
    if (self.LastRipperToggle or 0) > RealTime() then return end
    self.LastRipperToggle = RealTime() + 0.3

    local localPly = LocalPlayer()
    if not self:IsAdmin(localPly) then
        AddNotice("ДОСТУП ЗАПРЕЩЁН: нужны права администратора (ваш ранг: " .. tostring(localPly:GetUserGroup()) .. ")", 1)
        return
    end
    if IsValid(self.RipperFrame) then
        self.RipperFrame:Close()
        return
    end

    local patient = localPly
    local currentTab = "OS"
    local tierFilter = 0
    local hoverImplant = nil
    local search = ""

    local frame = CreateCyberFrame(1260, 800, "RIPPERDOC // ТЕРМИНАЛ ХИРУРГА", "ДОСТУП АДМИНИСТРАТОРА  •  ИЗМЕНЕНИЯ СОХРАНЯЮТСЯ АВТОМАТИЧЕСКИ", C.red)
    self.RipperFrame = frame
    local FW, FH = frame:GetWide(), frame:GetTall()
    local sideW = S(270)
    local mainX = S(24) + sideW + S(14)
    local mainW = FW - mainX - S(24)

    -- ===== Список пациентов =====
    local sideTop = S(76)
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(S(24), sideTop)
    searchBox:SetSize(sideW, S(32))
    searchBox:SetFont("CW_Body")
    searchBox:SetPlaceholderText("Поиск пациента…")
    searchBox:SetUpdateOnType(true)
    searchBox:SetPaintBackground(false)
    searchBox:SetTextColor(C.white)
    searchBox:SetCursorColor(C.yellow)
    searchBox:SetHighlightColor(A(C.yellow, 90))
    searchBox.PaintOver = function(self, w, h)
        DrawChamferOutline(0, 0, w, h, S(6), A(self:HasFocus() and C.yellow or C.cyan, 180))
    end
    local basePaint = searchBox.Paint
    searchBox.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(6), Color(14, 18, 27, 240))
        basePaint(self, w, h)
    end

    local plist = CyberScroll(frame)
    plist:SetPos(S(24), sideTop + S(40))
    plist:SetSize(sideW, FH - sideTop - S(40) - S(30))

    local RefreshContent -- forward

    local function RebuildPatients()
        plist:Clear()
        local players = player.GetAll()
        table.sort(players, function(a, b) return a:Nick():lower() < b:Nick():lower() end)
        for _, p in ipairs(players) do
            if search == "" or string.find(p:Nick():lower(), search:lower(), 1, true) then
                local row = vgui.Create("DButton", plist)
                row:Dock(TOP)
                row:DockMargin(0, 0, S(8), S(6))
                row:SetTall(S(54))
                row:SetText("")
                row.hl = 0

                local av = vgui.Create("AvatarImage", row)
                av:SetSize(S(38), S(38))
                av:SetPos(S(10), S(8))
                av:SetPlayer(p, 64)
                av:SetMouseInputEnabled(false)

                row.Paint = function(self, w, h)
                    if not IsValid(p) then return end
                    local sel = patient == p
                    self.hl = Lerp(FrameTime() * 14, self.hl, (self:IsHovered() or sel) and 1 or 0)
                    local hum = CYBERWARE:GetHumanity(p)
                    local sc = CYBERWARE.StageColors[CYBERWARE:GetPsychosisStage(hum)]
                    DrawChamfer(0, 0, w, h, S(7), sel and A(C.red, 40) or LerpColor(self.hl, Color(14, 18, 27, 235), Color(24, 30, 44, 240)))
                    DrawChamferOutline(0, 0, w, h, S(7), sel and C.red or A(C.line, 255))
                    if sel then
                        surface.SetDrawColor(C.red)
                        surface.DrawRect(0, S(7), S(3), h - S(7))
                    end
                    draw.SimpleText(p:Nick() .. (p == localPly and "  (вы)" or ""), "CW_BodyB", S(56), S(9), C.white)
                    draw.SimpleText("Человечность " .. hum .. "/" .. CYBERWARE:GetMaxHumanity(p), "CW_Tiny", S(56), S(29), sc)
                    surface.SetDrawColor(A(sc, 40))
                    surface.DrawRect(S(56), h - S(10), w - S(68), S(3))
                    surface.SetDrawColor(sc)
                    surface.DrawRect(S(56), h - S(10), (w - S(68)) * math.Clamp(hum / math.max(1, CYBERWARE:GetMaxHumanity(p)), 0, 1), S(3))
                end
                row.OnCursorEntered = function() UISound("hover") end
                row.DoClick = function()
                    patient = p
                    UISound("click")
                    RefreshContent()
                end
            end
        end
    end
    searchBox.OnValueChange = function(self, val)
        search = val or ""
        RebuildPatients()
    end
    RebuildPatients()

    -- ===== Карточка пациента =====
    local head = vgui.Create("DPanel", frame)
    head:SetPos(mainX, sideTop)
    head:SetSize(mainW, S(120))
    head.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(12), Color(12, 15, 23, 245))
        DrawChamferOutline(0, 0, w, h, S(12), A(C.red, 120))
        if not IsValid(patient) then
            draw.SimpleText("ПАЦИЕНТ НЕ ВЫБРАН", "CW_Sub", S(18), S(14), C.dim)
            return
        end
        local hum = CYBERWARE:GetHumanity(patient)
        local maxHum = CYBERWARE:GetMaxHumanity(patient)
        local stage = CYBERWARE:GetPsychosisStage(hum)
        local sc = CYBERWARE.StageColors[stage]
        draw.SimpleText(patient:Nick(), "CW_Sub", S(18), S(10), C.white)
        draw.SimpleText(patient:SteamID() or "", "CW_Tiny", S(18), S(36), C.dim)

        local gx, gy, gw = S(18), S(66), w * 0.5 - S(30)
        draw.SimpleText("ЧЕЛОВЕЧНОСТЬ " .. hum .. " / " .. maxHum .. "  •  " .. CYBERWARE.StageNames[stage], "CW_BodyB", gx, S(50) - S(6), sc)
        DrawSegBar(gx, gy + S(8), gw, S(10), hum / math.max(1, maxHum), sc, 30)

        -- прогноз при наведении на имплант
        if hoverImplant then
            local equipped = CYBERWARE:HasImplant(patient, hoverImplant.id)
            local delta = equipped and hoverImplant.data.humanity or -hoverImplant.data.humanity
            if not equipped and (CYBERWARE.Categories[hoverImplant.data.slot].maxSlots or 1) == 1 then
                local old = CYBERWARE:GetEquippedInSlot(patient, hoverImplant.data.slot)
                if old then delta = delta + old.humanity end
            end
            local after = hum + delta
            local ac = CYBERWARE.StageColors[CYBERWARE:GetPsychosisStage(after)]
            local px = gx + gw * math.Clamp(after / math.max(1, maxHum), 0, 1)
            surface.SetDrawColor(ac)
            surface.DrawRect(px - S(1), gy + S(2), S(3), S(22))
            draw.SimpleText("ПОСЛЕ ОПЕРАЦИИ: " .. after .. " (" .. (delta >= 0 and "+" or "") .. delta .. ")  " .. CYBERWARE.StageNames[CYBERWARE:GetPsychosisStage(after)], "CW_Tiny", gx, gy + S(26), ac)
        else
            draw.SimpleText("Наведите на имплант, чтобы увидеть прогноз человечности", "CW_Tiny", gx, gy + S(26), C.dark)
        end
        draw.SimpleText("ЛИМИТ ЧЕЛОВЕЧНОСТИ", "CW_Tiny", w * 0.5 + S(4), S(12), C.dim)
    end

    local function SendAdjust(delta, reset)
        if not IsValid(patient) then return end
        net.Start("Cyberware_AdjustMaxHumanity")
        net.WriteEntity(patient)
        net.WriteInt(delta, 16)
        net.WriteBool(reset)
        net.SendToServer()
    end

    local bx = mainW * 0.5 + S(4)
    for _, d in ipairs({ -50, -10, 10, 50 }) do
        local b = CyberButton(head, (d > 0 and "+" or "") .. d, d < 0 and C.red or C.green, function() SendAdjust(d, false) end)
        b:SetPos(bx, S(30))
        b:SetSize(S(56), S(30))
        bx = bx + S(62)
    end
    local resetB = CyberButton(head, "СБРОС", C.yellow, function() SendAdjust(0, true) end)
    resetB:SetPos(bx, S(30))
    resetB:SetSize(S(80), S(30))

    local valEntry = vgui.Create("DTextEntry", head)
    valEntry:SetPos(mainW * 0.5 + S(4), S(70))
    valEntry:SetSize(S(110), S(30))
    valEntry:SetNumeric(true)
    valEntry:SetFont("CW_Body")
    valEntry:SetPlaceholderText("значение")
    valEntry:SetPaintBackground(false)
    valEntry:SetTextColor(C.white)
    valEntry:SetCursorColor(C.yellow)
    local vePaint = valEntry.Paint
    valEntry.Paint = function(self, w, h)
        DrawChamfer(0, 0, w, h, S(5), Color(14, 18, 27, 240))
        DrawChamferOutline(0, 0, w, h, S(5), A(self:HasFocus() and C.yellow or C.cyan, 180))
        vePaint(self, w, h)
    end
    local setB = CyberButton(head, "УСТАНОВИТЬ", C.cyan, function()
        local v = tonumber(valEntry:GetValue())
        if not v or not IsValid(patient) then UISound("error") return end
        net.Start("Cyberware_SetMaxHumanity")
        net.WriteEntity(patient)
        net.WriteInt(math.Clamp(math.floor(v), 0, 30000), 16)
        net.SendToServer()
    end)
    setB:SetPos(mainW * 0.5 + S(120), S(70))
    setB:SetSize(S(120), S(30))

    local clearB = CyberButton(head, "СНЯТЬ ВСЁ", C.red, function()
        if not IsValid(patient) then return end
        local target = patient
        Derma_Query("Удалить ВСЕ импланты у " .. target:Nick() .. "?", "Риппердок", "Удалить", function()
            net.Start("Cyberware_ClearImplants")
            net.WriteEntity(target)
            net.SendToServer()
        end, "Отмена")
    end)
    clearB:SetPos(mainW - S(140), S(70))
    clearB:SetSize(S(124), S(30))

    -- ===== Вкладки категорий =====
    local tabY = sideTop + S(130)
    local tabKeys = {}
    for _, slot in ipairs(CYBERWARE.SlotOrder) do tabKeys[#tabKeys + 1] = slot end
    tabKeys[#tabKeys + 1] = "SCRIPTS"
    local tw = (mainW - (#tabKeys - 1) * S(4)) / #tabKeys
    for i, key in ipairs(tabKeys) do
        local b = CyberButton(frame, "", C.cyan, function()
            currentTab = key
            UISound("tab")
            RefreshContent()
        end, "CW_Small")
        b:SetPos(mainX + (i - 1) * (tw + S(4)), tabY)
        b:SetSize(tw, S(40))
        b.cText = function()
            if key == "SCRIPTS" then return "СКРИПТЫ" end
            local cat = CYBERWARE.Categories[key]
            local n = IsValid(patient) and #CYBERWARE:GetEquippedList(patient, key) or 0
            return cat.short .. "  " .. n .. "/" .. cat.maxSlots
        end
        b.cCol = function() return currentTab == key and C.yellow or (key == "SCRIPTS" and C.green or C.cyan) end
        local bp = b.Paint
        b.Paint = function(self, w, h)
            if currentTab == key then
                DrawChamfer(0, 0, w, h, S(7), A(C.yellow, 40))
                surface.SetDrawColor(C.yellow)
                surface.DrawRect(0, h - S(3), w, S(3))
            end
            bp(self, w, h)
        end
    end

    -- ===== Фильтр по уровню =====
    local filterY = tabY + S(48)
    for t = 0, 5 do
        local col = t == 0 and C.white or CYBERWARE.TierColors[t]
        local b = CyberButton(frame, t == 0 and "ВСЕ" or ("МК." .. t), col, function()
            tierFilter = t
            RefreshContent()
        end, "CW_Tiny")
        b:SetPos(mainX + t * S(70), filterY)
        b:SetSize(S(64), S(24))
        local bp = b.Paint
        b.Paint = function(self, w, h)
            if tierFilter == t then DrawChamfer(0, 0, w, h, S(6), A(col, 70)) end
            bp(self, w, h)
        end
    end

    local scroll = CyberScroll(frame)
    scroll:SetPos(mainX, filterY + S(34))
    scroll:SetSize(mainW, FH - filterY - S(34) - S(30))

    local function ImplantCard(id, imp)
        local tc = CYBERWARE.TierColors[imp.tier or 1]
        local lines = CYBERWARE:GetImplantStatLines(imp)
        local statRows = math.ceil(#lines / 2)
        local btnW = S(150)
        local textW = mainW - S(8) - btnW - S(40)
        local descLines = math.min(2, #WrapText(imp.desc, "CW_Small", textW))
        local h = S(56) + descLines * S(16) + statRows * S(18) + S(10)

        local card = vgui.Create("DPanel", scroll)
        card:Dock(TOP)
        card:DockMargin(0, 0, S(8), S(8))
        card:SetTall(h)
        card.hl = 0
        card.Paint = function(self, w, hh)
            local equipped = IsValid(patient) and CYBERWARE:HasImplant(patient, id)
            local hov = self:IsHovered() or self:IsChildHovered()
            self.hl = Lerp(FrameTime() * 12, self.hl, hov and 1 or 0)
            if hov then hoverImplant = { id = id, data = imp } end
            DrawChamfer(0, 0, w, hh, S(10), equipped and Color(14, 30, 34, 245) or LerpColor(self.hl, Color(13, 16, 24, 235), Color(20, 25, 37, 245)))
            DrawChamferOutline(0, 0, w, hh, S(10), equipped and A(C.cyan, 220) or A(tc, 70 + 120 * self.hl), equipped and 2 or 1)
            surface.SetDrawColor(tc)
            surface.DrawRect(0, S(10), S(5), hh - S(10))
            surface.SetDrawColor(A(tc, 25))
            surface.SetMaterial(matGradL)
            surface.DrawTexturedRect(S(5), 0, w * 0.3, hh)

            local bwid = DrawTierBadge(S(18), S(10), imp.tier)
            draw.SimpleText(CYBERWARE.TierNames[imp.tier or 1], "CW_Tiny", S(24) + bwid, S(12), tc)
            if equipped then draw.SimpleText("● УСТАНОВЛЕН", "CW_Tiny", S(120) + bwid, S(12), C.cyan) end
            draw.SimpleText(imp.name, "CW_Head", S(18), S(28), C.white)
            local dh = DrawWrapped(imp.desc, "CW_Small", S(18), S(52), textW, C.dim, S(16), 2)
            DrawStatLines(lines, S(18), S(56) + dh, textW / 2, S(18), 2)

            DrawChamfer(w - btnW - S(16), S(10), btnW, S(24), S(5), A(C.red, 40))
            draw.SimpleText("ЧЕЛОВЕЧНОСТЬ −" .. imp.humanity, "CW_Tiny", w - btnW / 2 - S(16), S(22), C.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        card.OnCursorExited = function()
            if hoverImplant and hoverImplant.id == id then hoverImplant = nil end
        end

        local btn = CyberButton(card, "", C.cyan, function()
            if not IsValid(patient) then return end
            net.Start("Cyberware_InstallOnPlayer")
            net.WriteEntity(patient)
            net.WriteString(id)
            net.SendToServer()
        end, "CW_BodyB")
        btn:SetSize(btnW, S(40))
        card.PerformLayout = function(self, w, hh)
            btn:SetPos(w - btnW - S(16), hh / 2 - S(10))
        end
        btn.cText = function()
            if not IsValid(patient) then return "—" end
            if CYBERWARE:HasImplant(patient, id) then return "ДЕМОНТАЖ" end
            local maxSlots = CYBERWARE.Categories[imp.slot].maxSlots or 1
            local n = #CYBERWARE:GetEquippedList(patient, imp.slot)
            if maxSlots == 1 and n > 0 then return "ЗАМЕНИТЬ" end
            if n >= maxSlots then return "СЛОТЫ ЗАНЯТЫ" end
            return "ВЖИВИТЬ"
        end
        btn.cCol = function()
            if not IsValid(patient) then return C.dark end
            if CYBERWARE:HasImplant(patient, id) then return C.red end
            local maxSlots = CYBERWARE.Categories[imp.slot].maxSlots or 1
            if maxSlots > 1 and #CYBERWARE:GetEquippedList(patient, imp.slot) >= maxSlots then return C.dark end
            return C.green
        end
    end

    RefreshContent = function()
        scroll:Clear()
        hoverImplant = nil
        if not IsValid(patient) then patient = localPly end

        if currentTab == "SCRIPTS" then
            for hackID, hack in SortedPairsByMemberValue(CYBERWARE.Quickhacks, "order") do
                local card = HackCard(scroll, hackID, hack, localPly, { target = patient, rightPad = S(180) })
                local b = CyberButton(card, "", C.green, function()
                    net.Start("Cyberware_ToggleQuickhack")
                    net.WriteEntity(patient)
                    net.WriteString(hackID)
                    net.SendToServer()
                end, "CW_BodyB")
                b:SetSize(S(150), S(36))
                card.PerformLayout = function(self, w, h)
                    b:SetPos(w - S(166), h / 2 - S(18))
                end
                b.cText = function() return IsValid(patient) and CYBERWARE:HasQuickhack(patient, hackID) and "ИЗЪЯТЬ" or "ВЫДАТЬ" end
                b.cCol = function() return IsValid(patient) and CYBERWARE:HasQuickhack(patient, hackID) and C.red or C.green end
            end
            return
        end

        local list = {}
        for id, imp in pairs(CYBERWARE.Implants) do
            if imp.slot == currentTab and (tierFilter == 0 or imp.tier == tierFilter) then
                list[#list + 1] = { id = id, data = imp }
            end
        end
        table.sort(list, function(a, b)
            if (a.data.tier or 1) == (b.data.tier or 1) then return a.data.name < b.data.name end
            return (a.data.tier or 1) < (b.data.tier or 1)
        end)
        for _, item in ipairs(list) do ImplantCard(item.id, item.data) end
    end

    RefreshContent()
end

net.Receive("Cyberware_OpenRipperdoc", function() CYBERWARE:OpenRipperdocMenu() end)
concommand.Add("cyber_ripperdoc", function() CYBERWARE:OpenRipperdocMenu() end)

-- ================= МЕНЮ БЫСТРОГО ВЗЛОМА =================
concommand.Add("cyber_quickhack_menu", function()
    local ply = LocalPlayer()
    local deck = CYBERWARE:GetDeck(ply)
    if not deck then return end

    if IsValid(CYBERWARE.HackMenu) then
        CYBERWARE.HackMenu:Close()
        return
    end

    local target = CYBERWARE:FindSmartHackTarget()
    if not IsValid(target) then
        AddNotice("В зоне видимости кибердеки нет целей", 1)
        return
    end

    local hacks = {}
    for id, hack in SortedPairsByMemberValue(CYBERWARE.Quickhacks, "order") do
        if CYBERWARE:HasQuickhack(ply, id) then hacks[#hacks + 1] = { id = id, data = hack } end
    end
    if #hacks == 0 then
        AddNotice("Нет загруженных скриптов", 1)
        return
    end

    local function Status(h)
        if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then return false, "ЭМИ" end
        if h.data.playersOnly and not target:IsPlayer() then return false, "ТОЛЬКО ИГРОКИ" end
        if h.data.npcOnly and not target:IsNPC() then return false, "ТОЛЬКО NPC" end
        local cd = CYBERWARE:GetHackCooldown(ply, h.id)
        if cd > 0 then return false, string.format("%.1f с", cd) end
        if CYBERWARE:GetRAM(ply) < h.data.ram then return false, "МАЛО ОЗУ" end
        return true
    end

    local rowH = S(50)
    local w = S(440)
    local h = S(118) + #hacks * (rowH + S(4)) + S(70)
    local menu = vgui.Create("DFrame")
    CYBERWARE.HackMenu = menu
    menu:SetSize(w, math.min(h, ScrH() - S(40)))
    menu:SetPos(ScrW() * 0.6, ScrH() / 2 - menu:GetTall() / 2)
    menu:SetTitle("")
    menu:ShowCloseButton(false)
    menu:SetDraggable(false)
    menu:MakePopup()
    menu:SetKeyboardInputEnabled(true)
    menu:SetAlpha(0)
    menu:AlphaTo(255, 0.12, 0)
    menu.born = RealTime()
    menu.openKeyHeld = true
    UISound("hack")

    local hovered = nil
    local function Use(h)
        local ok, why = Status(h)
        if not ok then
            UISound("error")
            AddNotice(h.data.name .. ": " .. why, 1)
            return
        end
        net.Start("Cyberware_UseQuickhack")
        net.WriteString(h.id)
        net.WriteEntity(target)
        net.SendToServer()
        menu:Close()
    end

    local oldClose = menu.Close
    menu.Close = function(self)
        if self.closing then return end
        self.closing = true
        self:AlphaTo(0, 0.1, 0, function() oldClose(self) end)
    end

    menu.Paint = function(self, pw, ph)
        DrawChamfer(0, 0, pw, ph, S(16), Color(5, 10, 10, 235))
        DrawChamferOutline(0, 0, pw, ph, S(16), A(C.green, 200), 2)
        surface.SetDrawColor(A(C.green, 20))
        surface.SetMaterial(matGradD)
        surface.DrawTexturedRect(0, 0, pw, S(90))
        GlitchText("БЫСТРЫЙ ВЗЛОМ", "CW_Sub", S(18), S(12), C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, S(2))
        if IsValid(target) then
            draw.SimpleText(EntDisplayName(target), "CW_BodyB", S(18), S(42), C.white)
            local dist = math.Round(ply:GetPos():Distance(target:GetPos()) * 0.01905, 1)
            draw.SimpleText(dist .. " м", "CW_Small", pw - S(18), S(44), C.green, TEXT_ALIGN_RIGHT)
            local frac = math.Clamp(target:Health() / math.max(1, target:GetMaxHealth()), 0, 1)
            surface.SetDrawColor(A(C.red, 50))
            surface.DrawRect(S(18), S(66), pw - S(36), S(6))
            surface.SetDrawColor(C.red)
            surface.DrawRect(S(18), S(66), (pw - S(36)) * frac, S(6))
        end
        local ram, maxRam = CYBERWARE:GetRAM(ply)
        draw.SimpleText("ОЗУ " .. math.floor(ram) .. "/" .. maxRam, "CW_Tiny", S(18), S(82), C.green)
        DrawSegBar(S(80), S(84), pw - S(98), S(9), ram / math.max(1, maxRam), C.green, maxRam, S(3))

        local desc = hovered and hovered.data.desc or ("[1-" .. math.min(9, #hacks) .. "] или клик — выбрать  •  [" .. CYBERWARE:GetKeyName("Quickhack") .. "] / ПКМ — закрыть")
        DrawWrapped(desc, "CW_Small", S(18), ph - S(60), pw - S(36), hovered and C.white or C.dim, S(16), 3)
        DrawScanlines(0, 0, pw, ph, 14, 3)
    end

    for i, hck in ipairs(hacks) do
        local b = vgui.Create("DButton", menu)
        b:SetPos(S(14), S(108) + (i - 1) * (rowH + S(4)))
        b:SetSize(w - S(28), rowH)
        b:SetText("")
        b.hl = 0
        b.Paint = function(self, bw, bh)
            local ok, why = Status(hck)
            local kc = CYBERWARE.HackKindColors[hck.data.kind] or C.cyan
            self.hl = Lerp(FrameTime() * 16, self.hl, self:IsHovered() and 1 or 0)
            local col = ok and kc or C.dark
            DrawChamfer(0, 0, bw, bh, S(7), ok and LerpColor(self.hl, Color(12, 20, 22, 240), A(kc, 60)) or Color(12, 13, 18, 230))
            DrawChamferOutline(0, 0, bw, bh, S(7), A(col, 120 + 135 * self.hl))
            surface.SetDrawColor(col)
            surface.DrawRect(0, S(7), S(3), bh - S(7))
            if i <= 9 then
                DrawChamfer(S(10), bh / 2 - S(11), S(22), S(22), S(4), A(col, 200))
                draw.SimpleText(tostring(i), "CW_Small", S(21), bh / 2, Color(8, 8, 12), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            draw.SimpleText(hck.data.name, "CW_BodyB", S(42), S(7), ok and C.white or C.dim)
            for r = 1, hck.data.ram do
                surface.SetDrawColor(ok and C.green or C.dark)
                surface.DrawRect(S(42) + (r - 1) * S(9), bh - S(15), S(6), S(8))
            end
            -- полоска перезарядки
            local cd = CYBERWARE:GetHackCooldown(ply, hck.id)
            if cd > 0 then
                local total = math.max(0.1, ply:GetNW2Float("Cyber_HackCDTotal_" .. hck.id, hck.data.cooldown))
                surface.SetDrawColor(A(C.cyan, 40))
                surface.DrawRect(S(3), bh - S(3), (bw - S(6)) * (1 - cd / total), S(2))
            end
            draw.SimpleText(ok and ("ОЗУ " .. hck.data.ram) or why, "CW_Tiny", bw - S(12), bh / 2, ok and C.green or C.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        b.OnCursorEntered = function() hovered = hck UISound("hover") end
        b.OnCursorExited = function() if hovered == hck then hovered = nil end end
        b.DoClick = function() Use(hck) end
        b.DoRightClick = function() menu:Close() end
    end

    menu.OnMousePressed = function(self, code) if code == MOUSE_RIGHT then self:Close() end end

    local numKeys = { KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9 }
    local prevDown = {}
    menu.Think = function(self)
        if self.closing then return end
        if not IsValid(target) or target:Health() <= 0 or not ply:Alive() or not CYBERWARE:GetDeck(ply)
            or ply:GetPos():DistToSqr(target:GetPos()) > (deck.hackRange * 1.25) ^ 2 then
            self:Close()
            return
        end
        if input.IsKeyDown(KEY_ESCAPE) then
            gui.HideGameUI()
            self:Close()
            return
        end
        -- закрытие той же клавишей (после того как её отпустили при открытии)
        local qk = KeyCode("Quickhack")
        local qDown = qk and qk > 0 and input.IsKeyDown(qk)
        if self.openKeyHeld then
            if not qDown then self.openKeyHeld = false end
        elseif qDown then
            self:Close()
            return
        end
        for i, k in ipairs(numKeys) do
            local down = input.IsKeyDown(k)
            if down and not prevDown[k] and hacks[i] then Use(hacks[i]) end
            prevDown[k] = down
        end
    end
end)
