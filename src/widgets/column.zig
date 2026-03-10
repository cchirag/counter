const std = @import("std");
const c = @import("../c.zig").c;

pub const MainAxisAlignment = enum {
    start,
    center,
    end,
    space_between,
};

pub const CrossAxisAlignment = enum {
    start,
    center,
    end,
    stretch,
};

pub const Column = struct {
    widget: *c.GtkWidget,

    pub const Config = struct {
        spacing: c_int = 0,
        homogeneous: bool = false,
        main_align: MainAxisAlignment = .start,
        cross_align: CrossAxisAlignment = .center,
        expand: bool = false,
        margin: ?c_int = null,
        margin_horizontal: ?c_int = null,
        margin_vertical: ?c_int = null,
        css_class: ?[*:0]const u8 = null,
        children: []const *c.GtkWidget = &.{},
    };

    pub fn init(config: Config) Column {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, config.spacing);

        c.gtk_box_set_homogeneous(@ptrCast(box), if (config.homogeneous) 1 else 0);

        // Main axis alignment (vertical for column)
        const valign: c_uint = switch (config.main_align) {
            .start => c.GTK_ALIGN_START,
            .center => c.GTK_ALIGN_CENTER,
            .end => c.GTK_ALIGN_END,
            .space_between => c.GTK_ALIGN_FILL,
        };
        c.gtk_widget_set_valign(box, valign);

        // Cross axis alignment (horizontal for column)
        const halign: c_uint = switch (config.cross_align) {
            .start => c.GTK_ALIGN_START,
            .center => c.GTK_ALIGN_CENTER,
            .end => c.GTK_ALIGN_END,
            .stretch => c.GTK_ALIGN_FILL,
        };
        c.gtk_widget_set_halign(box, halign);

        // Expansion
        if (config.expand or config.main_align == .space_between) {
            c.gtk_widget_set_vexpand(box, 1);
        }

        // Margins
        if (config.margin) |m| {
            c.gtk_widget_set_margin_top(box, m);
            c.gtk_widget_set_margin_bottom(box, m);
            c.gtk_widget_set_margin_start(box, m);
            c.gtk_widget_set_margin_end(box, m);
        }
        if (config.margin_horizontal) |m| {
            c.gtk_widget_set_margin_start(box, m);
            c.gtk_widget_set_margin_end(box, m);
        }
        if (config.margin_vertical) |m| {
            c.gtk_widget_set_margin_top(box, m);
            c.gtk_widget_set_margin_bottom(box, m);
        }

        // CSS class
        if (config.css_class) |class| {
            c.gtk_widget_add_css_class(box, class);
        }

        // Add children
        for (config.children) |child| {
            c.gtk_box_append(@ptrCast(box), child);
        }

        return .{ .widget = box };
    }

    pub fn append(self: Column, child: *c.GtkWidget) void {
        c.gtk_box_append(@ptrCast(self.widget), child);
    }

    pub fn prepend(self: Column, child: *c.GtkWidget) void {
        c.gtk_box_prepend(@ptrCast(self.widget), child);
    }

    pub fn remove(self: Column, child: *c.GtkWidget) void {
        c.gtk_box_remove(@ptrCast(self.widget), child);
    }

    pub fn setSpacing(self: Column, spacing: c_int) void {
        c.gtk_box_set_spacing(@ptrCast(self.widget), spacing);
    }

    pub fn addCssClass(self: Column, class: [*:0]const u8) void {
        c.gtk_widget_add_css_class(self.widget, class);
    }

    pub fn asWidget(self: Column) *c.GtkWidget {
        return self.widget;
    }
};
