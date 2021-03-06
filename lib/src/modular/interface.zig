const std = @import("std");
const manin_symbols = @import("./manin-symbols.zig");
const errors = @import("../errors.zig");
const interface = @import("../interface.zig");
const dense_vector_interface = @import("./dense-vector-interface.zig");
const dense_matrix_interface = @import("./dense-matrix-interface.zig");
const sparse_vector_interface = @import("./sparse-vector-interface.zig");
const elliptic_curve_interface = @import("./elliptic-curve-interface.zig");
const ManinSymbolsType = manin_symbols.ManinSymbols(i32, u32);

pub export fn DUMMY12345() void {
    // This is JUST to keep this code from not getting removed during compilation.
    // this is never actually called by anything.
    elliptic_curve_interface.EllipticCurve_free(0);
}

fn toSign(sign: i32) !manin_symbols.Sign {
    if (sign == -1) return manin_symbols.Sign.minus;
    if (sign == 1) return manin_symbols.Sign.plus;
    if (sign == 0) return manin_symbols.Sign.zero;
    interface.throw("invalid sign");
    return errors.Math.ValueError;
}

fn ManinSymbols_create(N: u32, sign: i32) !ManinSymbolsType {
    return try ManinSymbolsType.init(interface.allocator(), N, try toSign(sign));
}

var ManinSymbols_objects = interface.ProxyObjects(ManinSymbolsType).init();

pub export fn ManinSymbols(N: i32, sign: i32) i32 {
    if (N <= 0) {
        interface.throw("ManinSymbols: N must be positive");
        return 0;
    }
    var M = ManinSymbols_create(@intCast(u32, N), sign) catch {
        interface.throw("ManinSymbols: failed to create ManinSymbols");
        return 0;
    };

    return ManinSymbols_objects.put(M) catch {
        interface.throw("ManinSymbols: failed to store");
        return 0;
    };
}

pub export fn ManinSymbols_free(handle: i32) void {
    ManinSymbols_objects.free(handle);
}

fn ManinSymbols_get(n: i32) !ManinSymbolsType {
    return ManinSymbols_objects.get(n) orelse {
        interface.throw("ManinSymbols: failed to get space with given handle");
        return errors.General.RuntimeError;
    };
}

pub export fn ManinSymbols_dimensionFormula(handle: i32) i32 {
    var M = ManinSymbols_get(handle) catch return -1;
    // TODO: could overflow.
    return @intCast(i32, M.dimensionFormula());
}

pub export fn ManinSymbols_stringify(handle: i32) void {
    ManinSymbols_objects.stringify(handle);
}

pub export fn ManinSymbols_format(handle: i32) void {
    ManinSymbols_objects.format(handle);
}

pub export fn ManinSymbols_presentation(handle: i32, p: i32, verbose: i32) i32 {
    var M = ManinSymbols_get(handle) catch return 0;
    var P = M.presentation(i32, p, verbose != 0) catch {
        interface.throw("Failed to compute presentation.");
        return 0;
    };
    return Presentation_objects.put(P) catch {
        interface.throw("Presentation: failed to store");
        return 0;
    };
}

// Presentations of Manin symbols modulo a prime.

const PresentationType = manin_symbols.Presentation(ManinSymbolsType, i32, i32);

var Presentation_objects = interface.ProxyObjects(PresentationType).init();

pub export fn Presentation_free(handle: i32) void {
    Presentation_objects.free(handle);
}

fn Presentation_get(n: i32) !PresentationType {
    return Presentation_objects.get(n) orelse {
        interface.throw("Presentation: failed to get presentation with given handle");
        return errors.General.RuntimeError;
    };
}

pub export fn Presentation_stringify(handle: i32) void {
    Presentation_objects.stringify(handle);
}
pub export fn Presentation_format(handle: i32) void {
    Presentation_objects.format(handle);
}

pub export fn Presentation_reduce(handle: i32, u: i32, v: i32) i32 {
    var P = Presentation_get(handle) catch return 0;
    var vec = P.reduce(u, v) catch return 0;
    return dense_vector_interface.DenseVector_put(vec);
}

pub export fn Presentation_modularSymbol(handle: i32, numer_a: i32, denom_a: i32, numer_b: i32, denom_b: i32) i32 {
    var P = Presentation_get(handle) catch return 0;
    var vec = P.modularSymbol(numer_a, denom_a, numer_b, denom_b) catch return 0;
    return dense_vector_interface.DenseVector_put(vec);
}

pub export fn Presentation_fastModularSymbolMap_11a(handle: i32, numer: i32, denom: i32) i32 {
    var P = Presentation_get(handle) catch |err| {
        std.debug.print("\nPresentation_fastModularSymbolMap_11a -- {}\n", .{err});
        return -99999999;
    };
    return P.fastModularSymbolMap_11a(numer, denom) catch |err| {
        std.debug.print("\nPresentation_fastModularSymbolMap_11a -- {}\n", .{err});
        return -99999999;
    };
}

pub export fn Presentation_heckeOperator(handle: i32, p: i32) i32 {
    var P = Presentation_get(handle) catch return 0;
    var Tp = P.heckeOperator(p) catch |err| {
        std.debug.print("\nPresentation_heckeOperator -- {}\n", .{err});
        return 0;
    };
    return dense_matrix_interface.DenseMatrix_put(Tp);
}

pub export fn Presentation_starInvolution(handle: i32) i32 {
    var P = Presentation_get(handle) catch return 0;
    var S = P.starInvolution() catch |err| {
        std.debug.print("\nPresentation_starInvolution -- {}\n", .{err});
        return 0;
    };
    return dense_matrix_interface.DenseMatrix_put(S);
}
