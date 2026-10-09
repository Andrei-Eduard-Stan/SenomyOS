// SPDX-License-Identifier: BSD-3-Clause
// Client geometry only; tiling membership and the layout's target boxes stay intact.
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/LayerState.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <sstream>
#include <iomanip>
#include <hyprland/src/output/Monitor.hpp>
#include <array>
namespace SenomyAvoidance {
struct Saved { PHLWINDOWREF window; CBox base, applied; };
static std::vector<Saved> saved;
static pid_t owner=0;
static bool enabled=false;
static CBox local;
static bool equal(const CBox& a,const CBox& b) {return a.x==b.x && a.y==b.y && a.w==b.w && a.h==b.h;}
static void set(PHLWINDOW w,const CBox& b) {
    g_pHyprRenderer->damageWindow(w);w->setBox(b);w->finishAnimation();w->sendWindowSize();w->updateWindowDecos();g_pHyprRenderer->damageWindow(w);
}
static CBox goal(PHLWINDOW w) {return w->geometricBox(Desktop::View::IGeometric::GEOMETRIC_GOAL);}
static void restore() {
    for (auto& s:saved) if (auto w=s.window.lock();w && validMapped(w) && equal(goal(w),s.applied)) set(w,s.base);
    saved.clear();
}
static PHLLS layer() {
    for (const auto& l:Desktop::layerState()->layers()) {
        if (l && l->m_mapped && l->m_namespace=="wvkbd" && l->getPID()==owner) return l;
    }
    return nullptr;
}
static CBox fit(CBox b,CBox k,double minW,double minH) {
    if (b.x+b.w<=k.x || k.x+k.w<=b.x || b.y+b.h<=k.y || k.y+k.h<=b.y) return b;
    const double gap=8;
    std::array<CBox,4> choices={CBox{b.x,b.y,b.w,k.y-gap-b.y},
        CBox{b.x,k.y+k.h+gap,b.w,b.y+b.h-k.y-k.h-gap},
        CBox{b.x,b.y,k.x-gap-b.x,b.h},CBox{k.x+k.w+gap,b.y,b.x+b.w-k.x-k.w-gap,b.h}};
    CBox best{};double area=0;
    for (auto c:choices) if(c.w>=minW && c.h>=minH && c.w*c.h>area) {best=c;area=c.w*c.h;}
    return area>0?best:b; // A client that cannot fit keeps a usable size; no fabricated room.
}
static void tick() {
    const auto l=enabled?layer():nullptr;
    if (!l || !l->m_monitor) {restore();return;}
    const CBox k{l->m_geometry.x+local.x,l->m_geometry.y+local.y,local.w,local.h};
    std::erase_if(saved,[](const Saved& s){return s.window.expired();});
    for (const auto& w:Desktop::windowState()->windows()) {
        auto t=w->layoutTarget();
        auto it=std::find_if(saved.begin(),saved.end(),[&](const Saved& s){return s.window.lock()==w;});
        if (!validMapped(w) || !t || t->floating() || Fullscreen::controller()->isFullscreen(w) || w->m_monitor!=l->m_monitor) {
            if(it!=saved.end()) {if(validMapped(w)&&equal(goal(w),it->applied))set(w,it->base);saved.erase(it);}continue;
        }
        const auto current=goal(w);
        if(it==saved.end()) {saved.push_back({w,current,current});it=std::prev(saved.end());}
        else if(!equal(current,it->applied)) it->base=current; // User/compositor layout changes supersede our snapshot.
        const auto minimum=t->minSize().value_or(Vector2D{160,100});
        const auto next=fit(it->base,k,std::max(160.,minimum.x),std::max(100.,minimum.y));
        if(!equal(current,next))set(w,next);
        it->applied=next;
    }
}
static void init(HANDLE h) {
    if(!HyprlandAPI::registerHyprCtlCommand(h,{"senomy-osk-state",true,[](eHyprCtlOutputFormat,std::string){return std::string("{\"ok\":true,\"protocol\":1}");}})) throw std::runtime_error("Cannot register OSK state");
    if(!HyprlandAPI::registerHyprCtlCommand(h,{"senomy-osk-geometry",false,[](eHyprCtlOutputFormat,std::string arg){
        if(arg.size()>200)return std::string("{\"ok\":false}");
        std::istringstream in(arg);std::string command,extra;long pid,x,y,w,h,mode;
        if(!(in>>command>>pid>>x>>y>>w>>h>>mode) || (in>>extra) || command!="senomy-osk-geometry" || pid<2 || pid>4194304 || x<0 || y<0 || w<0 || h<0 || x+w>16384 || y+h>16384 || mode<0 || mode>1) return std::string("{\"ok\":false}");
        if(owner && owner!=pid) {if(layer())return std::string("{\"ok\":false}");restore();}
        owner=pid;local={double(x),double(y),double(w),double(h)};enabled=mode && w>0 && h>0;
        tick();auto l=layer();
        if(!l || !l->m_monitor)return std::string("{\"ok\":true,\"available\":false}");
        std::ostringstream out;out<<"{\"ok\":true,\"available\":true,\"screen\":"<<std::quoted(l->m_monitor->m_name)<<",\"x\":"<<l->m_geometry.x-l->m_monitor->m_position.x+local.x<<",\"y\":"<<l->m_geometry.y-l->m_monitor->m_position.y+local.y<<",\"width\":"<<local.w<<",\"height\":"<<local.h<<",\"reserved\":"<<(enabled?"true":"false")<<"}";return out.str();
    }})) throw std::runtime_error("Cannot register OSK geometry");
}
static void exit() {enabled=false;restore();owner=0;}
}
