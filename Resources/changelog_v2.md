# Version 2.0.0.0

This release merges in [FonWasH's RPChat fork](https://github.com/FonWasH/RPChat), adding a large set of RP-focused features and quality-of-life improvements on top of the existing mod.

## Added

- Emote support (`*does a thing*`), rendered in its own color
- Edit your last message: up-arrow reloads it if the input box is empty, or use the Edit button (works even mid-draft, caching and restoring whatever you were typing)
- Consecutive messages from the same character no longer repeat the name (re-shows automatically after 5 minutes of silence)
- 4 selectable chat display styles: Classic, Modern, Discord-like, and Roleplay-like, each with its own timestamp coloring
- Custom colors for the character name and the "(edited)" tag
- Multi-line input (Ctrl+Enter for a manual line break), growing upward as needed, with a native scrollbar past a certain size
- Typing indicator ("X is typing...", or "Several people are typing..." for 2+)
- Rebindable "open chat" key via a "press any key" capture button, instead of typing it manually
- A proper in-game settings panel (checkboxes, sliders, dropdown) that docks to whichever side of the chat
- Native drag/resize via a dedicated "Move Mode"
- Auto-hide after inactivity, with a configurable delay
- Toggleable shortcuts hint shown on startup instead of a static "Welcome" message
- Toggleable text above characters

## Changed

- Timestamps are now frozen at the moment a message is sent, instead of being recomputed every time the chat redraws
- Whitespace-only messages are no longer sent, and messages are trimmed before sending
- Manual line breaks are purely a typing convenience: the message that actually gets sent is always a continuous paragraph, wrapped naturally by the display

## Removed

- The chat log dump button has been removed. If you relied on it, let me know (I wanted a user-friendly menu, and I find this feature rather useless)
