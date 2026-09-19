# Task 001 — Implement `dma::Range` for Rust-for-Linux

## 1. Upstream Task

**Project:** Rust for Linux  
**Issue:** #1248 — `DMA: implement a dma::Range type`  
**Area:** Rust kernel abstractions / DMA / device resources  
**Difficulty:** Good first issue / Easy  
**Status when this task was selected:** Open, unassigned

This task implements a safer representation of DMA address ranges in the Rust kernel abstractions.

The objective is not simply to introduce a convenience wrapper around a DMA address. The new type must establish and preserve an important safety invariant:

> Safe Rust code must not be able to derive a DMA address or DMA sub-range outside the DMA allocation represented by the range.

---

# 2. Background

Linux drivers frequently allocate coherent memory that is accessible by both the CPU and a device.

Conceptually, a coherent DMA allocation gives the driver two related values:

```text
CPU virtual address
        +
DMA/device-visible address
```

The CPU uses the virtual address.

The hardware device uses the DMA address.

For example, a driver may allocate a 4 KiB coherent region:

```text
DMA base address: 0x1000
Length:           0x1000 bytes

Valid DMA range:

0x1000 ------------------------ 0x1fff
        4096 bytes
```

A driver may then divide this memory into smaller structures:

```text
0x1000  descriptor 0
0x1040  descriptor 1
0x1080  descriptor 2
...
```

It therefore needs to derive DMA addresses from the allocation's base DMA address.

---

# 3. Existing Problem

The current Rust DMA abstraction exposes a DMA address using an integer-like DMA address type.

Conceptually, driver code can end up performing operations equivalent to:

```rust
let descriptor_dma = dma_base + offset;
```

This creates two related problems.

## 3.1 Out-of-range address calculation

Consider:

```text
base = 0x1000
len  = 0x1000
```

The valid range is:

```text
[0x1000, 0x2000)
```

This is valid:

```text
base + 0x800 = 0x1800
```

This is not:

```text
base + 0x2000 = 0x3000
```

However, when the DMA address is handled as a bare integer, the type itself does not know the size of the allocation.

It therefore cannot determine whether an offset belongs to the original allocation.

---

## 3.2 Integer overflow

Bounds checking alone is not sufficient.

Suppose the DMA address is close to the maximum value representable by `dma_addr_t`.

For example:

```text
base = MAX - 0x0f
```

Then:

```text
base + 0x0f
```

may still be representable, while:

```text
base + 0x10
```

may overflow.

Unchecked integer arithmetic could wrap around and produce a seemingly valid but completely unrelated DMA address.

Therefore every operation must validate both:

1. allocation bounds;
2. arithmetic overflow.

---

# 4. Goal

Introduce a Rust DMA range abstraction that couples:

```text
DMA base address
+
allocation length
```

into one object.

Conceptually:

```rust
pub struct Range {
    base: Address,
    len: usize,
}
```

The exact upstream API must be determined after inspecting the current Rust DMA abstractions and following existing Rust-for-Linux conventions.

The important part is not the exact method names.

The important part is the invariant maintained by the type.

---

# 5. Core Invariant

For a DMA range:

```text
Range(base, len)
```

the represented address interval is:

```text
[base, base + len)
```

Any DMA address returned through safe operations on the range must satisfy:

```text
base <= address < base + len
```

Any sub-range returned through safe operations must be completely contained within the parent range.

Conceptually:

```text
parent.start <= child.start

child.end <= parent.end
```

All arithmetic involved in establishing these conditions must also be checked for overflow.

---

# 6. Desired Safety Model

The primary benefit is not that Rust magically knows DMA addresses at compile time.

DMA addresses are normally runtime values.

For example:

```text
boot
 ↓
DMA allocator / IOMMU
 ↓
device receives some DMA address
 ↓
driver creates Range
```

The compiler cannot know that address beforehand.

Instead, the Rust abstraction should provide two layers of protection.

## Compile-time protection

Safe driver code should not have unrestricted access to the raw internals necessary to construct arbitrary DMA addresses.

Instead of doing:

```rust
base + offset
```

a driver should be encouraged or required to use a checked API.

Conceptually:

```rust
range.address_at(offset)
```

This centralizes DMA address arithmetic.

## Runtime validation

Because `offset`, `base`, and `len` may be runtime values, the range implementation must perform runtime checks.

For example:

```text
Is offset inside the allocation?

Does offset + length fit within the allocation?

Does base + offset overflow dma_addr_t?
```

The combination is the important part:

```text
Rust type/API design
        +
checked runtime arithmetic
```

---

# 7. Potential API Shape

The upstream issue does not require a specific public API.

The following is therefore only a design sketch.

Possible operations might include:

```rust
Range::new(base, len)
```

```rust
range.address_at(offset)
```

```rust
range.subrange(offset, len)
```

The final API should be based on:

- existing `kernel::dma` conventions;
- existing Rust range/resource abstractions;
- maintainer feedback;
- minimal API surface.

Do not implement unnecessary convenience functions merely because they might be useful later.

The first patch should solve the exact current problem.

---

# 8. Example Semantics

Assume:

```text
base = 0x1000
len  = 0x1000
```

Therefore:

```text
range = [0x1000, 0x2000)
```

## Address lookup

Expected valid cases:

```text
offset 0x000
→ 0x1000

offset 0x001
→ 0x1001

offset 0xfff
→ 0x1fff
```

Expected invalid cases:

```text
offset 0x1000
→ error

offset 0x1001
→ error

offset 0x2000
→ error
```

The most important boundary condition is:

```text
offset == len - 1
→ valid

offset == len
→ invalid
```

---

# 9. Sub-range Semantics

Assume again:

```text
Range(0x1000, 0x1000)
```

A sub-range:

```text
offset = 0x200
length = 0x100
```

would represent:

```text
Range(0x1200, 0x100)
```

This is valid.

A sub-range:

```text
offset = 0xf00
length = 0x100
```

ends exactly at the parent's end and should normally be valid:

```text
[0x1f00, 0x2000)
```

However:

```text
offset = 0xf00
length = 0x101
```

would exceed the parent range and must fail.

---

# 10. Avoiding Overflow in Bounds Checks

A naive check such as:

```rust
if offset + length <= self.len {
    ...
}
```

may itself overflow.

Therefore the implementation should use overflow-safe arithmetic.

For example, depending on the surrounding kernel style:

```rust
offset.checked_add(length)
```

or an equivalent formulation such as:

```text
offset <= total_length
length <= total_length - offset
```

The same principle applies when translating an offset into a DMA address.

Conceptually:

```text
base.checked_add(offset)
```

must succeed before an address is returned.

---

# 11. Construction Invariant

One design decision to investigate is whether an invalid range should be rejected when the `Range` object is created.

For example:

```text
base = dma_addr_t::MAX - 10
len  = 20
```

The represented end address cannot be expressed without overflow.

A strong design would reject this at construction time.

That would establish:

> Every successfully constructed `Range` represents a valid DMA address interval.

This significantly simplifies reasoning about later operations.

However, the exact representation of the end of a half-open range must be considered carefully.

For example, a one-byte allocation at the highest representable DMA address may raise subtle questions if the implementation tries to explicitly represent `base + len`.

Therefore the implementation should avoid making assumptions about the representation before examining existing kernel DMA types and discussing the intended semantics if necessary.

---

# 12. Zero-Length Ranges

Zero-length ranges require an explicit decision.

Questions to investigate include:

```text
Is Range(base, 0) valid?

Is subrange(len, 0) valid?

Should an empty range have a usable DMA address?

Can address_at() ever succeed on an empty range?
```

Do not guess.

Check:

- Rust-for-Linux conventions;
- similar resource range abstractions;
- Linux DMA semantics;
- maintainer expectations.

The chosen behavior must be tested.

---

# 13. Non-Goals

This task should remain deliberately small.

The following are not goals unless required by the upstream maintainers.

## No DMA allocator redesign

Do not redesign:

```text
dma_alloc_coherent()
```

or the Rust coherent allocation abstraction.

---

## No new DMA subsystem functionality

Do not add unrelated features such as:

```text
streaming DMA mapping
scatter/gather abstractions
DMA pools
IOMMU management
DMA engine APIs
```

---

## No speculative driver conversion

Do not convert unrelated drivers to the new API merely to demonstrate usage unless an in-tree consumer is explicitly required by review.

---

## No premature generalization

Do not create a generic framework for every possible address range in the kernel.

The task specifically concerns DMA address ranges.

---

# 14. Initial Investigation

Before writing code, inspect the current Rust DMA implementation.

Suggested searches:

```bash
grep -R "DmaAddress" -n rust drivers
```

```bash
grep -R "struct Coherent" -n rust drivers
```

```bash
find rust/kernel -iname '*dma*'
```

Questions to answer:

1. Where is `DmaAddress` currently defined?
2. Is it a type alias or a newtype?
3. Which APIs currently return it?
4. Which Rust drivers perform arithmetic on it?
5. Is `dma::Address` already defined separately?
6. What integer type backs it?
7. Are there existing range/resource abstractions with similar semantics?
8. What error type should checked operations return?
9. Does the Rust DMA module already contain unit tests or doctests?
10. Is there an existing convention for checked address arithmetic?

The implementation should follow existing patterns rather than inventing a local style.

---

# 15. Development Branch

The implementation should be developed on top of the current Rust-for-Linux integration branch.

Example:

```bash
git fetch rust
git switch -c dma-range rust/rust-next
```

Before submitting, refresh against the appropriate current upstream branch if required.

---

# 16. Validation Strategy

Validation has four levels.

```text
Level 1
Static/build validation

Level 2
Focused Rust/KUnit tests

Level 3
QEMU ARM64 kernel validation

Level 4
Raspberry Pi 5 ARM64 hardware validation
```

The goal is to establish confidence from both pure boundary testing and real kernel execution.

---

# 17. Level 1 — Build and Static Validation

The patch must compile in the normal Rust kernel configuration.

At minimum:

```bash
make O=out ARCH=arm64 LLVM=1 olddefconfig
```

```bash
make O=out ARCH=arm64 LLVM=1 -j"$(nproc)" Image modules
```

Rust-specific development checks should also be run as applicable.

For example:

```bash
make O=out ARCH=arm64 LLVM=1 CLIPPY=1
```

If documentation is added or modified, run the applicable Rust documentation tests.

Also run the kernel's patch checking tools before submission.

No new warnings should be introduced.

---

# 18. Level 2 — Focused Boundary Tests

The range implementation should have automated tests covering its invariants.

At minimum, test the following.

## Address tests

### Case 1 — first byte

```text
offset = 0
```

Expected:

```text
success
address == base
```

### Case 2 — last valid byte

```text
offset = len - 1
```

Expected:

```text
success
```

### Case 3 — first invalid byte

```text
offset = len
```

Expected:

```text
failure
```

### Case 4 — clearly outside the range

```text
offset > len
```

Expected:

```text
failure
```

---

# 19. Sub-range Tests

## Full parent range

```text
offset = 0
length = parent.len
```

Expected:

```text
success
```

## Sub-range in the middle

```text
offset = 0x100
length = 0x100
```

Expected:

```text
success
```

## Sub-range ending exactly at the parent end

```text
offset + length == parent.len
```

Expected:

```text
success
```

## Sub-range extending one byte beyond the parent

```text
offset + length == parent.len + 1
```

Expected:

```text
failure
```

## Offset already outside the parent

Expected:

```text
failure
```

---

# 20. Arithmetic Overflow Tests

These are essential.

The patch is incomplete if it only tests logical bounds.

Test DMA addresses near the maximum value representable by the underlying DMA address type.

Conceptually:

```text
MAX = dma_addr_t::MAX
```

Then test cases such as:

```text
base = MAX - 0x0f
offset = 0x0f

→ valid if representable
```

and:

```text
base = MAX - 0x0f
offset = 0x10

→ must fail
```

Also test malicious or extreme sub-range inputs where:

```text
offset + length
```

would overflow a `usize`.

The implementation must not rely on an arithmetic expression that can wrap before the bounds check occurs.

---

# 21. Test Matrix

The initial target matrix is:

| Test | Expected |
|---|---|
| `address_at(0)` | PASS |
| `address_at(len - 1)` | PASS |
| `address_at(len)` | FAIL |
| `address_at(len + 1)` | FAIL |
| full-size sub-range | PASS |
| sub-range ending exactly at end | PASS |
| sub-range ending one byte past end | FAIL |
| offset outside parent | FAIL |
| `offset + length` overflow | FAIL |
| DMA address overflow | FAIL |
| zero-length behavior | Defined and tested |

---

# 22. Level 3 — QEMU ARM64 Validation

`kernel-lab` already provides the first-stage test environment:

```text
Debian host
    ↓
ARM64 cross-build
    ↓
QEMU virt / ARM64
    ↓
minimal ARM64 initramfs
```

The kernel should boot using:

```bash
./qemu/run.sh
```

The current known-good baseline reaches:

```text
Rust for Linux - QEMU ARM64

BusyBox shell
~ #
```

After adding the DMA range tests, boot the patched kernel in exactly the same environment.

Expected conditions:

```text
kernel boots successfully
Rust support initializes successfully
KUnit tests execute
all dma::Range tests pass
no WARN/OOPS/panic caused by the patch
userspace init is reached
```

Preserve the QEMU output if useful for the patch testing notes.

---

# 23. Level 4 — Raspberry Pi 5 Validation

The second-stage target is a Raspberry Pi 5.

Architecture:

```text
arm64
```

The purpose of this stage is not to prove the arithmetic logic itself; the focused tests already do that.

The purpose is to verify that the changed Rust DMA abstraction works in a real ARM64 kernel configuration on physical hardware.

Test sequence:

```text
build patched ARM64 kernel
        ↓
deploy kernel to Raspberry Pi 5
        ↓
boot physical hardware
        ↓
run/observe same tests
        ↓
inspect dmesg
```

Expected:

```text
normal boot
no Rust-related regression
no DMA-related warnings caused by the patch
all relevant tests pass
```

Where practical, enable:

```text
CONFIG_DMA_API_DEBUG=y
```

for additional DMA misuse detection during development.

This is supplementary validation, not a substitute for the range-specific tests.

---

# 24. Regression Principle

Tests must demonstrate that:

```text
existing valid operations
continue to work
```

while:

```text
previously unchecked invalid operations
are rejected
```

The patch should not alter unrelated DMA behavior.

---

# 25. API Review Questions

Before finalizing the implementation, answer these questions:

### Representation

Should `Range` store:

```text
base + len
```

or:

```text
start + end
```

or some other representation?

### Error handling

Should invalid access return:

```text
Option
Result
```

or use another existing kernel Rust convention?

### Visibility

Which constructors or fields should be public?

Ideally, safe callers should not be able to violate the invariant by directly modifying internal fields.

### Empty ranges

What is the exact semantic meaning of an empty DMA range?

### Address exposure

Does returning a raw DMA address undermine the intended safety property?

If the raw address must eventually be provided to hardware, determine the narrowest sensible API boundary.

### Existing users

Should an existing `Coherent` method begin returning a `Range`, or should `Range` initially be an independent abstraction?

Do not make this decision solely from the issue title; inspect the current API and upstream expectations.

---

# 26. Coding Principles

The implementation should favor:

```text
small API
clear invariants
checked arithmetic
private representation
minimal unsafe code
no speculative abstractions
```

Prefer making invalid states difficult or impossible to construct through safe Rust.

Any `unsafe` block must have a clear safety justification consistent with Rust-for-Linux conventions.

---

# 27. Commit Scope

Ideally the final patch should be small enough to review as one logical change.

Possible contents:

```text
Rust DMA Range type
+
focused tests
+
documentation for public APIs
```

Avoid mixing unrelated cleanup.

If prerequisite cleanup becomes necessary, determine whether it should be a separate patch in the series.

---

# 28. Commit Message Requirements

The commit message should explain:

1. what is unsafe or unchecked about the existing API;
2. why coupling the DMA address with its length fixes the abstraction problem;
3. what invariant `Range` guarantees;
4. how overflow is handled;
5. how the change was tested.

The upstream issue specifically requests a proper Linux kernel patch with Developer's Certificate of Origin sign-off.

Therefore commits must use:

```bash
git commit -s
```

The final commit message should also contain the requested upstream metadata, including:

```text
Suggested-by: ...
Link: ...
```

using the exact author information and canonical issue link appropriate for the upstream submission.

Do not invent these tags.

Retrieve the exact values from the upstream issue when preparing the final patch.

---

# 29. Pre-Submission Checklist

Before sending:

```text
[ ] Based on current Rust-for-Linux development branch
[ ] Builds successfully with LLVM
[ ] CONFIG_RUST enabled
[ ] No new compiler warnings
[ ] Clippy checked where applicable
[ ] Rust documentation generated/tested where applicable
[ ] Boundary tests pass
[ ] Overflow tests pass
[ ] QEMU ARM64 passes
[ ] Raspberry Pi 5 passes
[ ] checkpatch passes
[ ] Commit is Signed-off-by
[ ] Suggested-by tag added correctly
[ ] Link tag added correctly
[ ] Patch rebased onto appropriate current branch
[ ] Relevant maintainers/lists determined
```

---

# 30. Submission Workflow

Use `b4` rather than manually assembling the entire mail workflow.

Conceptually:

```text
implementation
    ↓
tests
    ↓
commit -s
    ↓
b4 preparation
    ↓
check recipients
    ↓
send patch
    ↓
review feedback
    ↓
v2 / v3 if needed
```

Do not send the first working implementation immediately.

First review:

```text
git diff
git show
```

and run the complete test matrix.

---

# 31. Definition of Done

This task is complete when all of the following are true.

## Functional

A `dma::Range` abstraction exists that associates:

```text
DMA base address
+
length
```

and safe operations cannot return addresses or sub-ranges outside the represented allocation.

## Arithmetic safety

All relevant arithmetic is checked for:

```text
range bounds
+
underlying DMA address overflow
```

## Testing

Automated tests cover:

```text
start boundary
end boundary
out-of-range offsets
valid sub-ranges
invalid sub-ranges
integer overflow
DMA address overflow
zero-length semantics
```

## QEMU

The patched ARM64 kernel boots in the `kernel-lab` QEMU environment and all relevant tests pass.

## Physical hardware

The same kernel changes are validated on the Raspberry Pi 5 with no observed regression.

## Upstream quality

The patch:

```text
builds cleanly
follows Rust-for-Linux style
contains required documentation
contains required DCO sign-off
contains upstream-requested tags
passes applicable checks
```

and is ready to submit to the Linux kernel mailing lists.

---

# 32. Why This Task Matters

DMA addresses are not ordinary integers from a driver's perspective.

They represent access to a specific region of memory that has been made visible to a hardware device.

Losing the relationship between:

```text
DMA address
```

and:

```text
allocation length
```

forces every driver author to manually maintain the same invariant.

That creates opportunities for:

```text
out-of-bounds device access
incorrect descriptor addresses
integer overflow
hard-to-debug hardware corruption
```

A well-designed Rust abstraction moves the invariant from individual drivers into one reusable kernel API.

Instead of every driver having to remember:

```text
check the offset
check the length
check integer overflow
```

the type itself becomes the boundary through which safe DMA address derivation occurs.

That is precisely the kind of problem Rust kernel abstractions are intended to solve.

---

# 33. Development Environment

Current test topology:

```text
                 Debian development host
                         │
                         │ LLVM / Rust
                         │
                    Linux kernel
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
        QEMU ARM64              Raspberry Pi 5
       first-stage test         second-stage test
              │                     │
              └──────────┬──────────┘
                         │
                   upstream patch
```

Repository responsibilities:

```text
linux/
    Rust-for-Linux kernel source
    dma::Range implementation
    kernel tests

kernel-lab/
    kernel build helpers
    QEMU runner
    ARM64 initramfs builder
    Raspberry Pi 5 deployment/testing helpers
```

The kernel source and test infrastructure should remain separate.
