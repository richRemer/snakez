pub fn Pair(T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError("Pair is for numeric types"),
    }

    return struct { T, T };
}

pub fn Quad(T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError("Quad is for numeric types"),
    }

    return struct { T, T, T, T };
}
