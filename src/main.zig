const std = @import("std");

// Import GTK4 directly via C headers
const c = @cImport({
    @cInclude("gtk/gtk.h");
});

// Application state
var count: i32 = 0;
var label: ?*c.GtkWidget = null;

fn updateLabel() void {
    if (label) |lbl| {
        var buf: [64]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buf, "Count: {d}", .{count}) catch "Error";
        c.gtk_label_set_text(@ptrCast(lbl), text.ptr);
    }
}

fn onIncrement(_: *c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    count += 1;
    updateLabel();
}

fn onDecrement(_: *c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    count -= 1;
    updateLabel();
}

fn activate(app: *c.GtkApplication, _: ?*anyopaque) callconv(.c) void {
    // Create window
    const window = c.gtk_application_window_new(app);
    c.gtk_window_set_title(@ptrCast(window), "Zig GTK Counter");
    c.gtk_window_set_default_size(@ptrCast(window), 300, 200);

    // Create vertical box
    const vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 10);
    c.gtk_widget_set_margin_top(vbox, 20);
    c.gtk_widget_set_margin_bottom(vbox, 20);
    c.gtk_widget_set_margin_start(vbox, 20);
    c.gtk_widget_set_margin_end(vbox, 20);
    c.gtk_widget_set_vexpand(vbox, 1);

    // Create label
    label = c.gtk_label_new("Count: 0");
    if (label) |lbl| {
        c.gtk_widget_set_vexpand(lbl, 1);
        c.gtk_widget_set_valign(lbl, c.GTK_ALIGN_CENTER);
        c.gtk_box_append(@ptrCast(vbox), lbl);
    }

    // Create horizontal box for buttons
    const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);
    c.gtk_widget_set_halign(hbox, c.GTK_ALIGN_CENTER);

    // Create decrement button
    const dec_btn = c.gtk_button_new_with_label("-");
    c.gtk_widget_set_size_request(dec_btn, 60, 40);
    _ = c.g_signal_connect_data(
        dec_btn,
        "clicked",
        @ptrCast(&onDecrement),
        null,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(hbox), dec_btn);

    // Create increment button
    const inc_btn = c.gtk_button_new_with_label("+");
    c.gtk_widget_set_size_request(inc_btn, 60, 40);
    _ = c.g_signal_connect_data(
        inc_btn,
        "clicked",
        @ptrCast(&onIncrement),
        null,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(hbox), inc_btn);

    c.gtk_box_append(@ptrCast(vbox), hbox);
    c.gtk_window_set_child(@ptrCast(window), vbox);
    c.gtk_window_present(@ptrCast(window));
}

pub fn main() void {
    const app = c.gtk_application_new("com.example.counter", c.G_APPLICATION_DEFAULT_FLAGS);
    defer c.g_object_unref(app);

    _ = c.g_signal_connect_data(
        app,
        "activate",
        @ptrCast(&activate),
        null,
        null,
        0,
    );

    _ = c.g_application_run(@ptrCast(app), 0, null);
}
