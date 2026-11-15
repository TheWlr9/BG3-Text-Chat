local M = {}

M.Abilities = {
    { id = "Strength",     enum = 1 },
    { id = "Dexterity",    enum = 2 },
    { id = "Constitution", enum = 3 },
    { id = "Intelligence", enum = 4 },
    { id = "Wisdom",       enum = 5 },
    { id = "Charisma",     enum = 6 },
}

M.Skills = {
    { id = "Deception",      enum = 0 },
    { id = "Intimidation",   enum = 1 },
    { id = "Performance",    enum = 2 },
    { id = "Persuasion",     enum = 3 },
    { id = "Acrobatics",     enum = 4 },
    { id = "SleightOfHand",  enum = 5 },
    { id = "Stealth",        enum = 6 },
    { id = "Arcana",         enum = 7 },
    { id = "History",        enum = 8 },
    { id = "Investigation",  enum = 9 },
    { id = "Nature",         enum = 10 },
    { id = "Religion",       enum = 11 },
    { id = "Athletics",      enum = 12 },
    { id = "AnimalHandling", enum = 13 },
    { id = "Insight",        enum = 14 },
    { id = "Medicine",       enum = 15 },
    { id = "Perception",     enum = 16 },
    { id = "Survival",       enum = 17 },
}

M.AbilityById = {}
for _, a in ipairs(M.Abilities) do M.AbilityById[a.id] = a end

M.SkillById = {}
for _, s in ipairs(M.Skills) do M.SkillById[s.id] = s end

M.Modes = { "normal", "adv", "dis" }
M.ModeSet = { normal = true, adv = true, dis = true }

return M
