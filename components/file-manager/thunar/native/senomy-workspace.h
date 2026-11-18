#pragma once
#include <gtk/gtk.h>
void senomy_workspace_compose(GtkWindow *window, GtkGrid *grid, GCallback places_callback);
void senomy_workspace_observe(GtkWidget *widget);
