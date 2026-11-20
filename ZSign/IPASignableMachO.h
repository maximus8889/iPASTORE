#pragma once
#include <stdint.h>
#include <stdio.h>

// Signing applies to loadable code, not compiler objects, dSYM files or other
// build products that happen to share a Mach-O magic value. Read bounded headers
// rather than trusting a filename extension. Supports thin and universal code.
static inline bool IPASignableMachO(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) return false;
    struct CloseFile { FILE *file; ~CloseFile() { fclose(file); } } closeFile{file};
    if (fseeko(file, 0, SEEK_END) != 0) return false;
    const off_t length = ftello(file);
    if (length < 16) return false;
    auto read = [&](uint64_t offset, unsigned char *bytes, size_t count) -> bool {
        return offset <= (uint64_t)length && count <= (uint64_t)length - offset &&
            fseeko(file, (off_t)offset, SEEK_SET) == 0 && fread(bytes, 1, count, file) == count;
    };
    auto u32 = [](const unsigned char *p, bool big) -> uint32_t {
        return big ? (uint32_t(p[0]) << 24 | uint32_t(p[1]) << 16 | uint32_t(p[2]) << 8 | p[3]) :
                     (uint32_t(p[3]) << 24 | uint32_t(p[2]) << 16 | uint32_t(p[1]) << 8 | p[0]);
    };
    auto u64 = [&](const unsigned char *p, bool big) -> uint64_t {
        return big ? (uint64_t(u32(p, true)) << 32 | u32(p + 4, true)) :
                     (uint64_t(u32(p + 4, false)) << 32 | u32(p, false));
    };
    auto code = [&](uint64_t offset, uint64_t size, bool &has64) -> bool {
        unsigned char header[16];
        if (size < sizeof(header) || !read(offset, header, sizeof(header))) return false;
        const uint32_t magic = u32(header, true);
        const bool big = magic == 0xfeedface || magic == 0xfeedfacf;
        const bool wide = magic == 0xfeedfacf || magic == 0xcffaedfe;
        if (!wide && magic != 0xfeedface && magic != 0xcefaedfe) return false;
        if (size < (wide ? 32u : 28u)) return false;
        const uint32_t type = u32(header + 12, big);
        if (type != 2 && type != 6 && type != 8) return false; // execute, dylib, bundle
        has64 |= wide;
        return true;
    };
    unsigned char header[8];
    if (!read(0, header, sizeof(header))) return false;
    const uint32_t magic = u32(header, true);
    const bool fat32 = magic == 0xcafebabe || magic == 0xbebafeca;
    const bool fat64 = magic == 0xcafebabf || magic == 0xbfbafeca;
    bool has64 = false;
    if (!fat32 && !fat64) return code(0, (uint64_t)length, has64) && has64;
    const bool big = magic == 0xcafebabe || magic == 0xcafebabf;
    const uint32_t count = u32(header + 4, big);
    const uint64_t stride = fat64 ? 32 : 20, tableEnd = 8 + uint64_t(count) * stride;
    if (count == 0 || count > 64 || tableEnd > (uint64_t)length) return false;
    for (uint32_t index = 0; index < count; ++index) {
        unsigned char arch[32];
        if (!read(8 + uint64_t(index) * stride, arch, (size_t)stride)) return false;
        const uint64_t offset = fat64 ? u64(arch + 8, big) : u32(arch + 8, big);
        const uint64_t size = fat64 ? u64(arch + 16, big) : u32(arch + 12, big);
        if (offset < tableEnd || offset > (uint64_t)length || size > (uint64_t)length - offset || !code(offset, size, has64)) return false;
    }
    return has64;
}
