pub fn BoundedArray(T: type, capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn slice(self: *Self) []T {
            return self.items[0..self.len];
        }

        pub fn constSlice(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        pub fn swapRemove(self: *Self, idx: usize) void {
            self.items[idx] = self.items[self.len - 1];
            self.len -= 1;
        }

        pub fn orderedRemove(self: *Self, idx: usize) void {
            for (self.items[idx .. self.len - 1], self.items[idx + 1 .. self.len]) |*dst, src| {
                dst.* = src;
            }
            self.len -= 1;
        }

        pub fn append(self: *Self, value: T) !void {
            if (self.len >= capacity) {
                return error.OutOfCapacity;
            }
            self.items[self.len] = value;
            self.len += 1;
        }
    };
}
