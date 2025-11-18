pub fn Color(T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError("Color is for numeric types"),
    }

    return extern struct { r: T, g: T, b: T, a: T };
}

pub fn Coord(T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError("Pos is for numeric types"),
    }

    return extern struct { x: T, y: T };
}

pub fn Size(T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError("Size is for numeric types"),
    }

    return extern struct { w: T, h: T };
}

pub fn Rect(T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError("Rect is for numeric types"),
    }

    return extern struct { x: T, y: T, w: T, h: T };
}
