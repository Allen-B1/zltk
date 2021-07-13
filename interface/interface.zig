const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const TypeInfo = std.builtin.TypeInfo;
const TypeId = std.builtin.TypeId;

pub const This = opaque {};

const Interface = struct {
    Impl: type,
};

fn itoa(comptime int: anytype) []const u8 {
    var buf: [20]u8 = undefined;
    return std.fmt.bufPrint(buf[0..], "{}", .{int}) catch unreachable;
}

fn compileAssert(comptime condition: bool, comptime message: []const u8) void {
    if (!condition) {
        @compileError(message);
    }
}

// Checks that `T` is an interface and returns corresponding information.
fn interface(comptime T: type) Interface {
    var res: Interface = undefined;

    comptime {
        const typeInfo = @typeInfo(T).Struct;

        const Impl = @field(T, "Impl");
        res.Impl = Impl;

        // Check that all fields of Impl are function pointers and that they match
        // the helper functions provided in the interface type.
        const implMethods = @typeInfo(Impl).Struct.fields;
        for (@typeInfo(Impl).Struct.fields) |field| {
            const isOptional = @typeInfo(field.field_type) == .Optional;
            const fnInfo = if (isOptional) @typeInfo(@typeInfo(field.field_type).Optional.child).Fn else @typeInfo(field.field_type).Fn;
            if (isOptional and !@hasDecl(T, field.name)) continue;
            const helperInfo = @typeInfo(@TypeOf(@field(T, field.name))).Fn;

            compileAssert(fnInfo.calling_convention == helperInfo.calling_convention, "method " ++ @typeName(T) ++ ".Impl." ++ field.name ++ " does not match helper function " ++ @typeName(T) ++ "." ++ field.name ++ ": different calling convention");
            compileAssert(fnInfo.alignment == helperInfo.alignment, "method " ++ @typeName(T) ++ ".Impl." ++ field.name ++ " does not match helper function " ++ @typeName(T) ++ "." ++ field.name ++ ": different alignment");
            compileAssert(fnInfo.is_generic == helperInfo.is_generic, "method " ++ @typeName(T) ++ ".Impl." ++ field.name ++ " does not match helper function " ++ @typeName(T) ++ "." ++ field.name ++ ": different arguments");
            compileAssert(fnInfo.is_var_args == helperInfo.is_var_args, "method " ++ @typeName(T) ++ ".Impl." ++ field.name ++ " does not match helper function " ++ @typeName(T) ++ "." ++ field.name ++ ": different arguments");
            compileAssert(fnInfo.return_type.? == helperInfo.return_type.?, "method " ++ @typeName(T) ++ ".Impl." ++ field.name ++ " does not match helper function " ++ @typeName(T) ++ "." ++ field.name ++ ": different return type");
            compileAssert(fnInfo.args.len == helperInfo.args.len, "method " ++ @typeName(T) ++ ".Impl." ++ field.name ++ " does not match helper function " ++ @typeName(T) ++ "." ++ field.name ++ ": different number of arguments");

            var i: usize = 0;
            while (i < fnInfo.args.len) : (i += 1) {
                compileAssert(fnInfo.args[i].is_generic == helperInfo.args[i].is_generic, "argument " ++ itoa(i) ++ " of method " ++ @typeName(T) ++ ".Impl." ++ field.name ++
                    " does not match corresponding argument in helper function " ++ @typeName(T) ++ "." ++ field.name);
                compileAssert(fnInfo.args[i].is_noalias == helperInfo.args[i].is_noalias, "argument " ++ itoa(i) ++ " of method " ++ @typeName(T) ++ ".Impl." ++ field.name ++
                    " does not match corresponding argument in helper function " ++ @typeName(T) ++ "." ++ field.name);
                if (fnInfo.args[i].arg_type.? == *This or fnInfo.args[i].arg_type.? == *const This) {
                    compileAssert(helperInfo.args[i].arg_type.? == T, "argument " ++ itoa(i) ++ " of method " ++ @typeName(T) ++ ".Impl." ++ field.name ++
                        " does not match corresponding argument in helper function " ++ @typeName(T) ++ "." ++ field.name);
                } else {
                    compileAssert(fnInfo.args[i].arg_type.? == helperInfo.args[i].arg_type.?, "argument " ++ itoa(i) ++ " of method " ++ @typeName(T) ++ ".Impl." ++ field.name ++
                        " does not match corresponding argument in helper function " ++ @typeName(T) ++ "." ++ field.name);
                }
            }
        }

        // Assert that the two fields `impl` and `data` are present and that they are the only fields.
        compileAssert(typeInfo.fields.len == 2, "interface " ++ @typeName(T) ++ " does not contain impl and data fields");
        compileAssert(mem.eql(u8, typeInfo.fields[0].name, "impl"), "interface " ++ @typeName(T) ++ " missing impl field");
        compileAssert(typeInfo.fields[0].field_type == *const Impl, "interface " ++ @typeName(T) ++ " has wrong type for impl field");
        compileAssert(mem.eql(u8, typeInfo.fields[1].name, "data"), "interface " ++ @typeName(T) ++ " missing data field");
        compileAssert(typeInfo.fields[1].field_type == *This, "interface " ++ @typeName(T) ++ " has wrong type for data field");
    }

    return res;
}

pub fn assert(comptime T: type) void {
    _ = interface(T);
}

/// Creates a new interface value.
pub fn new(comptime T: type, impl_: anytype, data: anytype) T {
    assert(T);
    return T{ .impl = impl_, .data = @ptrCast(*This, data) };
}

/// Creates an implementation of a given interface. 
pub fn impl(comptime T: type, comptime Funcs: type) *const T.Impl {
    const Impl = interface(T).Impl;

    const Storage = struct {
        const impl_ = blk: {
            comptime {
                var res: Impl = undefined;
                for (@typeInfo(Impl).Struct.fields) |field| {
                    const isOptional = @typeInfo(field.field_type) == .Optional;
                    if (isOptional and !@hasDecl(Funcs, field.name)) {
                        @field(res, field.name) = null;
                        continue;
                    }
                    const expectedTypeInfo = if (isOptional) @typeInfo(@typeInfo(field.field_type).Optional.child).Fn else @typeInfo(field.field_type).Fn;
                    const actualTypeInfo = @typeInfo(@TypeOf(@field(Funcs, field.name))).Fn;

                    debug.assert(expectedTypeInfo.calling_convention == actualTypeInfo.calling_convention);
                    debug.assert(expectedTypeInfo.alignment == actualTypeInfo.alignment);
                    debug.assert(expectedTypeInfo.is_generic == actualTypeInfo.is_generic);
                    debug.assert(expectedTypeInfo.is_var_args == actualTypeInfo.is_var_args);
                    debug.assert(expectedTypeInfo.return_type.? == actualTypeInfo.return_type.?);
                    debug.assert(expectedTypeInfo.args.len == actualTypeInfo.args.len);

                    var i: usize = 0;
                    while (i < actualTypeInfo.args.len) : (i += 1) {
                        debug.assert(actualTypeInfo.args[i].is_generic == expectedTypeInfo.args[i].is_generic);
                        debug.assert(actualTypeInfo.args[i].is_noalias == expectedTypeInfo.args[i].is_noalias);
                        if (expectedTypeInfo.args[i].arg_type.? == *This or expectedTypeInfo.args[i].arg_type.? == *const This) {
                            debug.assert(@typeInfo(actualTypeInfo.args[i].arg_type.?).Pointer.size != TypeInfo.Pointer.Size.Slice);
                        } else {
                            debug.assert(actualTypeInfo.args[i].arg_type.? == expectedTypeInfo.args[i].arg_type.?);
                        }
                    }

                    @field(res, field.name) = @ptrCast(@TypeOf(@field(res, field.name)), @field(Funcs, field.name));
                }

                break :blk res;
            }
        };
    };

    return &Storage.impl_;
}
