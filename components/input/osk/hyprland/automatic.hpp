// SPDX-License-Identifier: BSD-3-Clause
#pragma once
#include <hyprland/src/managers/SessionLockManager.hpp>
#include <aquamarine/input/Input.hpp>
#include <libinput.h>
#include <hyprland/src/protocols/TextInputV3.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <linux/input-event-codes.h>
namespace SenomyAutomatic {
static std::string previous;
static CTextInput* previousInput = nullptr;
static bool previousActive = false;
static uint64_t epoch = 0;
static CHyprSignalListener newInput;
struct InputWatch {WP<CTextInputV3> input;CHyprSignalListener enable,disable;};
static std::vector<InputWatch> inputs;
static void transition(WP<CTextInputV3> weak) {
    auto input=weak.lock();auto surface=Desktop::focusState()->surface();
    if (input && surface && input->client()==surface->client()) ++epoch;
}
static bool physical() {
    for (const auto& k : g_pInputManager->m_keyboards) {
        if (!k || !k->m_enabled || !k->m_allowed || k->isVirtual()) continue;
        auto aq = k->aq();
        auto device = aq ? aq->getLibinputHandle() : nullptr;
        // Remote/nested backends without key capabilities are conservative.
        if (!device) return true;
        const int a=libinput_device_keyboard_has_key(device,KEY_A);
        const int z=libinput_device_keyboard_has_key(device,KEY_Z);
        const int space=libinput_device_keyboard_has_key(device,KEY_SPACE);
        if (a<0 || z<0 || space<0 || (a && z && space)) return true;
    }
    return false;
}
static std::string state() {
    auto input = g_pInputManager->m_relay.getFocusedTextInput();
    const bool locked = g_pSessionLockManager->isSessionLocked();
    const bool focused = !locked && input && input->isEnabled();
    if (input!=previousInput || focused!=previousActive) {++epoch;previousInput=input;previousActive=focused;}
    return std::string("{\"ok\":true,\"protocol\":1,\"physicalKeyboard\":")+(physical()?"true":"false")
        +",\"textActive\":"+(focused?"true":"false")+",\"inputMethod\":"+(!g_pInputManager->m_relay.m_inputMethod.expired()?"true":"false")
        +",\"locked\":"+(locked?"true":"false")+",\"focusEpoch\":"+std::to_string(epoch)+"}";
}
static void tick() {
    std::erase_if(inputs,[](const auto& watch){return watch.input.expired();});
    auto next=state();
    if (next==previous) return;
    previous=next;
    g_pEventManager->postEvent({"senomy-osk-auto",next});
}
static void exit() {newInput.reset();inputs.clear();}
static void init(HANDLE handle) {
    newInput=PROTO::textInputV3->m_events.newTextInput.listen([](WP<CTextInputV3> weak) {
        auto input=weak.lock();if(!input)return;
        inputs.push_back({weak,input->m_events.enable.listen([weak]{transition(weak);}),input->m_events.disable.listen([weak]{transition(weak);})});
    });
    if (!HyprlandAPI::registerHyprCtlCommand(handle,{"senomy-osk-auto-state",true,[](eHyprCtlOutputFormat,std::string arg) {
        return arg=="senomy-osk-auto-state" ? state() : std::string("{\"ok\":false}");
    }})) throw std::runtime_error("Cannot register automatic OSK state");
}
}
