-- lua/autorun/cyberware_config.lua  (shared)
if SERVER then
    AddCSLuaFile()
end

CYBERWARE = CYBERWARE or {}
CYBERWARE.Version = "2.1"

CYBERWARE.Config = {
    -- Humanity. Load: Mk.1 4, Mk.2 6, Mk.3 8, Mk.4 11, Mk.5 14 (OS 10–22, optics 4–10).
    -- A typical RP loadout of 6 Mk.3 implants ≈ 54 pts (unstable), 8 implants — cyberpsychosis,
    -- a full Mk.3 set — terminal stage.
    DefaultMaxHumanity = 100,
    PsychosisStart = 50,      -- below: unstable (whispers, intrusive thoughts)
    PsychosisStage2 = 25,     -- below: cyberpsychosis (hallucinations, rage, damage bonus)
    PsychosisTerminal = 0,    -- below: terminal stage (uncontrolled episodes)
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

    -- Default keys. Every player can rebind them in F8 → “Settings”.
    DefaultKeys = {
        AdminMenu  = KEY_F6,  -- Ripperdoc terminal (admin)
        PlayerMenu = KEY_F8,  -- Personal implant layout
        OS         = KEY_Z,   -- Sandevistan / Berserk
        Quickhack  = KEY_X,   -- Cyberdeck: target capture and quickhacks
        Kerenzikov = KEY_V,   -- Dash
        Kiroshi    = KEY_F,   -- Optics scan
        Arms       = KEY_G,   -- Arm Projectile Launch System
        Camo       = KEY_B,   -- Optical Camo
    },

    -- Caps on total bonuses so that stacking implants doesn't make a player immortal.
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

    -- Gameplay effects of psychosis
    Psychosis = {
        DamageBonus = 0.10,        -- cyberpsychosis and above: +10% outgoing damage
        SpreadPenalty = 1.25,      -- cyberpsychosis and above: spread ×1.25 (hands shake)
        EpisodeChance = 0.05,      -- terminal stage: episode chance per tick
        EpisodeDuration = 8,
        EpisodeCooldown = 60,
        EpisodeMelee = 0.30,       -- episode: +30% melee damage
        EpisodeSpeed = 0.15,       -- episode: +15% speed
        EpisodeArmor = 0.10,       -- episode: −10% incoming damage
        WitnessRadius = 800,       -- players in range see the episode message
    },

    -- Blackwall: quickhacks from behind the Blackwall give Corruption, which temporarily drains Humanity
    Blackwall = {
        HumanityPerPoint = 0.5,    -- 1 pt of Corruption = −0.5 Humanity
        DecayDelay = 20,           -- Corruption starts to decay N sec after the last breach
        DecayPerSec = 0.35,
        Max = 100,                 -- when reached — overload
        OverloadResetTo = 60,
        OverloadDamage = 35,
        OverloadEMP = 5,
    },

    RegenTick = 1.5,         -- passive regeneration period (sec)
    RegenCombatDelay = 4,    -- no regeneration for N seconds after taking damage
    HackGlobalDelay = 0.6,   -- anti-spam between quickhacks
}

CYBERWARE.TierColors = {
    [1] = Color(170, 178, 190),
    [2] = Color(60, 230, 120),
    [3] = Color(40, 170, 255),
    [4] = Color(190, 90, 255),
    [5] = Color(255, 180, 20),
}

CYBERWARE.TierNames = {
    [1] = "COMMON",
    [2] = "UNCOMMON",
    [3] = "RARE",
    [4] = "EPIC",
    [5] = "LEGENDARY",
}

CYBERWARE.SlotOrder = { "OS", "OCULAR", "ARMS", "NERVOUS", "SKELETON", "CIRCULATORY", "INTEGUMENTARY" }

CYBERWARE.Categories = {
    ["OS"]            = { name = "Operating System", short = "OS",       order = 1, maxSlots = 1 },
    ["OCULAR"]        = { name = "Optics",               short = "OPTICS",   order = 2, maxSlots = 1 },
    ["ARMS"]          = { name = "Hands",                 short = "HANDS",     order = 3, maxSlots = 2 },
    ["NERVOUS"]       = { name = "Nervous System",      short = "NERVES",    order = 4, maxSlots = 2 },
    ["SKELETON"]      = { name = "Skeleton",               short = "SKELETON",   order = 5, maxSlots = 3 },
    ["CIRCULATORY"]   = { name = "Circulatory System",       short = "BLOOD",    order = 6, maxSlots = 3 },
    ["INTEGUMENTARY"] = { name = "Skin and Armor",         short = "SKIN",     order = 7, maxSlots = 3 },
}

-- Active ability labels (key = action in DefaultKeys)
CYBERWARE.ActionNames = {
    OS = "OS", Quickhack = "HACK", Kerenzikov = "DASH", Kiroshi = "SCAN", Arms = "ROCKET", Camo = "CAMO",
    PlayerMenu = "Personal menu", AdminMenu = "Ripperdoc",
}

--[[
    Implant fields:
      humanity — Humanity load; active — ability key (DefaultKeys key)
      OS:     speedBonus, dmgDodge, killExtend, sandyKillHeal | meleeMult, berserkArmor, slamWave | ram, ramRegen, hackRange, hackDmgMult, cdMult
      Optics: headMult (active), headPassive, scanRange
      Hands:  meleeBonus, gunBonus, spreadMult, knockback, shockDmg, bleedDps/bleedTime, chainShock/chainTargets, launcherDmg/launcherRadius
      Nerves: dashPower, dodgeTime, passiveDodge, speedPassive, selfIce
      Skeleton: bonusHP, armor, meleeResist, fallMult, speedPassive, meleeBonus, jumpCharge/jumpMult, doubleJump, silentSteps
      Blood:  healThreshold/healAmount, pumpShock, vampBurst, killHeal, cdRefund, regen, vamp, secondHeart
      Skin:   bonusHP, armor, fireResist, shockResist, reflectChance, regen, camo
]]
CYBERWARE.Implants = {
    -- ================= OPERATING SYSTEMS (1 slot) =================
    ["sandy_dynalar_t1"] = {
        name = "Sandevistan “Dynalar Mk.1”", slot = "OS", tier = 1, humanity = 10, active = "OS",
        cooldown = 30, duration = 5, speedBonus = 0.30, dmgDodge = 0.20,
        desc = "Budget neuron accelerator. The world slows down, you don't. Pressing again ends it early and refunds part of the cooldown.",
    },
    ["sandy_zetatech_t3"] = {
        name = "Sandevistan “Zetatech Mk.3”", slot = "OS", tier = 3, humanity = 15, active = "OS",
        cooldown = 26, duration = 6, speedBonus = 0.45, dmgDodge = 0.30,
        desc = "Reliable military model with a neon trail of afterimages.",
    },
    ["sandy_falcon_t4"] = {
        name = "Sandevistan “Militech Falcon Mk.4”", slot = "OS", tier = 4, humanity = 18, active = "OS",
        cooldown = 24, duration = 7, speedBonus = 0.55, dmgDodge = 0.35, killExtend = 1,
        desc = "Tactical version for Militech special units. Every kill extends the acceleration.",
    },
    ["sandevistan_apogee"] = {
        name = "Sandevistan “Militech Apogee Mk.5”", slot = "OS", tier = 5, humanity = 22, active = "OS",
        cooldown = 22, duration = 8, speedBonus = 0.65, dmgDodge = 0.40, killExtend = 2,
        desc = "Iconic implant. Absolute speed supremacy — as long as the neural net can take the strain.",
    },
    ["sandy_warp_dancer"] = {
        name = "Sandevistan “Qiant Warp Dancer Mk.5”", slot = "OS", tier = 5, humanity = 22, active = "OS",
        cooldown = 26, duration = 6, speedBonus = 0.60, dmgDodge = 0.35, killExtend = 1, sandyKillHeal = 0.10,
        desc = "Experimental Qiant design. Kills while accelerated feed the body.",
    },
    ["berserk_moore_t2"] = {
        name = "Berserk “Moore Technologies Mk.2”", slot = "OS", tier = 2, humanity = 12, active = "OS",
        cooldown = 40, duration = 6, meleeMult = 1.30, berserkArmor = 0.10, slamWave = false,
        desc = "Combat stimulant: the body refuses to die while the implant runs.",
    },
    ["berserk_biodyne_t4"] = {
        name = "Berserk “Biodyne Mk.4”", slot = "OS", tier = 4, humanity = 18, active = "OS",
        cooldown = 36, duration = 7, meleeMult = 1.45, berserkArmor = 0.15, slamWave = true,
        desc = "Reinforced servos let you crash down on enemies from above.",
    },
    ["berserk_militech"] = {
        name = "Berserk “Militech Ranger Mk.5”", slot = "OS", tier = 5, humanity = 22, active = "OS",
        cooldown = 34, duration = 8, meleeMult = 1.60, berserkArmor = 0.20, slamWave = true,
        desc = "Army-grade Berserk. Turns the user into a living battering ram.",
    },
    ["cyberdeck_biotech_t2"] = {
        name = "Cyberdeck “Biotech Sigma Mk.2”", slot = "OS", tier = 2, humanity = 12, active = "Quickhack",
        ram = 6, ramRegen = 0.5, hackRange = 800, hackDmgMult = 1.0, cdMult = 1.0,
        desc = "Entry-level civilian deck. Quickhacks consume RAM, which recovers over time.",
    },
    ["cyberdeck_paraline_t3"] = {
        name = "Cyberdeck “Militech Paraline Mk.3”", slot = "OS", tier = 3, humanity = 15, active = "Quickhack",
        ram = 8, ramRegen = 0.6, hackRange = 900, hackDmgMult = 1.10, cdMult = 0.90,
        desc = "Balanced military deck with an extended memory buffer.",
    },
    ["cyberdeck_arasaka_t4"] = {
        name = "Cyberdeck “Arasaka Shadow Mk.4”", slot = "OS", tier = 4, humanity = 18, active = "Quickhack",
        ram = 10, ramRegen = 0.7, hackRange = 1000, hackDmgMult = 1.20, cdMult = 0.80,
        desc = "Corporate deck for quiet operations.",
    },
    ["cyberdeck_tetratronic_t4"] = {
        name = "Cyberdeck “Tetratronic Rippler Mk.4”", slot = "OS", tier = 4, humanity = 18, active = "Quickhack",
        ram = 9, ramRegen = 0.8, hackRange = 950, hackDmgMult = 1.30, cdMult = 0.90,
        desc = "Deck for aggressive hacking: less memory, more damage.",
    },
    ["cyberdeck_netwatch"] = {
        name = "Cyberdeck “NetWatch Mk.5”", slot = "OS", tier = 5, humanity = 22, active = "Quickhack",
        ram = 13, ramRegen = 0.9, hackRange = 1200, hackDmgMult = 1.35, cdMult = 0.70,
        desc = "Legendary deck of NetWatch agents.",
    },
    ["cyberdeck_blackwall_gateway"] = {
        name = "Cyberdeck “Blackwall Gateway” Mk.5", slot = "OS", tier = 5, humanity = 22, active = "Quickhack",
        ram = 12, ramRegen = 0.9, hackRange = 1150, hackDmgMult = 1.40, cdMult = 0.80, blackwallMult = 0.5,
        desc = "A relic from beyond the Blackwall. Empowers Blackwall quickhacks and halves the Corruption they cause — but the voices beyond the Blackwall never fall silent.",
    },

    -- ================= OPTICS (1 slot) =================
    ["kiroshi_basic_t1"] = {
        name = "Optics “Kiroshi Basic Mk.1”", slot = "OCULAR", tier = 1, humanity = 4, active = "Kiroshi",
        cooldown = 20, duration = 4, headMult = 1.15, scanRange = 1500,
        desc = "Highlights living targets through walls and shows their condition.",
    },
    ["kiroshi_clairvoyant_t2"] = {
        name = "Optics “Kiroshi Clairvoyant Mk.2”", slot = "OCULAR", tier = 2, humanity = 5, active = "Kiroshi",
        cooldown = 18, duration = 5, headMult = 1.20, headPassive = 0.05, scanRange = 1800,
        desc = "Improved targeting matrix with passive weak-point analysis.",
    },
    ["kiroshi_sentry_t3"] = {
        name = "Optics “Kiroshi Sentry Mk.3”", slot = "OCULAR", tier = 3, humanity = 7, active = "Kiroshi",
        cooldown = 16, duration = 6, headMult = 1.25, headPassive = 0.08, scanRange = 2200,
        desc = "Military optics with an extended scanning spectrum.",
    },
    ["kiroshi_oracle_t4"] = {
        name = "Optics “Kiroshi Oracle Mk.4”", slot = "OCULAR", tier = 4, humanity = 8, active = "Kiroshi",
        cooldown = 15, duration = 7, headMult = 1.30, headPassive = 0.10, scanRange = 2600,
        desc = "High-precision spectral analyzer.",
    },
    ["kiroshi_stalker"] = {
        name = "Optics “Kiroshi Cockatrice Mk.5”", slot = "OCULAR", tier = 5, humanity = 10, active = "Kiroshi",
        cooldown = 14, duration = 8, headMult = 1.40, headPassive = 0.15, scanRange = 3200,
        desc = "Iconic vulnerability analyzer.",
    },

    -- ================= HANDS (2 slots) =================
    ["grip_boost_t1"] = {
        name = "Palm Servos Mk.1", slot = "ARMS", tier = 1, humanity = 4,
        meleeBonus = 0.15, gunBonus = 0.03, spreadMult = 0.90, knockback = 120,
        desc = "Reinforced grip for weapons and fists.",
    },
    ["shock_absorber_t2"] = {
        name = "Recoil Dampener “Vector Mk.2”", slot = "ARMS", tier = 2, humanity = 6,
        gunBonus = 0.08, spreadMult = 0.75,
        desc = "Absorbs recoil and steadies the barrel.",
    },
    ["knuckles_titanium_t2"] = {
        name = "Titanium Knuckles Mk.2", slot = "ARMS", tier = 2, humanity = 6,
        meleeBonus = 0.25, knockback = 200,
        desc = "Weighted knuckle joints knock the enemy back.",
    },
    ["ballistic_coprocessor"] = {
        name = "Ballistic Coprocessor “Kang Tao Mk.3”", slot = "ARMS", tier = 3, humanity = 8,
        gunBonus = 0.12, spreadMult = 0.65,
        desc = "Calculates the trajectory of every shot.",
    },
    ["microgenerator_t3"] = {
        name = "Palm Microgenerator “Zetatech Mk.3”", slot = "ARMS", tier = 3, humanity = 8,
        meleeBonus = 0.12, gunBonus = 0.06, shockDmg = 4,
        desc = "Charges every attack with an electric pulse.",
    },
    ["monowire_t3"] = {
        name = "Monowire “Kang Tao Mk.3”", slot = "ARMS", tier = 3, humanity = 8,
        meleeBonus = 0.15, chainShock = 0.35, chainTargets = 2,
        desc = "Monomolecular filament: melee hits arc to nearby targets.",
    },
    ["gorilla_arms"] = {
        name = "Gorilla Arms Mk.4", slot = "ARMS", tier = 4, humanity = 11,
        meleeBonus = 0.45, spreadMult = 0.85, knockback = 320,
        desc = "Crushing force in every blow.",
    },
    ["mantis_blades_t4"] = {
        name = "Mantis Blades “Arasaka Mk.4”", slot = "ARMS", tier = 4, humanity = 11,
        meleeBonus = 0.35, bleedDps = 8, bleedTime = 3,
        desc = "Retractable forearm blades. Melee hits cause bleeding.",
    },
    ["projectile_launcher_t4"] = {
        name = "Projectile Launch System “Militech Mk.4”", slot = "ARMS", tier = 4, humanity = 11, active = "Arms",
        cooldown = 14, launcherDmg = 70, launcherRadius = 180, gunBonus = 0.03,
        desc = "Forearm-mounted launcher. Fires an explosive projectile at the aim point.",
    },
    ["immovable_force_t4"] = {
        name = "Stabilizer “Irresistible Force Mk.4”", slot = "ARMS", tier = 4, humanity = 11,
        gunBonus = 0.18, spreadMult = 0.50,
        desc = "Gyroscopic shoulder compensator.",
    },
    ["gorilla_arms_t5"] = {
        name = "Gorilla Arms “Juggernaut Mk.5”", slot = "ARMS", tier = 5, humanity = 14,
        meleeBonus = 0.70, gunBonus = 0.05, spreadMult = 0.80, knockback = 450,
        desc = "Iconic arms. Enemies fly like bowling pins.",
    },
    ["smart_link_t5"] = {
        name = "Shooter Neuromatrix “Arasaka Mk.5”", slot = "ARMS", tier = 5, humanity = 14,
        gunBonus = 0.25, spreadMult = 0.35,
        desc = "Direct synaptic link to the weapon.",
    },

    -- ================= NERVOUS SYSTEM (2 slots) =================
    ["kerenzikov_t1"] = {
        name = "Kerenzikov “Basic Mk.1”", slot = "NERVOUS", tier = 1, humanity = 4, active = "Kerenzikov",
        cooldown = 8, dashPower = 650, dodgeTime = 0.25,
        desc = "Dash in the direction of movement with brief bullet immunity.",
    },
    ["tyrosine_injector_t1"] = {
        name = "Tyrosine Injector Mk.1", slot = "NERVOUS", tier = 1, humanity = 4,
        passiveDodge = 0.04, speedPassive = 0.04,
        desc = "Speeds up nerve impulse transmission.",
    },
    ["reflex_tuner_t2"] = {
        name = "Reflex Tuner “Instincts Mk.2”", slot = "NERVOUS", tier = 2, humanity = 6,
        passiveDodge = 0.07,
        desc = "Neural reaction accelerator.",
    },
    ["atomic_sensors_t2"] = {
        name = "Atomic Motion Sensors Mk.2", slot = "NERVOUS", tier = 2, humanity = 6,
        passiveDodge = 0.04, speedPassive = 0.06,
        desc = "Sensors anticipate enemy movements.",
    },
    ["kerenzikov_t3"] = {
        name = "Kerenzikov “Reflex Mk.3”", slot = "NERVOUS", tier = 3, humanity = 8, active = "Kerenzikov",
        cooldown = 6.5, dashPower = 760, dodgeTime = 0.35,
        desc = "Powerful tactical dash.",
    },
    ["neofiber_t3"] = {
        name = "Neofiber Mk.3", slot = "NERVOUS", tier = 3, humanity = 8,
        passiveDodge = 0.08, speedPassive = 0.05,
        desc = "Synthetic muscle fibers.",
    },
    ["self_ice_t3"] = {
        name = "Self-ICE “Arasaka Mk.3”", slot = "NERVOUS", tier = 3, humanity = 8,
        selfIce = true, cooldown = 45,
        desc = "Neural firewall. Fully blocks an enemy quickhack, then reboots.",
    },
    ["synaptic_accelerator_t4"] = {
        name = "Synaptic Accelerator Mk.4", slot = "NERVOUS", tier = 4, humanity = 11,
        passiveDodge = 0.11,
        desc = "Predicts the enemy's firing trajectory.",
    },
    ["deep_field_visual_t4"] = {
        name = "Deep-Field Sensor “Militech Mk.4”", slot = "NERVOUS", tier = 4, humanity = 11,
        passiveDodge = 0.07, speedPassive = 0.07,
        desc = "Coordinates motor skills in combat.",
    },
    ["kerenzikov_prime"] = {
        name = "Kerenzikov “Vector Mk.5”", slot = "NERVOUS", tier = 5, humanity = 14, active = "Kerenzikov",
        cooldown = 5, dashPower = 860, dodgeTime = 0.50,
        desc = "Supersonic dash with full evasion of bursts mid-flight.",
    },
    ["revulsor_t5"] = {
        name = "Revulsor Mk.5", slot = "NERVOUS", tier = 5, humanity = 14,
        passiveDodge = 0.13, speedPassive = 0.08,
        desc = "The pinnacle of neural engineering.",
    },

    -- ================= SKELETON (3 slots) =================
    ["titanium_bones_t1"] = {
        name = "Titanium Bones Mk.1", slot = "SKELETON", tier = 1, humanity = 4,
        fallMult = 0.5, speedPassive = 0.03,
        desc = "Lightweight and durable frame.",
    },
    ["universal_booster_t1"] = {
        name = "Bone Tissue Booster Mk.1", slot = "SKELETON", tier = 1, humanity = 4,
        bonusHP = 10, speedPassive = 0.02,
        desc = "Reinforces the ribcage.",
    },
    ["bionic_joints_t2"] = {
        name = "Bionic Joints Mk.2", slot = "SKELETON", tier = 2, humanity = 6,
        speedPassive = 0.05, meleeResist = 0.10,
        desc = "Mobile and sturdy joints.",
    },
    ["spring_joints_t2"] = {
        name = "Spring Joints Mk.2", slot = "SKELETON", tier = 2, humanity = 6,
        bonusHP = 15, armor = 0.04,
        desc = "Absorb kinetic impacts.",
    },
    ["reinforced_tendons_t2"] = {
        name = "Reinforced Tendons Mk.2", slot = "SKELETON", tier = 2, humanity = 6,
        doubleJump = true, fallMult = 0.75,
        desc = "Allow a second push-off right in mid-air (SPACE while jumping).",
    },
    ["lynx_paws_t2"] = {
        name = "Lynx Paws Mk.2", slot = "SKELETON", tier = 2, humanity = 6,
        silentSteps = true, speedPassive = 0.03,
        desc = "Soft foot dampeners: your steps are silent.",
    },
    ["fortified_ankles"] = {
        name = "Reinforced Ankles “Hydro-Jump Mk.3”", slot = "SKELETON", tier = 3, humanity = 8,
        fallMult = 0, speedPassive = 0.03, jumpCharge = true, jumpMult = 1.4,
        desc = "Hold SPACE to build up hydraulic charge for a high jump.",
    },
    ["scarab_carapace_t3"] = {
        name = "Corset “Scarab Mk.3”", slot = "SKELETON", tier = 3, humanity = 8,
        bonusHP = 20, armor = 0.06,
        desc = "Internal armored spine frame.",
    },
    ["jenkins_tendons_t3"] = {
        name = "Jenkins Tendons Mk.3", slot = "SKELETON", tier = 3, humanity = 8,
        speedPassive = 0.10,
        desc = "Synthetic tendons for maximum running speed.",
    },
    ["dense_marrow_t4"] = {
        name = "Dense Bone Marrow Mk.4", slot = "SKELETON", tier = 4, humanity = 11,
        speedPassive = 0.04, meleeBonus = 0.20,
        desc = "Adds weight to melee strikes.",
    },
    ["para_bellum_t4"] = {
        name = "Endoskeleton 'Para Bellum Mk.4'", slot = "SKELETON", tier = 4, humanity = 11,
        bonusHP = 30, meleeResist = 0.15, armor = 0.06,
        desc = "Heavy skeletal reinforcement.",
    },
    ["epimorphic_skeleton_t5"] = {
        name = "Endoskeleton 'Epimorphic Mk.5'", slot = "SKELETON", tier = 5, humanity = 14,
        bonusHP = 25, fallMult = 0, speedPassive = 0.08, jumpCharge = true, jumpMult = 1.8,
        desc = "Maximum hydro-jump power and mobility.",
    },
    ["atlas_frame_t5"] = {
        name = "Titanium Frame 'Atlant Mk.5'", slot = "SKELETON", tier = 5, humanity = 14,
        bonusHP = 40, meleeBonus = 0.25, armor = 0.08,
        desc = "Iconic military endoskeleton.",
    },

    -- ================= CIRCULATORY (3 slots) =================
    ["biomonitor_t1"] = {
        name = "Biomonitor Mk.1", slot = "CIRCULATORY", tier = 1, humanity = 4,
        healThreshold = 0.35, healAmount = 25, cooldown = 50,
        desc = "Automatic injection in critical condition.",
    },
    ["adrenaline_booster_t1"] = {
        name = "Adrenaline Booster Mk.1", slot = "CIRCULATORY", tier = 1, humanity = 4,
        killHeal = 15,
        desc = "Adrenaline surge after every takedown.",
    },
    ["heal_on_kill_t2"] = {
        name = "Synthetic Pacemaker Mk.2", slot = "CIRCULATORY", tier = 2, humanity = 6,
        regen = 1,
        desc = "Speeds up metabolism out of combat.",
    },
    ["blood_pump_t2"] = {
        name = "Blood Pump 'Biodyne Mk.2'", slot = "CIRCULATORY", tier = 2, humanity = 6,
        healThreshold = 0.40, healAmount = 40, cooldown = 40,
        desc = "Emergency plasma injection.",
    },
    ["adrenaline_converter"] = {
        name = "Adrenaline Converter 'Dynalar Mk.3'", slot = "CIRCULATORY", tier = 3, humanity = 8,
        killHeal = 25, cdRefund = 3,
        desc = "Turns every kill into fuel for the body and OS.",
    },
    ["feedback_circuit_t3"] = {
        name = "Feedback Circuit Mk.3", slot = "CIRCULATORY", tier = 3, humanity = 8,
        vamp = 0.05, regen = 1,
        desc = "Converts enemy pain into bioenergy.",
    },
    ["micro_rotors_t4"] = {
        name = "Blood Flow Microrotors Mk.4", slot = "CIRCULATORY", tier = 4, humanity = 11,
        regen = 2,
        desc = "Saturates the blood with oxygen.",
    },
    ["bioconductor_t4"] = {
        name = "Bioconductor 'Militech Mk.4'", slot = "CIRCULATORY", tier = 4, humanity = 11,
        killHeal = 20, cdRefund = 4, vamp = 0.05,
        desc = "Combat metabolic accelerator.",
    },
    ["blood_pump_shock"] = {
        name = "Blood Pump with Capacitor Mk.5", slot = "CIRCULATORY", tier = 5, humanity = 14,
        healThreshold = 0.45, healAmount = 60, cooldown = 45, pumpShock = 30, vampBurst = 6,
        desc = "Emergency healing with a shock discharge to nearby enemies and brief vampirism.",
    },
    ["isometric_stabilizer_t5"] = {
        name = "Electrolyte Heart Mk.5", slot = "CIRCULATORY", tier = 5, humanity = 14,
        regen = 3, vamp = 0.10,
        desc = "Iconic life-support system.",
    },
    ["second_heart_t5"] = {
        name = "Second Heart Mk.5", slot = "CIRCULATORY", tier = 5, humanity = 14,
        secondHeart = true, cooldown = 240,
        desc = "Backup heart. On lethal damage, instantly revives you with full health.",
    },

    -- ================= SKIN AND ARMOR (3 slots) =================
    ["subdermal_t1"] = {
        name = "Subdermal Armor Mk.1", slot = "INTEGUMENTARY", tier = 1, humanity = 4,
        bonusHP = 15, armor = 0.05,
        desc = "Basic subdermal protection.",
    },
    ["carapace_light_t1"] = {
        name = "Heat-Resistant Skin Coating Mk.1", slot = "INTEGUMENTARY", tier = 1, humanity = 4,
        bonusHP = 10, armor = 0.03, fireResist = 0.60,
        desc = "Fireproof epidermis layer.",
    },
    ["subdermal_t2"] = {
        name = "Reinforced Skin 'Carapace Mk.2'", slot = "INTEGUMENTARY", tier = 2, humanity = 6,
        bonusHP = 25, armor = 0.07,
        desc = "Multilayer skin protection.",
    },
    ["grounded_plating_t2"] = {
        name = "Grounding Lining Mk.2", slot = "INTEGUMENTARY", tier = 2, humanity = 6,
        bonusHP = 20, armor = 0.05, shockResist = 0.50,
        desc = "Diverts electric discharges into the ground.",
    },
    ["subdermal_carapace"] = {
        name = "Carbon Subdermal Shell Mk.3", slot = "INTEGUMENTARY", tier = 3, humanity = 8,
        bonusHP = 35, armor = 0.09, fireResist = 0.50,
        desc = "Lightweight carbon shell.",
    },
    ["nano_plating_t3"] = {
        name = "Nanoplates 'Reflector Mk.3'", slot = "INTEGUMENTARY", tier = 3, humanity = 8,
        bonusHP = 30, armor = 0.07, reflectChance = 0.06,
        desc = "Angled plates make bullets ricochet.",
    },
    ["optical_camo_t3"] = {
        name = "Optical Camo 'Sandayu Mk.3'", slot = "INTEGUMENTARY", tier = 3, humanity = 8, active = "Camo",
        camo = true, duration = 5, cooldown = 35,
        desc = "Makes you nearly invisible. NPCs lose their target. Attacking breaks the camo.",
    },
    ["supradermal_t4"] = {
        name = "Nano-Lining 'Supradermis Mk.4'", slot = "INTEGUMENTARY", tier = 4, humanity = 11,
        bonusHP = 50, armor = 0.11, fireResist = 0.75, regen = 1,
        desc = "Self-repairing coating.",
    },
    ["pain_editor_t4"] = {
        name = "Pain Editor 'Arasaka Mk.4'", slot = "INTEGUMENTARY", tier = 4, humanity = 11,
        bonusHP = 40, armor = 0.13,
        desc = "Blocks pain receptors.",
    },
    ["optical_camo_t5"] = {
        name = "Optical Camo 'Arasaka Phantom Mk.5'", slot = "INTEGUMENTARY", tier = 5, humanity = 14, active = "Camo",
        camo = true, duration = 8, cooldown = 28, armor = 0.04,
        desc = "Perfect active camouflage of corporate shinobi.",
    },
    ["chitin_shell_t5"] = {
        name = "Chitin Shell 'Militech Mk.5'", slot = "INTEGUMENTARY", tier = 5, humanity = 14,
        bonusHP = 65, armor = 0.14, fireResist = 1.0, regen = 1,
        desc = "Heavy bio-armor.",
    },
    ["cellular_adapter_t5"] = {
        name = "Cellular Adapter Mk.5", slot = "INTEGUMENTARY", tier = 5, humanity = 14,
        bonusHP = 60, armor = 0.12, fireResist = 1.0, shockResist = 0.50, regen = 2,
        desc = "Iconic protection against all elements.",
    },
}

--[[
    Cyberdeck Quickhacks. ram = RAM cost, cooldown = personal quickhack cooldown.
    playersOnly / npcOnly = target type restrictions.
]]
CYBERWARE.Quickhacks = {
    ["ping"] = {
        name = "Ping", ram = 1, cooldown = 10, defaultUnlocked = true, kind = "covert", order = 1,
        desc = "Highlights the target and all enemies within 700 units of it for 8 s.",
    },
    ["short_circuit"] = {
        name = "Short Circuit", ram = 2, cooldown = 4, defaultUnlocked = true, kind = "damage", order = 2,
        damage = 30,
        desc = "Shocks the target (30 damage) and slows a player by 30% for 2.5 s.",
    },
    ["optics_reboot"] = {
        name = "Reboot Optics", ram = 3, cooldown = 12, defaultUnlocked = true, kind = "control", order = 3,
        desc = "Blinds a player with interference for 4 s. An NPC loses its target.",
    },
    ["memory_wipe"] = {
        name = "Memory Wipe", ram = 3, cooldown = 18, defaultUnlocked = false, kind = "covert", order = 4, npcOnly = true,
        desc = "An NPC forgets you and does not attack for 6 s.",
    },
    ["cripple_movement"] = {
        name = "Cripple Movement", ram = 4, cooldown = 16, defaultUnlocked = false, kind = "control", order = 5, playersOnly = true,
        desc = "Disables Sandevistan and stops the target from running, jumping and dashing for 4 s.",
    },
    ["weapon_glitch"] = {
        name = "Weapon Glitch", ram = 4, cooldown = 15, defaultUnlocked = false, kind = "control", order = 6, playersOnly = true,
        desc = "Ejects the target's magazine ammo into reserve.",
    },
    ["overheat"] = {
        name = "Overheat", ram = 4, cooldown = 15, defaultUnlocked = false, kind = "damage", order = 7,
        damage = 10,
        desc = "Sets the target on fire for 5 s and deals 10 fire damage.",
    },
    ["synapse_burn"] = {
        name = "Synapse Burnout", ram = 5, cooldown = 16, defaultUnlocked = false, kind = "damage", order = 8,
        damage = 45,
        desc = "45 damage + up to 45 more depending on the target's missing health.",
    },
    ["contagion"] = {
        name = "Contagion", ram = 5, cooldown = 20, defaultUnlocked = false, kind = "damage", order = 9,
        damage = 8,
        desc = "Poisons the target and enemies within 300: 8 damage per second for 5 s.",
    },
    ["cyberware_malfunction"] = {
        name = "Cyberware Malfunction (EMP)", ram = 6, cooldown = 20, defaultUnlocked = false, kind = "control", order = 10,
        damage = 30,
        desc = "30 damage. Player: disables and locks all active implants for 6 s.",
    },
    ["detonate_grenade"] = {
        name = "Detonate Grenade", ram = 7, cooldown = 28, defaultUnlocked = false, kind = "ultimate", order = 11,
        damage = 65,
        desc = "Detonates the target's gear: 65 explosive damage and knock-up.",
    },
    ["system_reset"] = {
        name = "System Reset", ram = 9, cooldown = 45, defaultUnlocked = false, kind = "ultimate", order = 12,
        damage = 150,
        desc = "An NPC with up to 150 health is shut down instantly, otherwise takes 150 damage. Player: 60 damage, 3 s EMP and interference.",
    },

    -- ===== BLACKWALL: powerful quickhacks at the cost of Corruption (lowers Humanity) =====
    ["blackwall_whisper"] = {
        name = "Whisper from Beyond the Blackwall", ram = 5, cooldown = 25, defaultUnlocked = false, kind = "blackwall", order = 13,
        playersOnly = true, corruption = 15, targetCorruption = 30,
        desc = "Lets the voices of rogue AIs into the target's mind: +30 Corruption to the target, hallucinations and interference for 5 s.",
    },
    ["blackwall_breach"] = {
        name = "Blackwall Breach", ram = 8, cooldown = 40, defaultUnlocked = false, kind = "blackwall", order = 14,
        damage = 110, splash = 45, corruption = 30,
        desc = "Hurls code from beyond the Blackwall at the target: 110 damage and 45 to everyone nearby (radius 260). The most dangerous quickhack on the Net.",
    },
}

CYBERWARE.HackKindColors = {
    damage    = Color(255, 80, 80),
    control   = Color(80, 200, 255),
    covert    = Color(80, 255, 170),
    ultimate  = Color(255, 190, 30),
    blackwall = Color(230, 20, 50),
}

--[[
    Sounds: layers { path, pitch = {min,max}, vol, level }. Standard HL2/GMod content only.
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
    blackwall     = { { "ambient/levels/citadel/strange_talk5.wav", pitch = { 60, 70 }, vol = 0.8 }, { "ambient/levels/labs/electric_explosion1.wav", pitch = { 70, 80 }, vol = 0.7 }, { "npc/stalker/go_alert2a.wav", pitch = { 55, 65 }, vol = 0.5 } },
    bw_overload   = { { "ambient/levels/labs/electric_explosion5.wav", pitch = { 60, 70 }, vol = 1, level = 85 }, { "npc/stalker/go_alert2a.wav", pitch = { 45, 55 }, vol = 0.8 } },
    episode       = { { "npc/antlion_guard/angry2.wav", pitch = { 70, 80 }, vol = 0.8, level = 85 }, { "player/heartbeat1.wav", pitch = { 120, 130 }, vol = 1 } },
}

-- ================= COMMON FUNCTIONS =================

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

-- Best (by tier) implant in a slot that has the given field
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

-- Cyberdeck RAM: stores a value + write time, regeneration is computed identically on server and client
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

-- Blackwall Corruption: stores a value + time of last gain, decay is computed identically on server and client
function CYBERWARE:GetBlackwall(ply)
    if not IsValid(ply) then return 0 end
    local bw = self.Config.Blackwall
    local base = ply:GetNW2Float("Cyber_BW", 0)
    if base <= 0 then return 0 end
    local idle = CurTime() - ply:GetNW2Float("Cyber_BWStamp", 0) - bw.DecayDelay
    return math.Clamp(base - math.max(0, idle) * bw.DecayPerSec, 0, bw.Max)
end

-- Humanity without Corruption (implants and cap only)
function CYBERWARE:GetBaseHumanity(ply)
    if not IsValid(ply) then return self.Config.DefaultMaxHumanity end
    return self:GetMaxHumanity(ply) - self:GetUsedHumanity(ply)
end

function CYBERWARE:GetHumanity(ply)
    if not IsValid(ply) then return self.Config.DefaultMaxHumanity end
    local hum = self:GetBaseHumanity(ply) - math.floor(self:GetBlackwall(ply) * self.Config.Blackwall.HumanityPerPoint)
    return math.Clamp(hum, self.Config.MinHumanityCap, self.Config.MaxHumanityCap)
end

-- How much Humanity remains until the next threshold (nil — already terminal stage)
function CYBERWARE:GetNextThreshold(hum)
    local c = self.Config
    if hum >= c.PsychosisStart then return hum - c.PsychosisStart + 1, 1 end
    if hum > c.PsychosisStage2 then return hum - c.PsychosisStage2, 2 end
    if hum > c.PsychosisTerminal then return hum - c.PsychosisTerminal, 3 end
    return nil
end

CYBERWARE.StageHints = {
    [0] = "Mind is intact.",
    [1] = "A whisper at the edge of consciousness, interference in your optics. Stop before it's too late.",
    [2] = "Hallucinations, rage: +10% damage, but your hands shake (spread ×1.25).",
    [3] = "Uncontrollable episodes of rage. Those around you can see you losing yourself.",
}

-- 0 — stable, 1 — unstable, 2 — cyberpsychosis, 3 — terminal stage
function CYBERWARE:GetPsychosisStage(hum)
    local c = self.Config
    if hum <= c.PsychosisTerminal then return 3 end
    if hum <= c.PsychosisStage2 then return 2 end
    if hum < c.PsychosisStart then return 1 end
    return 0
end

CYBERWARE.StageNames = { [0] = "STABLE", [1] = "UNSTABLE", [2] = "CYBERPSYCHOSIS", [3] = "TERMINAL STAGE" }
CYBERWARE.StageColors = { [0] = Color(94, 246, 255), [1] = Color(252, 226, 5), [2] = Color(255, 110, 60), [3] = Color(255, 40, 70) }

function CYBERWARE:GetPsychosisSeverity(hum)
    local c = self.Config
    if hum >= c.PsychosisStart then return 0 end
    return math.Clamp((c.PsychosisStart - hum) / math.max(1, c.PsychosisStart - c.PsychosisTerminal), 0.05, 1)
end

-- Aggregated passive stats with all caps. Cached until the implant set changes.
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

-- Action key name (on the client — respects the user's custom binding)
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

-- Readable implant stat lines: { text, type } (type: 'pos' / 'neg' / 'info' / 'active')
function CYBERWARE:GetImplantStatLines(d)
    local L = {}
    local function add(text, kind) L[#L + 1] = { text, kind or "pos" } end

    if d.active then add("Activation: key [" .. self:GetKeyName(d.active) .. "]", "active") end
    if d.duration then add("Duration: " .. d.duration .. " s", "info") end
    if d.cooldown then add("Cooldown: " .. d.cooldown .. " s", "info") end

    if d.speedBonus then add("Speed on activation: +" .. Pct(d.speedBonus)) end
    if d.dmgDodge then add("Damage reduction while moving: " .. Pct(d.dmgDodge)) end
    if d.killExtend then add("Kill extends duration by " .. d.killExtend .. " s") end
    if d.sandyKillHeal then add("Kill during boost heals " .. Pct(d.sandyKillHeal) .. " HP") end
    if d.meleeMult then
        add("Health never drops below 1 HP")
        add("Melee damage: ×" .. d.meleeMult)
    end
    if d.berserkArmor then add("Damage reduction on activation: " .. Pct(d.berserkArmor)) end
    if d.slamWave then add("Shockwave on landing from height") end
    if d.ram then add("RAM: " .. d.ram .. " (regen. " .. d.ramRegen .. "/s)") end
    if d.hackRange then add("Hack range: " .. d.hackRange) end
    if d.hackDmgMult and d.hackDmgMult > 1 then add("Quickhack damage: +" .. Pct(d.hackDmgMult - 1)) end
    if d.cdMult and d.cdMult < 1 then add("Quickhack cooldown: −" .. Pct(1 - d.cdMult)) end
    if d.blackwallMult then add("Blackwall Corruption: −" .. Pct(1 - d.blackwallMult)) end

    if d.headMult then add("Headshot damage while scanning: +" .. Pct(d.headMult - 1)) end
    if d.headPassive then add("Passive headshot damage: +" .. Pct(d.headPassive)) end
    if d.scanRange then add("Scan radius: " .. d.scanRange, "info") end

    if d.meleeBonus then add("Melee damage: +" .. Pct(d.meleeBonus)) end
    if d.gunBonus then add("Firearm damage: +" .. Pct(d.gunBonus)) end
    if d.spreadMult then add("Bullet spread: −" .. Pct(1 - d.spreadMult)) end
    if d.knockback then add("Melee knockback: " .. d.knockback) end
    if d.shockDmg then add("Shock damage per hit: +" .. d.shockDmg) end
    if d.bleedDps then add("Bleeding: " .. d.bleedDps .. " /s, " .. (d.bleedTime or 3) .. " s") end
    if d.chainShock then add("Chain shock: " .. Pct(d.chainShock) .. " damage to " .. (d.chainTargets or 2) .. " targets") end
    if d.launcherDmg then add("Projectile: " .. d.launcherDmg .. " damage, radius " .. d.launcherRadius) end

    if d.dashPower then add("Dash power: " .. d.dashPower, "info") end
    if d.dodgeTime then add("Bullet immunity: " .. d.dodgeTime .. " s") end
    if d.passiveDodge then add("Bullet dodge chance: +" .. Pct(d.passiveDodge)) end
    if d.speedPassive then add("Movement speed: +" .. Pct(d.speedPassive)) end
    if d.selfIce then add("Blocks one enemy quickhack") end

    if d.bonusHP then add("Max health: +" .. d.bonusHP) end
    if d.armor then add("Incoming damage reduction: " .. Pct(d.armor)) end
    if d.meleeResist then add("Melee damage reduction: " .. Pct(d.meleeResist)) end
    if d.fallMult then
        if d.fallMult <= 0 then add("Fall damage immunity") else add("Fall damage: −" .. Pct(1 - d.fallMult)) end
    end
    if d.jumpCharge then add("Charged jump (hold SPACE): ×" .. (d.jumpMult or 1.4)) end
    if d.doubleJump then add("Double jump") end
    if d.silentSteps then add("Silent steps") end

    if d.healThreshold then add("Auto-heal +" .. d.healAmount .. " HP at HP < " .. Pct(d.healThreshold)) end
    if d.pumpShock then add("Shock discharge to nearby enemies: " .. d.pumpShock .. " damage") end
    if d.vampBurst then add("Vampirism +15% for " .. d.vampBurst .. " s after trigger") end
    if d.killHeal then add("Heal per kill: +" .. d.killHeal .. " HP") end
    if d.cdRefund then add("Kill reduces OS cooldown by " .. d.cdRefund .. " s") end
    if d.regen then add("Out-of-combat regen: +" .. d.regen .. " HP / " .. self.Config.RegenTick .. " s") end
    if d.vamp then add("Vampirism: " .. Pct(d.vamp)) end
    if d.secondHeart then add("Revive with full HP on lethal damage") end

    if d.fireResist then
        if d.fireResist >= 1 then add("Fire immunity") else add("Fire resistance: " .. Pct(d.fireResist)) end
    end
    if d.shockResist then add("Electric resistance: " .. Pct(d.shockResist)) end
    if d.reflectChance then add("Bullet ricochet chance: " .. Pct(d.reflectChance)) end
    if d.camo then add("Invisibility, NPCs lose their target") end

    add("Humanity load: −" .. (d.humanity or 0), "neg")
    return L
end

-- ================= MOVEMENT (shared prediction hook) =================
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
