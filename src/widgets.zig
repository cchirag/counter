// Widget library - ergonomic wrappers over GTK/libadwaita
//
// Usage:
//   const ui = @import("widgets.zig");
//
//   const btn = ui.Button.init(.{
//       .label = "Click me",
//       .style = .suggested,
//       .on_click = handleClick,
//   });
//
//   const row = ui.Row.init(.{
//       .spacing = 16,
//       .children = &.{ btn.asWidget(), other.asWidget() },
//   });

pub const Button = @import("widgets/button.zig").Button;
pub const ButtonStyle = @import("widgets/button.zig").ButtonStyle;

pub const Row = @import("widgets/row.zig").Row;
pub const Column = @import("widgets/column.zig").Column;

pub const Container = @import("widgets/container.zig").Container;
pub const CenteredContainer = @import("widgets/container.zig").CenteredContainer;

pub const Text = @import("widgets/text.zig").Text;
pub const TextStyle = @import("widgets/text.zig").TextStyle;

// Re-export alignment enums
pub const MainAxisAlignment = @import("widgets/row.zig").MainAxisAlignment;
pub const CrossAxisAlignment = @import("widgets/row.zig").CrossAxisAlignment;
pub const Alignment = @import("widgets/container.zig").Alignment;

// Re-export C bindings for advanced usage
pub const c = @import("c.zig").c;
