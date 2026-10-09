// SPDX-License-Identifier: BSD-3-Clause
// SenomyOS: share Caps Lock while wvkbd is connected. No key-event listener.
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <algorithm>
#include <stdexcept>

static HANDLE handle;
static CHyprSignalListener tick;
struct Watch { WP<IKeyboard> keyboard; CHyprSignalListener listener; };
static std::vector<Watch> watches;
static bool active = false, caps = false, updating = false;
static bool candidate(const SP<IKeyboard>& k) {
    return k && k->m_enabled && k->m_allowed && (!k->isVirtual() || k->m_deviceName.find("wvkbd") != std::string::npos);
}
static uint32_t mask(const SP<IKeyboard>& k) {
    if (!k || !k->m_xkbKeymap) return 0;
    auto index = xkb_keymap_mod_get_index(k->m_xkbKeymap, XKB_MOD_NAME_CAPS);
    return index == XKB_MOD_INVALID || index >= 32 ? 0 : 1u << index;
}
static bool locked(const SP<IKeyboard>& k) { return (k->m_modifiersState.locked & mask(k)) != 0; }
static void publish() { g_pEventManager->postEvent({"senomy-caps", active ? (caps ? "1" : "0") : "unavailable"}); }
static void apply() {
    updating = true;
    for (const auto& k : g_pInputManager->m_keyboards) {
        if (!candidate(k)) continue;
        const auto m = mask(k);
        const auto state = k->m_modifiersState;
        k->updateModifiers(state.depressed, state.latched, (state.locked & ~m) | (caps ? m : 0), state.group);
        k->updateLEDs();
    }
    updating = false;
}
static void reconcile() {
    std::erase_if(watches, [](const Watch& w) { return w.keyboard.expired(); });
    const bool present = std::ranges::any_of(g_pInputManager->m_keyboards, [](const auto& k) {
        return candidate(k) && k->isVirtual();
    });
    if (present && !active) {
        auto seed = g_pSeatManager->m_keyboard.lock();
        if (!candidate(seed) || seed->isVirtual()) {
            seed = nullptr;
            for (const auto& k : g_pInputManager->m_keyboards) if (candidate(k) && !k->isVirtual()) { seed=k; break; }
        }
        caps = seed ? locked(seed) : false;
        active = true;
        apply();publish();
    } else if (!present && active) { active = false;publish(); }
    for (const auto& k : g_pInputManager->m_keyboards) {
        if (!candidate(k) || std::ranges::any_of(watches, [&](const Watch& w) {return w.keyboard.lock()==k;})) continue;
        if (active) apply();
        WP<IKeyboard> weak=k;
        auto listener=k->m_keyboardEvents.modifiers.listen([weak] {
            auto source=weak.lock();
            if (updating || !active || !candidate(source)) return;
            const bool next=locked(source);
            if (next==caps) return;
            if (!source->isVirtual()) caps=next;
            apply();publish();
        });
        watches.push_back({weak,listener});
    }
}
APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE h) {
    handle=h;
    if (HyprlandAPI::getHyprlandVersion(handle).hash != GIT_COMMIT_HASH)
        throw std::runtime_error("Senomy Caps sync must be rebuilt for this exact Hyprland version");
    if (!HyprlandAPI::registerHyprCtlCommand(handle,{"senomy-caps-toggle",true,[](eHyprCtlOutputFormat,std::string arg) {
        reconcile();
        if (arg != "senomy-caps-toggle" || !active) return std::string("{\"ok\":false}");
        caps=!caps;apply();
        auto k=g_pSeatManager->m_keyboard.lock();
        if (candidate(k)) {const auto s=k->m_modifiersState;g_pSeatManager->sendKeyboardMods(g_pInputManager->getModsFromAllKBs(),s.latched,s.locked,s.group);}
        publish();return std::string("{\"ok\":true}");
    }})) throw std::runtime_error("Cannot register Caps sync action");
    if (!HyprlandAPI::registerHyprCtlCommand(handle,{"senomy-caps-state",true,[](eHyprCtlOutputFormat,std::string){
        reconcile();return std::string("{\"ok\":true,\"available\":")+(active?"true":"false")+",\"capsLock\":"+(caps?"true":"false")+"}";
    }})) throw std::runtime_error("Cannot register Caps sync state");
    tick=Event::bus()->m_events.tick.listen(reconcile);reconcile();
    return {"senomy-caps-sync","Session-scoped shared Caps Lock for wvkbd","SenomyOS","1"};
}
APICALL EXPORT void PLUGIN_EXIT() { tick.reset();watches.clear();active=false;publish(); }
