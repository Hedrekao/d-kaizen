const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cDefine("RAYGUI_IMPLEMENTATION", "");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

const STATE_PATH = @import("config").STATE_PATH;
const BoundedArray = @import("utils.zig").BoundedArray;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
const TITLE = "D-KAIZEN";

const MAX_REMAINDERS = 32;
const MAX_DAILY_TASKS = 16;

const State = struct {
    remainders: BoundedArray([:0]const u8, MAX_REMAINDERS) = .{},
    daily_tasks: BoundedArray(DailyTask, MAX_DAILY_TASKS) = .{},
    water: f32 = 0.0,
    last_save: i64 = 0,

    const DailyTask = struct {
        name: [:0]const u8 = "",
        target: u8 = 1,
        completed: u8 = 0,
    };

    const JsonFormat = struct {
        remainders: []const [:0]const u8,
        water: f32,
        last_save: i64,
        daily_tasks: []DailyTask,
    };

    fn default() !State {
        var state = State{ .water = 0.0, .last_save = 0 };

        try state.daily_tasks.append(State.DailyTask{ .name = "take vitamin D", .target = 2, .completed = 0 });
        try state.daily_tasks.append(State.DailyTask{ .name = "read", .target = 1, .completed = 0 });
        try state.daily_tasks.append(State.DailyTask{ .name = "exercise", .target = 1, .completed = 0 });
        try state.daily_tasks.append(State.DailyTask{ .name = "japanese", .target = 1, .completed = 0 });

        return state;
    }

    fn fromParsed(parsed: JsonFormat) !State {
        const new_day = @divFloor(std.time.timestamp(), std.time.s_per_day);
        const last_day = @divFloor(parsed.last_save, std.time.s_per_day);
        const is_new_day = new_day > last_day;

        var state = State{
            .water = if (is_new_day) 0.0 else parsed.water,
            .last_save = parsed.last_save,
        };

        for (parsed.remainders) |rem| {
            try state.remainders.append(rem);
        }
        for (parsed.daily_tasks) |task| {
            var new_task = task;
            if (is_new_day) {
                new_task.completed = 0;
            }
            try state.daily_tasks.append(new_task);
        }
        return state;
    }

    fn save(self: *State) !void {
        const file = std.fs.cwd().createFile(STATE_PATH, .{}) catch return;
        defer file.close();

        var buffer: [4096]u8 = undefined;
        var writer = file.writer(&buffer);
        try writer.interface.print("{f}", .{std.json.fmt(JsonFormat{
            .remainders = self.remainders.constSlice(),
            .daily_tasks = self.daily_tasks.slice(),
            .water = self.water,
            .last_save = std.time.timestamp(),
        }, .{ .whitespace = .indent_2 })});
        try writer.interface.flush();
    }
};

pub fn main() !void {
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE);
    defer r.CloseWindow();
    r.SetTargetFPS(60);
    r.GuiLoadStyleDark();

    // Persistent allocator for state that lives across frames
    var buffer: [1024 * 8]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    var state_arena = std.heap.ArenaAllocator.init(fba.allocator());
    defer state_arena.deinit();

    var raw_state: [4096]u8 = undefined;
    const file_data: ?[]u8 = std.fs.cwd().readFile(STATE_PATH, &raw_state) catch |e| blk: {
        if (e == error.FileNotFound) {
            break :blk null;
        }
        return e;
    };

    var state = if (file_data) |data| blk: {
        const parsed = try std.json.parseFromSliceLeaky(State.JsonFormat, state_arena.allocator(), data, .{ .ignore_unknown_fields = true });
        defer state_arena.deinit();

        break :blk try State.fromParsed(parsed);
    } else blk: {
        break :blk try State.default();
    };

    defer state.save() catch std.debug.print("Failed to save state\n", .{});

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
        for (state.daily_tasks.slice(), 0..) |*task, i| {
            const y = boxes_y + 30 + @as(f32, @floatFromInt(i * 40));

            var label_buf: [96]u8 = undefined;
            const label = if (task.completed >= task.target)
                std.fmt.bufPrintZ(&label_buf, "#112#{s}", .{task.name}) catch task.name
            else
                std.fmt.bufPrintZ(&label_buf, "{s} ({d}/{d})", .{ task.name, task.completed, task.target }) catch task.name;

            if (r.GuiLabelButton(.{ .x = 40, .y = y, .width = 320, .height = 24 }, label.ptr) == 1) {
                if (task.completed < task.target) task.completed += 1;
            }
        }

        // Water Tracker
        _ = r.GuiGroupBox(.{ .x = 410, .y = boxes_y, .width = 370, .height = boxes_h }, "WATER TRACKER");
        _ = r.GuiLabel(.{ .x = wx, .y = boxes_y + 25, .width = 150, .height = 20 }, "Water in me:");
        _ = r.GuiProgressBar(.{ .x = wx, .y = boxes_y + 50, .width = 330, .height = 30 }, null, null, &state.water, 0, 2);

        var water_label: [32]u8 = undefined;
        const water_text = std.fmt.bufPrintZ(&water_label, "{d:.2}L / 2.0L", .{state.water}) catch "?";
        _ = r.GuiLabel(.{ .x = wx, .y = boxes_y + 85, .width = 330, .height = 20 }, water_text.ptr);

        if (r.GuiButton(.{ .x = wx + 100, .y = boxes_y + 120, .width = 60, .height = 35 }, "-") == 1) {
            state.water -= 0.25;
            if (state.water < 0) state.water = 0;
        }
        if (r.GuiButton(.{ .x = wx + 170, .y = boxes_y + 120, .width = 60, .height = 35 }, "+") == 1) {
            state.water += 0.25;
            if (state.water > 2.0) state.water = 2.0;
        }

        // Remainders
        var rem_to_remove: ?usize = null;
        _ = r.GuiGroupBox(.{ .x = 20, .y = rem_y, .width = 760, .height = 180 }, "REMINDERS");
        for (state.remainders.slice(), 0..) |rem, i| {
            const y_offset = rem_y + 30 + @as(f32, @floatFromInt(i * 35));
            if (r.GuiButton(.{ .x = 40, .y = y_offset, .width = 22, .height = 22 }, "x") == 1) {
                rem_to_remove = i;
            }
            _ = r.GuiLabel(.{ .x = 75, .y = y_offset, .width = 600, .height = 22 }, rem.ptr);
        }

        if (rem_to_remove) |idx| {
            state.remainders.orderedRemove(idx);
        }

        r.EndDrawing();
    }
}
