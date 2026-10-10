#define _GNU_SOURCE
#include <wayland-client.h>
#include "xdg.h"
#include "text.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
static struct wl_compositor *compositor;static struct wl_shm *shm;static struct wl_seat *seat;static struct xdg_wm_base *wm;static struct zwp_text_input_manager_v3 *manager;static struct zwp_text_input_v3 *text;static struct wl_surface *surface;static struct wl_buffer *buffer;static bool entered,editing;
static void change(void){fprintf(stderr,"edit=%d entered=%d\n",editing,entered);if(!entered)return;if(editing)zwp_text_input_v3_enable(text);else zwp_text_input_v3_disable(text);zwp_text_input_v3_commit(text);}
static void enter(void*d,struct zwp_text_input_v3*t,struct wl_surface*s){entered=true;fprintf(stderr,"entered\n");change();}
static void leave(void*d,struct zwp_text_input_v3*t,struct wl_surface*s){entered=false;}
static void pre(void*d,struct zwp_text_input_v3*t,const char*s,int32_t a,int32_t b){}
static void commit(void*d,struct zwp_text_input_v3*t,const char*s){}
static void del(void*d,struct zwp_text_input_v3*t,uint32_t a,uint32_t b){}
static void done(void*d,struct zwp_text_input_v3*t,uint32_t serial){}
static const struct zwp_text_input_v3_listener listener={enter,leave,pre,commit,del,done};
static void ping(void*d,struct xdg_wm_base*w,uint32_t serial){xdg_wm_base_pong(w,serial);}
static const struct xdg_wm_base_listener wml={ping};
static void global(void*d,struct wl_registry*r,uint32_t name,const char*iface,uint32_t version){
 if(!strcmp(iface,"wl_compositor"))compositor=wl_registry_bind(r,name,&wl_compositor_interface,4);
 if(!strcmp(iface,"wl_shm"))shm=wl_registry_bind(r,name,&wl_shm_interface,1);
 if(!strcmp(iface,"wl_seat"))seat=wl_registry_bind(r,name,&wl_seat_interface,1);
 if(!strcmp(iface,"xdg_wm_base"))wm=wl_registry_bind(r,name,&xdg_wm_base_interface,1);
 if(!strcmp(iface,"zwp_text_input_manager_v3"))manager=wl_registry_bind(r,name,&zwp_text_input_manager_v3_interface,1);
}
static void removed(void*d,struct wl_registry*r,uint32_t n){}
static const struct wl_registry_listener reg={global,removed};
static void configure(void*d,struct xdg_surface*x,uint32_t serial){xdg_surface_ack_configure(x,serial);wl_surface_attach(surface,buffer,0,0);wl_surface_damage(surface,0,0,600,300);wl_surface_commit(surface);}
static const struct xdg_surface_listener xsl={configure};
static void size(void*d,struct xdg_toplevel*t,int32_t w,int32_t h,struct wl_array*a){}
static void close_(void*d,struct xdg_toplevel*t){exit(0);}
static const struct xdg_toplevel_listener tl={size,close_};
static void km(void*d,struct wl_keyboard*k,uint32_t f,int32_t fd,uint32_t s){close(fd);}
static void ke(void*d,struct wl_keyboard*k,uint32_t s,struct wl_surface*w,struct wl_array*a){}
static void kl(void*d,struct wl_keyboard*k,uint32_t s,struct wl_surface*w){}
static void kk(void*d,struct wl_keyboard*k,uint32_t s,uint32_t t,uint32_t key,uint32_t state){}
static void mods(void*d,struct wl_keyboard*k,uint32_t s,uint32_t a,uint32_t b,uint32_t c,uint32_t g){}
static const struct wl_keyboard_listener klistener={km,ke,kl,kk,mods};
int main(void){
 if(!getenv("SENOMY_PRIVATE_OSK_TEST"))return 2;
 struct wl_display*d=wl_display_connect(NULL);if(!d)return 3;
 struct wl_registry*r=wl_display_get_registry(d);wl_registry_add_listener(r,&reg,NULL);wl_display_roundtrip(d);
 if(!compositor||!shm||!seat||!wm||!manager)return 4;
 struct wl_keyboard*k=wl_seat_get_keyboard(seat);wl_keyboard_add_listener(k,&klistener,NULL);
 xdg_wm_base_add_listener(wm,&wml,NULL);surface=wl_compositor_create_surface(compositor);
 int fd=memfd_create("senomy-test",MFD_CLOEXEC);ftruncate(fd,600*300*4);uint32_t*p=mmap(NULL,600*300*4,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
 for(int i=0;i<600*300;i++)p[i]=0xff202530;
 struct wl_shm_pool*pool=wl_shm_create_pool(shm,fd,600*300*4);buffer=wl_shm_pool_create_buffer(pool,0,600,300,600*4,WL_SHM_FORMAT_ARGB8888);wl_shm_pool_destroy(pool);close(fd);
 struct xdg_surface*x=xdg_wm_base_get_xdg_surface(wm,surface);xdg_surface_add_listener(x,&xsl,NULL);
 struct xdg_toplevel*t=xdg_surface_get_toplevel(x);xdg_toplevel_add_listener(t,&tl,NULL);xdg_toplevel_set_title(t,"senomy-protocol-text-field");xdg_toplevel_set_app_id(t,"senomy-private-test");
 text=zwp_text_input_manager_v3_get_text_input(manager,seat);zwp_text_input_v3_add_listener(text,&listener,NULL);
 wl_surface_commit(surface);wl_display_roundtrip(d);
 struct pollfd fds[2]={{wl_display_get_fd(d),POLLIN,0},{STDIN_FILENO,POLLIN,0}};
 while(1){wl_display_dispatch_pending(d);wl_display_flush(d);if(poll(fds,2,-1)<0)break;
  if(fds[0].revents&POLLIN)if(wl_display_dispatch(d)<0)break;
  if(fds[1].revents&POLLIN){char c;if(read(0,&c,1)!=1)break;if(c=='1'||c=='0'){editing=c=='1';change();}}
 }
 wl_display_disconnect(d);return 0;
}
