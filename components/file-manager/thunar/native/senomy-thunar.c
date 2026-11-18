/* Scoped GTK3 projection for native Thunar. No providers, polling or file actions. */
#include <gtk/gtk.h>
#include <gmodule.h>
#include "senomy-workspace.h"

static void style_columns(GtkTreeView *view);

/* Same material construction as the Island: clip, base, artwork, scrim.
 * Loaded once, drawn only for GTK damage; text and native input stay untouched. */
static GdkPixbuf *material;
static gboolean material_loaded;

static void load_material(void) {
    if (material_loaded) return;
    material_loaded = TRUE;
    const char *theme = g_getenv("GTK_THEME");
    char *base = g_strdup(theme && *theme ? theme : "SenomyOS");
    char *variant = strchr(base, ':');
    if (variant) *variant = 0;
    if (g_str_has_suffix(base, "-Touch")) base[strlen(base) - strlen("-Touch")] = 0;
    char *path = g_build_filename(g_get_user_data_dir(), "themes", base,
                                  "gtk-3.0", "assets", "chrome-sculpture-v1.png", NULL);
    GError *error = NULL;
    material = gdk_pixbuf_new_from_file_at_scale(path, 1672, 941, TRUE, &error);
    if (error) {
        g_warning("Senomy file material unavailable; keeping the dark surface: %s", error->message);
        g_error_free(error);
    }
    g_free(path); g_free(base);
}

static gboolean draw_material(GtkWidget *window, cairo_t *cr, gpointer unused) {
    GtkWidget *grid = GTK_IS_BIN(window) ? gtk_bin_get_child(GTK_BIN(window)) : NULL;
    if (!GTK_IS_GRID(grid)) return FALSE;
    GtkAllocation a;
    gtk_widget_get_allocation(grid, &a);
    if (a.width < 24 || a.height < 24) return FALSE;
    const double l = a.x, t = a.y, r = l + a.width, b = t + a.height, k = 12;
    GdkRGBA ground = { 0.0314, 0.0353, 0.0431, 1 };
    gtk_style_context_lookup_color(gtk_widget_get_style_context(window), "senomy_bg", &ground);
    cairo_save(cr);
    cairo_move_to(cr, l + k, t); cairo_line_to(cr, r - k, t);
    cairo_line_to(cr, r, t + k); cairo_line_to(cr, r, b - k);
    cairo_line_to(cr, r - k, b); cairo_line_to(cr, l + k, b);
    cairo_line_to(cr, l, b - k); cairo_line_to(cr, l, t + k);
    cairo_close_path(cr); cairo_clip(cr);
    cairo_set_source_rgba(cr, ground.red, ground.green, ground.blue, .96);
    cairo_paint(cr);
    if (material) {
        double iw = gdk_pixbuf_get_width(material), ih = gdk_pixbuf_get_height(material);
        double scale = MAX(a.width / iw, a.height / ih);
        cairo_save(cr);
        cairo_rectangle(cr,l,t,a.width,128);
        cairo_rectangle(cr,l,b-230,230,230);
        cairo_rectangle(cr,r-230,b-230,230,230);
        cairo_clip(cr);
        cairo_translate(cr, l + (a.width - iw * scale) / 2, t + (a.height - ih * scale) / 2);
        cairo_scale(cr, scale, scale);
        gdk_cairo_set_source_pixbuf(cr, material, 0, 0);
        cairo_paint_with_alpha(cr, .95);
        cairo_restore(cr);
    }
    cairo_set_source_rgba(cr, ground.red, ground.green, ground.blue, .08);
    cairo_paint(cr);
    cairo_restore(cr);
    return FALSE;
}


static gboolean is_file_view(GtkWidget *widget) {
    for (GtkWidget *p = gtk_widget_get_parent(widget); p; p = gtk_widget_get_parent(p))
        if (gtk_style_context_has_class(gtk_widget_get_style_context(p), "standard-view")) return TRUE;
    return FALSE;
}

static void metadata_font(GtkCellRenderer *renderer, GParamSpec *spec, gpointer unused) {
    const char *theme = g_getenv("GTK_THEME");
    double target = theme && g_str_has_suffix(theme, "-Touch") ? 11.0 : 10.0;
    char *family = NULL;
    double size = 0;
    g_object_get(renderer, "family", &family, "size-points", &size, NULL);
    if (g_strcmp0(family, "JetBrainsMono Nerd Font") || size != target)
        g_object_set(renderer, "family", "JetBrainsMono Nerd Font", "size-points", target, NULL);
    g_free(family);
}

static void style_columns(GtkTreeView *view) {
    GList *columns = gtk_tree_view_get_columns(view);
    GtkTreeViewColumn *last = NULL;
    for (GList *c = columns; c; c = c->next)
        if (gtk_tree_view_column_get_visible(c->data)) last = c->data;
    for (GList *c = columns; c; c = c->next) {
        GList *cells = gtk_cell_layout_get_cells(GTK_CELL_LAYOUT(c->data));
        gboolean text_only = cells != NULL;
        /* Native Name columns contain an icon and text; metadata is text-only.
         * This remains correct after reordering and without translated titles. */
        for (GList *i = cells; i; i = i->next)
            if (!GTK_IS_CELL_RENDERER_TEXT(i->data)) text_only = FALSE;
        /* Seed a native expandable Name column once, never on each allocation.
         * Subsequent manual resizing/reordering remains the user's choice. */
        if (gtk_widget_get_mapped(GTK_WIDGET(view)) &&
            !g_object_get_data(c->data, "senomy-width-policy")) {
            gboolean touch = g_str_has_suffix(g_getenv("GTK_THEME") ?: "", "-Touch");
            int width = 320;
            if (text_only && cells) {
                gfloat alignment = 0;
                g_object_get(cells->data, "xalign", &alignment, NULL);
                width = alignment > .5f ? (touch ? 112 : 100) : (touch ? 168 : 144);
            }
            gtk_tree_view_column_set_expand(c->data, text_only && c->data == last);
            gtk_tree_view_column_set_alignment(c->data, 0);
            gtk_tree_view_column_set_sizing(c->data, GTK_TREE_VIEW_COLUMN_FIXED);
            gtk_tree_view_column_set_fixed_width(c->data, width);
            gtk_tree_view_column_set_min_width(c->data, text_only ? 60 : 112);
            g_object_set_data(c->data, "senomy-width-policy", GINT_TO_POINTER(1));
            if (!text_only) g_object_set_data(c->data, "senomy-auto-name-width", GINT_TO_POINTER(width));
        }
        if (text_only) for (GList *i = cells; i; i = i->next) {
            if (!g_object_get_data(i->data, "senomy-metadata")) {
                g_object_set_data(i->data, "senomy-metadata", GINT_TO_POINTER(1));
                g_signal_connect(i->data, "notify::text", G_CALLBACK(metadata_font), NULL);
            }
            metadata_font(i->data, NULL, NULL);
        }
        g_list_free(cells);
    }
    g_list_free(columns);
}

/* Keep the three primary fields together on wide displays. Native manual
 * changes to fixed-width opt Name out; metadata widths remain owner-managed. */
static void fit_name(GtkTreeView *view) {
    GList *columns = gtk_tree_view_get_columns(view);
    GtkTreeViewColumn *name = NULL;
    int metadata = 0;
    for (GList *c = columns; c; c = c->next) {
        if (!gtk_tree_view_column_get_visible(c->data)) continue;
        if (g_object_get_data(c->data, "senomy-auto-name-width")) name = c->data;
        else metadata += MAX(gtk_tree_view_column_get_fixed_width(c->data), 60);
    }
    if (name && !g_object_get_data(G_OBJECT(name), "senomy-owner-width")) {
        int previous = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(name), "senomy-auto-name-width"));
        if (gtk_tree_view_column_get_fixed_width(name) != previous)
            g_object_set_data(G_OBJECT(name), "senomy-owner-width", GINT_TO_POINTER(1));
        else {
            gboolean touch = g_str_has_suffix(g_getenv("GTK_THEME") ?: "", "-Touch");
            int width = CLAMP(gtk_widget_get_allocated_width(GTK_WIDGET(view)) - metadata,
                              112, touch ? 740 : 680);
            if (width != previous) {
                g_object_set_data(G_OBJECT(name), "senomy-auto-name-width", GINT_TO_POINTER(width));
                gtk_tree_view_column_set_fixed_width(name, width);
                for (GList *c = columns; c; c = c->next) gtk_tree_view_column_queue_resize(c->data);
                gtk_widget_queue_resize(GTK_WIDGET(view));
            }
        }
    }
    g_list_free(columns);
}

static gboolean fit_name_idle(gpointer data) {
    GtkWidget *view = data;
    g_object_set_data(G_OBJECT(view), "senomy-fit-queued", NULL);
    if (!gtk_widget_in_destruction(view) && gtk_widget_get_mapped(view)) fit_name(GTK_TREE_VIEW(view));
    return G_SOURCE_REMOVE;
}

/* Reveal a previously visible cursor after a height reduction. Never select a
 * different row, steal focus, or undo an intentional scroll away from it. */
static gboolean reveal_cursor(gpointer data) {
    GtkTreeView *view = data;
    g_object_set_data(G_OBJECT(view), "senomy-reveal-queued", NULL);
    GtkWidget *top = gtk_widget_get_toplevel(GTK_WIDGET(view));
    if (!gtk_widget_in_destruction(GTK_WIDGET(view)) && GTK_IS_WINDOW(top) &&
        gtk_window_get_focus(GTK_WINDOW(top)) == GTK_WIDGET(view)) {
        GtkTreePath *path = NULL;
        gtk_tree_view_get_cursor(view, &path, NULL);
        if (path) {
            gtk_tree_view_scroll_to_cell(view, path, NULL, FALSE, 0, 0);
            gtk_tree_path_free(path);
        }
    }
    return G_SOURCE_REMOVE;
}

static void file_view_allocated(GtkTreeView *view, GtkAllocation *allocation, gpointer unused) {
    /* Resize requests during allocation are lost by GTK; settle in one idle. */
    if (!g_object_get_data(G_OBJECT(view), "senomy-fit-queued")) {
        g_object_set_data(G_OBJECT(view), "senomy-fit-queued", GINT_TO_POINTER(1));
        g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, fit_name_idle, g_object_ref(view), g_object_unref);
    }
    GdkWindow *bin = gtk_tree_view_get_bin_window(view);
    if (!bin) return;
    int height = gdk_window_get_height(bin);
    int previous = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(view), "senomy-bin-height"));
    g_object_set_data(G_OBJECT(view), "senomy-bin-height", GINT_TO_POINTER(height));
    if (!previous || height >= previous ||
        g_object_get_data(G_OBJECT(view), "senomy-reveal-queued")) return;
    GtkTreePath *path = NULL;
    gtk_tree_view_get_cursor(view, &path, NULL);
    if (path) {
        GdkRectangle row;
        gtk_tree_view_get_background_area(view, path, NULL, &row);
        if (row.y >= 0 && row.y + row.height <= previous && row.y + row.height > height) {
            g_object_set_data(G_OBJECT(view), "senomy-reveal-queued", GINT_TO_POINTER(1));
            g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, reveal_cursor, g_object_ref(view), g_object_unref);
        }
        gtk_tree_path_free(path);
    }
}

static void columns_changed(GtkTreeView *view, gpointer unused) { style_columns(view); fit_name(view); }

static void compose(GtkWidget *widget) {
    senomy_workspace_observe(widget);
    if (GTK_IS_TOOLBAR(widget)) gtk_toolbar_set_icon_size(GTK_TOOLBAR(widget), GTK_ICON_SIZE_MENU);
    if (GTK_IS_TREE_VIEW(widget) && is_file_view(widget)) {
        if (!g_object_get_data(G_OBJECT(widget), "senomy-columns")) {
            g_object_set_data(G_OBJECT(widget), "senomy-columns", GINT_TO_POINTER(1));
            gtk_tree_view_set_grid_lines(GTK_TREE_VIEW(widget), GTK_TREE_VIEW_GRID_LINES_HORIZONTAL);
            g_signal_connect(widget, "columns-changed", G_CALLBACK(columns_changed), NULL);
            g_signal_connect(widget, "size-allocate", G_CALLBACK(file_view_allocated), NULL);
        }
        style_columns(GTK_TREE_VIEW(widget));
        fit_name(GTK_TREE_VIEW(widget));
    }
    if (GTK_IS_CONTAINER(widget)) {
        GList *children = gtk_container_get_children(GTK_CONTAINER(widget));
        for (GList *i = children; i; i = i->next) compose(i->data);
        g_list_free(children);
    }
}

static void toggle_places(GtkButton *button, GtkWindow *window) {
    GtkAccelKey key;
    if (gtk_accel_map_lookup_entry("<Actions>/ThunarWindow/toggle-side-pane", &key) && key.accel_key)
        gtk_accel_groups_activate(G_OBJECT(window), key.accel_key, key.accel_mods);
}

static gboolean compose_window(gpointer data) {
    GtkWidget *window = data;
    if (!gtk_widget_in_destruction(window)) {
        GtkWidget *grid = GTK_IS_BIN(window) ? gtk_bin_get_child(GTK_BIN(window)) : NULL;
        if (GTK_IS_GRID(grid) && !g_object_get_data(G_OBJECT(window), "senomy-heading")) {
            load_material();
            gtk_style_context_add_class(gtk_widget_get_style_context(window), "senomy-material");
            g_signal_connect(window, "draw", G_CALLBACK(draw_material), NULL);
            gtk_widget_queue_draw(window);
            g_object_set_data(G_OBJECT(window), "senomy-heading", GINT_TO_POINTER(1));
            gtk_style_context_add_class(gtk_widget_get_style_context(window), "senomy-sculpted");
            senomy_workspace_compose(GTK_WINDOW(window), GTK_GRID(grid), G_CALLBACK(toggle_places));
        }
        compose(window);
    }
    return G_SOURCE_REMOVE;
}

static gboolean mapped(GSignalInvocationHint *hint, guint n_values,
                       const GValue *values, gpointer unused) {
    GtkWidget *widget = g_value_get_object(values);
    if (g_strcmp0(G_OBJECT_TYPE_NAME(widget), "ThunarWindow") == 0) {
        if (!g_object_get_data(G_OBJECT(widget), "senomy-heading")) compose_window(widget);
    } else if (GTK_IS_TREE_VIEW(widget) && is_file_view(widget)) compose(widget);
    else if (GTK_IS_TOOLBAR(widget)) gtk_toolbar_set_icon_size(GTK_TOOLBAR(widget), GTK_ICON_SIZE_MENU);
    return TRUE;
}

static gboolean application_window_added(GSignalInvocationHint *hint,guint count,const GValue *values,gpointer unused){
    GtkWidget *window=count>1?g_value_get_object(values+1):NULL;
    if(window&&g_strcmp0(G_OBJECT_TYPE_NAME(window),"ThunarWindow")==0&&!g_object_get_data(G_OBJECT(window),"senomy-heading"))compose_window(window);
    return TRUE;
}

G_MODULE_EXPORT void gtk_module_init(gint *argc, gchar ***argv) {
    const char *program = g_get_prgname();
    if (!program || g_ascii_strcasecmp(program, "thunar") != 0) return;
    GtkSettings *settings = gtk_settings_get_default();
    if (settings) g_object_set(settings, "gtk-icon-theme-name", "SenomyOS-Files", NULL);
    gpointer app_class=g_type_class_ref(GTK_TYPE_APPLICATION);
    guint added=g_signal_lookup("window-added",GTK_TYPE_APPLICATION);
    if(added)g_signal_add_emission_hook(added,0,application_window_added,NULL,NULL);
    g_type_class_unref(app_class);
    gpointer klass = g_type_class_ref(GTK_TYPE_WIDGET);
    guint signal = g_signal_lookup("show", GTK_TYPE_WIDGET);
    if (signal) g_signal_add_emission_hook(signal, 0, mapped, NULL, NULL);
    signal = g_signal_lookup("map", GTK_TYPE_WIDGET);
    if (signal) g_signal_add_emission_hook(signal, 0, mapped, NULL, NULL);
    signal = g_signal_lookup("parent-set", GTK_TYPE_WIDGET);
    if (signal) g_signal_add_emission_hook(signal, 0, mapped, NULL, NULL);
    g_type_class_unref(klass);
}
