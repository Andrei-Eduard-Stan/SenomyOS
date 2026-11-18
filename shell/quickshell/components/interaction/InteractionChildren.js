.pragma library

// Only opted-in shell controls are touched. No application windows, providers,
// action cancellation or arbitrary close() methods are traversed.
function dismiss(item) {
    if (!item) return;
    if (typeof item.closeInteractionChildren === "function") item.closeInteractionChildren();
    for (const child of item.children || []) dismiss(child);
}
