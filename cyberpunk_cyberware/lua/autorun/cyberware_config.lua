-- lua/autorun/sh_cyberware_config.lua
if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("autorun/client/cl_cyberware_ui.lua")
end

CYBERWARE = CYBERWARE or {}

CYBERWARE.Config = {
    DefaultMaxHumanity = 100,
    PsychosisStart = 35,
    PsychosisStage2 = 10,
    PsychosisTerminal = -25,
    MinHumanityCap = -150,
    MaxHumanityCap = 500,
    RipperdocDistance = 200,
    AdminOnlyRipperdoc = true,
    UnlockAllScriptsByDefault = false,
    AdminRanks = {
        ["superadmin"] = true,
        ["admin"] = true,
        ["owner"] = true,
        ["founder"] = true,
        ["root"] = true,
        ["gamemaster"] = true,
        ["moderator"] = true,
        ["operator"] = true,
    },
    DefaultKeys = {
        AdminMenu = KEY_F6,          -- Меню Риппердока (F6 — Админ)
        PlayerMenu = KEY_F8,         -- Личное меню схемы тела для всех игроков (F8)
        OS = KEY_Z,                  -- Вкл/Выкл Сандевистана или Берсерка (Z)
        Quickhack = KEY_X,           -- Смарт-захват цели и меню Кибердеки (X)
        Kerenzikov = KEY_V,          -- Рывок Керензикова (V)
        Kiroshi = KEY_F,             -- Сканер Кироши (F)
    }
}

function CYBERWARE:IsAdmin(ply)
    if not self.Config.AdminOnlyRipperdoc then return true end
    if game.SinglePlayer() then return true end
    if not IsValid(ply) then return false end
    if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
    if SERVER and ply:IsListenServerHost() then return true end

    local group = string.lower(ply:GetUserGroup() or "")
    if self.Config.AdminRanks[group] then return true end

    return false
end

CYBERWARE.TierColors = {
    [1] = Color(180, 185, 195), -- Уровень 1 (Обычный)
    [2] = Color(45, 230, 115),  -- Уровень 2 (Необычный)
    [3] = Color(0, 195, 255),   -- Уровень 3 (Редкий)
    [4] = Color(185, 75, 255),  -- Уровень 4 (Эпический)
    [5] = Color(255, 185, 0),   -- Уровень 5 (Легендарный / Культовый)
}

CYBERWARE.Categories = {
    ["OS"]             = { name = "Операционная система", order = 1, maxSlots = 1 },
    ["OCULAR"]         = { name = "Оптика",               order = 2, maxSlots = 1 },
    ["ARMS"]           = { name = "Импланты рук",         order = 3, maxSlots = 2 },
    ["NERVOUS"]        = { name = "Нервная система",      order = 4, maxSlots = 2 },
    ["SKELETON"]       = { name = "Скелет",               order = 5, maxSlots = 3 },
    ["CIRCULATORY"]    = { name = "Кровообращение",       order = 6, maxSlots = 3 },
    ["INTEGUMENTARY"]  = { name = "Кожа и броня (+HP)",   order = 7, maxSlots = 3 },
}

CYBERWARE.Implants = {
    -- ================= ОПЕРАЦИОННЫЕ СИСТЕМЫ (1 слот) =================
    ["sandy_dynalar_t1"] = {
        name = "Сандевистан «Дайналар МК.1»",
        slot = "OS", tier = 1, humanity = 10, cooldown = 26, duration = 5,
        speedBonus = 0.40, dmgDodge = 0.25,
        desc = "Активный (Z — Вкл/Выкл): Ускоряет бег на +40%, снижает урон в движении на 25% на 5 сек. Повторное нажатие Z отключает имплант досрочно.",
    },
    ["sandy_zetatech_t3"] = {
        name = "Сандевистан «Зетатех МК.3»",
        slot = "OS", tier = 3, humanity = 16, cooldown = 22, duration = 7,
        speedBonus = 0.65, dmgDodge = 0.40,
        desc = "Активный (Z — Вкл/Выкл): Ускоряет бег на +65%, оставляет неоновый шлейф и снижает урон в движении на 40% на 7 сек.",
    },
    ["sandevistan_apogee"] = {
        name = "Сандевистан «Милитех Апогей МК.5»",
        slot = "OS", tier = 5, humanity = 24, cooldown = 18, duration = 9,
        speedBonus = 0.90, dmgDodge = 0.60,
        desc = "Активный (Z — Вкл/Выкл): Культовый имплант. +90% к скорости бега, -60% урона в движении на 9 сек. Убийство врага продлевает действие на 2 сек.",
    },
    ["berserk_moore_t2"] = {
        name = "Берсерк «Мур Текнологиз МК.2»",
        slot = "OS", tier = 2, humanity = 12, cooldown = 32, duration = 6,
        meleeMult = 1.50, slamWave = false,
        desc = "Активный (Z): Здоровье не падает ниже 1 HP, урон в ближнем бою увеличен на +50% в течение 6 секунд.",
    },
    ["berserk_biodyne_t4"] = {
        name = "Берсерк «Биодайн МК.4»",
        slot = "OS", tier = 4, humanity = 18, cooldown = 28, duration = 8,
        meleeMult = 1.80, slamWave = true,
        desc = "Активный (Z): Здоровье не падает ниже 1 HP, урон в ближнем бою +80%. Приземление с высоты создает ударную волну.",
    },
    ["berserk_militech"] = {
        name = "Берсерк «Милитех Рейнджер МК.5»",
        slot = "OS", tier = 5, humanity = 24, cooldown = 24, duration = 10,
        meleeMult = 2.20, slamWave = true,
        desc = "Активный (Z): Неуязвимость к смерти (минимум 1 HP) на 10 сек, урон в ближнем бою +120%, мощная взрывная волна при падении.",
    },
    ["cyberdeck_biotech_t2"] = {
        name = "Кибердека «Биотех Сигма МК.2»",
        slot = "OS", tier = 2, humanity = 10, cooldown = 8,
        hackRange = 800, hackDmgMult = 1.0, cdMult = 1.0,
        desc = "Активный (X): Смарт-захват цели на дистанции до 800 юнитов. Позволяет загружать базовые и выданные скрипты.",
    },
    ["cyberdeck_arasaka_t4"] = {
        name = "Кибердека «Арасака Тень МК.4»",
        slot = "OS", tier = 4, humanity = 16, cooldown = 6,
        hackRange = 1000, hackDmgMult = 1.20, cdMult = 0.80,
        desc = "Активный (X): Дистанция взлома 1000 юнитов, урон всех скриптов увеличен на +20%, а их перезарядка ускорена на 20%.",
    },
    ["cyberdeck_netwatch"] = {
        name = "Кибердека «Сетевой Дозор МК.5»",
        slot = "OS", tier = 5, humanity = 22, cooldown = 4,
        hackRange = 1250, hackDmgMult = 1.40, cdMult = 0.65,
        desc = "Активный (X): Легендарная дека. Дальность смарт-захвата 1250 юнитов, урон скриптов +40%, перезарядка скриптов быстрее на 35%.",
    },

    -- ================= ОПТИКА (1 слот, Уровни 1-5) =================
    ["kiroshi_basic_t1"] = {
        name = "Оптика «Кироши Базовая МК.1»",
        slot = "OCULAR", tier = 1, humanity = 4, cooldown = 18, duration = 4, headMult = 1.15,
        desc = "Активный (F): Подсвечивает врагов сквозь стены на 4 сек и увеличивает урон в голову на +15%.",
    },
    ["kiroshi_clairvoyant_t2"] = {
        name = "Оптика «Кироши Ясновидящий МК.2»",
        slot = "OCULAR", tier = 2, humanity = 7, cooldown = 16, duration = 5, headMult = 1.22, passiveHead = 0.08,
        desc = "Активный (F): Сканирует цели на 5 сек (+22% в голову). Пассивно дает постоянный бонус +8% к урону в голову.",
    },
    ["kiroshi_sentry_t3"] = {
        name = "Оптика «Кироши Часовой МК.3»",
        slot = "OCULAR", tier = 3, humanity = 10, cooldown = 15, duration = 6, headMult = 1.30, passiveHead = 0.12,
        desc = "Активный (F): Подсвечивает врагов сквозь стены на 6 сек (+30% в голову). Пассивно: +12% к урону в голову.",
    },
    ["kiroshi_oracle_t4"] = {
        name = "Оптика «Кироши Оракул МК.4»",
        slot = "OCULAR", tier = 4, humanity = 13, cooldown = 14, duration = 7, headMult = 1.40, passiveHead = 0.18,
        desc = "Активный (F): Высокоточный спектр на 7 сек (+40% к урону в голову). Пассивно повышает точность и урон в голову на +18%.",
    },
    ["kiroshi_stalker"] = {
        name = "Оптика «Кироши Кокатрис МК.5»",
        slot = "OCULAR", tier = 5, humanity = 16, cooldown = 12, duration = 8, headMult = 1.55, passiveHead = 0.25,
        desc = "Активный (F): Культовый анализатор уязвимостей. Подсветка целей на 8 сек (+55% в голову) и постоянный пассивный бонус +25% в голову.",
    },

    -- ================= ИМПЛАНТЫ РУК (До 2 слотов, Уровни 1-5) =================
    ["grip_boost_t1"] = {
        name = "Сервоприводы ладоней МК.1",
        slot = "ARMS", tier = 1, humanity = 5, meleeBoost = 1.25, gunBoost = 1.05, spreadMult = 0.85, knockback = 150,
        desc = "Пассивный: Увеличивает урон в ближнем бою на +25%, урон оружия на +5% и снижает отдачу на 15%.",
    },
    ["shock_absorber_t2"] = {
        name = "Амортизатор отдачи «Вектор МК.2»",
        slot = "ARMS", tier = 2, humanity = 8, meleeBoost = 1.0, gunBoost = 1.12, spreadMult = 0.65, knockback = 0,
        desc = "Пассивный: Гасит 35% отдачи и разброса пуль, повышая урон любого огнестрельного оружия на +12%.",
    },
    ["knuckles_titanium_t2"] = {
        name = "Титановые кастеты МК.2",
        slot = "ARMS", tier = 2, humanity = 8, meleeBoost = 1.45, gunBoost = 1.0, spreadMult = 0.90, knockback = 250,
        desc = "Пассивный: Утяжеленные суставы кулаков. Повышают урон любого оружия ближнего боя на +45% и отталкивают цель.",
    },
    ["ballistic_coprocessor"] = {
        name = "Баллистический сопроцессор «Канг-Тао МК.3»",
        slot = "ARMS", tier = 3, humanity = 11, meleeBoost = 1.0, gunBoost = 1.18, spreadMult = 0.50, knockback = 0,
        desc = "Пассивный: Повышает урон любого стрелкового оружия на +18% и снижает разброс пуль на 50%.",
    },
    ["microgenerator_t3"] = {
        name = "Микрогенератор ладони «Зеттатех МК.3»",
        slot = "ARMS", tier = 3, humanity = 11, meleeBoost = 1.20, gunBoost = 1.14, spreadMult = 0.75, shockDmg = 8,
        desc = "Пассивный: Насыщает оружие электро-импульсом: +20% к ближнему бою, +14% к огнестрелу и +8 ед. шокового урона к каждой атаке.",
    },
    ["gorilla_arms"] = {
        name = "Импланты «Руки Гориллы МК.4»",
        slot = "ARMS", tier = 4, humanity = 14, meleeBoost = 1.75, gunBoost = 1.0, spreadMult = 0.65, knockback = 380,
        desc = "Пассивный: Урон ближнего боя +75%, удары отбрасывают врагов, а отдача стрелкового оружия снижена на 35%.",
    },
    ["immovable_force_t4"] = {
        name = "Стабилизатор «Неодолимая Сила МК.4»",
        slot = "ARMS", tier = 4, humanity = 15, meleeBoost = 1.0, gunBoost = 1.25, spreadMult = 0.35, knockback = 0,
        desc = "Пассивный: Гироскопический компенсатор плеча. Урон огнестрельного оружия +25%, разброс пуль снижен на 65%.",
    },
    ["gorilla_arms_t5"] = {
        name = "Культовые «Руки Гориллы: Джаггернаут МК.5»",
        slot = "ARMS", tier = 5, humanity = 19, meleeBoost = 2.15, gunBoost = 1.10, spreadMult = 0.55, knockback = 520,
        desc = "Пассивный: +115% к урону в ближнем бою, сокрушительное отбрасывание врагов, +10% к урону огнестрела и -45% отдачи.",
    },
    ["smart_link_t5"] = {
        name = "Нейро-матрица стрелка «Арасака МК.5»",
        slot = "ARMS", tier = 5, humanity = 19, meleeBoost = 1.0, gunBoost = 1.35, spreadMult = 0.20, knockback = 0,
        desc = "Пассивный: Увеличивает урон любого огнестрельного оружия на +35% и гасит 80% разброса при стрельбе.",
    },

    -- ================= НЕРВНАЯ СИСТЕМА (До 2 слотов, Уровни 1-5) =================
    ["kerenzikov_t1"] = {
        name = "Керензиков «Базовый МК.1»",
        slot = "NERVOUS", tier = 1, humanity = 5, cooldown = 8, dashPower = 750, dodgeTime = 0.25,
        desc = "Активный (V): Быстрый рывок в сторону движения раз в 8 сек (0.25 сек уклонения от пуль).",
    },
    ["tyrosine_injector_t1"] = {
        name = "Тирозиновый инъектор МК.1",
        slot = "NERVOUS", tier = 1, humanity = 5, passiveDodge = 0.07, nervousSpeed = 0.05,
        desc = "Пассивный: Ускоряет передачу нервных импульсов, давая +7% шанс уклонения от пуль и +5% к скорости бега.",
    },
    ["reflex_tuner_t2"] = {
        name = "Рефлекторный тюнер «Инстинкты МК.2»",
        slot = "NERVOUS", tier = 2, humanity = 8, passiveDodge = 0.12,
        desc = "Пассивный: Нейро-ускоритель реакций. Дает постоянный 12% шанс полностью избежать пулевого урона.",
    },
    ["atomic_sensors_t2"] = {
        name = "Атомные датчики движения МК.2",
        slot = "NERVOUS", tier = 2, humanity = 8, passiveDodge = 0.08, nervousSpeed = 0.10,
        desc = "Пассивный: Повышает базовую скорость передвижения на +10% и дает +8% шанс уклонения от выстрелов.",
    },
    ["kerenzikov_t3"] = {
        name = "Керензиков «Рефлекс МК.3»",
        slot = "NERVOUS", tier = 3, humanity = 11, cooldown = 6, dashPower = 880, dodgeTime = 0.40,
        desc = "Активный (V): Мощный тактический рывок раз в 6 сек (0.40 сек полного уклонения от пуль).",
    },
    ["neofiber_t3"] = {
        name = "Искусственное «Неоволокно МК.3»",
        slot = "NERVOUS", tier = 3, humanity = 11, passiveDodge = 0.16, nervousSpeed = 0.08,
        desc = "Пассивный: Синтетические мышечные волокна дают +16% шанс уклонения от пуль и +8% к скорости бега.",
    },
    ["synaptic_accelerator_t4"] = {
        name = "Синаптический ускоритель МК.4",
        slot = "NERVOUS", tier = 4, humanity = 14, passiveDodge = 0.22,
        desc = "Пассивный: Позволяет предугадывать траекторию стрельбы врага, давая постоянный 22% шанс уклонения от пуль.",
    },
    ["deep_field_visual_t4"] = {
        name = "Сенсор глубокого поля «Милитех МК.4»",
        slot = "NERVOUS", tier = 4, humanity = 14, passiveDodge = 0.15, nervousSpeed = 0.12,
        desc = "Пассивный: Координирует моторику в бою: +15% шанс уклонения от пуль и +12% к постоянной скорости движения.",
    },
    ["kerenzikov_prime"] = {
        name = "Керензиков «Вектор МК.5»",
        slot = "NERVOUS", tier = 5, humanity = 16, cooldown = 4, dashPower = 1020, dodgeTime = 0.60,
        desc = "Активный (V): Сверхзвуковой рывок каждые 4 секунды со 100% уклонением от очередей во время полета.",
    },
    ["revulsor_t5"] = {
        name = "Культовый «Ревульсор МК.5»",
        slot = "NERVOUS", tier = 5, humanity = 18, passiveDodge = 0.26, nervousSpeed = 0.15,
        desc = "Пассивный: Вершина нейро-инженерии. Дает постоянный 26% шанс уклонения от пуль и +15% к скорости бега.",
    },

    -- ================= СКЕЛЕТ (До 3 слотов, Уровни 1-5) =================
    ["titanium_bones_t1"] = {
        name = "Титановые кости МК.1",
        slot = "SKELETON", tier = 1, humanity = 4, fallMult = 0.4, speedPassive = 0.06, jumpCharge = false,
        desc = "Пассивный: Снижает урон от падения на 60% и повышает базовую скорость передвижения на +6%.",
    },
    ["universal_booster_t1"] = {
        name = "Усилитель костной ткани МК.1",
        slot = "SKELETON", tier = 1, humanity = 5, skelHP = 20, speedPassive = 0.04,
        desc = "Пассивный: Укрепляет грудную клетку, добавляя +20 к макс. HP и +4% к скорости бега.",
    },
    ["bionic_joints_t2"] = {
        name = "Бионические суставы МК.2",
        slot = "SKELETON", tier = 2, humanity = 7, speedPassive = 0.10, meleeResist = 0.15,
        desc = "Пассивный: Повышает скорость передвижения на +10% и снижает входящий урон в ближнем бою на 15%.",
    },
    ["spring_joints_t2"] = {
        name = "Пружинные сочленения МК.2",
        slot = "SKELETON", tier = 2, humanity = 8, skelHP = 30, skelArmor = 0.08,
        desc = "Пассивный: Амортизирует кинетические удары: дает +30 к макс. HP и поглощает 8% любого урона.",
    },
    ["fortified_ankles"] = {
        name = "Укрепленные лодыжки (Гидро-прыжок МК.3)",
        slot = "SKELETON", tier = 3, humanity = 10, fallMult = 0.0, speedPassive = 0.05, jumpCharge = true, jumpMult = 1.5,
        desc = "Пассивный: Зажатие ПРОБЕЛА копит заряд гидравлики для высокого прыжка. Полный иммунитет к урону от падения.",
    },
    ["scarab_carapace_t3"] = {
        name = "Корсет «Скарабей МК.3»",
        slot = "SKELETON", tier = 3, humanity = 11, skelHP = 45, skelArmor = 0.12,
        desc = "Пассивный: Внутренний бронекаркас позвоночника: +45 к макс. HP и снижение любого входящего урона на 12%.",
    },
    ["dense_marrow_t4"] = {
        name = "Плотный костный мозг МК.4",
        slot = "SKELETON", tier = 4, humanity = 13, speedPassive = 0.08, meleeDmgSkel = 0.30,
        desc = "Пассивный: Увеличивает урон ваших атак ближнего боя на +30% и скорость бега на +8%.",
    },
    ["para_bellum_t4"] = {
        name = "Эндоскелет «Пара Беллум МК.4»",
        slot = "SKELETON", tier = 4, humanity = 14, skelHP = 65, meleeResist = 0.25, skelArmor = 0.10,
        desc = "Пассивный: Тяжелое укрепление скелета: +65 к макс. HP, -25% урона в ближнем бою и -10% общего урона.",
    },
    ["epimorphic_skeleton_t5"] = {
        name = "Эндоскелет «Эпиморфик МК.5»",
        slot = "SKELETON", tier = 5, humanity = 17, skelHP = 50, fallMult = 0.0, speedPassive = 0.15, jumpCharge = true, jumpMult = 1.9,
        desc = "Пассивный: Максимальная мощь гидро-прыжка, +50 к макс. HP, +15% к базовой скорости бега и иммунитет к падению.",
    },
    ["atlas_frame_t5"] = {
        name = "Титановый каркас «Атлант МК.5»",
        slot = "SKELETON", tier = 5, humanity = 18, skelHP = 90, meleeDmgSkel = 0.45, skelArmor = 0.16,
        desc = "Пассивный: Культовый военный эндоскелет: +90 к макс. HP, +45% урона в ближнем бою и 16% поглощения урона.",
    },

    -- ================= КРОВООБРАЩЕНИЕ (До 3 слотов, Уровни 1-5) =================
    ["biomonitor_t1"] = {
        name = "Биомонитор МК.1",
        slot = "CIRCULATORY", tier = 1, humanity = 5, cooldown = 45, healAmount = 40,
        desc = "Пассивный: При падении HP ниже 40% автоматически восстанавливает 40 HP (КД: 45 сек).",
    },
    ["adrenaline_booster_t1"] = {
        name = "Адреналиновый стимулятор МК.1",
        slot = "CIRCULATORY", tier = 1, humanity = 5, killHeal = 25,
        desc = "Пассивный: Мгновенно восстанавливает +25 HP после каждого устранения противника.",
    },
    ["heal_on_kill_t2"] = {
        name = "Синтетический кардиостимулятор МК.2",
        slot = "CIRCULATORY", tier = 2, humanity = 7, bonusRegen = 2,
        desc = "Пассивный: Ускоряет метаболизм и непрерывно восстанавливает +2 HP каждые 1.5 секунды.",
    },
    ["blood_pump_t2"] = {
        name = "Кровавый насос «Биодайн МК.2»",
        slot = "CIRCULATORY", tier = 2, humanity = 8, cooldown = 38, healAmount = 55,
        desc = "Пассивный: При падении HP ниже 45% автоматически впрыскивает плазму, восстанавливая +55 HP (КД: 38 сек).",
    },
    ["adrenaline_converter"] = {
        name = "Адреналиновый конвертер «Дайналар МК.3»",
        slot = "CIRCULATORY", tier = 3, humanity = 10, killHeal = 45, cdRefund = 5,
        desc = "Пассивный: Каждое убийство врага мгновенно исцеляет вас на 45 HP и сокращает перезарядку ОС на 5 секунд.",
    },
    ["feedback_circuit_t3"] = {
        name = "Контур обратной связи МК.3",
        slot = "CIRCULATORY", tier = 3, humanity = 11, passiveVamp = 0.10, bonusRegen = 1,
        desc = "Пассивный: Преобразует боль врагов в био-энергию: постоянный 10% вампиризм от любого урона и +1 HP регенерации.",
    },
    ["micro_rotors_t4"] = {
        name = "Микророторы кровотока МК.4",
        slot = "CIRCULATORY", tier = 4, humanity = 13, bonusRegen = 4,
        desc = "Пассивный: Насыщает кровь кислородом, непрерывно восстанавливая +4 HP каждые 1.5 секунды.",
    },
    ["bioconductor_t4"] = {
        name = "Биопроводник «Милитех МК.4»",
        slot = "CIRCULATORY", tier = 4, humanity = 14, killHeal = 35, cdRefund = 8, passiveVamp = 0.08,
        desc = "Пассивный: Постоянный 8% вампиризм, а убийство врага лечит на +35 HP и сокращает перезарядку ОС на 8 сек.",
    },
    ["blood_pump_shock"] = {
        name = "Кровавый насос с электро-конденсатором МК.5",
        slot = "CIRCULATORY", tier = 5, humanity = 17, cooldown = 30,
        desc = "Пассивный: При падении HP ниже 50% мгновенно восстанавливает 75 HP, бьет врагов вокруг молнией (35 урона) и дает 30% вампиризма на 6 сек.",
    },
    ["isometric_stabilizer_t5"] = {
        name = "Культовый «Электролит-Сердце МК.5»",
        slot = "CIRCULATORY", tier = 5, humanity = 18, bonusRegen = 6, passiveVamp = 0.18,
        desc = "Пассивный: Непрерывная регенерация +6 HP каждые 1.5 сек и постоянный 18% вампиризм от всех ваших атак.",
    },

    -- ================= КОЖА И БРОНЯ (+МАКС. HP, До 3 слотов, Уровни 1-5) =================
    ["subdermal_t1"] = {
        name = "Подкожная броня МК.1",
        slot = "INTEGUMENTARY", tier = 1, humanity = 4, bonusHP = 25, armorMult = 0.92, fireImmune = false, regen = 0,
        desc = "Пассивный: Увеличивает максимальное здоровье на +25 HP и снижает входящий урон на 8%.",
    },
    ["carapace_light_t1"] = {
        name = "Термостойкое покрытие кожи МК.1",
        slot = "INTEGUMENTARY", tier = 1, humanity = 5, bonusHP = 30, armorMult = 0.94, fireImmune = true, regen = 0,
        desc = "Пассивный: +30 к макс. HP, снижает входящий урон на 6% и дает полный иммунитет к огню.",
    },
    ["subdermal_t2"] = {
        name = "Армированная кожа «Панцирь МК.2»",
        slot = "INTEGUMENTARY", tier = 2, humanity = 7, bonusHP = 50, armorMult = 0.86, fireImmune = false, regen = 0,
        desc = "Пассивный: Увеличивает максимальное здоровье на +50 HP и снижает входящий урон на 14%.",
    },
    ["grounded_plating_t2"] = {
        name = "Заземляющая коронарная обшивка МК.2",
        slot = "INTEGUMENTARY", tier = 2, humanity = 8, bonusHP = 45, armorMult = 0.88, shockResist = true, regen = 1,
        desc = "Пассивный: +45 к макс. HP, снижает урон на 12%, поглощает 50% электро-урона и регенерирует +1 HP/тик.",
    },
    ["subdermal_carapace"] = {
        name = "Карбоновый подкожный панцирь МК.3",
        slot = "INTEGUMENTARY", tier = 3, humanity = 11, bonusHP = 80, armorMult = 0.80, fireImmune = true, regen = 0,
        desc = "Пассивный: Увеличивает максимальное здоровье на +80 HP, снижает урон на 20% и дает иммунитет к огню.",
    },
    ["nano_plating_t3"] = {
        name = "Нано-пластины «Отражатель МК.3»",
        slot = "INTEGUMENTARY", tier = 3, humanity = 12, bonusHP = 70, armorMult = 0.84, reflectChance = 0.15, regen = 0,
        desc = "Пассивный: +70 к макс. HP, снижает урон на 16% и дает 15% шанс полностью рикошетить вражескую пулю.",
    },
    ["supradermal_t4"] = {
        name = "Нано-обшивка «Супрадерм МК.4»",
        slot = "INTEGUMENTARY", tier = 4, humanity = 15, bonusHP = 120, armorMult = 0.74, fireImmune = true, regen = 2,
        desc = "Пассивный: +120 к макс. HP, снижает входящий урон на 26%, иммунитет к огню и регенерация +2 HP/тик.",
    },
    ["pain_editor_t4"] = {
        name = "Редактор боли «Арасака МК.4»",
        slot = "INTEGUMENTARY", tier = 4, humanity = 16, bonusHP = 110, armorMult = 0.72, fireImmune = false, regen = 1,
        desc = "Пассивный: Блокирует болевые рецепторы: +110 к макс. HP, снижает любой входящий урон на 28% и дает +1 HP/тик.",
    },
    ["chitin_shell_t5"] = {
        name = "Хитиновый панцирь «Милитех МК.5»",
        slot = "INTEGUMENTARY", tier = 5, humanity = 20, bonusHP = 165, armorMult = 0.68, fireImmune = true, regen = 3,
        desc = "Пассивный: +165 к макс. HP, поглощает 32% любого урона, полный иммунитет к огню и регенерация +3 HP/тик.",
    },
    ["cellular_adapter_t5"] = {
        name = "Культовый «Клеточный адаптер МК.5»",
        slot = "INTEGUMENTARY", tier = 5, humanity = 22, bonusHP = 200, armorMult = 0.65, fireImmune = true, regen = 4,
        desc = "Пассивный: Абсолютная защита: +200 к макс. HP, снижение любого урона на 35%, иммунитет к огню и +4 HP регенерации/тик.",
    }
}

CYBERWARE.Quickhacks = {
    ["short_circuit"] = {
        name = "Короткое замыкание", cooldown = 7, range = 950, defaultUnlocked = true,
        desc = "Базовый скрипт: Мгновенно бьет цель током на 40 урона и замедляет её на 30% на 2.5 сек.",
    },
    ["optics_reboot"] = {
        name = "Перезагрузка оптики", cooldown = 14, range = 950, defaultUnlocked = true,
        desc = "Базовый скрипт: Заливает экран цели яркими помехами и ослепляет на 4.5 секунды.",
    },
    ["cripple_movement"] = {
        name = "Паралич суставов (Контр-Сандевистан)", cooldown = 16, range = 950, defaultUnlocked = false,
        desc = "Блокирует сервоприводы ног: принудительно выключает Сандевистан и запрещает цели бегать, прыгать и делать рывки на 5 сек.",
    },
    ["synapse_burn"] = {
        name = "Синаптический коллапс", cooldown = 18, range = 950, defaultUnlocked = false,
        desc = "Сжигает нейросеть врага: наносит 60 чистого урона (+1% за каждый недостающий процент HP цели).",
    },
    ["cyberware_malfunction"] = {
        name = "Детонация имплантов (EMP)", cooldown = 20, range = 950, defaultUnlocked = false,
        desc = "Взрывает конденсаторы имплантов: отключает Сандевистан/Берсерк, наносит 45 урона и блокирует все импланты на 7 сек.",
    },
    ["weapon_glitch"] = {
        name = "Сбой вооружения", cooldown = 15, range = 950, defaultUnlocked = false,
        desc = "Электромагнитный клин оружия: выбрасывает патроны из магазина цели в запас и подбрасывает прицел.",
    },
    ["contagion"] = {
        name = "Нейровирус «Заражение»", cooldown = 22, range = 900, defaultUnlocked = false,
        desc = "Отравляет цель и всех врагов рядом в радиусе 300 юнитов: наносит по 12 урона в секунду в течение 5 сек.",
    },
    ["detonate_grenade"] = {
        name = "Подрыв боекомплекта", cooldown = 28, range = 900, defaultUnlocked = false,
        desc = "Ультимативный скрипт: детонирует гранату на поясе врага, нанося 80 взрывного урона и подбрасывая его в воздух.",
    }
}

function CYBERWARE:GetEquippedList(ply, slot)
    if not IsValid(ply) then return {} end
    local raw = ply:GetNW2String("Cyber_Slot_" .. slot, "")
    if raw == "" then return {} end

    local res = {}
    for _, id in ipairs(string.Explode(",", raw)) do
        if self.Implants[id] then
            table.insert(res, { id = id, data = self.Implants[id] })
        end
    end
    return res
end

function CYBERWARE:GetEquippedInSlot(ply, slot)
    local list = self:GetEquippedList(ply, slot)
    if #list == 0 then return nil, nil end
    table.sort(list, function(a, b) return (a.data.tier or 1) > (b.data.tier or 1) end)
    return list[1].data, list[1].id
end

function CYBERWARE:HasImplant(ply, id)
    if not IsValid(ply) then return false end
    local imp = self.Implants[id]
    if not imp then return false end
    local raw = ply:GetNW2String("Cyber_Slot_" .. imp.slot, "")
    if raw == "" then return false end
    for _, eqID in ipairs(string.Explode(",", raw)) do
        if eqID == id then return true end
    end
    return false
end

function CYBERWARE:HasQuickhack(ply, hackID)
    if not IsValid(ply) then return false end
    local hack = self.Quickhacks[hackID]
    if not hack then return false end
    if self.Config.UnlockAllScriptsByDefault or hack.defaultUnlocked then
        return not ply:GetNW2Bool("Cyber_HackRevoked_" .. hackID, false)
    end
    return ply:GetNW2Bool("Cyber_Hack_" .. hackID, false)
end

function CYBERWARE:GetMaxHumanity(ply)
    if not IsValid(ply) then return self.Config.DefaultMaxHumanity end
    return ply:GetNW2Int("Cyber_MaxHumanity", self.Config.DefaultMaxHumanity)
end

function CYBERWARE:GetHumanity(ply)
    if not IsValid(ply) then return self.Config.DefaultMaxHumanity end
    local maxH = self:GetMaxHumanity(ply)
    local used = 0
    for slot, _ in pairs(self.Categories) do
        for _, item in ipairs(self:GetEquippedList(ply, slot)) do
            used = used + (item.data.humanity or 0)
        end
    end
    return math.Clamp(maxH - used, self.Config.MinHumanityCap, self.Config.MaxHumanityCap)
end

hook.Add("SetupMove", "Cyberware_MovementControl", function(ply, mv, cmd)
    if not ply:Alive() then return end

    if ply:GetNW2Float("Cyber_Crippled_Until", 0) > CurTime() then
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP), bit.bnot(IN_SPEED)))
        ply:SetNW2Float("Cyber_JumpCharge", 0)
        ply.Cyber_JumpCharge = 0
        return
    end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then return end

    local canChargeJump = false
    local bestJumpMult = 1.5
    for _, item in ipairs(CYBERWARE:GetEquippedList(ply, "SKELETON")) do
        if item.data.jumpCharge then
            canChargeJump = true
            bestJumpMult = math.max(bestJumpMult, item.data.jumpMult or 1.5)
        end
    end

    if canChargeJump then
        if ply:OnGround() then
            if mv:KeyDown(IN_JUMP) then
                mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
                ply.Cyber_JumpCharge = math.min(1.0, (ply.Cyber_JumpCharge or 0) + FrameTime() * 1.4)
                if SERVER then ply:SetNW2Float("Cyber_JumpCharge", ply.Cyber_JumpCharge) end
            elseif (ply.Cyber_JumpCharge or 0) > 0 then
                local charge = ply.Cyber_JumpCharge
                ply.Cyber_JumpCharge = 0
                if SERVER then ply:SetNW2Float("Cyber_JumpCharge", 0) end

                ply:SetGroundEntity(NULL)
                local vel = mv:GetVelocity()
                if charge < 0.20 then
                    vel.z = ply:GetJumpPower()
                else
                    vel.z = ply:GetJumpPower() * (1.25 + charge * bestJumpMult)
                    if SERVER then ply:EmitSound("npc/scanner/scanner_nearmiss2.wav", 75, 95) end
                end
                mv:SetVelocity(vel)
            end
        else
            if (ply.Cyber_JumpCharge or 0) > 0 then
                ply.Cyber_JumpCharge = 0
                if SERVER then ply:SetNW2Float("Cyber_JumpCharge", 0) end
            end
        end
    end
end)