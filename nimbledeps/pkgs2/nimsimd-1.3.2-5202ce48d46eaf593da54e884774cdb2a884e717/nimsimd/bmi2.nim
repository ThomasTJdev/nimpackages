{.push header: "immintrin.h".}

func bzhi_u32*(a: uint32, index: uint32): uint32 {.importc: "_bzhi_u32".}
func bzhi_u64*(a: uint64, index: uint32): uint64 {.importc: "_bzhi_u64".}

func mulx_u32*(a, b: uint32; hi: ptr uint32): uint32 {.importc: "_mulx_u32".}
func mulx_u64*(a, b: uint64; hi: ptr uint64): uint64 {.importc: "_mulx_u64".}

func pext_u32*(a, mask: uint32): uint32 {.importc: "_pext_u32".}
func pext_u64*(a, mask: uint64): uint64 {.importc: "_pext_u64".}

func pdep_u32*(a, mask: uint32): uint32 {.importc: "_pdep_u32".}
func pdep_u64*(a, mask: uint64): uint64 {.importc: "_pdep_u64".}

{.pop.}
