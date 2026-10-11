//===- MipsMulMulBugPass.cpp - Mips VR4300 mulmul bugfix pass -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Early revisions of the VR4300 have a hardware bug where two consecutive
// multiplications can produce an incorrect result in the second multiply.
//
// The first multiply is a single or double-precision floating-point mul
// instruction. The second one can be a mul of any kind (mul.s, mul.d, mult,
// multu, dmult, dmultu), and it is the next instruction executed: in the same
// basic block, at the start of a fall-through or branch target block, or, if
// the first one is in a delay slot, at the branch target or after the return
// in the caller. Any instruction in between avoids the bug.
//
// Like GCC's -mfix4300, this pass follows every single or double-precision
// floating-point mul instruction with a nop, so the next instruction executed
// is never a multiply. The nop has unmodeled side effects, so the delay slot
// filler, which runs after this pass, does not move the mul past it into a
// delay slot either.
//===----------------------------------------------------------------------===//

#include "Mips.h"
#include "MipsInstrInfo.h"
#include "MipsSubtarget.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/Support/Debug.h"
#include "llvm/Target/TargetMachine.h"

#define DEBUG_TYPE "mips-vr4300-mulmul-fix"

using namespace llvm;

namespace {

class MipsMulMulBugFix : public MachineFunctionPass {
public:
  MipsMulMulBugFix() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "Mips VR4300 mulmul bugfix"; }

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setNoVRegs();
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  static char ID;

private:
  bool fixMulMulBB(MachineBasicBlock &MBB, const MipsInstrInfo &MipsII);
};

} // namespace

INITIALIZE_PASS(MipsMulMulBugFix, "mips-vr4300-mulmul-fix",
                "Mips VR4300 mulmul bugfix", false, false)

char MipsMulMulBugFix::ID = 0;

bool MipsMulMulBugFix::runOnMachineFunction(MachineFunction &MF) {
  const MipsInstrInfo &MipsII =
      *static_cast<const MipsInstrInfo *>(MF.getSubtarget().getInstrInfo());

  bool Modified = false;

  for (auto &MBB : MF)
    Modified |= fixMulMulBB(MBB, MipsII);

  return Modified;
}

static bool isFirstMul(const MachineInstr &MI) {
  switch (MI.getOpcode()) {
  case Mips::FMUL_S:
  case Mips::FMUL_D:
  case Mips::FMUL_D32:
  case Mips::FMUL_D64:
    return true;
  default:
    return false;
  }
}

bool MipsMulMulBugFix::fixMulMulBB(MachineBasicBlock &MBB,
                                   const MipsInstrInfo &MipsII) {
  bool Modified = false;

  MachineBasicBlock::instr_iterator NextMII;

  // Iterate through the instructions in the basic block
  for (MachineBasicBlock::instr_iterator MII = MBB.instr_begin(),
                                         E = MBB.instr_end();
       MII != E; MII = NextMII) {

    NextMII = next_nodbg(MII, E);

    // Follow every FPU mul with a nop, also at the end of the block. Looking
    // only at the next instruction in the block is not enough: integer
    // multiplies are still PseudoMULT/PseudoDMULT/... here, the next block can
    // start with a multiply, and the delay slot filler could move the mul
    // into a return or loop branch delay slot.
    if (isFirstMul(*MII)) {
      LLVM_DEBUG(dbgs() << "Found mulmul!\n");

      const MCInstrDesc &NewMCID = MipsII.get(Mips::NOP);
      BuildMI(MBB, NextMII, DebugLoc(), NewMCID);
      Modified = true;
    }
  }

  return Modified;
}

FunctionPass *llvm::createMipsMulMulBugPass() { return new MipsMulMulBugFix(); }
