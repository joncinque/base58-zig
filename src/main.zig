const clap = @import("clap");
const std = @import("std");
const bitcoin = @import("./root.zig").bitcoin;

const debug = std.debug;
const io = std.io;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`
    const params = comptime clap.parseParamsComptime(
        \\-h, --help          Display this help and exit.
        \\-o, --outfile <str> Path to generated keypair file.
        \\
    );

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer).interface;
    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostics` provides.
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(&stderr_writer, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.usage(&stderr_writer, clap.Help, &params);
    if (res.args.outfile) |s| {
        try generateKeypair(s, gpa.allocator());
    }
}

pub fn generateKeypair(path: []const u8, allocator: std.mem.Allocator) !void {
    const cwd = std.fs.cwd();
    if (cwd.openFile(path, .{})) |keypair_file| {
        const keypair_json = try keypair_file.readToEndAlloc(allocator, 1024);
        defer allocator.free(keypair_json);
        const parsed_keypair = try std.json.parseFromSlice([std.crypto.sign.Ed25519.SecretKey.encoded_length]u8, allocator, keypair_json, .{});
        defer parsed_keypair.deinit();
        const keypair_secret = parsed_keypair.value;

        const keypair = try std.crypto.sign.Ed25519.KeyPair.fromSecretKey(try std.crypto.sign.Ed25519.SecretKey.fromBytes(keypair_secret));

        var pubkey_buffer: [bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        const pubkey = bitcoin.encode(&pubkey_buffer, &keypair.public_key.bytes);

        std.debug.print("Existing keypair pubkey: {s}\n", .{pubkey});
    } else |err| {
        if (err != std.fs.File.OpenError.FileNotFound) {
            return err;
        }

        const keypair = std.crypto.sign.Ed25519.KeyPair.generate();
        var keypair_writer = std.Io.Writer.Allocating.init(allocator);
        defer keypair_writer.deinit();
        const json_fmt = std.json.fmt(keypair.secret_key.bytes, .{});
        try json_fmt.format(&keypair_writer.writer);
        var file = try createFileWithRetries(path);
        try file.writeAll(keypair_writer.written());

        var pubkey_buffer: [bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        const pubkey = bitcoin.encode(&pubkey_buffer, &keypair.public_key.bytes);

        std.debug.print("New keypair pubkey: {s}\n", .{pubkey});
    }
}

fn createFileWithRetries(path: []const u8) !std.fs.File {
    const attempts = 5;
    const cwd = std.fs.cwd();
    for (0..attempts + 1) |i| {
        return cwd.createFile(path, .{ .exclusive = true }) catch |err| if (i == attempts) return err else continue;
    }
    return error.FileNotFound;
}
