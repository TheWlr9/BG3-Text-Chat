local Text_Chat_Config = {
    InputFirstLineHeightPx = 32,
    InputExtraLineHeightPx = 18,

    DefaultLanguage = "en",

    DefaultWindowXPos = 150,
    DefaultWindowYPos = 750,
    DefaultWindowWidth = 600,
    DefaultWindowHeight = 300,

    DefaultActiveAlpha = 1.0,
    DefaultInactiveAlpha = 0.5,

    DefaultShowTimestamps = false,

    DefaultShowHintMessage = true,

    DefaultOpenKey = "RETURN",

    AutoHideDelaySeconds = 8,
    DefaultAutoHideEnabled = true,

    TypingIndicatorTimeoutSeconds = 4,

    NameRepeatDelaySeconds = 5 * 60,

    TypingBroadcastThrottleSeconds = 1.0,

    DefaultTypingNotificationsEnabled = true,

    DefaultOverheadTextEnabled = true,

    DefaultChatFormat = "roleplayer",

    EmoteColor = {0.62, 0.62, 0.68, 1.0},

    EmoteFontName = "",

    NameColor = {1.0, 1.0, 1.0, 1.0},

    TypingIndicatorColor = {0.75, 0.75, 0.75, 1.0},

    EditedColor = {0.45, 0.45, 0.45, 1.0},

    MaxKeptMessages = 300,

    DiceAbilities = {
        { id = "Strength" },
        { id = "Dexterity" },
        { id = "Constitution" },
        { id = "Intelligence" },
        { id = "Wisdom" },
        { id = "Charisma" },
    },

    DiceSkills = {
        { id = "Deception" },
        { id = "Intimidation" },
        { id = "Performance" },
        { id = "Persuasion" },
        { id = "Acrobatics" },
        { id = "SleightOfHand" },
        { id = "Stealth" },
        { id = "Arcana" },
        { id = "History" },
        { id = "Investigation" },
        { id = "Nature" },
        { id = "Religion" },
        { id = "Athletics" },
        { id = "AnimalHandling" },
        { id = "Insight" },
        { id = "Medicine" },
        { id = "Perception" },
        { id = "Survival" },
    },

    -- "active" = RequestActiveRoll (dice window), "passive" = RequestPassiveRoll (overhead popup)
    DiceRollTypes = { "active", "passive" },

    -- DC tiers. Each tier is a DifficultyClass resource (UUID) created by the mod at session load,
    -- with a single fixed value in Difficulties. The UUIDs must never change.
    DiceDifficultyTiers = {
        { id = "VeryEasy",         dc = 5,  uuid = "038475dc-e674-47d3-92f6-d10cb8cb8179" },
        { id = "Easy",             dc = 10, uuid = "e3e5d485-2f94-4e8f-b60b-6c1f1e3afe24" },
        { id = "Medium",           dc = 15, uuid = "51d64f36-b320-415a-86c7-9ce224d8319f" },
        { id = "Hard",             dc = 20, uuid = "97afaee6-89f0-4d4b-974f-2b42270518dd" },
        { id = "VeryHard",         dc = 25, uuid = "40a7a1ac-19ce-4da8-a7e2-675335da7b95" },
        { id = "NearlyImpossible", dc = 30, uuid = "846d0b96-588e-4403-b52f-381ab5243228" },
    },
    DiceDefaultTierIndex = 3,

    DiceWhoPollMs = 1000,

    DicePendingRollTimeoutMs = 10 * 60 * 1000,
}

Text_Chat_Config.DiceAbilityById = {}
for _, a in ipairs(Text_Chat_Config.DiceAbilities) do Text_Chat_Config.DiceAbilityById[a.id] = a end

Text_Chat_Config.DiceSkillById = {}
for _, s in ipairs(Text_Chat_Config.DiceSkills) do Text_Chat_Config.DiceSkillById[s.id] = s end

Text_Chat_Config.DiceRollTypeSet = {}
for _, t in ipairs(Text_Chat_Config.DiceRollTypes) do Text_Chat_Config.DiceRollTypeSet[t] = true end

Text_Chat_Config.DiceTierById = {}
for _, t in ipairs(Text_Chat_Config.DiceDifficultyTiers) do Text_Chat_Config.DiceTierById[t.id] = t end

local function _single_difficulty(res)
    local ok, value = pcall(function()
        if res.Difficulties and #res.Difficulties == 1 then return res.Difficulties[1] end
        return nil
    end)
    if ok then return value end
    return nil
end

-- Makes sure every DC tier points to a DifficultyClass the engine knows.
-- 1. Our own resource (created here with the tier UUID), so other mods that rebalance
--    the vanilla DCs can't change our values.
-- 2. If creating fails, a vanilla DifficultyClass with the same single value.
-- Must run on both server and client (the active roll window reads the DC on the client).
function Text_Chat_Config.ResolveDiceDifficultyClasses()
    if not (Ext.StaticData and Ext.StaticData.Get) then return end

    local vanilla_by_dc = nil
    local function _vanilla(dc)
        if vanilla_by_dc == nil then
            vanilla_by_dc = {}
            pcall(function()
                for _, guid in ipairs(Ext.StaticData.GetAll("DifficultyClass")) do
                    local res = Ext.StaticData.Get(guid, "DifficultyClass")
                    local value = res and _single_difficulty(res)
                    if value and vanilla_by_dc[value] == nil then vanilla_by_dc[value] = guid end
                end
            end)
        end
        return vanilla_by_dc[dc]
    end

    for _, tier in ipairs(Text_Chat_Config.DiceDifficultyTiers) do
        local ok = pcall(function()
            local res = Ext.StaticData.Get(tier.uuid, "DifficultyClass")
            if not res then res = Ext.StaticData.Create("DifficultyClass", tier.uuid) end
            if not res then error("create failed") end
            res.Name = "TextChat_DC" .. tier.dc
            res.Difficulties = { tier.dc }
            if _single_difficulty(Ext.StaticData.Get(tier.uuid, "DifficultyClass")) ~= tier.dc then
                error("value not applied")
            end
        end)
        if ok then
            tier.guid = tier.uuid
        else
            tier.guid = _vanilla(tier.dc)
        end
    end
end

return Text_Chat_Config
