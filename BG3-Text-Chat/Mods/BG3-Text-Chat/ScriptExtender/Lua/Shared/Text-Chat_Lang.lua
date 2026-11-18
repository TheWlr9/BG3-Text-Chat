--[[
    Text-Chat translations
    ======================

    HOW TO ADD A LANGUAGE
      1. Copy the whole `en = { ... }` block of Lang.Strings below and paste it right after it.
      2. Rename the copy's key (`en`) to your language code, e.g. `de`, `es`, `pt`.
      3. Translate the VALUES on the right of the `=` signs. Never change the KEYS on the left.
      4. Add one line to `Lang.Languages`:  { code = "de", name = "Deutsch" },
      That's it. The language then shows up in Settings > Language.

    RULES
      * Keep the placeholders (%s, %d) in your translation, in the order you need them.
        Example: "%s is typing..." -> "%s écrit..."
      * A missing key falls back to English, so a partial translation never breaks the mod.
      * Accented letters (é, è, ê, à, ç, ñ, ...) display correctly in game.
        Other special symbols or non-Latin scripts may show up as "?", so test them in game first.
      * Window layout adapts automatically to the text length (buttons, panels and the input box
        are sized from the real font), so long translations do not need any other change.
]]

if _G.__TC_LANG then
    return _G.__TC_LANG
end

local Lang = {}

Lang.Languages = {
    { code = "en", name = "English" },
    { code = "fr", name = "Français" },
}

Lang.Default = "en"
Lang.Current = Lang.Default

Lang.Strings = {
    en = {
        ["top.menu"]  = "Menu",
        ["top.dice"]  = "Dice",
        ["top.clear"] = "Clear",
        ["top.close"] = "Close",

        ["input.edit"]   = "Edit",
        ["input.cancel"] = "Cancel",

        ["status.typing"]  = "%s is typing...",
        ["status.several"] = "Several people are typing...",

        ["chat.hint"]   = "~ Tip: Ctrl+Enter for a new line, Up Arrow to edit your last message ~",
        ["chat.joined"] = "~ %s joined the chat ~",
        ["chat.left"]   = "~ %s left the chat ~",
        ["chat.edited"] = "(edited)",
        ["chat.logSaved"]  = "~ Chat log saved: %s ~",
        ["chat.logFailed"] = "~ Could not save the chat log ~",

        ["move.title"] = "Text-Chat (drag to move/resize)",

        ["settings.display"]      = "Display",
        ["settings.moveMode"]     = "Move Mode",
        ["settings.timestamps"]   = "Timestamps",
        ["settings.hint"]         = "Show shortcuts hint",
        ["settings.overhead"]     = "Text above character",
        ["settings.opacityActive"] = "Opacity (input focused)",
        ["settings.opacityIdle"]   = "Opacity (idle)",
        ["settings.chatFormat"]   = "Chat format",
        ["settings.behavior"]     = "Behavior",
        ["settings.openKey"]      = "Open key",
        ["settings.keyCurrent"]   = "Current: %s",
        ["settings.keyPress"]     = "Press a key...",
        ["settings.typing"]       = "Typing notifications",
        ["settings.autoHide"]     = "Auto-hide",
        ["settings.autoHideDelay"] = "Auto-hide delay (seconds)",
        ["settings.language"]     = "Language",
        ["settings.tools"]        = "Tools",
        ["settings.generateLog"]  = "Generate log file",

        ["format.classic"]    = "Classic",
        ["format.modern"]     = "Modern",
        ["format.discord"]    = "Discord",
        ["format.roleplayer"] = "Roleplayer",

        ["dice.character"]   = "Character: %s",
        ["dice.rollType"]    = "Roll type",
        ["dice.type.active"]  = "Active (dice window)",
        ["dice.type.passive"] = "Passive (overhead)",
        ["dice.advantageOption"] = "Advantage",
        ["dice.hiddenOption"]    = "Hidden roll",
        ["dice.dc"]          = "DC",
        ["dice.tierLabel"]   = "%s (DC %d)",
        ["dice.tier.VeryEasy"]         = "Very easy",
        ["dice.tier.Easy"]             = "Easy",
        ["dice.tier.Medium"]           = "Medium",
        ["dice.tier.Hard"]             = "Hard",
        ["dice.tier.VeryHard"]         = "Very hard",
        ["dice.tier.NearlyImpossible"] = "Nearly impossible",
        ["dice.abilities"]   = "Ability check",
        ["dice.rollAbility"] = "Roll ability",
        ["dice.skills"]      = "Skill check",
        ["dice.rollSkill"]   = "Roll skill",

        ["dice.advantage"]       = "(advantage)",
        ["dice.dcValue"]         = "DC %d",
        ["dice.success"]         = "success",
        ["dice.failure"]         = "failure",
        ["dice.criticalSuccess"] = "critical success!",
        ["dice.criticalFailure"] = "critical failure!",
        ["dice.cancelled"]       = "roll cancelled",
        ["dice.overhead"]        = "%s : %s",
        ["dice.noDifficultyClass"] = "~ This DC is not available, the roll could not be made ~",

        ["ability.Strength"]     = "Strength",
        ["ability.Dexterity"]    = "Dexterity",
        ["ability.Constitution"] = "Constitution",
        ["ability.Intelligence"] = "Intelligence",
        ["ability.Wisdom"]       = "Wisdom",
        ["ability.Charisma"]     = "Charisma",
        ["check.Strength"]     = "Strength check",
        ["check.Dexterity"]    = "Dexterity check",
        ["check.Constitution"] = "Constitution check",
        ["check.Intelligence"] = "Intelligence check",
        ["check.Wisdom"]       = "Wisdom check",
        ["check.Charisma"]     = "Charisma check",

        ["skill.Acrobatics"]     = "Acrobatics",
        ["skill.AnimalHandling"] = "Animal Handling",
        ["skill.Arcana"]         = "Arcana",
        ["skill.Athletics"]      = "Athletics",
        ["skill.Deception"]      = "Deception",
        ["skill.History"]        = "History",
        ["skill.Insight"]        = "Insight",
        ["skill.Intimidation"]   = "Intimidation",
        ["skill.Investigation"]  = "Investigation",
        ["skill.Medicine"]       = "Medicine",
        ["skill.Nature"]         = "Nature",
        ["skill.Perception"]     = "Perception",
        ["skill.Performance"]    = "Performance",
        ["skill.Persuasion"]     = "Persuasion",
        ["skill.Religion"]       = "Religion",
        ["skill.SleightOfHand"]  = "Sleight of Hand",
        ["skill.Stealth"]        = "Stealth",
        ["skill.Survival"]       = "Survival",
    },

    fr = {
        ["top.menu"]  = "Menu",
        ["top.dice"]  = "Dés",
        ["top.clear"] = "Effacer",
        ["top.close"] = "Fermer",

        ["input.edit"]   = "Modifier",
        ["input.cancel"] = "Annuler",

        ["status.typing"]  = "%s écrit...",
        ["status.several"] = "Plusieurs personnes écrivent...",

        ["chat.hint"]   = "~ Astuce : Ctrl+Entrée pour un retour à la ligne, Flèche haut pour modifier votre dernier message ~",
        ["chat.joined"] = "~ %s a rejoint le chat ~",
        ["chat.left"]   = "~ %s a quitté le chat ~",
        ["chat.edited"] = "(modifié)",
        ["chat.logSaved"]  = "~ Journal du chat enregistré : %s ~",
        ["chat.logFailed"] = "~ Impossible d'enregistrer le journal du chat ~",

        ["move.title"] = "Text-Chat (glisser pour déplacer/redimensionner)",

        ["settings.display"]      = "Affichage",
        ["settings.moveMode"]     = "Mode déplacement",
        ["settings.timestamps"]   = "Horodatage",
        ["settings.hint"]         = "Afficher l'astuce des raccourcis",
        ["settings.overhead"]     = "Texte au-dessus du personnage",
        ["settings.opacityActive"] = "Opacité (saisie active)",
        ["settings.opacityIdle"]   = "Opacité (inactif)",
        ["settings.chatFormat"]   = "Format du chat",
        ["settings.behavior"]     = "Comportement",
        ["settings.openKey"]      = "Touche d'ouverture",
        ["settings.keyCurrent"]   = "Actuelle : %s",
        ["settings.keyPress"]     = "Appuyez sur une touche...",
        ["settings.typing"]       = "Notifications de saisie",
        ["settings.autoHide"]     = "Masquage auto",
        ["settings.autoHideDelay"] = "Délai de masquage (secondes)",
        ["settings.language"]     = "Langue",
        ["settings.tools"]        = "Outils",
        ["settings.generateLog"]  = "Générer le fichier de log",

        ["format.classic"]    = "Classique",
        ["format.modern"]     = "Moderne",
        ["format.discord"]    = "Discord",
        ["format.roleplayer"] = "Roleplay",

        ["dice.character"]   = "Personnage : %s",
        ["dice.rollType"]    = "Type de jet",
        ["dice.type.active"]  = "Actif (fenêtre de dé)",
        ["dice.type.passive"] = "Passif (au-dessus du personnage)",
        ["dice.advantageOption"] = "Avantage",
        ["dice.hiddenOption"]    = "Jet caché",
        ["dice.dc"]          = "DC",
        ["dice.tierLabel"]   = "%s (DC %d)",
        ["dice.tier.VeryEasy"]         = "Très facile",
        ["dice.tier.Easy"]             = "Facile",
        ["dice.tier.Medium"]           = "Moyen",
        ["dice.tier.Hard"]             = "Difficile",
        ["dice.tier.VeryHard"]         = "Très difficile",
        ["dice.tier.NearlyImpossible"] = "Quasi impossible",
        ["dice.abilities"]   = "Test de caractéristique",
        ["dice.rollAbility"] = "Lancer (caractéristique)",
        ["dice.skills"]      = "Test de compétence",
        ["dice.rollSkill"]   = "Lancer (compétence)",

        ["dice.advantage"]       = "(avantage)",
        ["dice.dcValue"]         = "DC %d",
        ["dice.success"]         = "réussite",
        ["dice.failure"]         = "échec",
        ["dice.criticalSuccess"] = "réussite critique !",
        ["dice.criticalFailure"] = "échec critique !",
        ["dice.cancelled"]       = "jet annulé",
        ["dice.overhead"]        = "%s : %s",
        ["dice.noDifficultyClass"] = "~ Ce DC n'est pas disponible, le jet n'a pas pu être lancé ~",

        ["ability.Strength"]     = "Force",
        ["ability.Dexterity"]    = "Dextérité",
        ["ability.Constitution"] = "Constitution",
        ["ability.Intelligence"] = "Intelligence",
        ["ability.Wisdom"]       = "Sagesse",
        ["ability.Charisma"]     = "Charisme",
        ["check.Strength"]     = "Test de Force",
        ["check.Dexterity"]    = "Test de Dextérité",
        ["check.Constitution"] = "Test de Constitution",
        ["check.Intelligence"] = "Test d'Intelligence",
        ["check.Wisdom"]       = "Test de Sagesse",
        ["check.Charisma"]     = "Test de Charisme",

        ["skill.Acrobatics"]     = "Acrobaties",
        ["skill.AnimalHandling"] = "Dressage",
        ["skill.Arcana"]         = "Arcanes",
        ["skill.Athletics"]      = "Athlétisme",
        ["skill.Deception"]      = "Tromperie",
        ["skill.History"]        = "Histoire",
        ["skill.Insight"]        = "Perspicacité",
        ["skill.Intimidation"]   = "Intimidation",
        ["skill.Investigation"]  = "Investigation",
        ["skill.Medicine"]       = "Médecine",
        ["skill.Nature"]         = "Nature",
        ["skill.Perception"]     = "Perception",
        ["skill.Performance"]    = "Représentation",
        ["skill.Persuasion"]     = "Persuasion",
        ["skill.Religion"]       = "Religion",
        ["skill.SleightOfHand"]  = "Escamotage",
        ["skill.Stealth"]        = "Discrétion",
        ["skill.Survival"]       = "Survie",
    },
}

function Lang.IndexOf(code)
    for i, l in ipairs(Lang.Languages) do
        if l.code == code then return i end
    end
    return nil
end

function Lang.Set(code)
    if type(code) == "string" and Lang.Strings[code] then
        Lang.Current = code
        return true
    end
    return false
end

function Lang.T(key, ...)
    local s = (Lang.Strings[Lang.Current] or {})[key]
    if s == nil then s = Lang.Strings[Lang.Default][key] end
    if s == nil then s = key end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, s, ...)
        if ok then return formatted end
    end
    return s
end

_G.__TC_LANG = Lang

return Lang
