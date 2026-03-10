const std = @import("std");
const ui = @import("widgets.zig");
const c = ui.c;

// CSS styling
const css_data =
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
    \\    background: alpha(@card_bg_color, 0.8);
    \\    border-radius: 12px;
    \\    padding: 16px;
    \\}
    \\
    \\.card-row {
    \\    padding: 12px 16px;
    \\    border-radius: 8px;
    \\}
    \\
    \\.card-row:hover {
    \\    background: alpha(@card_bg_color, 0.5);
    \\}
;

fn onNewProtocol() void {
    std.debug.print("New Protocol clicked\n", .{});
}

fn onOpenProtocol() void {
    std.debug.print("Open Protocol clicked\n", .{});
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

    // Header bar
    const toolbar_view = c.adw_toolbar_view_new();
    const header = c.adw_header_bar_new();
    c.adw_header_bar_set_title_widget(@ptrCast(header), c.adw_window_title_new("Spectre", "Binary Protocol Builder"));
    c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar_view), header);

    // Scrolled content
    const scrolled = c.gtk_scrolled_window_new();
    c.gtk_scrolled_window_set_policy(@ptrCast(scrolled), c.GTK_POLICY_NEVER, c.GTK_POLICY_AUTOMATIC);

    // === Build UI with widgets ===

    // Logo
    const logo = ui.Text.init(.{
        .text = "👻",
        .scale = 4.0,
        .halign = c.GTK_ALIGN_CENTER,
    });

    // Title
    const title = ui.Text.init(.{
        .text = "Spectre",
        .style = .title1,
        .halign = c.GTK_ALIGN_CENTER,
    });

    // Subtitle
    const subtitle = ui.Text.init(.{
        .text = "Craft, test, and debug binary protocols with ease.",
        .halign = c.GTK_ALIGN_CENTER,
        .opacity = 0.5,
    });

    // Header section
    const header_section = ui.Column.init(.{
        .spacing = 12,
        .cross_align = .center,
        .children = &.{
            logo.asWidget(),
            title.asWidget(),
            subtitle.asWidget(),
        },
    });

    // Action buttons
    const new_btn = ui.Button.init(.{
        .label = "New Protocol",
        .icon = "list-add-symbolic",
        .style = .suggested,
        .on_click = &onNewProtocol,
    });

    const open_btn = ui.Button.init(.{
        .label = "Open Protocol",
        .icon = "folder-open-symbolic",
        .on_click = &onOpenProtocol,
    });

    const button_row = ui.Row.init(.{
        .spacing = 12,
        .main_align = .center,
        .children = &.{
            new_btn.asWidget(),
            open_btn.asWidget(),
        },
    });

    // Main content
    const main_content = ui.Column.init(.{
        .spacing = 32,
        .margin = 48,
        .cross_align = .center,
        .children = &.{
            header_section.asWidget(),
            button_row.asWidget(),
        },
    });

    // Centered container
    const centered = ui.CenteredContainer.init(.{
        .max_width = 600,
        .child = main_content.asWidget(),
    });

    // Assemble view
    c.gtk_scrolled_window_set_child(@ptrCast(scrolled), centered.asWidget());
    c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), scrolled);
    c.adw_application_window_set_content(@ptrCast(window), toolbar_view);

    c.gtk_window_present(@ptrCast(window));
}

pub fn main() void {
    c.g_set_application_name("Spectre");

    const app = c.adw_application_new("com.spectre.app", c.G_APPLICATION_DEFAULT_FLAGS);
    defer c.g_object_unref(app);

    _ = c.g_signal_connect_data(app, "activate", @ptrCast(&activate), null, null, 0);

    _ = c.g_application_run(@ptrCast(app), 0, null);
}
