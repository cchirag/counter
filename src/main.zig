const std = @import("std");

const c = @cImport({
    @cInclude("adwaita.h");
});

// Minimal CSS - libadwaita handles most styling
const css_data =
    \\.welcome-box {
    \\    padding: 24px;
    \\}
    \\
    \\.title-1 {
    \\    font-size: 36px;
    \\    font-weight: 800;
    \\}
    \\
    \\.dim-label {
    \\    opacity: 0.55;
    \\}
    \\
    \\.card {
    \\    background-color: alpha(@card_bg_color, 0.8);
    \\    border-radius: 12px;
    \\    padding: 0;
    \\}
    \\
    \\.action-row-box {
    \\    padding: 8px 16px;
    \\}
;

fn onNewProtocol(_: *c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    std.debug.print("New Protocol clicked\n", .{});
}

fn onOpenProtocol(_: *c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    std.debug.print("Open Protocol clicked\n", .{});
}

fn onRecentClicked(_: *c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    std.debug.print("Recent protocol clicked\n", .{});
}

fn createActionRow(icon_name: [*:0]const u8, title: [*:0]const u8, subtitle: [*:0]const u8, callback: *const fn (*c.GtkWidget, ?*anyopaque) callconv(.c) void) *c.GtkWidget {
    const row = c.adw_action_row_new();
    c.adw_preferences_row_set_title(@ptrCast(row), title);
    c.adw_action_row_set_subtitle(@ptrCast(row), subtitle);
    c.gtk_list_box_row_set_activatable(@ptrCast(row), 1);

    // Add icon
    const icon = c.gtk_image_new_from_icon_name(icon_name);
    c.gtk_image_set_icon_size(@ptrCast(icon), c.GTK_ICON_SIZE_LARGE);
    c.adw_action_row_add_prefix(@ptrCast(row), icon);

    // Add arrow
    const arrow = c.gtk_image_new_from_icon_name("go-next-symbolic");
    c.gtk_widget_add_css_class(arrow, "dim-label");
    c.adw_action_row_add_suffix(@ptrCast(row), arrow);

    _ = c.g_signal_connect_data(row, "activated", @ptrCast(callback), null, null, 0);

    return row;
}

fn createRecentRow(title: [*:0]const u8, subtitle: [*:0]const u8, time_str: [*:0]const u8) *c.GtkWidget {
    const row = c.adw_action_row_new();
    c.adw_preferences_row_set_title(@ptrCast(row), title);
    c.adw_action_row_set_subtitle(@ptrCast(row), subtitle);
    c.gtk_list_box_row_set_activatable(@ptrCast(row), 1);

    // Folder icon
    const icon = c.gtk_image_new_from_icon_name("folder-symbolic");
    c.adw_action_row_add_prefix(@ptrCast(row), icon);

    // Time label
    const time_label = c.gtk_label_new(time_str);
    c.gtk_widget_add_css_class(time_label, "dim-label");
    c.gtk_widget_set_valign(time_label, c.GTK_ALIGN_CENTER);
    c.adw_action_row_add_suffix(@ptrCast(row), time_label);

    _ = c.g_signal_connect_data(row, "activated", @ptrCast(&onRecentClicked), null, null, 0);

    return row;
}

fn activate(app: *c.AdwApplication, _: ?*anyopaque) callconv(.c) void {
    // Load CSS
    const provider = c.gtk_css_provider_new();
    c.gtk_css_provider_load_from_string(provider, css_data);
    c.gtk_style_context_add_provider_for_display(
        c.gdk_display_get_default(),
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
    );

    // Create window
    const window = c.adw_application_window_new(@ptrCast(app));
    c.gtk_window_set_title(@ptrCast(window), "Spectre");
    c.gtk_window_set_default_size(@ptrCast(window), 700, 650);

    // Main layout with toolbar
    const toolbar_view = c.adw_toolbar_view_new();

    // Header bar
    const header = c.adw_header_bar_new();
    c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar_view), header);

    // Scrolled content
    const scrolled = c.gtk_scrolled_window_new();
    c.gtk_scrolled_window_set_policy(@ptrCast(scrolled), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);

    // Center the content
    const clamp = c.adw_clamp_new();
    c.adw_clamp_set_maximum_size(@ptrCast(clamp), 600);

    // Main content box
    const main_box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 24);
    c.gtk_widget_add_css_class(main_box, "welcome-box");
    c.gtk_widget_set_margin_top(main_box, 48);
    c.gtk_widget_set_margin_bottom(main_box, 48);

    // Logo and title section
    const header_box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 12);
    c.gtk_widget_set_halign(header_box, c.GTK_ALIGN_CENTER);

    // Logo using a symbolic icon or emoji
    const logo = c.gtk_label_new("👻");
    const logo_attrs = c.pango_attr_list_new();
    _ = c.pango_attr_list_insert(logo_attrs, c.pango_attr_scale_new(4.0));
    c.gtk_label_set_attributes(@ptrCast(logo), logo_attrs);
    c.gtk_box_append(@ptrCast(header_box), logo);

    // Title
    const title = c.gtk_label_new("Spectre");
    c.gtk_widget_add_css_class(title, "title-1");
    c.gtk_box_append(@ptrCast(header_box), title);

    // Subtitle
    const subtitle = c.gtk_label_new("Craft, test, and debug binary protocols with ease.");
    c.gtk_widget_add_css_class(subtitle, "dim-label");
    c.gtk_box_append(@ptrCast(header_box), subtitle);

    c.gtk_box_append(@ptrCast(main_box), header_box);

    // Action cards using AdwPreferencesGroup
    const actions_group = c.adw_preferences_group_new();
    c.adw_preferences_group_set_title(@ptrCast(actions_group), "Get Started");

    const new_row = createActionRow("list-add-symbolic", "New Protocol", "Define message schemas and start testing", &onNewProtocol);
    c.adw_preferences_group_add(@ptrCast(actions_group), new_row);

    const open_row = createActionRow("folder-open-symbolic", "Open Protocol", "Open an existing protocol folder", &onOpenProtocol);
    c.adw_preferences_group_add(@ptrCast(actions_group), open_row);

    c.gtk_box_append(@ptrCast(main_box), @ptrCast(actions_group));

    // Recent protocols section
    const recent_group = c.adw_preferences_group_new();
    c.adw_preferences_group_set_title(@ptrCast(recent_group), "Recent Protocols");

    const recent1 = createRecentRow("modbus-tcp", "~/protocols/modbus-tcp", "2 hours ago");
    c.adw_preferences_group_add(@ptrCast(recent_group), recent1);

    const recent2 = createRecentRow("custom-sensor", "~/protocols/custom-sensor", "Yesterday");
    c.adw_preferences_group_add(@ptrCast(recent_group), recent2);

    const recent3 = createRecentRow("mqtt-binary", "~/protocols/mqtt-binary", "3 days ago");
    c.adw_preferences_group_add(@ptrCast(recent_group), recent3);

    c.gtk_box_append(@ptrCast(main_box), @ptrCast(recent_group));

    // Assemble the view
    c.adw_clamp_set_child(@ptrCast(clamp), main_box);
    c.gtk_scrolled_window_set_child(@ptrCast(scrolled), @ptrCast(clamp));
    c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), scrolled);
    c.adw_application_window_set_content(@ptrCast(window), toolbar_view);

    c.gtk_window_present(@ptrCast(window));
}

pub fn main() void {
    // Use AdwApplication for automatic dark mode and styling
    const app = c.adw_application_new("com.spectre.app", c.G_APPLICATION_DEFAULT_FLAGS);
    defer c.g_object_unref(app);

    _ = c.g_signal_connect_data(app, "activate", @ptrCast(&activate), null, null, 0);

    _ = c.g_application_run(@ptrCast(app), 0, null);
}
