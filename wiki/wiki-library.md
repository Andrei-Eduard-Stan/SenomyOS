---
title: Your Wiki library
category: Reference
category_order: 20
order: 10
summary: Find local guides, copy expressions, save personal emoticons and look up active Hyprland shortcuts.
---

# Your Wiki library

Open Insights from the Senomy island, then choose Wiki. Articles, Emoticons and
Shortcuts keep reading, collecting and keyboard reference together.

## Copy an expression

Emoticons includes faces, animals, affection, decorations, emoji, symbols and ASCII
expressions. Search by name, category or character. Copy preserves the original
Unicode text and line breaks. A star saves an expression to Favorites; choose
Favorites to see that collection.

## Save your own

Choose Add emoticon, give it a searchable name and category, and paste the
expression. Save expression keeps it in your personal library on this device.
Edit lets you change or remove a personal entry. Switching Wiki sections preserves
an unfinished editor while the Wiki remains loaded; Save is required for storage
across shell restarts.

## Missing-character boxes

A box containing a code or a blank square usually means the selected application
cannot find a font for that character. The Wiki checks installed coverage and
shows a warning when an expression needs more fonts. Copy still preserves the
characters. Another application or recipient may render the same text differently.

Senomy's Unicode fallback setup includes emoji, CJK kaomoji, mathematical symbols,
Egyptian decorations and Tibetan characters. Refresh an already-open browser page
after installing fonts. Applications with an older font cache may need reopening;
there is no need to restart the desktop to use the Wiki library.

## Find a shortcut

Shortcuts reads every active binding exposed by this Hyprland session, including
modifiers, pointer bindings, submaps, repeat and release conditions. Search keys,
actions or groups. Copy list copies the filtered reference; it does not execute
shortcuts. Page Up, Page Down, Home and End scroll the reference.

The list refreshes on opening and every 15 seconds while visible. Hyprland is the
source for active keys and flags. Lua action names come from the current config;
Senomy-managed workspace labels follow the workspace policy. Unknown actions
remain labeled by their runtime dispatcher. Editing a config file alone does not
prove the compositor has loaded its new actions.
