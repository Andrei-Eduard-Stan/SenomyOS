#include "senomy-workspace.h"
#include <thunarx/thunarx.h>

typedef struct {
    GtkWindow *window;
    GtkWidget *grid, *body, *toolbar, *header, *title, *path, *panel, *dock, *dock_content, *popover, *compact, *toggle, *commands;
    GtkWidget *name, *kind, *image, *fields[5], *contents;
    GtkWidget *selection_actions[3];
    GCancellable *cancel;
    GWeakRef active_view;
    ThunarxFileInfo *current;
    guint selected;
    guint generation;
    gboolean wide, wanted, syncing, destroyed, mode_queued, target_wide;
} Workspace;

typedef struct { GWeakRef window; guint generation; GFileEnumerator *enumerator; } Preview;

static Workspace *workspace(GtkWidget *w) {
    GtkWidget *top=GTK_IS_WINDOW(w)?w:gtk_widget_get_toplevel(w);
    return g_object_get_data(G_OBJECT(top),"senomy-workspace");
}
static void add_class(GtkWidget *w,const char *name){gtk_style_context_add_class(gtk_widget_get_style_context(w),name);}
static GtkWidget *label(const char *text,const char *style) {
    GtkWidget *w=gtk_label_new(text);gtk_label_set_xalign(GTK_LABEL(w),0);
    gtk_label_set_ellipsize(GTK_LABEL(w),PANGO_ELLIPSIZE_END);
    if(style&&g_str_has_prefix(style,"inspector-"))gtk_label_set_max_width_chars(GTK_LABEL(w),22);
    if(style) add_class(w,style);
    if(style&&(g_str_has_prefix(style,"workspace-")||g_strcmp0(style,"senomy-files-title")==0)){gtk_widget_set_halign(w,GTK_ALIGN_START);gtk_label_set_max_width_chars(GTK_LABEL(w),70);}
    return w;
}
static void set_text(GtkWidget *w,const char *value){gtk_label_set_text(GTK_LABEL(w),value?value:"Unavailable");}
static void preview_free(Preview *p){g_clear_object(&p->enumerator);g_weak_ref_clear(&p->window);g_free(p);}
static Workspace *preview_workspace(Preview *p,GObject **owner){
    *owner=g_weak_ref_get(&p->window);if(!*owner)return NULL;
    Workspace *s=g_object_get_data(*owner,"senomy-workspace");
    return s&&!s->destroyed&&s->generation==p->generation?s:NULL;
}
static void listed(GObject *object,GAsyncResult *result,gpointer data){
    Preview *p=data;GError *error=NULL;
    GList *items=g_file_enumerator_next_files_finish(G_FILE_ENUMERATOR(object),result,&error);
    GObject *owner=NULL;Workspace *s=preview_workspace(p,&owner);
    if(s){
        GList *children=gtk_container_get_children(GTK_CONTAINER(s->contents));
        for(GList *i=children;i;i=i->next) gtk_widget_destroy(i->data);
        g_list_free(children);
        if(error)gtk_box_pack_start(GTK_BOX(s->contents),label("Contents unavailable", "inspector-muted"),FALSE,FALSE,0);
        else if(!items)gtk_box_pack_start(GTK_BOX(s->contents),label("Empty directory", "inspector-muted"),FALSE,FALSE,0);
        int n=0;
        for(GList *i=items;i&&n<8;i=i->next,n++){
            GFileInfo *info=i->data;GtkWidget *row=gtk_box_new(GTK_ORIENTATION_HORIZONTAL,9);
            GtkWidget *icon=gtk_image_new_from_gicon(g_file_info_get_icon(info),GTK_ICON_SIZE_MENU);
            GtkWidget *text=label(g_file_info_get_display_name(info),"inspector-child");
            gtk_widget_set_tooltip_text(text,g_file_info_get_display_name(info));
            gtk_box_pack_start(GTK_BOX(row),icon,FALSE,FALSE,0);gtk_box_pack_start(GTK_BOX(row),text,TRUE,TRUE,0);
            gtk_box_pack_start(GTK_BOX(s->contents),row,FALSE,FALSE,0);
        }
        if(g_list_length(items)>8)gtk_box_pack_start(GTK_BOX(s->contents),label("More items…", "inspector-muted"),FALSE,FALSE,0);
        gtk_widget_show_all(s->contents);
    }
    g_clear_object(&owner);g_list_free_full(items,g_object_unref);g_clear_error(&error);preview_free(p);
}
static void enumerated(GObject *object,GAsyncResult *result,gpointer data){
    Preview *p=data;GError *error=NULL;p->enumerator=g_file_enumerate_children_finish(G_FILE(object),result,&error);
    GObject *owner=NULL;Workspace *s=preview_workspace(p,&owner);
    if(!s||!p->enumerator){
        if(s&&!g_error_matches(error,G_IO_ERROR,G_IO_ERROR_CANCELLED)){
            GList *children=gtk_container_get_children(GTK_CONTAINER(s->contents));for(GList *i=children;i;i=i->next) gtk_widget_destroy(i->data);
        g_list_free(children);
            gtk_box_pack_start(GTK_BOX(s->contents),label("Contents unavailable","inspector-muted"),FALSE,FALSE,0);gtk_widget_show_all(s->contents);
        }
        g_clear_object(&owner);g_clear_error(&error);preview_free(p);return;
    }
    g_file_enumerator_next_files_async(p->enumerator,9,G_PRIORITY_DEFAULT,s->cancel,listed,p);
    g_clear_object(&owner);g_clear_error(&error);
}
static void metadata_ready(GObject *object,GAsyncResult *result,gpointer data){
    Preview *p=data;GError *error=NULL;GFileInfo *info=g_file_query_info_finish(G_FILE(object),result,&error);
    GObject *owner=NULL;Workspace *s=preview_workspace(p,&owner);
    if(s&&info){const char *user=g_file_info_get_attribute_string(info,G_FILE_ATTRIBUTE_OWNER_USER);const char *group=g_file_info_get_attribute_string(info,G_FILE_ATTRIBUTE_OWNER_GROUP);if(user){char *text=g_strjoin(" · ",user,group,NULL);set_text(s->fields[4],text);g_free(text);}}
    g_clear_object(&info);g_clear_object(&owner);g_clear_error(&error);preview_free(p);
}
static void clear_contents(Workspace *s,const char *text){
    if(s->cancel) g_cancellable_cancel(s->cancel);
    g_clear_object(&s->cancel);s->generation++;
    GList *children=gtk_container_get_children(GTK_CONTAINER(s->contents));for(GList *i=children;i;i=i->next) gtk_widget_destroy(i->data);
        g_list_free(children);
    gtk_box_pack_start(GTK_BOX(s->contents),label(text,"inspector-muted"),FALSE,FALSE,0);gtk_widget_show_all(s->contents);
}
static void show_object(Workspace *s,ThunarxFileInfo *file,guint selected){
    clear_contents(s,"No directory preview");
    g_set_object(&s->current,file);s->selected=selected;
    for(int i=0;i<3;i++)gtk_widget_set_sensitive(s->selection_actions[i],selected>0&&g_object_get_data(G_OBJECT(s->selection_actions[i]),"native-available"));
    for(int i=0;i<5;i++)set_text(s->fields[i],"—");
    if(!file){set_text(s->name,"Select an object");set_text(s->kind,"INSPECTOR");return;}
    GFileInfo *info=thunarx_file_info_get_file_info(file);GFile *location=thunarx_file_info_get_location(file);
    char *name=thunarx_file_info_get_name(file);set_text(s->name,name);g_free(name);
    if(location){char *path=g_file_get_parse_name(location);set_text(s->fields[0],path);gtk_widget_set_tooltip_text(s->fields[0],path);g_free(path);}
    if(info){
        GIcon *icon=g_file_info_has_attribute(info,G_FILE_ATTRIBUTE_STANDARD_ICON)?g_file_info_get_icon(info):NULL;
        if(icon)gtk_image_set_from_gicon(GTK_IMAGE(s->image),icon,GTK_ICON_SIZE_DIALOG);
        else gtk_image_set_from_icon_name(GTK_IMAGE(s->image),g_file_info_get_file_type(info)==G_FILE_TYPE_DIRECTORY?"folder":"text-x-generic",GTK_ICON_SIZE_DIALOG);
        gtk_image_set_pixel_size(GTK_IMAGE(s->image),68);
        gboolean directory=g_file_info_get_file_type(info)==G_FILE_TYPE_DIRECTORY;
        set_text(s->kind,directory?"DIRECTORY":"FILE");
        char *size=directory?g_strdup("— (directory)"):g_format_size(g_file_info_get_size(info));set_text(s->fields[1],size);g_free(size);
        GDateTime *date=g_file_info_get_modification_date_time(info);
        if(date){char *formatted=g_date_time_format(date,"%d %b %Y, %H:%M");set_text(s->fields[2],formatted);g_free(formatted);g_date_time_unref(date);}
        if(g_file_info_has_attribute(info,G_FILE_ATTRIBUTE_UNIX_MODE)){char *mode=g_strdup_printf("%04o",g_file_info_get_attribute_uint32(info,G_FILE_ATTRIBUTE_UNIX_MODE)&07777);set_text(s->fields[3],mode);g_free(mode);}
        const char *user=g_file_info_get_attribute_string(info,G_FILE_ATTRIBUTE_OWNER_USER);const char *group=g_file_info_get_attribute_string(info,G_FILE_ATTRIBUTE_OWNER_GROUP);
        if(user){char *owner=g_strjoin(" · ",user,group,NULL);set_text(s->fields[4],owner);g_free(owner);}
        if(directory&&location&&g_file_is_native(location)&&gtk_widget_get_mapped(s->panel)){
            clear_contents(s,"Loading contents…");s->cancel=g_cancellable_new();Preview *p=g_new0(Preview,1);g_weak_ref_init(&p->window,G_OBJECT(s->window));p->generation=s->generation;
            g_file_enumerate_children_async(location,"standard::name,standard::display-name,standard::type,standard::icon",G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,G_PRIORITY_DEFAULT,s->cancel,enumerated,p);
        }else if(directory)clear_contents(s,g_file_is_native(location)?"Open Inspector to preview contents":"Preview unavailable for remote locations");
        g_object_unref(info);
    }
    if(location&&g_file_is_native(location)&&gtk_widget_get_mapped(s->panel)){
        if(!s->cancel)s->cancel=g_cancellable_new();
        Preview *p=g_new0(Preview,1);g_weak_ref_init(&p->window,G_OBJECT(s->window));p->generation=s->generation;
        g_file_query_info_async(location,"owner::user,owner::group",G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,G_PRIORITY_DEFAULT,s->cancel,metadata_ready,p);
    }
    g_clear_object(&location);
}
static void selected_changed(GObject *view,GParamSpec *spec,GtkWindow *window){
    Workspace *s=workspace(GTK_WIDGET(window));if(!s||s->destroyed||!gtk_widget_get_mapped(GTK_WIDGET(view)))return;
    g_weak_ref_set(&s->active_view,view);
    GParamSpec *property=g_object_class_find_property(G_OBJECT_GET_CLASS(view),"selected-files");if(!property||!G_TYPE_IS_BOXED(property->value_type))return;
    GValue value=G_VALUE_INIT;g_value_init(&value,property->value_type);g_object_get_property(view,"selected-files",&value);
    GList *files=g_value_get_boxed(&value);guint count=g_list_length(files);
    if(count==1&&THUNARX_IS_FILE_INFO(files->data))show_object(s,files->data,1);
    else if(count>1){show_object(s,NULL,count);char *text=g_strdup_printf("%u objects selected",count);set_text(s->name,text);set_text(s->kind,"MULTIPLE SELECTION");g_free(text);}
    else {GObject *directory=NULL;g_object_get(window,"current-directory",&directory,NULL);show_object(s,THUNARX_IS_FILE_INFO(directory)?THUNARX_FILE_INFO(directory):NULL,0);g_clear_object(&directory);}
    g_value_unset(&value);
}
static void view_mapped(GtkWidget *view,GtkWindow *window){selected_changed(G_OBJECT(view),NULL,window);}
void senomy_workspace_observe(GtkWidget *widget){
    GtkWidget *view=widget;
    while(view&&!gtk_style_context_has_class(gtk_widget_get_style_context(view),"standard-view"))view=gtk_widget_get_parent(view);
    if(!view||!workspace(widget)||g_object_get_data(G_OBJECT(view),"senomy-inspector-observed"))return;
    GtkWidget *top=gtk_widget_get_toplevel(widget);g_object_set_data(G_OBJECT(view),"senomy-inspector-observed",GINT_TO_POINTER(1));
    g_signal_connect_object(view,"notify::selected-files",G_CALLBACK(selected_changed),top,0);
    g_signal_connect_object(view,"map",G_CALLBACK(view_mapped),top,G_CONNECT_AFTER);
    selected_changed(G_OBJECT(view),NULL,GTK_WINDOW(top));
}
static void directory_changed(GtkWindow *window,GParamSpec *spec,Workspace *s){
    GObject *object=NULL;g_object_get(window,"current-directory",&object,NULL);
    const char *native=gtk_window_get_title(window);char *folder=g_strdup(native?native:"Files");if(g_str_has_suffix(folder," - Thunar"))folder[strlen(folder)-9]=0;
    char *upper=g_utf8_strup(folder,-1);char *title=g_strconcat("FILES / ",upper,NULL);set_text(s->title,title);g_free(title);g_free(upper);g_free(folder);
    if(THUNARX_IS_FILE_INFO(object)){
        GFile *file=thunarx_file_info_get_location(THUNARX_FILE_INFO(object));if(file){char *path=g_file_get_parse_name(file);set_text(s->path,path);gtk_widget_set_tooltip_text(s->path,path);g_free(path);g_object_unref(file);}
        show_object(s,THUNARX_FILE_INFO(object),0);
    }
    g_clear_object(&object);
    GObject *active=g_weak_ref_get(&s->active_view);if(active&&gtk_widget_get_mapped(GTK_WIDGET(active)))selected_changed(active,NULL,window);g_clear_object(&active);
}
static void action_clicked(GtkButton *button,GtkWindow *window){
    const char *path=g_object_get_data(G_OBJECT(button),"native-action");GtkAccelKey key;
    if(path&&gtk_accel_map_lookup_entry(path,&key)&&key.accel_key)gtk_accel_groups_activate(G_OBJECT(window),key.accel_key,key.accel_mods);
}
static GtkWidget *native_action(Workspace *s,const char *icon,const char *name,const char *path){
    GtkWidget *button=gtk_button_new_from_icon_name(icon,GTK_ICON_SIZE_MENU);gtk_widget_set_tooltip_text(button,name);atk_object_set_name(gtk_widget_get_accessible(button),name);g_object_set_data_full(G_OBJECT(button),"native-action",g_strdup(path),g_free);
    GtkAccelKey key;gboolean available=gtk_accel_map_lookup_entry(path,&key)&&key.accel_key;gtk_widget_set_sensitive(button,available);g_object_set_data(G_OBJECT(button),"native-available",GINT_TO_POINTER(available));
    if(!available)gtk_widget_set_tooltip_text(button,"Use the native menu for this action");
    g_signal_connect_object(button,"clicked",G_CALLBACK(action_clicked),s->window,0);return button;
}
static void closed(GtkPopover *popover,Workspace *s){if(!s->destroyed&&!s->syncing){s->syncing=TRUE;gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(s->toggle),FALSE);s->syncing=FALSE;}}
static void apply_mode(Workspace *s,gboolean wide);
static void toggled(GtkToggleButton *button,Workspace *s){
    if(s->syncing)return;
    gboolean active=gtk_toggle_button_get_active(button);
    if(s->wide){s->wanted=active;apply_mode(s,TRUE);}
    else if(active)gtk_popover_popup(GTK_POPOVER(s->popover));else gtk_popover_popdown(GTK_POPOVER(s->popover));
}
static void apply_mode(Workspace *s,gboolean wide){
    s->syncing=TRUE;
    if(s->wide!=wide){
        s->wide=wide;gtk_popover_popdown(GTK_POPOVER(s->popover));g_object_ref(s->panel);
        GtkWidget *parent=gtk_widget_get_parent(s->panel);if(parent)gtk_container_remove(GTK_CONTAINER(parent),s->panel);
        gtk_container_add(GTK_CONTAINER(wide?s->dock_content:s->compact),s->panel);
        if(wide)gtk_box_set_child_packing(GTK_BOX(s->dock_content),s->panel,TRUE,TRUE,0,GTK_PACK_START);
        g_object_unref(s->panel);gtk_widget_show_all(s->panel);
    }
    gtk_widget_set_visible(s->dock,wide&&s->wanted);gtk_widget_set_visible(s->commands,wide);
    if(s->body)gtk_container_child_set(GTK_CONTAINER(s->grid),s->body,"width",wide&&s->wanted?1:2,NULL);
    if(s->toolbar)gtk_container_child_set(GTK_CONTAINER(s->grid),s->toolbar,"width",wide?1:2,NULL);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(s->toggle),wide&&s->wanted);s->syncing=FALSE;
    gtk_widget_queue_resize(s->grid);
}
static gboolean apply_mode_idle(gpointer data){
    GtkWidget *window=data;Workspace *s=workspace(window);
    if(s){s->mode_queued=FALSE;if(!s->destroyed)apply_mode(s,s->target_wide);}
    return G_SOURCE_REMOVE;
}
static void allocated(GtkWidget *grid,GtkAllocation *allocation,Workspace *s){
    s->target_wide=allocation->width>=1120;
    if(s->wide==s->target_wide||s->mode_queued)return;
    s->mode_queued=TRUE;
    /* Never mutate GtkGrid child topology during its allocation; queued work
     * runs before GTK's next resize pass and does not request window geometry. */
    g_idle_add_full(G_PRIORITY_HIGH_IDLE,apply_mode_idle,g_object_ref(s->window),g_object_unref);
}
static void destroyed(GtkWidget *window,Workspace *s){s->destroyed=TRUE;if(s->cancel)g_cancellable_cancel(s->cancel);gtk_widget_destroy(s->popover);}
static void workspace_free(gpointer data){Workspace *s=data;g_clear_object(&s->cancel);g_clear_object(&s->current);g_weak_ref_clear(&s->active_view);g_clear_object(&s->popover);g_free(s);}
static void panel_unmapped(GtkWidget *panel,Workspace *s){if(s->cancel)g_cancellable_cancel(s->cancel);s->generation++;}
static void panel_mapped(GtkWidget *panel,Workspace *s){if(s->current)show_object(s,s->current,s->selected);}
static void window_action(GtkButton *button,GtkWindow *window){
    int action=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button),"window-action"));
    if(action==1)gtk_window_iconify(window);
    else if(action==2){if(gtk_window_is_maximized(window))gtk_window_unmaximize(window);else gtk_window_maximize(window);}
    else gtk_window_close(window);
}
static gboolean drag_header(GtkWidget *widget,GdkEventButton *event,GtkWindow *window){
    if(event->button!=1)return FALSE;
    if(event->type==GDK_2BUTTON_PRESS){if(gtk_window_is_maximized(window))gtk_window_unmaximize(window);else gtk_window_maximize(window);}
    else gtk_window_begin_move_drag(window,event->button,event->x_root,event->y_root,event->time);
    return TRUE;
}
static gboolean resize_edge(GtkWidget *widget,GdkEventButton *event,gpointer unused){
    if(event->button!=1||event->type!=GDK_BUTTON_PRESS||event->window!=gtk_widget_get_window(widget))return FALSE;
    int w=gtk_widget_get_allocated_width(widget),h=gtk_widget_get_allocated_height(widget);gboolean l=event->x<8,r=event->x>w-8,t=event->y<8,b=event->y>h-8;
    if(!(l||r||t||b))return FALSE;
    GdkWindowEdge edge=t?(l?GDK_WINDOW_EDGE_NORTH_WEST:r?GDK_WINDOW_EDGE_NORTH_EAST:GDK_WINDOW_EDGE_NORTH):b?(l?GDK_WINDOW_EDGE_SOUTH_WEST:r?GDK_WINDOW_EDGE_SOUTH_EAST:GDK_WINDOW_EDGE_SOUTH):l?GDK_WINDOW_EDGE_WEST:GDK_WINDOW_EDGE_EAST;
    gtk_window_begin_resize_drag(GTK_WINDOW(widget),edge,event->button,event->x_root,event->y_root,event->time);return TRUE;
}
void senomy_workspace_compose(GtkWindow *window,GtkGrid *grid,GCallback places_callback){
    gtk_window_set_decorated(window,FALSE);
    Workspace *s=g_new0(Workspace,1);s->window=window;s->grid=GTK_WIDGET(grid);s->wanted=TRUE;g_weak_ref_init(&s->active_view,NULL);g_object_set_data_full(G_OBJECT(window),"senomy-workspace",s,workspace_free);
    s->header=gtk_box_new(GTK_ORIENTATION_VERTICAL,5);add_class(s->header,"senomy-files-heading");
    GtkWidget *strap=gtk_box_new(GTK_ORIENTATION_HORIZONTAL,6);
    GtkWidget *brand=label("SENOMYOS  /  ////   SYSTEM FILE MANAGER","workspace-brand");gtk_box_pack_start(GTK_BOX(strap),brand,TRUE,TRUE,0);
    const char *window_icons[]={"window-minimize-symbolic","window-maximize-symbolic","window-close-symbolic"};
    const char *window_names[]={"Minimize","Maximize or restore","Close file manager"};
    for(int i=0;i<3;i++){GtkWidget *button=gtk_button_new_from_icon_name(window_icons[i],GTK_ICON_SIZE_MENU);add_class(button,"workspace-window-action");gtk_widget_set_tooltip_text(button,window_names[i]);atk_object_set_name(gtk_widget_get_accessible(button),window_names[i]);g_object_set_data(G_OBJECT(button),"window-action",GINT_TO_POINTER(i+1));g_signal_connect_object(button,"clicked",G_CALLBACK(window_action),window,0);gtk_box_pack_start(GTK_BOX(strap),button,FALSE,FALSE,0);}
    gtk_box_pack_start(GTK_BOX(s->header),strap,FALSE,FALSE,0);
    GtkWidget *row=gtk_box_new(GTK_ORIENTATION_HORIZONTAL,12);s->title=label("FILES","senomy-files-title");gtk_box_pack_start(GTK_BOX(row),s->title,TRUE,TRUE,0);
    GtkWidget *places=gtk_button_new_with_label("Places");gtk_widget_set_name(places,"senomy-places-toggle");add_class(places,"senomy-places-toggle");gtk_widget_set_tooltip_text(places,"Show or hide native Places");GtkAccelKey places_key;gboolean places_bound=gtk_accel_map_lookup_entry("<Actions>/ThunarWindow/toggle-side-pane",&places_key)&&places_key.accel_key;gtk_widget_set_sensitive(places,places_bound);if(!places_bound)gtk_widget_set_tooltip_text(places,"Use Menu → View → Side Pane");g_signal_connect_object(places,"clicked",places_callback,window,0);gtk_box_pack_end(GTK_BOX(row),places,FALSE,FALSE,0);
    s->toggle=gtk_toggle_button_new_with_label("Inspector");gtk_widget_set_name(s->toggle,"senomy-inspector-toggle");gtk_box_pack_end(GTK_BOX(row),s->toggle,FALSE,FALSE,0);gtk_box_pack_start(GTK_BOX(s->header),row,FALSE,FALSE,0);
    s->path=label("Directory","workspace-path");gtk_box_pack_start(GTK_BOX(s->header),s->path,FALSE,FALSE,0);
    GtkWidget *drag=gtk_event_box_new();gtk_event_box_set_visible_window(GTK_EVENT_BOX(drag),FALSE);gtk_container_add(GTK_CONTAINER(drag),s->header);gtk_widget_add_events(drag,GDK_BUTTON_PRESS_MASK);g_signal_connect_object(drag,"button-press-event",G_CALLBACK(drag_header),window,0);
    gtk_grid_insert_row(grid,0);gtk_grid_attach(grid,drag,0,0,2,1);
    GList *children=gtk_container_get_children(GTK_CONTAINER(grid));int body_row=5,toolbar_row=2;
    for(GList *i=children;i;i=i->next){int top=0;gtk_container_child_get(GTK_CONTAINER(grid),i->data,"top-attach",&top,NULL);if(GTK_IS_PANED(i->data)){body_row=top;s->body=i->data;}if(GTK_IS_TOOLBAR(i->data)){toolbar_row=top;s->toolbar=i->data;}}
    g_list_free(children);
    s->dock=gtk_box_new(GTK_ORIENTATION_VERTICAL,0);add_class(s->dock,"inspector-dock");gtk_widget_set_hexpand(s->dock,FALSE);gtk_widget_set_vexpand(s->dock,TRUE);gtk_grid_attach(grid,s->dock,1,body_row,1,1);
    GtkWidget *dock_scroll=gtk_scrolled_window_new(NULL,NULL);gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(dock_scroll),0);gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(dock_scroll),GTK_POLICY_NEVER,GTK_POLICY_AUTOMATIC);gtk_widget_set_vexpand(dock_scroll,TRUE);gtk_box_pack_start(GTK_BOX(s->dock),dock_scroll,TRUE,TRUE,0);s->dock_content=gtk_box_new(GTK_ORIENTATION_VERTICAL,0);gtk_widget_set_vexpand(s->dock_content,TRUE);gtk_container_add(GTK_CONTAINER(dock_scroll),s->dock_content);gtk_widget_show_all(dock_scroll);
    s->panel=gtk_box_new(GTK_ORIENTATION_VERTICAL,18);g_signal_connect(s->panel,"map",G_CALLBACK(panel_mapped),s);g_signal_connect(s->panel,"unmap",G_CALLBACK(panel_unmapped),s);add_class(s->panel,"object-inspector");gtk_widget_set_name(s->panel,"senomy-object-inspector");
    GtkWidget *band=label("////  OBJECT / INSPECTOR","inspector-band");gtk_box_pack_start(GTK_BOX(s->panel),band,FALSE,FALSE,0);
    s->image=gtk_image_new_from_icon_name("folder",GTK_ICON_SIZE_DIALOG);
        gtk_image_set_pixel_size(GTK_IMAGE(s->image),68);gtk_widget_set_halign(s->image,GTK_ALIGN_START);gtk_box_pack_start(GTK_BOX(s->panel),s->image,FALSE,FALSE,0);
    s->name=label("Select an object","inspector-name");gtk_widget_set_name(s->name,"senomy-inspector-name");gtk_box_pack_start(GTK_BOX(s->panel),s->name,FALSE,FALSE,0);s->kind=label("DIRECTORY","inspector-kind");gtk_box_pack_start(GTK_BOX(s->panel),s->kind,FALSE,FALSE,0);
    GtkWidget *fields=gtk_grid_new();gtk_grid_set_column_spacing(GTK_GRID(fields),14);gtk_grid_set_row_spacing(GTK_GRID(fields),14);const char *names[]={"PATH","SIZE","MODIFIED","PERMISSIONS","OWNER"};
    for(int i=0;i<5;i++){GtkWidget *key=label(names[i],"inspector-key");s->fields[i]=label("—","inspector-value");gtk_widget_set_hexpand(s->fields[i],TRUE);gtk_grid_attach(GTK_GRID(fields),key,0,i,1,1);gtk_grid_attach(GTK_GRID(fields),s->fields[i],1,i,1,1);}gtk_box_pack_start(GTK_BOX(s->panel),fields,FALSE,FALSE,0);
    gtk_box_pack_start(GTK_BOX(s->panel),gtk_separator_new(GTK_ORIENTATION_HORIZONTAL),FALSE,FALSE,0);gtk_box_pack_start(GTK_BOX(s->panel),label("CONTENTS / PREVIEW","inspector-key"),FALSE,FALSE,0);
    s->contents=gtk_box_new(GTK_ORIENTATION_VERTICAL,10);gtk_box_pack_start(GTK_BOX(s->panel),s->contents,FALSE,FALSE,0);
    s->popover=gtk_popover_new(s->toggle);g_object_ref_sink(s->popover);gtk_popover_set_position(GTK_POPOVER(s->popover),GTK_POS_BOTTOM);
    GtkWidget *scroll=gtk_scrolled_window_new(NULL,NULL);gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll),GTK_POLICY_NEVER,GTK_POLICY_AUTOMATIC);gtk_scrolled_window_set_propagate_natural_height(GTK_SCROLLED_WINDOW(scroll),TRUE);gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(scroll),220);gtk_scrolled_window_set_max_content_height(GTK_SCROLLED_WINDOW(scroll),480);
    s->compact=gtk_box_new(GTK_ORIENTATION_VERTICAL,0);gtk_container_add(GTK_CONTAINER(s->popover),scroll);gtk_container_add(GTK_CONTAINER(scroll),s->compact);gtk_container_add(GTK_CONTAINER(s->compact),s->panel);gtk_widget_set_size_request(s->panel,288,-1);gtk_widget_show_all(scroll);g_signal_connect(s->popover,"closed",G_CALLBACK(closed),s);g_signal_connect(s->toggle,"toggled",G_CALLBACK(toggled),s);
    s->commands=gtk_box_new(GTK_ORIENTATION_HORIZONTAL,8);add_class(s->commands,"file-commands");const char *icons[]={"folder-new-symbolic","edit-cut-symbolic","edit-copy-symbolic","user-trash-symbolic"};const char *names2[]={"New folder","Cut","Copy","Move to Trash"};const char *paths[]={"<Actions>/ThunarStandardView/create-folder","<Actions>/ThunarActionManager/cut","<Actions>/ThunarActionManager/copy","<Actions>/ThunarActionManager/trash-delete"};
    for(int i=0;i<4;i++){GtkWidget *button=native_action(s,icons[i],names2[i],paths[i]);gtk_box_pack_start(GTK_BOX(s->commands),button,FALSE,FALSE,0);if(i)s->selection_actions[i-1]=button;}
    gtk_grid_attach(grid,s->commands,1,toolbar_row,1,1);
    gtk_widget_show_all(drag);gtk_widget_show_all(s->commands);gtk_widget_hide(s->commands);gtk_widget_hide(s->dock);
    gtk_widget_add_events(GTK_WIDGET(window),GDK_BUTTON_PRESS_MASK);g_signal_connect(window,"button-press-event",G_CALLBACK(resize_edge),NULL);
    g_signal_connect(grid,"size-allocate",G_CALLBACK(allocated),s);g_signal_connect(window,"destroy",G_CALLBACK(destroyed),s);g_signal_connect(window,"notify::current-directory",G_CALLBACK(directory_changed),s);g_signal_connect(window,"notify::title",G_CALLBACK(directory_changed),s);directory_changed(window,NULL,s);
    int initial_width=0,initial_height=0;gtk_window_get_default_size(window,&initial_width,&initial_height);apply_mode(s,initial_width>=1120);
}
