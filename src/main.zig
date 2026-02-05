const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cDefine("RAYGUI_IMPLEMENTATION", "");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
const TITLE = "D-TRACKER";

const State = struct {
    const DailyTask = struct {
        name: []const u8,
        completed: bool,
    };

    remainders: std.ArrayList([]const u8),
    daily_tasks: std.ArrayList(DailyTask),
};

pub fn main() !void {
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE);
    defer r.CloseWindow();
    r.SetTargetFPS(60);
    r.GuiLoadStyleDark();

    var buffer: [3][]const u8 = undefined;
    var remainders = std.ArrayList([]const u8).initBuffer(&buffer);
    try remainders.appendBounded("Stand up and stretch for 5 minutes.");
    try remainders.appendBounded("Check the Zig documentation for build system updates.");
    try remainders.appendBounded("Review your code for potential optimizations.");

    var task_buffer: [3]State.DailyTask = undefined;
    var daily_tasks = std.ArrayList(State.DailyTask).initBuffer(&task_buffer);
    try daily_tasks.appendBounded(.{ .name = "Drink Coffee", .completed = false });
    try daily_tasks.appendBounded(.{ .name = "Write Zig Code", .completed = false });
    try daily_tasks.appendBounded(.{ .name = "Fix Compiler Errors", .completed = false });

    var state = State{ .remainders = remainders, .daily_tasks = daily_tasks };

    const font_size = 30;
    const text_width = r.MeasureText(TITLE, font_size);
    const boxes_y: f32 = 90;
    const boxes_h: f32 = 260;
    const wx: f32 = 430;

    const rem_y = boxes_y + boxes_h + 20;

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();

        r.ClearBackground(r.GetColor(@intCast(r.GuiGetStyle(r.DEFAULT, r.BACKGROUND_COLOR))));

        r.DrawText(TITLE, @divTrunc(SCREEN_WIDTH - text_width, 2), 20, font_size, r.RAYWHITE);
        _ = r.GuiLine(.{ .x = 20, .y = 65, .width = 760, .height = 1 }, null);

        // Daily Tasks
        _ = r.GuiGroupBox(.{ .x = 20, .y = boxes_y, .width = 370, .height = boxes_h }, "DAILY TASKS");
        for (state.daily_tasks.items, 0..) |*task, i| {
            _ = r.GuiCheckBox(.{ .x = 40, .y = boxes_y + 30 + @as(f32, @floatFromInt(i * 40)), .width = 24, .height = 24 }, task.name.ptr, &task.completed);
        }

        // Water Tracker
        _ = r.GuiGroupBox(.{ .x = 410, .y = boxes_y, .width = 370, .height = boxes_h }, "WATER TRACKER");
        _ = r.GuiLabel(.{ .x = wx, .y = boxes_y + 25, .width = 150, .height = 20 }, "Water in me:");
        var progress: f32 = 0.45;
        _ = r.GuiProgressBar(.{ .x = wx, .y = boxes_y + 50, .width = 330, .height = 30 }, null, null, &progress, 0, 1);
        _ = r.GuiLabel(.{ .x = wx, .y = boxes_y + 85, .width = 330, .height = 20 }, "0.9L / 2.0L");
        _ = r.GuiButton(.{ .x = wx, .y = boxes_y + 120, .width = 60, .height = 35 }, "-");
        _ = r.GuiButton(.{ .x = wx + 70, .y = boxes_y + 120, .width = 60, .height = 35 }, "+");

        // Remainders
        _ = r.GuiGroupBox(.{ .x = 20, .y = rem_y, .width = 760, .height = 180 }, "REMINDERS");
        const len = state.remainders.items.len;
        for (0..len) |row_idx| {
            const y_offset = rem_y + 30 + @as(f32, @floatFromInt(row_idx * 35));
            const rem_idx = len - 1 - row_idx;
            const button_clicked = r.GuiButton(.{ .x = 40, .y = y_offset, .width = 22, .height = 22 }, "x");
            _ = r.GuiLabel(.{ .x = 75, .y = y_offset, .width = 600, .height = 22 }, state.remainders.items[rem_idx].ptr);

            if (button_clicked == 1) {
                _ = state.remainders.orderedRemove(rem_idx);
            }
        }

        r.EndDrawing();
    }
}
