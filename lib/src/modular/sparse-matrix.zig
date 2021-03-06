const std = @import("std");
const errors = @import("../errors.zig");
const inverseMod = @import("../arith.zig").inverseMod;
const SparseVectorMod = @import("./sparse-vector.zig").SparseVectorMod;
const mod = @import("../arith.zig").mod;

pub fn SparseMatrixMod(comptime T: type) type {
    return struct {
        const Matrix = @This();

        modulus: T,
        ncols: usize,
        nrows: usize,
        rows: std.ArrayList(SparseVectorMod(T)),

        pub fn init(modulus: T, nrows: usize, ncols: usize, allocator: std.mem.Allocator) !Matrix {
            if (modulus <= 0) {
                return errors.Math.ValueError;
            }
            var rows = try std.ArrayList(SparseVectorMod(T)).initCapacity(allocator, nrows);
            var i: usize = 0;
            while (i < nrows) : (i += 1) {
                try rows.append(try SparseVectorMod(T).init(modulus, ncols, allocator));
            }
            return Matrix{ .rows = rows, .modulus = modulus, .ncols = ncols, .nrows = nrows };
        }

        pub fn deinit(self: *Matrix) void {
            var i: usize = 0;
            while (i < self.nrows) : (i += 1) {
                self.rows.items[i].deinit();
            }
            self.rows.deinit();
        }

        // Mutate this matrix by increasing the number of rows by 1.
        // This is useful when building a sparse matrix.
        pub fn appendRow(self: *Matrix) !void {
            try self.rows.append(try SparseVectorMod(T).init(self.modulus, self.ncols, self.rows.allocator));
            self.nrows += 1;
        }

        pub fn jsonStringify(
            self: Matrix,
            options: std.json.StringifyOptions,
            writer: anytype,
        ) !void {
            _ = options;
            const obj = .{ .type = "SparseMatrixMod", .modulus = self.modulus, .nrows = self.nrows, .ncols = self.ncols };
            try std.json.stringify(obj, options, writer);
        }

        pub fn format(self: Matrix, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            var i: usize = 0;
            while (i < self.nrows) : (i += 1) {
                if (i > 0) try writer.print("\n", .{});
                try writer.print("[", .{});
                var j: usize = 0;
                while (j < self.ncols) : (j += 1) {
                    if (j > 0) try writer.print(" ", .{});
                    try writer.print("{}", .{self.get(i, j)});
                }
                try writer.print("]", .{});
            }
        }

        pub fn set(self: *Matrix, row: usize, col: usize, x: T) !void {
            if (col >= self.ncols or row >= self.nrows) {
                return errors.General.IndexError;
            }
            try self.rows.items[row].unsafeSet(col, mod(x, self.modulus));
        }

        pub fn get(self: Matrix, row: usize, col: usize) !T {
            if (col >= self.ncols or row >= self.nrows) {
                return errors.General.IndexError;
            }
            return self.rows.items[row].unsafeGet(col);
        }

        pub fn swapRows(self: *Matrix, row1: usize, row2: usize) !void {
            if (row1 == row2) return;
            if (row1 >= self.nrows or row2 >= self.nrows) {
                return errors.General.IndexError;
            }
            const t = self.rows.items[row2];
            self.rows.items[row2] = self.rows.items[row1];
            self.rows.items[row1] = t;
        }

        // Replace self by its reduction to reduced row echelon form.
        // We use Gauss elimination, in a slightly intelligent way,
        // in that we clear each column using a row with the minimum
        // number of nonzero entries.  Return pivot columns (caller
        // must deinit that) that is *sorted*.
        pub fn echelonize(self: *Matrix) !std.ArrayList(ColumnType) {
            var columnTypes = std.ArrayList(ColumnType).init(self.rows.allocator);
            var c: usize = 0;
            var startRow: usize = 0;
            var nonPivotIndex: usize = 0;
            var pivotIndex: usize = 0;
            while (c < self.ncols) : (c += 1) {
                // Goal -- clear column c, if not already cleared.
                // First find row that we can use that has min number of nonzero entries:
                var min: usize = self.ncols + 1;
                var minRow: usize = undefined;
                var r: usize = startRow;
                var found: bool = false;
                while (r < self.nrows) : (r += 1) {
                    const row = self.rows.items[r];
                    const cnt = row.count();
                    if (cnt > 0 and cnt < min and row.unsafeGet(c) != 0) {
                        minRow = r;
                        min = cnt;
                        found = true;
                    }
                }
                if (!found) {
                    // non-pivot column
                    try columnTypes.append(ColumnType{ .isPivot = false, .index = nonPivotIndex });
                    nonPivotIndex += 1;
                    continue;
                }
                try columnTypes.append(ColumnType{ .isPivot = true, .index = pivotIndex });
                pivotIndex += 1;
                r = minRow;
                // Now use the row we found to clear column c.
                const a = self.rows.items[r].unsafeGet(c);
                if (a != 1) {
                    const aInverse = try inverseMod(a, self.modulus);
                    try self.rows.items[r].rescale(aInverse);
                }
                try self.swapRows(r, startRow);
                var i: usize = 0;
                while (i < self.nrows) : (i += 1) {
                    if (i == startRow) continue;
                    const b = try self.get(i, c);
                    if (b == 0) continue;
                    try self.rows.items[i].addInPlace(self.rows.items[startRow], self.modulus - b);
                }
                startRow += 1;
            }
            return columnTypes;
        }

        pub fn randomize(self: *Matrix, cols: usize) !void {
            var rand = (try @import("../random.zig").seededPrng()).random();
            var row: usize = 0;
            while (row < self.nrows) : (row += 1) {
                var j: usize = 0;
                while (j < cols) : (j += 1) {
                    const x = rand.intRangeLessThan(T, 0, self.modulus);
                    const col = rand.intRangeLessThan(usize, 0, self.ncols);
                    try self.set(row, col, x);
                }
            }
        }
    };
}

const ColumnType = struct { isPivot: bool, index: usize };

const testing_allocator = std.testing.allocator;
const expect = std.testing.expect;

test "setting and getting " {
    var m = try SparseMatrixMod(i32).init(11, 100, 100000, testing_allocator);
    defer m.deinit();
    try expect((try m.get(0, 0)) == 0);
    try m.set(0, 0, 2);
    try expect((try m.get(0, 0)) == 2);
    try m.set(50, 50000, 13);
    try expect((try m.get(50, 50000)) == 2);
}

test "appending a row" {
    var m = try SparseMatrixMod(i32).init(5, 1, 2, testing_allocator);
    defer m.deinit();
    try m.appendRow();
    try expect(m.nrows == 2);
    try expect(m.ncols == 2);
    try m.appendRow();
    try expect(m.nrows == 3);
    try expect(m.ncols == 2);
}

test "computing an echelon form" {
    var m = try SparseMatrixMod(i32).init(11, 2, 3, testing_allocator);
    defer m.deinit();
    try m.set(0, 1, 1);
    try m.set(0, 2, 2);
    try m.set(1, 0, 3);
    try m.set(1, 1, 4);
    try m.set(1, 2, 5);
    const columnTypes = try m.echelonize();
    defer columnTypes.deinit();
    try expect((try m.get(0, 0)) == 1);
}

test "compute echelon form of [1..N^2] square rank 2 matrix mod 997, for N=100" {
    const N = 100;
    var m = try SparseMatrixMod(i32).init(997, N, N, testing_allocator);
    defer m.deinit();
    var i: usize = 0;
    var k: i32 = 0;
    while (i < N) : (i += 1) {
        var j: usize = 0;
        while (j < N) : (j += 1) {
            try m.set(i, j, k);
            k += 1;
        }
    }
    const columnTypes = try m.echelonize();
    defer columnTypes.deinit();
    try expect(columnTypes.items[0].isPivot);
    try expect(columnTypes.items[0].index == 0);
    try expect(columnTypes.items[1].isPivot);
    try expect(columnTypes.items[1].index == 1);
    try expect(!columnTypes.items[2].isPivot);
    try expect(columnTypes.items[2].index == 0);
    try expect(columnTypes.items.len == N);
}

test "compute echelon form of a larger random matrix" {
    const time = std.time.milliTimestamp;
    const N = 100;
    var m = try SparseMatrixMod(i16).init(17, N, 3 * N, testing_allocator);
    defer m.deinit();
    try m.randomize(3);
    //m.print();
    const t = time();
    const columnTypes = try m.echelonize();
    defer columnTypes.deinit();
    std.debug.print("tm = {}\n", .{time() - t});
}

pub fn bench(N: i32) !void {
    var m = try SparseMatrixMod(i32).init(17, @intCast(usize, N), @intCast(usize, 3 * N), testing_allocator);
    defer m.deinit();
    try m.randomize(3);
    const columnTypes = try m.echelonize();
    defer columnTypes.deinit();
}
