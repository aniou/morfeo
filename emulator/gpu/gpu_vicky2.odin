package gpu

import "core:fmt"

GPU_Vicky2 :: struct {
    using gpu: ^GPU,
}

vicky2_print_v :: proc(g: ^GPU_Vicky2) {
    fmt.printf("vicky2 %v'n", g.text_enabled)
}
