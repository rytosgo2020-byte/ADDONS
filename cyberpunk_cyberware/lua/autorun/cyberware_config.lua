-- lua/autorun/cyberware_config.lua  (shared)
if SERVER then
    AddCSLuaFile()
end

CYBERWARE = CYBERWARE or {}
CYBERWARE.Version = "2.0"

CYBERWARE.Config = {
    -- Человечность. Полный комплект МК.3 ≈ 66 ед., МК.4 ≈ 95 ед., МК.5 ≈ 124 ед. нагрузки.
    DefaultMaxHumanity = 100,
    PsychosisStart = 25,      -- ниже: нестабильность (лёгкие галлюцинации)
    PsychosisStage2 = 0,      -- ниже: киберпсихоз
    PsychosisTerminal = -20,  -- ниже: терминальная стадия
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

    -- Клавиши по умолчанию. Каждый игрок может переназначить их в F8 → «Настройки».
    DefaultKeys = {
        AdminMenu  = KEY_F6,  -- Терминал риппердока (админ)
        PlayerMenu = KEY_F8,  -- Личная схема имплантов
        OS         = KEY_Z,   -- Сандевистан / Берсерк
        Quickhack  = KEY_X,   -- Кибердека: захват цели и скрипты
        Kerenzikov = KEY_V,   -- Рывок
        Kiroshi    = KEY_F,   -- Сканирование оптикой
        Arms       = KEY_G,   -- Ракетная система рук
        Camo       = KEY_B,   -- Оптический камуфляж
    },

    -- Потолки суммарных бонусов, чтобы стак имплантов не делал игрока бессмертным.
    Caps = {
        BonusHP     = 200,
        Armor       = 0.50,
        MeleeResist = 0.45,
        Dodge       = 0.30,
        Speed       = 0.35,
        Melee       = 1.50,
        Gun         = 0.50,
        SpreadMin   = 0.30,
        Regen       = 6,
        Vamp        = 0.25,
        KillHeal    = 50,
        CDRefund    = 6,
    },

    RegenTick = 1.5,         -- период пассивной регенерации (сек)
    RegenCombatDelay = 4,    -- регенерация не работает N секунд после получения урона
    HackGlobalDelay = 0.6,   -- анти-спам между скриптами
}

CYBERWARE.TierColors = {
    [1] = Color(170, 178, 190),
    [2] = Color(60, 230, 120),
    [3] = Color(40, 170, 255),
    [4] = Color(190, 90, 255),
    [5] = Color(255, 180, 20),
}

CYBERWARE.TierNames = {
    [1] = "ОБЫЧНЫЙ",
    [2] = "НЕОБЫЧНЫЙ",
    [3] = "РЕДКИЙ",
    [4] = "ЭПИЧЕСКИЙ",
    [5] = "ЛЕГЕНДАРНЫЙ",
}

CYBERWARE.SlotOrder = { "OS", "OCULAR", "ARMS", "NERVOUS", "SKELETON", "CIRCULATORY", "INTEGUMENTARY" }

CYBERWARE.Categories = {
    ["OS"]            = { name = "Операционная система", short = "ОС",       order = 1, maxSlots = 1 },
    ["OCULAR"]        = { name = "Оптика",               short = "ОПТИКА",   order = 2, maxSlots = 1 },
    ["ARMS"]          = { name = "Руки",                 short = "РУКИ",     order = 3, maxSlots = 2 },
    ["NERVOUS"]       = { name = "Нервная система",      short = "НЕРВЫ",    order = 4, maxSlots = 2 },
    ["SKELETON"]      = { name = "Скелет",               short = "СКЕЛЕТ",   order = 5, maxSlots = 3 },
    ["CIRCULATORY"]   = { name = "Кровообращение",       short = "КРОВЬ",    order = 6, maxSlots = 3 },
    ["INTEGUMENTARY"] = { name = "Кожа и броня",         short = "КОЖА",     order = 7, maxSlots = 3 },
}

-- Подписи активных способностей (ключ = действие в DefaultKeys)
CYBERWARE.ActionNames = {
    OS = "ОС", Quickhack = "ВЗЛОМ", Kerenzikov = "РЫВОК", Kiroshi = "СКАН", Arms = "РАКЕТА", Camo = "КАМО",
    PlayerMenu = "Личное меню", AdminMenu = "Риппердок",
}

--[[
    Поля имплантов:
      humanity — нагрузка на человечность; active — клавиша способности (ключ DefaultKeys)
      ОС:     speedBonus, dmgDodge, killExtend, sandyKillHeal | meleeMult, berserkArmor, slamWave | ram, ramRegen, hackRange, hackDmgMult, cdMult
      Оптика: headMult (активно), headPassive, scanRange
      Руки:   meleeBonus, gunBonus, spreadMult, knockback, shockDmg, bleedDps/bleedTime, chainShock/chainTargets, launcherDmg/launcherRadius
      Нервы:  dashPower, dodgeTime, passiveDodge, speedPassive, selfIce
      Скелет: bonusHP, armor, meleeResist, fallMult, speedPassive, meleeBonus, jumpCharge/jumpMult, doubleJump, silentSteps
      Кровь:  healThreshold/healAmount, pumpShock, vampBurst, killHeal, cdRefund, regen, vamp, secondHeart
      Кожа:   bonusHP, armor, fireResist, shockResist, reflectChance, regen, camo
]]
CYBERWARE.Implants = {
    -- ================= ОПЕРАЦИОННЫЕ СИСТЕМЫ (1 слот) =================
    ["sandy_dynalar_t1"] = {
        name = "Сандевистан «Дайналар МК.1»", slot = "OS", tier = 1, humanity = 6, active = "OS",
        cooldown = 30, duration = 5, speedBonus = 0.30, dmgDodge = 0.20,
        desc = "Бюджетный ускоритель нейронов. Мир замедляется, ты — нет. Повторное нажатие отключает досрочно и частично возвращает перезарядку.",
    },
    ["sandy_zetatech_t3"] = {
        name = "Сандевистан «Зетатех МК.3»", slot = "OS", tier = 3, humanity = 10, active = "OS",
        cooldown = 26, duration = 6, speedBonus = 0.45, dmgDodge = 0.30,
        desc = "Надёжная военная модель с неоновым шлейфом остаточных образов.",
    },
    ["sandy_falcon_t4"] = {
        name = "Сандевистан «Милитех Фалкон МК.4»", slot = "OS", tier = 4, humanity = 12, active = "OS",
        cooldown = 24, duration = 7, speedBonus = 0.55, dmgDodge = 0.35, killExtend = 1,
        desc = "Тактическая версия для спецподразделений Милитеха. Каждое убийство продлевает ускорение.",
    },
    ["sandevistan_apogee"] = {
        name = "Сандевистан «Милитех Апогей МК.5»", slot = "OS", tier = 5, humanity = 14, active = "OS",
        cooldown = 22, duration = 8, speedBonus = 0.65, dmgDodge = 0.40, killExtend = 2,
        desc = "Культовый имплант. Абсолютное превосходство в скорости — пока нейросеть выдерживает нагрузку.",
    },
    ["sandy_warp_dancer"] = {
        name = "Сандевистан «Квиант Варп-Дансер МК.5»", slot = "OS", tier = 5, humanity = 14, active = "OS",
        cooldown = 26, duration = 6, speedBonus = 0.60, dmgDodge = 0.35, killExtend = 1, sandyKillHeal = 0.10,
        desc = "Экспериментальная разработка Квиант. Убийства в ускорении подпитывают организм.",
    },
    ["berserk_moore_t2"] = {
        name = "Берсерк «Мур Текнолоджиз МК.2»", slot = "OS", tier = 2, humanity = 8, active = "OS",
        cooldown = 40, duration = 6, meleeMult = 1.30, berserkArmor = 0.10, slamWave = false,
        desc = "Боевой стимулятор: тело отказывается умирать, пока работает имплант.",
    },
    ["berserk_biodyne_t4"] = {
        name = "Берсерк «Биодайн МК.4»", slot = "OS", tier = 4, humanity = 12, active = "OS",
        cooldown = 36, duration = 7, meleeMult = 1.45, berserkArmor = 0.15, slamWave = true,
        desc = "Укреплённые сервоприводы позволяют обрушиваться на врагов с высоты.",
    },
    ["berserk_militech"] = {
        name = "Берсерк «Милитех Рейнджер МК.5»", slot = "OS", tier = 5, humanity = 14, active = "OS",
        cooldown = 34, duration = 8, meleeMult = 1.60, berserkArmor = 0.20, slamWave = true,
        desc = "Армейский берсерк. Превращает носителя в живой таран.",
    },
    ["cyberdeck_biotech_t2"] = {
        name = "Кибердека «Биотех Сигма МК.2»", slot = "OS", tier = 2, humanity = 8, active = "Quickhack",
        ram = 6, ramRegen = 0.5, hackRange = 800, hackDmgMult = 1.0, cdMult = 1.0,
        desc = "Гражданская дека начального уровня. Скрипты расходуют ОЗУ, которое восстанавливается со временем.",
    },
    ["cyberdeck_paraline_t3"] = {
        name = "Кибердека «Милитех Паралайн МК.3»", slot = "OS", tier = 3, humanity = 10, active = "Quickhack",
        ram = 8, ramRegen = 0.6, hackRange = 900, hackDmgMult = 1.10, cdMult = 0.90,
        desc = "Сбалансированная военная дека с расширенным буфером памяти.",
    },
    ["cyberdeck_arasaka_t4"] = {
        name = "Кибердека «Арасака Тень МК.4»", slot = "OS", tier = 4, humanity = 12, active = "Quickhack",
        ram = 10, ramRegen = 0.7, hackRange = 1000, hackDmgMult = 1.20, cdMult = 0.80,
        desc = "Корпоративная дека для тихих операций.",
    },
    ["cyberdeck_tetratronic_t4"] = {
        name = "Кибердека «Тетратроник Риплер МК.4»", slot = "OS", tier = 4, humanity = 12, active = "Quickhack",
        ram = 9, ramRegen = 0.8, hackRange = 950, hackDmgMult = 1.30, cdMult = 0.90,
        desc = "Дека для агрессивного взлома: меньше памяти, больше урона.",
    },
    ["cyberdeck_netwatch"] = {
        name = "Кибердека «Сетевой Дозор МК.5»", slot = "OS", tier = 5, humanity = 14, active = "Quickhack",
        ram = 13, ramRegen = 0.9, hackRange = 1200, hackDmgMult = 1.35, cdMult = 0.70,
        desc = "Легендарная дека агентов Сетевого Дозора.",
    },

    -- ================= ОПТИКА (1 слот) =================
    ["kiroshi_basic_t1"] = {
        name = "Оптика «Кироши Базовая МК.1»", slot = "OCULAR", tier = 1, humanity = 2, active = "Kiroshi",
        cooldown = 20, duration = 4, headMult = 1.15, scanRange = 1500,
        desc = "Подсвечивает живые цели сквозь стены и показывает их состояние.",
    },
    ["kiroshi_clairvoyant_t2"] = {
        name = "Оптика «Кироши Ясновидящий МК.2»", slot = "OCULAR", tier = 2, humanity = 3, active = "Kiroshi",
        cooldown = 18, duration = 5, headMult = 1.20, headPassive = 0.05, scanRange = 1800,
        desc = "Улучшенная матрица захвата с пассивным анализом уязвимых зон.",
    },
    ["kiroshi_sentry_t3"] = {
        name = "Оптика «Кироши Часовой МК.3»", slot = "OCULAR", tier = 3, humanity = 4, active = "Kiroshi",
        cooldown = 16, duration = 6, headMult = 1.25, headPassive = 0.08, scanRange = 2200,
        desc = "Военная оптика с расширенным спектром сканирования.",
    },
    ["kiroshi_oracle_t4"] = {
        name = "Оптика «Кироши Оракул МК.4»", slot = "OCULAR", tier = 4, humanity = 5, active = "Kiroshi",
        cooldown = 15, duration = 7, headMult = 1.30, headPassive = 0.10, scanRange = 2600,
        desc = "Высокоточный спектральный анализатор.",
    },
    ["kiroshi_stalker"] = {
        name = "Оптика «Кироши Кокатрис МК.5»", slot = "OCULAR", tier = 5, humanity = 6, active = "Kiroshi",
        cooldown = 14, duration = 8, headMult = 1.40, headPassive = 0.15, scanRange = 3200,
        desc = "Культовый анализатор уязвимостей.",
    },

    -- ================= РУКИ (2 слота) =================
    ["grip_boost_t1"] = {
        name = "Сервоприводы ладоней МК.1", slot = "ARMS", tier = 1, humanity = 2,
        meleeBonus = 0.15, gunBonus = 0.03, spreadMult = 0.90, knockback = 120,
        desc = "Усиленный хват для оружия и кулаков.",
    },
    ["shock_absorber_t2"] = {
        name = "Амортизатор отдачи «Вектор МК.2»", slot = "ARMS", tier = 2, humanity = 3,
        gunBonus = 0.08, spreadMult = 0.75,
        desc = "Гасит отдачу и стабилизирует ствол.",
    },
    ["knuckles_titanium_t2"] = {
        name = "Титановые кастеты МК.2", slot = "ARMS", tier = 2, humanity = 3,
        meleeBonus = 0.25, knockback = 200,
        desc = "Утяжелённые суставы кулаков отбрасывают противника.",
    },
    ["ballistic_coprocessor"] = {
        name = "Баллистический сопроцессор «Канг-Тао МК.3»", slot = "ARMS", tier = 3, humanity = 4,
        gunBonus = 0.12, spreadMult = 0.65,
        desc = "Рассчитывает траекторию каждого выстрела.",
    },
    ["microgenerator_t3"] = {
        name = "Микрогенератор ладони «Зетатех МК.3»", slot = "ARMS", tier = 3, humanity = 4,
        meleeBonus = 0.12, gunBonus = 0.06, shockDmg = 4,
        desc = "Насыщает каждую атаку электрическим импульсом.",
    },
    ["monowire_t3"] = {
        name = "Моноструна «Кан Тао МК.3»", slot = "ARMS", tier = 3, humanity = 4,
        meleeBonus = 0.15, chainShock = 0.35, chainTargets = 2,
        desc = "Мономолекулярная нить: удары в ближнем бою перескакивают разрядом на соседние цели.",
    },
    ["gorilla_arms"] = {
        name = "Руки Гориллы МК.4", slot = "ARMS", tier = 4, humanity = 6,
        meleeBonus = 0.45, spreadMult = 0.85, knockback = 320,
        desc = "Сокрушительная сила в каждом ударе.",
    },
    ["mantis_blades_t4"] = {
        name = "Клинки Богомола «Арасака МК.4»", slot = "ARMS", tier = 4, humanity = 6,
        meleeBonus = 0.35, bleedDps = 8, bleedTime = 3,
        desc = "Выдвижные клинки из предплечий. Удары в ближнем бою вызывают кровотечение.",
    },
    ["projectile_launcher_t4"] = {
        name = "Ракетная система «Милитех МК.4»", slot = "ARMS", tier = 4, humanity = 6, active = "Arms",
        cooldown = 14, launcherDmg = 70, launcherRadius = 180, gunBonus = 0.03,
        desc = "Встроенная в предплечье пусковая установка. Выпускает разрывной снаряд в точку прицела.",
    },
    ["immovable_force_t4"] = {
        name = "Стабилизатор «Неодолимая Сила МК.4»", slot = "ARMS", tier = 4, humanity = 6,
        gunBonus = 0.18, spreadMult = 0.50,
        desc = "Гироскопический компенсатор плеча.",
    },
    ["gorilla_arms_t5"] = {
        name = "Руки Гориллы «Джаггернаут МК.5»", slot = "ARMS", tier = 5, humanity = 8,
        meleeBonus = 0.70, gunBonus = 0.05, spreadMult = 0.80, knockback = 450,
        desc = "Культовые руки. Враги разлетаются как кегли.",
    },
    ["smart_link_t5"] = {
        name = "Нейро-матрица стрелка «Арасака МК.5»", slot = "ARMS", tier = 5, humanity = 8,
        gunBonus = 0.25, spreadMult = 0.35,
        desc = "Прямая синаптическая связь с оружием.",
    },

    -- ================= НЕРВНАЯ СИСТЕМА (2 слота) =================
    ["kerenzikov_t1"] = {
        name = "Керензиков «Базовый МК.1»", slot = "NERVOUS", tier = 1, humanity = 2, active = "Kerenzikov",
        cooldown = 8, dashPower = 650, dodgeTime = 0.25,
        desc = "Рывок в сторону движения с кратковременной неуязвимостью к пулям.",
    },
    ["tyrosine_injector_t1"] = {
        name = "Тирозиновый инъектор МК.1", slot = "NERVOUS", tier = 1, humanity = 2,
        passiveDodge = 0.04, speedPassive = 0.04,
        desc = "Ускоряет передачу нервных импульсов.",
    },
    ["reflex_tuner_t2"] = {
        name = "Рефлекторный тюнер «Инстинкты МК.2»", slot = "NERVOUS", tier = 2, humanity = 3,
        passiveDodge = 0.07,
        desc = "Нейро-ускоритель реакций.",
    },
    ["atomic_sensors_t2"] = {
        name = "Атомные датчики движения МК.2", slot = "NERVOUS", tier = 2, humanity = 3,
        passiveDodge = 0.04, speedPassive = 0.06,
        desc = "Датчики предугадывают движения противника.",
    },
    ["kerenzikov_t3"] = {
        name = "Керензиков «Рефлекс МК.3»", slot = "NERVOUS", tier = 3, humanity = 4, active = "Kerenzikov",
        cooldown = 6.5, dashPower = 760, dodgeTime = 0.35,
        desc = "Мощный тактический рывок.",
    },
    ["neofiber_t3"] = {
        name = "Неоволокно МК.3", slot = "NERVOUS", tier = 3, humanity = 4,
        passiveDodge = 0.08, speedPassive = 0.05,
        desc = "Синтетические мышечные волокна.",
    },
    ["self_ice_t3"] = {
        name = "Само-ЛЁД «Арасака МК.3»", slot = "NERVOUS", tier = 3, humanity = 4,
        selfIce = true, cooldown = 45,
        desc = "Нейро-файрвол. Полностью блокирует вражеский скрипт, после чего перезагружается.",
    },
    ["synaptic_accelerator_t4"] = {
        name = "Синаптический ускоритель МК.4", slot = "NERVOUS", tier = 4, humanity = 6,
        passiveDodge = 0.11,
        desc = "Предугадывает траекторию стрельбы врага.",
    },
    ["deep_field_visual_t4"] = {
        name = "Сенсор глубокого поля «Милитех МК.4»", slot = "NERVOUS", tier = 4, humanity = 6,
        passiveDodge = 0.07, speedPassive = 0.07,
        desc = "Координирует моторику в бою.",
    },
    ["kerenzikov_prime"] = {
        name = "Керензиков «Вектор МК.5»", slot = "NERVOUS", tier = 5, humanity = 8, active = "Kerenzikov",
        cooldown = 5, dashPower = 860, dodgeTime = 0.50,
        desc = "Сверхзвуковой рывок с полным уклонением от очередей во время полёта.",
    },
    ["revulsor_t5"] = {
        name = "Ревульсор МК.5", slot = "NERVOUS", tier = 5, humanity = 8,
        passiveDodge = 0.13, speedPassive = 0.08,
        desc = "Вершина нейро-инженерии.",
    },

    -- ================= СКЕЛЕТ (3 слота) =================
    ["titanium_bones_t1"] = {
        name = "Титановые кости МК.1", slot = "SKELETON", tier = 1, humanity = 2,
        fallMult = 0.5, speedPassive = 0.03,
        desc = "Облегчённый и прочный каркас.",
    },
    ["universal_booster_t1"] = {
        name = "Усилитель костной ткани МК.1", slot = "SKELETON", tier = 1, humanity = 2,
        bonusHP = 10, speedPassive = 0.02,
        desc = "Укрепляет грудную клетку.",
    },
    ["bionic_joints_t2"] = {
        name = "Бионические суставы МК.2", slot = "SKELETON", tier = 2, humanity = 3,
        speedPassive = 0.05, meleeResist = 0.10,
        desc = "Подвижные и прочные суставы.",
    },
    ["spring_joints_t2"] = {
        name = "Пружинные сочленения МК.2", slot = "SKELETON", tier = 2, humanity = 3,
        bonusHP = 15, armor = 0.04,
        desc = "Амортизируют кинетические удары.",
    },
    ["reinforced_tendons_t2"] = {
        name = "Усиленные сухожилия МК.2", slot = "SKELETON", tier = 2, humanity = 3,
        doubleJump = true, fallMult = 0.75,
        desc = "Позволяют оттолкнуться повторно прямо в воздухе (ПРОБЕЛ в прыжке).",
    },
    ["lynx_paws_t2"] = {
        name = "Рысьи лапы МК.2", slot = "SKELETON", tier = 2, humanity = 3,
        silentSteps = true, speedPassive = 0.03,
        desc = "Мягкие амортизаторы стоп: ваши шаги не слышно.",
    },
    ["fortified_ankles"] = {
        name = "Укреплённые лодыжки «Гидро-прыжок МК.3»", slot = "SKELETON", tier = 3, humanity = 4,
        fallMult = 0, speedPassive = 0.03, jumpCharge = true, jumpMult = 1.4,
        desc = "Зажмите ПРОБЕЛ, чтобы накопить заряд гидравлики для высокого прыжка.",
    },
    ["scarab_carapace_t3"] = {
        name = "Корсет «Скарабей МК.3»", slot = "SKELETON", tier = 3, humanity = 4,
        bonusHP = 20, armor = 0.06,
        desc = "Внутренний бронекаркас позвоночника.",
    },
    ["jenkins_tendons_t3"] = {
        name = "Сухожилия Дженкинса МК.3", slot = "SKELETON", tier = 3, humanity = 4,
        speedPassive = 0.10,
        desc = "Синтетические сухожилия для максимальной скорости бега.",
    },
    ["dense_marrow_t4"] = {
        name = "Плотный костный мозг МК.4", slot = "SKELETON", tier = 4, humanity = 6,
        speedPassive = 0.04, meleeBonus = 0.20,
        desc = "Утяжеляет удары в ближнем бою.",
    },
    ["para_bellum_t4"] = {
        name = "Эндоскелет «Пара Беллум МК.4»", slot = "SKELETON", tier = 4, humanity = 6,
        bonusHP = 30, meleeResist = 0.15, armor = 0.06,
        desc = "Тяжёлое укрепление скелета.",
    },
    ["epimorphic_skeleton_t5"] = {
        name = "Эндоскелет «Эпиморфик МК.5»", slot = "SKELETON", tier = 5, humanity = 8,
        bonusHP = 25, fallMult = 0, speedPassive = 0.08, jumpCharge = true, jumpMult = 1.8,
        desc = "Максимальная мощь гидро-прыжка и подвижность.",
    },
    ["atlas_frame_t5"] = {
        name = "Титановый каркас «Атлант МК.5»", slot = "SKELETON", tier = 5, humanity = 8,
        bonusHP = 40, meleeBonus = 0.25, armor = 0.08,
        desc = "Культовый военный эндоскелет.",
    },

    -- ================= КРОВООБРАЩЕНИЕ (3 слота) =================
    ["biomonitor_t1"] = {
        name = "Биомонитор МК.1", slot = "CIRCULATORY", tier = 1, humanity = 2,
        healThreshold = 0.35, healAmount = 25, cooldown = 50,
        desc = "Автоматическая инъекция при критическом состоянии.",
    },
    ["adrenaline_booster_t1"] = {
        name = "Адреналиновый стимулятор МК.1", slot = "CIRCULATORY", tier = 1, humanity = 2,
        killHeal = 15,
        desc = "Выброс адреналина после каждого устранения.",
    },
    ["heal_on_kill_t2"] = {
        name = "Синтетический кардиостимулятор МК.2", slot = "CIRCULATORY", tier = 2, humanity = 3,
        regen = 1,
        desc = "Ускоряет метаболизм вне боя.",
    },
    ["blood_pump_t2"] = {
        name = "Кровяной насос «Биодайн МК.2»", slot = "CIRCULATORY", tier = 2, humanity = 3,
        healThreshold = 0.40, healAmount = 40, cooldown = 40,
        desc = "Экстренный впрыск плазмы.",
    },
    ["adrenaline_converter"] = {
        name = "Адреналиновый конвертер «Дайналар МК.3»", slot = "CIRCULATORY", tier = 3, humanity = 4,
        killHeal = 25, cdRefund = 3,
        desc = "Превращает каждое убийство в топливо для организма и ОС.",
    },
    ["feedback_circuit_t3"] = {
        name = "Контур обратной связи МК.3", slot = "CIRCULATORY", tier = 3, humanity = 4,
        vamp = 0.05, regen = 1,
        desc = "Преобразует боль врагов в биоэнергию.",
    },
    ["micro_rotors_t4"] = {
        name = "Микророторы кровотока МК.4", slot = "CIRCULATORY", tier = 4, humanity = 6,
        regen = 2,
        desc = "Насыщает кровь кислородом.",
    },
    ["bioconductor_t4"] = {
        name = "Биопроводник «Милитех МК.4»", slot = "CIRCULATORY", tier = 4, humanity = 6,
        killHeal = 20, cdRefund = 4, vamp = 0.05,
        desc = "Боевой метаболический ускоритель.",
    },
    ["blood_pump_shock"] = {
        name = "Кровяной насос с электроконденсатором МК.5", slot = "CIRCULATORY", tier = 5, humanity = 8,
        healThreshold = 0.45, healAmount = 60, cooldown = 45, pumpShock = 30, vampBurst = 6,
        desc = "Экстренное лечение с электроразрядом по врагам вокруг и кратковременным вампиризмом.",
    },
    ["isometric_stabilizer_t5"] = {
        name = "Электролит-Сердце МК.5", slot = "CIRCULATORY", tier = 5, humanity = 8,
        regen = 3, vamp = 0.10,
        desc = "Культовая система жизнеобеспечения.",
    },
    ["second_heart_t5"] = {
        name = "Второе сердце МК.5", slot = "CIRCULATORY", tier = 5, humanity = 8,
        secondHeart = true, cooldown = 240,
        desc = "Резервное сердце. При смертельном уроне мгновенно возвращает к жизни с полным здоровьем.",
    },

    -- ================= КОЖА И БРОНЯ (3 слота) =================
    ["subdermal_t1"] = {
        name = "Подкожная броня МК.1", slot = "INTEGUMENTARY", tier = 1, humanity = 2,
        bonusHP = 15, armor = 0.05,
        desc = "Базовая подкожная защита.",
    },
    ["carapace_light_t1"] = {
        name = "Термостойкое покрытие кожи МК.1", slot = "INTEGUMENTARY", tier = 1, humanity = 2,
        bonusHP = 10, armor = 0.03, fireResist = 0.60,
        desc = "Огнеупорный слой эпидермиса.",
    },
    ["subdermal_t2"] = {
        name = "Армированная кожа «Панцирь МК.2»", slot = "INTEGUMENTARY", tier = 2, humanity = 3,
        bonusHP = 25, armor = 0.07,
        desc = "Многослойная защита кожи.",
    },
    ["grounded_plating_t2"] = {
        name = "Заземляющая обшивка МК.2", slot = "INTEGUMENTARY", tier = 2, humanity = 3,
        bonusHP = 20, armor = 0.05, shockResist = 0.50,
        desc = "Отводит электрические разряды в землю.",
    },
    ["subdermal_carapace"] = {
        name = "Карбоновый подкожный панцирь МК.3", slot = "INTEGUMENTARY", tier = 3, humanity = 4,
        bonusHP = 35, armor = 0.09, fireResist = 0.50,
        desc = "Лёгкий карбоновый панцирь.",
    },
    ["nano_plating_t3"] = {
        name = "Нанопластины «Отражатель МК.3»", slot = "INTEGUMENTARY", tier = 3, humanity = 4,
        bonusHP = 30, armor = 0.07, reflectChance = 0.06,
        desc = "Пластины под углом заставляют пули рикошетить.",
    },
    ["optical_camo_t3"] = {
        name = "Оптический камуфляж «Сэндайрен МК.3»", slot = "INTEGUMENTARY", tier = 3, humanity = 4, active = "Camo",
        camo = true, duration = 5, cooldown = 35,
        desc = "Делает вас почти невидимым. NPC теряют цель. Атака снимает маскировку.",
    },
    ["supradermal_t4"] = {
        name = "Нано-обшивка «Супрадерм МК.4»", slot = "INTEGUMENTARY", tier = 4, humanity = 6,
        bonusHP = 50, armor = 0.11, fireResist = 0.75, regen = 1,
        desc = "Самовосстанавливающееся покрытие.",
    },
    ["pain_editor_t4"] = {
        name = "Редактор боли «Арасака МК.4»", slot = "INTEGUMENTARY", tier = 4, humanity = 6,
        bonusHP = 40, armor = 0.13,
        desc = "Блокирует болевые рецепторы.",
    },
    ["optical_camo_t5"] = {
        name = "Оптический камуфляж «Арасака Призрак МК.5»", slot = "INTEGUMENTARY", tier = 5, humanity = 8, active = "Camo",
        camo = true, duration = 8, cooldown = 28, armor = 0.04,
        desc = "Совершенная активная маскировка корпоративных шиноби.",
    },
    ["chitin_shell_t5"] = {
        name = "Хитиновый панцирь «Милитех МК.5»", slot = "INTEGUMENTARY", tier = 5, humanity = 8,
        bonusHP = 65, armor = 0.14, fireResist = 1.0, regen = 1,
        desc = "Тяжёлая биоброня.",
    },
    ["cellular_adapter_t5"] = {
        name = "Клеточный адаптер МК.5", slot = "INTEGUMENTARY", tier = 5, humanity = 8,
        bonusHP = 60, armor = 0.12, fireResist = 1.0, shockResist = 0.50, regen = 2,
        desc = "Культовая защита от любых стихий.",
    },
}

--[[
    Скрипты кибердеки. ram — стоимость ОЗУ, cooldown — личная перезарядка скрипта.
    playersOnly / npcOnly — ограничения по типу цели.
]]
CYBERWARE.Quickhacks = {
    ["ping"] = {
        name = "Пинг", ram = 1, cooldown = 10, defaultUnlocked = true, kind = "covert", order = 1,
        desc = "Подсвечивает цель и всех врагов в радиусе 700 юнитов вокруг неё на 8 сек.",
    },
    ["short_circuit"] = {
        name = "Короткое замыкание", ram = 2, cooldown = 4, defaultUnlocked = true, kind = "damage", order = 2,
        damage = 30,
        desc = "Бьёт цель током (30 ед. урона) и замедляет игрока на 30% на 2.5 сек.",
    },
    ["optics_reboot"] = {
        name = "Перезагрузка оптики", ram = 3, cooldown = 12, defaultUnlocked = true, kind = "control", order = 3,
        desc = "Ослепляет игрока помехами на 4 сек. NPC теряет цель.",
    },
    ["memory_wipe"] = {
        name = "Стирание памяти", ram = 3, cooldown = 18, defaultUnlocked = false, kind = "covert", order = 4, npcOnly = true,
        desc = "NPC забывает о вас и не атакует 6 сек.",
    },
    ["cripple_movement"] = {
        name = "Паралич суставов", ram = 4, cooldown = 16, defaultUnlocked = false, kind = "control", order = 5, playersOnly = true,
        desc = "Отключает Сандевистан и запрещает цели бегать, прыгать и делать рывки 4 сек.",
    },
    ["weapon_glitch"] = {
        name = "Сбой вооружения", ram = 4, cooldown = 15, defaultUnlocked = false, kind = "control", order = 6, playersOnly = true,
        desc = "Выбрасывает патроны из магазина цели в запас.",
    },
    ["overheat"] = {
        name = "Перегрев", ram = 4, cooldown = 15, defaultUnlocked = false, kind = "damage", order = 7,
        damage = 10,
        desc = "Поджигает цель на 5 сек и наносит 10 ед. урона огнём.",
    },
    ["synapse_burn"] = {
        name = "Синаптический коллапс", ram = 5, cooldown = 16, defaultUnlocked = false, kind = "damage", order = 8,
        damage = 45,
        desc = "45 ед. урона + до 45 ед. дополнительно в зависимости от потерянного цели здоровья.",
    },
    ["contagion"] = {
        name = "Заражение", ram = 5, cooldown = 20, defaultUnlocked = false, kind = "damage", order = 9,
        damage = 8,
        desc = "Отравляет цель и врагов в радиусе 300: 8 ед. урона в секунду в течение 5 сек.",
    },
    ["cyberware_malfunction"] = {
        name = "Сбой имплантов (ЭМИ)", ram = 6, cooldown = 20, defaultUnlocked = false, kind = "control", order = 10,
        damage = 30,
        desc = "30 ед. урона. Игрок: отключает и блокирует все активные импланты на 6 сек.",
    },
    ["detonate_grenade"] = {
        name = "Подрыв боекомплекта", ram = 7, cooldown = 28, defaultUnlocked = false, kind = "ultimate", order = 11,
        damage = 65,
        desc = "Детонирует снаряжение цели: 65 ед. взрывного урона и подбрасывание.",
    },
    ["system_reset"] = {
        name = "Системный сброс", ram = 9, cooldown = 45, defaultUnlocked = false, kind = "ultimate", order = 12,
        damage = 150,
        desc = "NPC с запасом здоровья до 150 отключается мгновенно, иначе — 150 ед. урона. Игрок: 60 ед. урона, ЭМИ 3 сек и помехи.",
    },
}

CYBERWARE.HackKindColors = {
    damage   = Color(255, 80, 80),
    control  = Color(80, 200, 255),
    covert   = Color(80, 255, 170),
    ultimate = Color(255, 190, 30),
}

--[[
    Звуки: слои { путь, pitch = {min,max}, vol, level }. Только стандартный контент HL2/GMod.
]]
CYBERWARE.Sounds = {
    sandy_on      = { { "ambient/machines/teleport4.wav", pitch = { 150, 160 }, vol = 0.6, level = 80 }, { "weapons/physcannon/energy_sing_flyby1.wav", pitch = { 65, 75 }, vol = 0.9 }, { "ambient/energy/whiteflash.wav", pitch = { 140, 150 }, vol = 0.45 } },
    sandy_off     = { { "weapons/physcannon/physcannon_drop.wav", pitch = { 110, 120 }, vol = 0.8 }, { "weapons/physcannon/energy_sing_flyby2.wav", pitch = { 140, 150 }, vol = 0.5 } },
    sandy_extend  = { { "weapons/physcannon/superphys_small_zap1.wav", pitch = { 150, 165 }, vol = 0.6 } },
    berserk_on    = { { "npc/antlion_guard/angry1.wav", pitch = { 105, 115 }, vol = 0.8, level = 85 }, { "ambient/machines/thumper_hit.wav", pitch = { 120, 130 }, vol = 0.7 }, { "weapons/physcannon/physcannon_charge.wav", pitch = { 80, 90 }, vol = 0.5 } },
    berserk_off   = { { "weapons/physcannon/physcannon_drop.wav", pitch = { 70, 80 }, vol = 0.7 } },
    slam          = { { "physics/concrete/boulder_impact_hard4.wav", pitch = { 90, 100 }, vol = 1, level = 90 }, { "ambient/machines/thumper_hit.wav", pitch = { 80, 90 }, vol = 1 } },
    kiroshi       = { { "npc/scanner/scanner_scan2.wav", pitch = { 125, 135 }, vol = 0.6, level = 65 }, { "npc/turret_floor/ping.wav", pitch = { 115, 125 }, vol = 0.5, level = 60 } },
    dash          = { { "weapons/iceaxe/iceaxe_swing1.wav", pitch = { 75, 85 }, vol = 0.9 }, { "npc/scanner/scanner_nearmiss1.wav", pitch = { 125, 140 }, vol = 0.6 } },
    dodge         = { { "weapons/fx/rics/ric2.wav", pitch = { 125, 140 }, vol = 0.7, level = 70 }, { "weapons/fx/nearmiss/bulletltor03.wav", pitch = { 110, 120 }, vol = 0.5 } },
    reflect       = { { "weapons/fx/rics/ric4.wav", pitch = { 130, 145 }, vol = 0.7, level = 70 } },
    hack_upload   = { { "npc/roller/code2.wav", pitch = { 130, 140 }, vol = 0.5, level = 65 }, { "buttons/combine_button7.wav", pitch = { 110, 120 }, vol = 0.5, level = 65 } },
    hack_hit      = { { "ambient/energy/weld2.wav", pitch = { 125, 140 }, vol = 0.6 }, { "npc/scanner/scanner_electric1.wav", pitch = { 110, 125 }, vol = 0.5 } },
    hack_block    = { { "npc/turret_floor/retract.wav", pitch = { 120, 130 }, vol = 0.7 }, { "buttons/combine_button_locked.wav", pitch = { 100, 110 }, vol = 0.6 } },
    shock         = { { "ambient/energy/zap1.wav", pitch = { 100, 120 }, vol = 0.7 }, { "ambient/energy/spark5.wav", pitch = { 100, 115 }, vol = 0.5 } },
    emp           = { { "ambient/levels/labs/electric_explosion4.wav", pitch = { 110, 120 }, vol = 0.8 }, { "npc/scanner/scanner_pain1.wav", pitch = { 90, 100 }, vol = 0.6 } },
    install       = { { "npc/roller/blade_out.wav", pitch = { 95, 105 }, vol = 0.8 }, { "items/suitchargeok1.wav", pitch = { 110, 120 }, vol = 0.6 } },
    uninstall     = { { "npc/roller/blade_in.wav", pitch = { 95, 105 }, vol = 0.8 }, { "weapons/physcannon/physcannon_claws_close.wav", pitch = { 115, 125 }, vol = 0.5 } },
    heal          = { { "items/medshot4.wav", pitch = { 105, 115 }, vol = 0.8 }, { "items/smallmedkit1.wav", pitch = { 115, 125 }, vol = 0.4 } },
    pump_shock    = { { "weapons/physcannon/superphys_small_zap1.wav", pitch = { 100, 110 }, vol = 0.9, level = 85 }, { "ambient/energy/whiteflash.wav", pitch = { 110, 120 }, vol = 0.6 }, { "items/medshot4.wav", pitch = { 100, 110 }, vol = 0.7 } },
    second_heart  = { { "ambient/energy/whiteflash.wav", pitch = { 80, 90 }, vol = 0.9, level = 85 }, { "items/suitchargeok1.wav", pitch = { 70, 80 }, vol = 0.8 }, { "player/heartbeat1.wav", pitch = { 90, 100 }, vol = 1 } },
    camo_on       = { { "weapons/physcannon/physcannon_charge.wav", pitch = { 150, 160 }, vol = 0.4, level = 60 }, { "ambient/machines/teleport1.wav", pitch = { 175, 185 }, vol = 0.35, level = 60 } },
    camo_off      = { { "weapons/physcannon/energy_disintegrate4.wav", pitch = { 160, 175 }, vol = 0.45, level = 65 } },
    launcher      = { { "weapons/rpg/rocketfire1.wav", pitch = { 115, 125 }, vol = 0.8, level = 85 }, { "weapons/ar2/npc_ar2_altfire.wav", pitch = { 130, 140 }, vol = 0.5 } },
    jump_charge   = { { "weapons/physcannon/superphys_launch1.wav", pitch = { 130, 145 }, vol = 0.5 } },
    double_jump   = { { "weapons/iceaxe/iceaxe_swing1.wav", pitch = { 110, 120 }, vol = 0.6 }, { "npc/scanner/scanner_nearmiss2.wav", pitch = { 140, 150 }, vol = 0.35 } },
    self_ice      = { { "npc/turret_floor/deploy.wav", pitch = { 135, 145 }, vol = 0.7 }, { "ambient/energy/whiteflash.wav", pitch = { 160, 170 }, vol = 0.4 } },
    denied        = { { "buttons/combine_button_locked.wav", pitch = { 115, 125 }, vol = 0.5, level = 60 } },
}

-- ================= ОБЩИЕ ФУНКЦИИ =================

function CYBERWARE:PlaySound(ent, key, volMult)
    if not IsValid(ent) then return end
    local layers = self.Sounds[key]
    if not layers then return end
    for _, layer in ipairs(layers) do
        local pitch = layer.pitch and math.random(layer.pitch[1], layer.pitch[2]) or 100
        ent:EmitSound(layer[1], layer.level or 75, pitch, (layer.vol or 1) * (volMult or 1), CHAN_AUTO)
    end
end

function CYBERWARE:IsAdmin(ply)
    if not self.Config.AdminOnlyRipperdoc then return true end
    if game.SinglePlayer() then return true end
    if not IsValid(ply) then return false end
    if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
    if SERVER and ply:IsListenServerHost() then return true end

    local group = string.lower(ply:GetUserGroup() or "")
    return self.Config.AdminRanks[group] == true
end

function CYBERWARE:GetEquippedList(ply, slot)
    if not IsValid(ply) then return {} end
    local raw = ply:GetNW2String("Cyber_Slot_" .. slot, "")
    if raw == "" then return {} end

    local res = {}
    for _, id in ipairs(string.Explode(",", raw)) do
        if self.Implants[id] then
            res[#res + 1] = { id = id, data = self.Implants[id] }
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

-- Лучший (по уровню) имплант слота, у которого есть указанное поле
function CYBERWARE:GetBestWith(ply, slot, field)
    local best, bestID
    for _, item in ipairs(self:GetEquippedList(ply, slot)) do
        if item.data[field] and (not best or (item.data.tier or 1) > (best.tier or 1)) then
            best, bestID = item.data, item.id
        end
    end
    return best, bestID
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

function CYBERWARE:GetDeck(ply)
    local imp = self:GetEquippedInSlot(ply, "OS")
    if imp and imp.hackRange then return imp end
    return nil
end

-- ОЗУ кибердеки: хранится значение + момент записи, восстановление считается одинаково на сервере и клиенте
function CYBERWARE:GetRAM(ply)
    local deck = self:GetDeck(ply)
    if not deck then return 0, 0 end
    local base = ply:GetNW2Float("Cyber_RAM", deck.ram)
    local stamp = ply:GetNW2Float("Cyber_RAMStamp", 0)
    local cur = math.min(deck.ram, base + math.max(0, CurTime() - stamp) * (deck.ramRegen or 0.5))
    return cur, deck.ram
end

function CYBERWARE:GetHackCooldown(ply, hackID)
    return math.max(0, ply:GetNW2Float("Cyber_HackCD_" .. hackID, 0) - CurTime())
end

function CYBERWARE:GetMaxHumanity(ply)
    if not IsValid(ply) then return self.Config.DefaultMaxHumanity end
    return ply:GetNW2Int("Cyber_MaxHumanity", self.Config.DefaultMaxHumanity)
end

function CYBERWARE:GetUsedHumanity(ply)
    local used = 0
    for _, slot in ipairs(self.SlotOrder) do
        for _, item in ipairs(self:GetEquippedList(ply, slot)) do
            used = used + (item.data.humanity or 0)
        end
    end
    return used
end

function CYBERWARE:GetHumanity(ply)
    if not IsValid(ply) then return self.Config.DefaultMaxHumanity end
    local hum = self:GetMaxHumanity(ply) - self:GetUsedHumanity(ply)
    return math.Clamp(hum, self.Config.MinHumanityCap, self.Config.MaxHumanityCap)
end

-- 0 — стабильно, 1 — нестабильно, 2 — киберпсихоз, 3 — терминальная стадия
function CYBERWARE:GetPsychosisStage(hum)
    local c = self.Config
    if hum <= c.PsychosisTerminal then return 3 end
    if hum <= c.PsychosisStage2 then return 2 end
    if hum < c.PsychosisStart then return 1 end
    return 0
end

CYBERWARE.StageNames = { [0] = "СТАБИЛЬНО", [1] = "НЕСТАБИЛЬНО", [2] = "КИБЕРПСИХОЗ", [3] = "ТЕРМИНАЛЬНАЯ СТАДИЯ" }
CYBERWARE.StageColors = { [0] = Color(94, 246, 255), [1] = Color(252, 226, 5), [2] = Color(255, 110, 60), [3] = Color(255, 40, 70) }

function CYBERWARE:GetPsychosisSeverity(hum)
    local c = self.Config
    if hum >= c.PsychosisStart then return 0 end
    return math.Clamp((c.PsychosisStart - hum) / math.max(1, c.PsychosisStart - c.PsychosisTerminal), 0.05, 1)
end

-- Сводные пассивные характеристики со всеми потолками. Кэшируется до изменения набора имплантов.
function CYBERWARE:GetStats(ply)
    if not IsValid(ply) then return nil end

    local key = ""
    for _, slot in ipairs(self.SlotOrder) do
        key = key .. ply:GetNW2String("Cyber_Slot_" .. slot, "") .. "|"
    end
    if ply.Cyber_StatCache and ply.Cyber_StatCacheKey == key then
        return ply.Cyber_StatCache
    end

    local s = {
        used = 0, bonusHP = 0, armor = 0, meleeResist = 0, fallMult = 1, fireResist = 0, shockResist = 0,
        dodge = 0, speed = 0, melee = 0, gun = 0, spreadMult = 1, knockback = 0, shockDmg = 0,
        regen = 0, vamp = 0, killHeal = 0, cdRefund = 0, headPassive = 0,
        jumpCharge = false, jumpMult = 0, doubleJump = false, silentSteps = false,
        bleedDps = 0, bleedTime = 0, chainShock = 0, chainTargets = 0,
    }

    for _, slot in ipairs(self.SlotOrder) do
        for _, item in ipairs(self:GetEquippedList(ply, slot)) do
            local d = item.data
            s.used = s.used + (d.humanity or 0)
            s.bonusHP = s.bonusHP + (d.bonusHP or 0)
            s.armor = s.armor + (d.armor or 0)
            s.meleeResist = s.meleeResist + (d.meleeResist or 0)
            if d.fallMult then s.fallMult = math.min(s.fallMult, d.fallMult) end
            s.fireResist = math.max(s.fireResist, d.fireResist or 0)
            s.shockResist = math.max(s.shockResist, d.shockResist or 0)
            s.dodge = s.dodge + (d.passiveDodge or 0) + (d.reflectChance or 0)
            s.speed = s.speed + (d.speedPassive or 0)
            s.melee = s.melee + (d.meleeBonus or 0)
            s.gun = s.gun + (d.gunBonus or 0)
            if d.spreadMult then s.spreadMult = s.spreadMult * d.spreadMult end
            s.knockback = math.max(s.knockback, d.knockback or 0)
            s.shockDmg = s.shockDmg + (d.shockDmg or 0)
            s.regen = s.regen + (d.regen or 0)
            s.vamp = s.vamp + (d.vamp or 0)
            s.killHeal = s.killHeal + (d.killHeal or 0)
            s.cdRefund = s.cdRefund + (d.cdRefund or 0)
            s.headPassive = math.max(s.headPassive, d.headPassive or 0)
            if d.jumpCharge then
                s.jumpCharge = true
                s.jumpMult = math.max(s.jumpMult, d.jumpMult or 1.4)
            end
            if d.doubleJump then s.doubleJump = true end
            if d.silentSteps then s.silentSteps = true end
            if (d.bleedDps or 0) > s.bleedDps then
                s.bleedDps, s.bleedTime = d.bleedDps, d.bleedTime or 3
            end
            if (d.chainShock or 0) > s.chainShock then
                s.chainShock, s.chainTargets = d.chainShock, d.chainTargets or 2
            end
        end
    end

    local caps = self.Config.Caps
    s.raw = { bonusHP = s.bonusHP, armor = s.armor, meleeResist = s.meleeResist, dodge = s.dodge, speed = s.speed,
              melee = s.melee, gun = s.gun, regen = s.regen, vamp = s.vamp, killHeal = s.killHeal, cdRefund = s.cdRefund }
    s.bonusHP = math.min(s.bonusHP, caps.BonusHP)
    s.armor = math.min(s.armor, caps.Armor)
    s.meleeResist = math.min(s.meleeResist, caps.MeleeResist)
    s.dodge = math.min(s.dodge, caps.Dodge)
    s.speed = math.min(s.speed, caps.Speed)
    s.melee = math.min(s.melee, caps.Melee)
    s.gun = math.min(s.gun, caps.Gun)
    s.spreadMult = math.max(s.spreadMult, caps.SpreadMin)
    s.regen = math.min(s.regen, caps.Regen)
    s.vamp = math.min(s.vamp, caps.Vamp)
    s.killHeal = math.min(s.killHeal, caps.KillHeal)
    s.cdRefund = math.min(s.cdRefund, caps.CDRefund)

    ply.Cyber_StatCache = s
    ply.Cyber_StatCacheKey = key
    return s
end

-- Имя клавиши действия (на клиенте — с учётом пользовательской привязки)
function CYBERWARE:GetKeyName(action)
    local code = self.Config.DefaultKeys[action]
    if CLIENT then
        local cv = GetConVar("cyber_key_" .. string.lower(action))
        if cv then code = cv:GetInt() end
    end
    if not code or code <= 0 or not input or not input.GetKeyName then return "—" end
    return string.upper(input.GetKeyName(code) or "?")
end

local function Pct(v) return math.Round(v * 100) .. "%" end

-- Читаемые строки характеристик импланта: { текст, тип } (тип: "pos" / "neg" / "info" / "active")
function CYBERWARE:GetImplantStatLines(d)
    local L = {}
    local function add(text, kind) L[#L + 1] = { text, kind or "pos" } end

    if d.active then add("Активация: клавиша [" .. self:GetKeyName(d.active) .. "]", "active") end
    if d.duration then add("Длительность: " .. d.duration .. " с", "info") end
    if d.cooldown then add("Перезарядка: " .. d.cooldown .. " с", "info") end

    if d.speedBonus then add("Скорость при активации: +" .. Pct(d.speedBonus)) end
    if d.dmgDodge then add("Снижение урона в движении: " .. Pct(d.dmgDodge)) end
    if d.killExtend then add("Убийство продлевает действие на " .. d.killExtend .. " с") end
    if d.sandyKillHeal then add("Убийство в ускорении лечит " .. Pct(d.sandyKillHeal) .. " HP") end
    if d.meleeMult then
        add("Здоровье не падает ниже 1 HP")
        add("Урон в ближнем бою: ×" .. d.meleeMult)
    end
    if d.berserkArmor then add("Снижение урона при активации: " .. Pct(d.berserkArmor)) end
    if d.slamWave then add("Ударная волна при приземлении с высоты") end
    if d.ram then add("ОЗУ: " .. d.ram .. " (восст. " .. d.ramRegen .. "/с)") end
    if d.hackRange then add("Дальность взлома: " .. d.hackRange) end
    if d.hackDmgMult and d.hackDmgMult > 1 then add("Урон скриптов: +" .. Pct(d.hackDmgMult - 1)) end
    if d.cdMult and d.cdMult < 1 then add("Перезарядка скриптов: −" .. Pct(1 - d.cdMult)) end

    if d.headMult then add("Урон в голову при сканировании: +" .. Pct(d.headMult - 1)) end
    if d.headPassive then add("Пассивный урон в голову: +" .. Pct(d.headPassive)) end
    if d.scanRange then add("Радиус сканирования: " .. d.scanRange, "info") end

    if d.meleeBonus then add("Урон в ближнем бою: +" .. Pct(d.meleeBonus)) end
    if d.gunBonus then add("Урон огнестрела: +" .. Pct(d.gunBonus)) end
    if d.spreadMult then add("Разброс пуль: −" .. Pct(1 - d.spreadMult)) end
    if d.knockback then add("Отбрасывание ударом: " .. d.knockback) end
    if d.shockDmg then add("Электроурон за попадание: +" .. d.shockDmg) end
    if d.bleedDps then add("Кровотечение: " .. d.bleedDps .. " ед./с, " .. (d.bleedTime or 3) .. " с") end
    if d.chainShock then add("Цепной разряд: " .. Pct(d.chainShock) .. " урона на " .. (d.chainTargets or 2) .. " цели") end
    if d.launcherDmg then add("Снаряд: " .. d.launcherDmg .. " урона, радиус " .. d.launcherRadius) end

    if d.dashPower then add("Сила рывка: " .. d.dashPower, "info") end
    if d.dodgeTime then add("Неуязвимость к пулям: " .. d.dodgeTime .. " с") end
    if d.passiveDodge then add("Шанс уклонения от пуль: +" .. Pct(d.passiveDodge)) end
    if d.speedPassive then add("Скорость передвижения: +" .. Pct(d.speedPassive)) end
    if d.selfIce then add("Блокирует один вражеский скрипт") end

    if d.bonusHP then add("Макс. здоровье: +" .. d.bonusHP) end
    if d.armor then add("Снижение входящего урона: " .. Pct(d.armor)) end
    if d.meleeResist then add("Снижение урона в ближнем бою: " .. Pct(d.meleeResist)) end
    if d.fallMult then
        if d.fallMult <= 0 then add("Иммунитет к урону от падения") else add("Урон от падения: −" .. Pct(1 - d.fallMult)) end
    end
    if d.jumpCharge then add("Заряженный прыжок (зажать ПРОБЕЛ): ×" .. (d.jumpMult or 1.4)) end
    if d.doubleJump then add("Двойной прыжок") end
    if d.silentSteps then add("Бесшумные шаги") end

    if d.healThreshold then add("Авто-лечение +" .. d.healAmount .. " HP при HP < " .. Pct(d.healThreshold)) end
    if d.pumpShock then add("Электроразряд по врагам вокруг: " .. d.pumpShock .. " урона") end
    if d.vampBurst then add("Вампиризм +15% на " .. d.vampBurst .. " с после срабатывания") end
    if d.killHeal then add("Лечение за убийство: +" .. d.killHeal .. " HP") end
    if d.cdRefund then add("Убийство сокращает перезарядку ОС на " .. d.cdRefund .. " с") end
    if d.regen then add("Регенерация вне боя: +" .. d.regen .. " HP / " .. self.Config.RegenTick .. " с") end
    if d.vamp then add("Вампиризм: " .. Pct(d.vamp)) end
    if d.secondHeart then add("Воскрешение с полным HP при смертельном уроне") end

    if d.fireResist then
        if d.fireResist >= 1 then add("Иммунитет к огню") else add("Сопротивление огню: " .. Pct(d.fireResist)) end
    end
    if d.shockResist then add("Сопротивление электричеству: " .. Pct(d.shockResist)) end
    if d.reflectChance then add("Шанс рикошета пули: " .. Pct(d.reflectChance)) end
    if d.camo then add("Невидимость, NPC теряют цель") end

    add("Нагрузка на человечность: −" .. (d.humanity or 0), "neg")
    return L
end

-- ================= ДВИЖЕНИЕ (общий хук для предсказания) =================
hook.Add("SetupMove", "Cyberware_MovementControl", function(ply, mv, cmd)
    if not ply:Alive() then return end

    if ply:GetNW2Float("Cyber_Crippled_Until", 0) > CurTime() then
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(bit.bor(IN_JUMP, IN_SPEED))))
        ply:SetNW2Float("Cyber_JumpCharge", 0)
        ply.Cyber_JumpCharge = 0
        return
    end

    if ply:GetNW2Float("Cyber_EMP_Until", 0) > CurTime() then return end

    local st = CYBERWARE:GetStats(ply)
    if not st then return end

    if ply:OnGround() then
        ply.Cyber_DoubleJumped = false
    elseif st.doubleJump and not ply.Cyber_DoubleJumped and mv:KeyPressed(IN_JUMP) and ply:WaterLevel() < 2 then
        ply.Cyber_DoubleJumped = true
        local vel = mv:GetVelocity()
        vel.z = math.max(vel.z, 0) + ply:GetJumpPower() * 1.05
        mv:SetVelocity(vel)
        if SERVER then CYBERWARE:PlaySound(ply, "double_jump") end
    end

    if not st.jumpCharge then return end

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
                vel.z = ply:GetJumpPower() * (1.25 + charge * st.jumpMult)
                if SERVER then CYBERWARE:PlaySound(ply, "jump_charge") end
            end
            mv:SetVelocity(vel)
        end
    elseif (ply.Cyber_JumpCharge or 0) > 0 then
        ply.Cyber_JumpCharge = 0
        if SERVER then ply:SetNW2Float("Cyber_JumpCharge", 0) end
    end
end)

hook.Add("PlayerFootstep", "Cyberware_SilentSteps", function(ply)
    local st = CYBERWARE:GetStats(ply)
    if st and st.silentSteps then return true end
end)
