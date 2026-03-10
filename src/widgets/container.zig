const std = @import("std");
const c = @import("../c.zig").c;

pub const Alignment = enum {
    start,
    center,
    end,
    fill,
};

pub const Container = struct {
    widget: *c.GtkWidget,

    pub const Config = struct {
        child: ?*c.GtkWidget = null,
        padding: ?c_int = null,
        padding_horizontal: ?c_int = null,
        padding_vertical: ?c_int = null,
        padding_top: ?c_int = null,
        padding_bottom: ?c_int = null,
        padding_start: ?c_int = null,
        padding_end: ?c_int = null,
        halign: Alignment = .fill,
        valign: Alignment = .fill,
        hexpand: bool = false,
        vexpand: bool = false,
        width: ?c_int = null,
        height: ?c_int = null,
        css_class: ?[*:0]const u8 = null,
    };

    pub fn init(config: Config) Container {
        // Use a GtkBox as a simple container
        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0);

        // Alignment
        c.gtk_widget_set_halign(box, alignToGtk(config.halign));
        c.gtk_widget_set_valign(box, alignToGtk(config.valign));

        // Expansion
        c.gtk_widget_set_hexpand(box, if (config.hexpand) 1 else 0);
        c.gtk_widget_set_vexpand(box, if (config.vexpand) 1 else 0);

        // Size request
        if (config.width != null or config.height != null) {
            c.gtk_widget_set_size_request(
                box,
                config.width orelse -1,
                config.height orelse -1,
            );
        }

        // Padding (using margins)
        if (config.padding) |p| {
            c.gtk_widget_set_margin_top(box, p);
            c.gtk_widget_set_margin_bottom(box, p);
            c.gtk_widget_set_margin_start(box, p);
            c.gtk_widget_set_margin_end(box, p);
        }
        if (config.padding_horizontal) |p| {
            c.gtk_widget_set_margin_start(box, p);
            c.gtk_widget_set_margin_end(box, p);
        }
        if (config.padding_vertical) |p| {
            c.gtk_widget_set_margin_top(box, p);
            c.gtk_widget_set_margin_bottom(box, p);
        }
        if (config.padding_top) |p| c.gtk_widget_set_margin_top(box, p);
        if (config.padding_bottom) |p| c.gtk_widget_set_margin_bottom(box, p);
        if (config.padding_start) |p| c.gtk_widget_set_margin_start(box, p);
        if (config.padding_end) |p| c.gtk_widget_set_margin_end(box, p);

        // CSS class
        if (config.css_class) |class| {
            c.gtk_widget_add_css_class(box, class);
        }

        // Add child
        if (config.child) |child| {
            c.gtk_box_append(@ptrCast(box), child);
        }

        return .{ .widget = box };
    }

    fn alignToGtk(alignment: Alignment) c_uint {
        return switch (alignment) {
            .start => c.GTK_ALIGN_START,
            .center => c.GTK_ALIGN_CENTER,
            .end => c.GTK_ALIGN_END,
            .fill => c.GTK_ALIGN_FILL,
        };
    }

    pub fn setChild(self: Container, child: *c.GtkWidget) void {
        // Remove existing children first
        var current = c.gtk_widget_get_first_child(self.widget);
        while (current != null) {
            const next = c.gtk_widget_get_next_sibling(current);
            c.gtk_box_remove(@ptrCast(self.widget), current);
            current = next;
        }
        c.gtk_box_append(@ptrCast(self.widget), child);
    }

    pub fn addCssClass(self: Container, class: [*:0]const u8) void {
        c.gtk_widget_add_css_class(self.widget, class);
    }

    pub fn asWidget(self: Container) *c.GtkWidget {
        return self.widget;
    }
};

// Convenience wrapper that centers content with max width (like AdwClamp)
pub const CenteredContainer = struct {
    widget: *c.GtkWidget,

    pub const Config = struct {
        child: ?*c.GtkWidget = null,
        max_width: c_int = 600,
        padding: ?c_int = null,
        css_class: ?[*:0]const u8 = null,
    };

    pub fn init(config: Config) CenteredContainer {
        const clamp = c.adw_clamp_new();
        c.adw_clamp_set_maximum_size(@ptrCast(clamp), config.max_width);

        if (config.padding) |p| {
            c.gtk_widget_set_margin_top(clamp, p);
            c.gtk_widget_set_margin_bottom(clamp, p);
            c.gtk_widget_set_margin_start(clamp, p);
            c.gtk_widget_set_margin_end(clamp, p);
        }

        if (config.css_class) |class| {
            c.gtk_widget_add_css_class(clamp, class);
        }

        if (config.child) |child| {
            c.adw_clamp_set_child(@ptrCast(clamp), child);
        }

        return .{ .widget = clamp };
    }

    pub fn setChild(self: CenteredContainer, child: *c.GtkWidget) void {
        c.adw_clamp_set_child(@ptrCast(self.widget), child);
    }

    pub fn asWidget(self: CenteredContainer) *c.GtkWidget {
        return self.widget;
    }
};
