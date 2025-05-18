const std = @import("std");
const Parser = @import("teltonika/parser.zig").Parser;
const TeltonikaData = @import("model/teltonika_data.zig").TeltonikaData;
const ImeiHandler = @import("teltonika/imei_handler.zig").ImeiHandler;
const isValidChecksum = @import("teltonika/validate_checksum.zig").isValidChecksum;

pub const TcpServer = struct {
    address: std.net.Address,
    server: std.net.Server,
    allocator: std.mem.Allocator,
    thread_pool: *std.Thread.Pool,
    running: bool,

    connection_semaphore: std.Thread.Semaphore,
    const MAX_CONCURRENT_CONNECTIONS = 500;

    pub fn init(allocator: std.mem.Allocator, ip: []const u8, port: u16) !TcpServer {
        const address = try std.net.Address.parseIp(ip, port);
        const server = try address.listen(.{
            .reuse_address = true,
        });

        var thread_pool = try allocator.create(std.Thread.Pool);
        try thread_pool.init(.{
            .allocator = allocator,
            .n_jobs = 16,
        });

        return TcpServer{
            .address = address,
            .server = server,
            .allocator = allocator,
            .thread_pool = thread_pool,
            .running = false,
            .connection_semaphore = std.Thread.Semaphore{ .permits = MAX_CONCURRENT_CONNECTIONS },
        };
    }

    pub fn deinit(self: *TcpServer) void {
        self.running = false;
        self.thread_pool.deinit();
        self.server.deinit();
        self.allocator.destroy(self.thread_pool);
    }

    pub fn start(self: *TcpServer, comptime handler: fn (anytype, std.mem.Allocator) void) !void {
        self.running = true;
        try self.thread_pool.spawn(acceptConnections, .{ self, handler });
    }

    fn acceptConnections(self: *TcpServer, comptime handler: fn (anytype, std.mem.Allocator) void) void {
        while (self.running) {
            self.connection_semaphore.wait();
            const conn = self.server.accept() catch |err| {
                self.connection_semaphore.post();
                std.log.err("Accept error: {}", .{err});
                continue;
            };

            self.thread_pool.spawn(handleConnection, .{ self, conn, handler }) catch |err| {
                self.connection_semaphore.post();
                std.log.err("Thread pool spawn error: {}", .{err});
                conn.stream.close();
                continue;
            };
            continue;
        }
    }

    fn readWithTimeout(stream: *const std.net.Stream, buffer: []u8, timeout_ns: u64) !usize {
        const deadline = std.time.nanoTimestamp() + timeout_ns;

        while (true) {
            const bytes = stream.read(buffer) catch |err| {
                std.log.err("Erro durante leitura: {}", .{err});
                return err;
            };

            if (bytes != 0) {
                return bytes;
            }

            if (std.time.nanoTimestamp() > deadline) {
                return error.Timeout;
            }

            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    fn handleConnection(self: *TcpServer, conn: std.net.Server.Connection, comptime handler: fn (anytype, std.mem.Allocator) void) void {
        defer {
            conn.stream.close();
            self.connection_semaphore.post();
        }

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const conn_allocator = arena.allocator();

        std.log.info("New connection from {}", .{conn.address});

        var buffer: [1024]u8 = undefined;
        const bytes_read = readWithTimeout(&conn.stream, &buffer, 5 * std.time.ns_per_s) catch |err| {
            if (err == error.Timeout) {
                std.log.warn("Timeout ao tentar ler do stream.", .{});
            } else {
                std.log.err("Erro durante leitura: {}", .{err});
            }
            return;
        };
        if (bytes_read == 0) return;

        var imei_handler = ImeiHandler.init(conn_allocator) catch |err| {
            std.log.err("Error initializing IMEI handler: {}", .{err});
            return;
        };
        defer imei_handler.deinit();

        const imei = imei_handler.handle(buffer[0..bytes_read]);
        std.log.info("Received IMEI: {}", .{imei});

        const response: []const u8 = if (imei == 0) &[_]u8{0x00} else &[_]u8{0x01};
        conn.stream.writeAll(response) catch return;

        var packet_buffer: [2048]u8 = undefined;
        const packet_bytes_read = readWithTimeout(&conn.stream, &packet_buffer, 10 * std.time.ns_per_s) catch |err| {
            std.log.err("Packet read error: {}", .{err});
            return;
        };
        var packet_data = packet_buffer[0..packet_bytes_read];

        if (packet_data.len == 0) {
            std.log.warn("Received empty packet data. Ignoring...", .{});
            return;
        }

        if (!isValidChecksum(packet_data)) {
            std.log.warn("Invalid checksum. Discarding packet.", .{});
            return;
        }

        const teltonika_data = Parser.init(&packet_data, imei, conn_allocator) catch |err| {
            std.log.err("Parser error: {}", .{err});
            return;
        };

        handler(teltonika_data, conn_allocator);
    }
};

pub fn defaultHandler(teltonika_data: anytype, allocator: std.mem.Allocator) void {
    // defer teltonika_data.deinit(allocator);

    const json_string = std.json.stringifyAlloc(allocator, teltonika_data, .{ .emit_null_optional_fields = false }) catch |err| {
        std.log.err("Error stringifying JSON: {}", .{err});
        return;
    };
    defer allocator.free(json_string);

    std.log.info("DATA: {s}\n\n", .{json_string});

    var c_json = allocator.alloc(u8, json_string.len + 1) catch |err| {
        std.log.err("Failed to allocate memory for C JSON: {}", .{err});
        return;
    };
    defer allocator.free(c_json);

    @memcpy(c_json[0..json_string.len], json_string);
    c_json[json_string.len] = 0;
}
