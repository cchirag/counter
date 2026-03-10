const std = @import("std");
const c = @import("../c.zig").c;

pub const TextStyle = enum {
    body,
    title1,
    title2,
    title3,
    heading,
    caption,
    monospace,
};

pub const Text = struct {
    widget: *c.GtkWidget,

    pub const Config = struct {
        text: [*:0]const u8,
        style: TextStyle = .body,
        selectable: bool = false,
        wrap: bool = false,
        halign: c_uint = c.GTK_ALIGN_START,
        opacity: ?f64 = null,
        scale: ?f64 = null,
        css_class: ?[*:0]const u8 = null,
    };

    pub fn init(config: Config) Text {
        const label = c.gtk_label_new(config.text);

        // Apply style
        switch (config.style) {
            .title1 => c.gtk_widget_add_css_class(label, "title-1"),
            .title2 => c.gtk_widget_add_css_class(label, "title-2"),
            .title3 => c.gtk_widget_add_css_class(label, "title-3"),
            .heading => c.gtk_widget_add_css_class(label, "heading"),
            .caption => c.gtk_widget_add_css_class(label, "caption"),
            .monospace => c.gtk_widget_add_css_class(label, "monospace"),
            .body => {},
        }

        // Opacity (dim-label effect)
        if (config.opacity) |_| {
            c.gtk_widget_add_css_class(label, "dim-label");
        }

        // Scale using pango attributes
        if (config.scale) |scale| {
            const attrs = c.pango_attr_list_new();
            _ = c.pango_attr_list_insert(attrs, c.pango_attr_scale_new(scale));
            c.gtk_label_set_attributes(@ptrCast(label), attrs);
        }

        // Selectable
        c.gtk_label_set_selectable(@ptrCast(label), if (config.selectable) 1 else 0);

        // Wrap
        c.gtk_label_set_wrap(@ptrCast(label), if (config.wrap) 1 else 0);

        // Alignment
        c.gtk_widget_set_halign(label, config.halign);

        // Custom CSS
        if (config.css_class) |class| {
            c.gtk_widget_add_css_class(label, class);
        }

        return .{ .widget = label };
    }

    pub fn setText(self: Text, text: [*:0]const u8) void {
        c.gtk_label_set_text(@ptrCast(self.widget), text);
    }

    pub fn addCssClass(self: Text, class: [*:0]const u8) void {
        c.gtk_widget_add_css_class(self.widget, class);
    }

    pub fn asWidget(self: Text) *c.GtkWidget {
        return self.widget;
    }
};
