const std: type = @import("std");

const IMEI_CACHE_SIZE = 1000;
const IMEI_PREFIX: [2]u8 = [2]u8{ 0x00, 0x0f };
const IMEI_MAX_LENGTH = 15;

pub const ImeiHandler = struct {
    cache: std.AutoHashMap(u64, void),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !ImeiHandler {
        return ImeiHandler{
            .cache = std.AutoHashMap(u64, void).init(allocator),
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ImeiHandler) void {
        self.cache.deinit();
    }

    pub fn handle(self: *ImeiHandler, packet: []const u8) u64 {
        if (packet.len < 2 or !std.mem.eql(u8, packet[0..2], &IMEI_PREFIX)) return 0;

        const imei_length: u16 = readInt(u16, packet[0..2], .big) catch return 0;
        if (imei_length == 0 or imei_length > IMEI_MAX_LENGTH or packet.len < 2 + imei_length) return 0;

        const imei: []const u8 = packet[2 .. 2 + imei_length];
        const parse_result: u64 = parseInt(u64, imei, 10) catch return 0;

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.contains(parse_result)) {
            return parse_result;
        }

        if (self.cache.count() < IMEI_CACHE_SIZE) {
            self.cache.put(parse_result, {}) catch {};
        }

        return parse_result;
    }
};

fn readInt(comptime T: type, bytes: []const u8, endian: std.builtin.Endian) !T {
    if (bytes.len < @sizeOf(T)) return error.InvalidLength;
    return std.mem.readInt(T, bytes[0..@sizeOf(T)], endian);
}

fn parseInt(comptime T: type, bytes: []const u8, radix: u8) !T {
    if (bytes.len == 0) return error.InvalidLength;
    return std.fmt.parseInt(T, bytes, radix);
}
