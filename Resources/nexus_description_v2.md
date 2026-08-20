# Text Chat

Also check it out in the in-game mod manager! Just search for "Text Chat"

## Overview

There is no text chat in Baldur's Gate 3. Which is weird. There should be. So we implemented it!

Version 2.0 merges in a big round of RP-focused features and quality-of-life improvements from FonWasH's fork of this mod, RPChat. Full details in the changelog.

## Features

*Patch 8 compatible!*

- Moveable and resizeable!
- Compatible with [Party Limit Begone](https://www.nexusmods.com/baldursgate3/mods/327) and [Adjustable Party Limit](https://mod.io/g/baldursgate3/m/adjustable-party-limit) mods! (16 player multiplayer anyone?)
- Settings save locally, unique per user, persistent across saves
- Semi-transparent so you can still see the game when you're not actively using it
- Passes clicks through it so you're not accidentally clicking the chat box
- Emote support (`*does a thing*`), shown in its own color
- Edit your last message (up-arrow, or a dedicated Edit button)
- Consecutive messages from the same character don't repeat the name
- 4 selectable chat display styles: Classic, Modern, Discord-like, and Roleplay-like
- Multi-line input (Ctrl+Enter for a line break), growing as needed
- Typing indicator ("X is typing...")
- Auto-hide after inactivity, fully configurable
- Rebindable "open chat" key with a simple "press any key" capture
- A proper in-game settings panel, docked left/right next to the chat window, depending on the position

## Setup/Installation

- All players in a multiplayer game must have this mod installed, on the same version
- Make sure you have [BG3 Mod Manager](https://github.com/LaughingLeader/BG3ModManager/releases) (BG3MM)
- Make sure you have everything listed under this mod's "Requirements"
- The quickest way to install is through BG3MM: download the .zip, import it, place it in your Active Mods list (order doesn't matter for this mod), then click "Export Order to Game"

## How to use

- Click on, or hit Enter, to focus the input box and start typing
- Hit Enter to send your message
- Ctrl+Enter for a line break while composing
- Up-arrow to edit your last message
- Open the in-chat Menu button to reposition/resize the window, adjust opacity, change the chat style, rebind the open key, and more

## Developers

[GitHub repo](https://github.com/TheWlr9/BG3-Text-Chat)

We use `Ext.Events.NetMessage` to send and receive messages. To hook into it from your own mod (to send or receive messages programmatically), grab the channel we use with:

```lua
Mods["BG3-Text-Chat"].CHANNEL
```

## Other Works

- [Differentiate between blocking and missing!](https://www.nexusmods.com/baldursgate3/mods/9646)

## Special Thanks

- [FonWasH](https://www.nexusmods.com/profile/FoNoicH) for the huge round of RP features and improvements in version 2.0.0.0
- HUGE shoutout to [Zeffuro](https://www.nexusmods.com/profile/Zeffuro) for the patch 1.4.0.0 work!
- Norbyte, for making BG3 mods Turing-complete with Script Extender
- LaughingLeader, for publishing BG3MM
- ShinyHobo, for BG3 Modders Multitool
- Larian Studios, for making one of our favorite games of all time

---

*Note: neither of us is responsible for the content shared in chat, nor is it endorsed by Larian Studios. Content in the chat is driven by player input and is not rated by the E.S.R.B. or Pegi. If you're a minor in your country, ask your parents' permission before using this mod.*
