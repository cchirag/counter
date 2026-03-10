const std = @import("std");
const c = @import("../c.zig").c;

pub const ButtonStyle = enum {
    default,
    suggested, // Primary/accent color
    destructive, // Red/danger
    flat, // No background
    pill, // Rounded pill shape
};

pub const Button = struct {
    widget: *c.GtkWidget,

    pub const Config = struct {
        label: ?[*:0]const u8 = null,
        icon: ?[*:0]const u8 = null,
        style: ButtonStyle = .default,
        css_class: ?[*:0]const u8 = null,
        on_click: ?*const fn () void = null,
        expand: bool = false,
        halign: c_uint = c.GTK_ALIGN_CENTER,
        valign: c_uint = c.GTK_ALIGN_CENTER,
    };

    pub fn init(config: Config) Button {
        var btn: *c.GtkWidget = undefined;

        // Create button with label or icon
        if (config.icon) |icon_name| {
            if (config.label) |label| {
                // Button with icon and label
                btn = c.gtk_button_new();
                const box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8);
                const icon = c.gtk_image_new_from_icon_name(icon_name);
                const lbl = c.gtk_label_new(label);
                c.gtk_box_append(@ptrCast(box), icon);
                c.gtk_box_append(@ptrCast(box), lbl);
                c.gtk_button_set_child(@ptrCast(btn), box);
            } else {
                // Icon only button
                btn = c.gtk_button_new_from_icon_name(icon_name);
            }
        } else if (config.label) |label| {
            btn = c.gtk_button_new_with_label(label);
        } else {
            btn = c.gtk_button_new();
        }

        // Apply style
        switch (config.style) {
            .suggested => c.gtk_widget_add_css_class(btn, "suggested-action"),
            .destructive => c.gtk_widget_add_css_class(btn, "destructive-action"),
            .flat => c.gtk_widget_add_css_class(btn, "flat"),
            .pill => c.gtk_widget_add_css_class(btn, "pill"),
            .default => {},
        }

        // Apply custom CSS class
        if (config.css_class) |class| {
            c.gtk_widget_add_css_class(btn, class);
        }

        // Apply alignment and expansion
        c.gtk_widget_set_halign(btn, config.halign);
        c.gtk_widget_set_valign(btn, config.valign);
        c.gtk_widget_set_hexpand(btn, if (config.expand) 1 else 0);

        // Connect click handler
        if (config.on_click) |callback| {
            _ = c.g_signal_connect_data(
                btn,
                "clicked",
                @ptrCast(&clickWrapper),
                @constCast(@ptrCast(callback)),
                null,
                0,
            );
        }

        return .{ .widget = btn };
    }

    fn clickWrapper(_: *c.GtkWidget, user_data: ?*anyopaque) callconv(.c) void {
        if (user_data) |ptr| {
            const callback: *const fn () void = @ptrCast(@alignCast(ptr));
            callback();
        }
    }

    pub fn setLabel(self: Button, label: [*:0]const u8) void {
        c.gtk_button_set_label(@ptrCast(self.widget), label);
    }

    pub fn setSensitive(self: Button, sensitive: bool) void {
        c.gtk_widget_set_sensitive(self.widget, if (sensitive) 1 else 0);
    }

    pub fn addCssClass(self: Button, class: [*:0]const u8) void {
        c.gtk_widget_add_css_class(self.widget, class);
    }

    pub fn asWidget(self: Button) *c.GtkWidget {
        return self.widget;
    }
};
