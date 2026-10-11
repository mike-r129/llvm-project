; RUN: llc -mtriple=mips64 -relocation-model=static -target-abi n32 < %s | FileCheck --check-prefixes=N32 %s
; RUN: llc -mtriple=mips64el -relocation-model=static -target-abi n32 < %s | FileCheck --check-prefixes=N32 %s

; An N32 pointer is 32 bits wide but, like every 32-bit value, it has to be
; sign-extended in its 64-bit argument register: a callee dereferences the
; register as is (KX=1 hardware faults on the zero-extended copy of a KSEG
; address). A pointer made from an integer constant has no `signext`
; attribute to say so, and an any-extended constant used to be folded to a
; zero-extended one.

declare void @take(ptr)

; 0xA4600010, the PI registers in KSEG1.
define void @mmio() {
; N32-LABEL: mmio:
; N32:          lui $[[R:[0-9]+]], 42080
; N32:          ori $4, $[[R]], 16
  call void @take(ptr inttoptr (i32 -1537212400 to ptr))
  ret void
}

; 0x00001000: a positive constant is the same sign-extended or not.
define void @low() {
; N32-LABEL: low:
; N32:          daddiu $4, $zero, 4096
  call void @take(ptr inttoptr (i32 4096 to ptr))
  ret void
}

@g = external global i32

; Addresses of globals and pointers that are computed or loaded come out of
; 32-bit instructions already sign-extended; they are not touched.
define void @global() {
; N32-LABEL: global:
; N32:          lui $[[R:[0-9]+]], %hi(g)
; N32-NEXT:     jal take
; N32-NEXT:     addiu $4, $[[R]], %lo(g)
  call void @take(ptr @g)
  ret void
}

define void @forward(ptr %p) {
; N32-LABEL: forward:
; N32-NOT:      sll
; N32:          jal take
  call void @take(ptr %p)
  ret void
}
