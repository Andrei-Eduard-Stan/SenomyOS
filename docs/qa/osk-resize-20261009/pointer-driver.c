#include "pointer.h"
#include <wayland-client.h>
#include <linux/input-event-codes.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *d,struct wl_registry *r,uint32_t name,const char *iface,uint32_t version) {
 if (!strcmp(iface,"zwlr_virtual_pointer_manager_v1")) manager=wl_registry_bind(r,name,&zwlr_virtual_pointer_manager_v1_interface,1);
}
static void removed(void*d,struct wl_registry*r,uint32_t n){}
static const struct wl_registry_listener listener={global,removed};
int main(int argc,char**argv){
 if(argc!=7 || !getenv("SENOMY_PRIVATE_POINTER_TEST")) return 2;
 struct wl_display*d=wl_display_connect(NULL);if(!d)return 3;
 struct wl_registry*r=wl_display_get_registry(d);wl_registry_add_listener(r,&listener,NULL);wl_display_roundtrip(d);if(!manager)return 4;
 struct zwlr_virtual_pointer_v1*p=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager,NULL);
 int w=atoi(argv[1]),h=atoi(argv[2]),x=atoi(argv[3]),y=atoi(argv[4]),endx=atoi(argv[5]),endy=atoi(argv[6]);
 zwlr_virtual_pointer_v1_motion_absolute(p,10,x,y,w,h);zwlr_virtual_pointer_v1_frame(p);wl_display_flush(d);usleep(150000);
 zwlr_virtual_pointer_v1_button(p,11,BTN_LEFT,WL_POINTER_BUTTON_STATE_PRESSED);zwlr_virtual_pointer_v1_frame(p);wl_display_flush(d);usleep(150000);
 for(int i=1;i<=12;i++) {zwlr_virtual_pointer_v1_motion(p,11+i,wl_fixed_from_double((endx-x)/12.0),wl_fixed_from_double((endy-y)/12.0));zwlr_virtual_pointer_v1_frame(p);wl_display_flush(d);usleep(70000);}
 zwlr_virtual_pointer_v1_button(p,30,BTN_LEFT,WL_POINTER_BUTTON_STATE_RELEASED);zwlr_virtual_pointer_v1_frame(p);wl_display_roundtrip(d);usleep(100000);
 zwlr_virtual_pointer_v1_destroy(p);wl_display_roundtrip(d);wl_display_disconnect(d);return 0;
}
