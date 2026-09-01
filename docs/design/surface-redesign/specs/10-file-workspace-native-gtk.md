# File Workspace and native GTK

| Contract | Specification |
| --- | --- |
| Renderer | Thunar / namespaced GTK 3 theme |
| Opens | Super+E, Command Lens Files, approved reveal/open handoffs |
| Geometry | Hyprland-managed native window |
| Frame | Native Level 1 plus compositor edge |
| Density | Standard and touch theme variants |

## Composition

Keep native menu, toolbar, path entry, tree, file list, status line, dialogs, and extension behavior. Apply dark obsidian fields, ivory dividers/text, sparse violet selection/focus, and restrained header geometry. Do not paste a Large Eww frame inside the file view.

## Interaction

Preserve native keyboard navigation, context menus, drag/drop, file operations, and the wrapper's fresh-daemon theme ownership. Standard controls target 38–40px; touch controls target 48px.

## Constraints

The theme applies to GTK 3 and fresh namespaced Thunar sessions. Already-running Thunar and GTK 4 utilities require separate handling and truthful fallback.

## Acceptance

The compositor border no longer dominates the client; tree/list density stays useful; focus, selection, destructive file dialogs, and touch density remain native and clear.
