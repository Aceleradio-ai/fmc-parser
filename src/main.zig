const std = @import("std");
const server_lib = @import("server_lib");

const BindConfig = struct {
    address: []const u8,
    port: u16,

    pub fn validate(self: BindConfig) !void {
        if (self.address.len == 0) return error.EmptyBindAddress;
        if (self.port == 0) return error.InvalidPort;
    }
};

const Config = struct {
    pub const BIND_ADDRESS_DEFAULT: []const u8 = "0.0.0.0";
    pub const PORT_DEFAULT: u16 = 4444;
    pub const SLEEP_INTERVAL_NS: u64 = 100 * std.time.ns_per_ms;
};

comptime {
    const default_config = BindConfig{
        .address = Config.BIND_ADDRESS_DEFAULT,
        .port = Config.PORT_DEFAULT,
    };
    _ = default_config.validate() catch @compileError("Default config is invalid");
}

fn parseArgs(allocator: std.mem.Allocator) !BindConfig {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len >= 3) {
        const port = std.fmt.parseInt(u16, args[2], 10) catch |err| {
            std.log.err("Invalid port number: {s}. Using default port {d}.", .{ @errorName(err), Config.PORT_DEFAULT });
            return BindConfig{ .address = args[1], .port = Config.PORT_DEFAULT };
        };
        return BindConfig{ .address = args[1], .port = port };
    }
    return BindConfig{ .address = Config.BIND_ADDRESS_DEFAULT, .port = Config.PORT_DEFAULT };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try parseArgs(allocator);
    try config.validate();

    var server = try server_lib.TcpServer.init(allocator, config.address, config.port);
    defer server.deinit();

    std.log.info("Server is running on {s}:{d}...", .{ config.address, config.port });

    try server.start(server_lib.defaultHandler);

    while (true) {
        std.time.sleep(Config.SLEEP_INTERVAL_NS);
    }
}
