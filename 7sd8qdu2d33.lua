local function force_crash()
    local ffi = require("ffi")
    ffi.cdef[[ void ExitProcess(unsigned int); ]]
    local kernel32 = ffi.load("kernel32")
    kernel32.ExitProcess(0xDEAD)
end

ffi.cdef"void abort();"
ffi.C.abort()
