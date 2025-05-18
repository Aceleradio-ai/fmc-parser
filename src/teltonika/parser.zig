const std = @import("std");

const AvlData = @import("../model/avl_data.zig").AvlData;
const TeltonikaData = @import("../model/teltonika_data.zig").TeltonikaData;
const Avl = @import("parser/avl.zig").Avl;
const parseCodecId = @import("parser/codec.zig").parseCodecId;
const parseCrc16 = @import("parser/crc16.zig").parseCrc16;
const parseDataField = @import("parser/data_field.zig").parseDataField;
const parseNumberData = @import("parser/number_data.zig").parseNumberData;
const parsePreamble = @import("parser/preamble.zig").parsePreamble;

pub const Parser = struct {
    pub fn init(packet_data: *[]u8, imei: u64, allocator: std.mem.Allocator) !TeltonikaData {
        var data = TeltonikaData.init(imei);
        var cursor: usize = 0;

        data.preamble = try parsePreamble(packet_data.*, &cursor);
        data.data_size = try parseDataField(packet_data.*, &cursor);
        data.codec_id = try parseCodecId(packet_data.*, &cursor);
        data.number_data = try parseNumberData(packet_data.*, &cursor);
        const avl_data_count = data.number_data orelse 0;
        data.avl_data_list = try allocator.alloc(AvlData, avl_data_count);
        if (data.avl_data_list) |avl_data_list| {
            for (avl_data_list) |*avl_data| {
                try Avl.init(avl_data, packet_data.*, &cursor, allocator);
            }
        }
        data.crc16 = try parseCrc16(packet_data.*, &cursor);
        data.number_data_2 = try parseNumberData(packet_data.*, &cursor);

        packet_data.* = packet_data.*[cursor..];

        return data;
    }
};
