const std = @import("std");
const IoElement: type = @import("../../../../model/io_element.zig").IoElement;
const getProperty = @import("./mapping_io.zig").getProperty;

pub const IoElementParser = struct {
    const EventSize = struct {
        size: u8,
        count: u16,
    };

    const EventSizes = [_]u8{ 1, 2, 4, 8 };

    fn readU16(data: []u8, offset: usize) !u16 {
        if (offset + 2 > data.len) return error.InvalidPacketData;
        return std.mem.readInt(u16, data[offset..][0..2], .big);
    }

    fn readU64(data: []u8, offset: usize, size: usize) !u64 {
        if (offset + size > data.len) return error.InvalidPacketData;

        var buf: [8]u8 = .{0} ** 8;

        @memcpy(buf[(8 - size)..], data[offset .. offset + size]);

        return std.mem.readInt(u64, buf[0..], .big);
    }

    fn bytesToHex(allocator: std.mem.Allocator, data: []u8) ![]u8 {
        const hex_value = try allocator.alloc(u8, data.len * 2);
        errdefer allocator.free(hex_value);

        if (comptime std.debug.runtime_safety) {
            var hex_index: usize = 0;
            for (data) |byte| {
                hex_value[hex_index] = if ((byte >> 4) < 10) (byte >> 4) + '0' else (byte >> 4) - 10 + 'a';
                hex_value[hex_index + 1] = if ((byte & 0xF) < 10) (byte & 0xF) + '0' else (byte & 0xF) - 10 + 'a';
                hex_index += 2;
            }
        }

        return hex_value;
    }

    pub fn parseIoElements(packet_data: []u8, cursor: *usize, allocator: std.mem.Allocator) ![]IoElement {
        if (cursor.* + 4 > packet_data.len) return error.InvalidPacketData;

        const event_io_id = try readU16(packet_data, cursor.*);
        const total_io_elements = try readU16(packet_data, cursor.* + 2);
        cursor.* += 4;

        _ = event_io_id;

        var io_elements_array = try allocator.alloc(IoElement, total_io_elements);
        errdefer allocator.free(io_elements_array);
        var index: usize = 0;

        for (EventSizes) |size| {
            const event_count = try readU16(packet_data, cursor.*);
            cursor.* += 2;

            const remaining = @min(event_count, total_io_elements - index);
            for (0..remaining) |_| {
                const event_id = try readU16(packet_data, cursor.*);
                cursor.* += 2;

                const event_value = try readU64(packet_data, cursor.*, size);
                cursor.* += size;

                io_elements_array[index] = .{
                    .id = event_id,
                    .property = try getProperty(event_id),
                    .value = event_value,
                    .hex_value = null,
                };
                index += 1;
            }
        }

        const event_count_xb = try readU16(packet_data, cursor.*);
        cursor.* += 2;

        const remaining_xb = @min(event_count_xb, total_io_elements - index);
        for (0..remaining_xb) |_| {
            if (cursor.* + 4 > packet_data.len) return error.InvalidPacketData;

            const event_id = try readU16(packet_data, cursor.*);
            const event_value_size = try readU16(packet_data, cursor.* + 2);
            cursor.* += 4;

            if (cursor.* + event_value_size > packet_data.len) return error.InvalidPacketData;

            const event_value = try allocator.alloc(u8, event_value_size);
            errdefer allocator.free(event_value);
            @memcpy(event_value, packet_data[cursor.*..][0..event_value_size]);
            cursor.* += event_value_size;

            var io_element_instance = IoElement{
                .id = event_id,
                .property = try getProperty(event_id),
                .value = null,
                .hex_value = null,
            };

            if (event_value_size <= @sizeOf(u64)) {
                io_element_instance.value = try readU64(event_value, 0, @intCast(event_value_size));
                allocator.free(event_value);
            } else {
                const hex_value = try bytesToHex(allocator, event_value);
                allocator.free(event_value);
                errdefer allocator.free(hex_value);
            }

            io_elements_array[index] = io_element_instance;
            index += 1;
        }

        return io_elements_array[0..index];
    }
};
