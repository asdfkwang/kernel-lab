# DMA Range 설계 메모 (001)

## 1. Upstream 이슈
- `Rust-for-Linux/linux#1248` — `DMA: implement a dma::Range type`
- 작성: Danilo Krummrich (`dakr`), 2026-07-25, Open / unassigned
- 라벨: `device resources`, `easy`, `good first issue`
- 본문 요지:
  - 현재 `dma::Coherent`는 `type DmaAddress = bindings::dma_addr_t` bare integer만 제공
  - 드라이버의 `base + offset` 연산이 unchecked
  - `base dma::Address + len` 결합해서 `[base, base+len)` 안에 증명되는 주소/서브레인지만 내주는 `dma::Range` 추가
  - 모든 연산은 길이 + `dma_addr_t` overflow 둘 다 체크
- 제출 요구: ML 정식 패치, DCO `Signed-off-by`, `Suggested-by:` + `Link:` to issue, doctest/문서 테스트

## 2. 현재 모듈 상태 (`linux/rust/kernel/dma.rs`)
- `dma.rs:50`: `pub type DmaAddress = bindings::dma_addr_t;` (u32 or u64, `CONFIG_ARCH_DMA_ADDR_T_64BIT`)
- `dma::Address` 타입 없음 → 이슈 본문의 `dma::Address` vs 실제 `DmaAddress` 네이밍 결정 필요
- `Range` 타입 없음
- bare 반환 3곳: `Coherent::dma_address:632`, `CoherentHandle::dma_address:1065`, `CoherentView::dma_address:1127`
- unchecked 연산: `CoherentIoBackend::project_view:1181`
  ```rust
  let dma_addr = view.dma_addr + offset as DmaAddress; // "can never overflow"
  ```
- `rust/` 내 `dma_address()` 호출자 없음 (정의 + `scatterlist.rs:86` wrapper만) → 1차 패치는 독립 타입으로 가능
- 참고 패턴: `rust/kernel/io/resource.rs:30 Region` (private 필드 + invariant 문서화)
- 에러 관례: `dma.rs`는 `Result` + `EINVAL/ENOMEM`, `resource.rs`는 `Option`
- zero-length 관례: `alloc_slice_with_attrs:792`, `CoherentHandle::alloc:1020` 둘 다 `len==0 → EINVAL`
- `dma.rs` 내 KUnit/doctest 없음 (`DmaMask` doctest 제외)

## 3. 최소 API 스케치

삽입 위치: `DmaAddress:50` 직후.

```rust
/// # Invariants
/// - `len > 0`, `base + (len-1)` 반드시 표현 가능.
///   `[base, base+len)` 이 항상 유효한 구간.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Range {
    base: DmaAddress, // private
    len: usize,       // private, 바이트 단위
}

impl Range {
    pub fn new(base: DmaAddress, len: usize) -> Result<Self> {
        if len == 0 { return Err(EINVAL); }
        let len_addr = DmaAddress::try_from(len).map_err(|_| EINVAL)?;
        base.checked_add(len_addr - 1).ok_or(EINVAL)?;
        Ok(Self { base, len })
    }

    pub fn base(&self) -> DmaAddress { self.base }
    pub fn size(&self) -> usize { self.len }

    pub fn address_at(&self, offset: usize) -> Result<DmaAddress> {
        if offset >= self.len { return Err(EINVAL); }
        let off = DmaAddress::try_from(offset).map_err(|_| EINVAL)?;
        self.base.checked_add(off).ok_or(EINVAL)
    }

    pub fn subrange(&self, offset: usize, len: usize) -> Result<Self> {
        if len == 0 { return Err(EINVAL); }
        let end = offset.checked_add(len).ok_or(EINVAL)?;
        if end > self.len { return Err(EINVAL); }
        let off = DmaAddress::try_from(offset).map_err(|_| EINVAL)?;
        let base = self.base.checked_add(off).ok_or(EINVAL)?;
        Ok(Self { base, len })
    }
}
```

### 설계 근거
- `base(DmaAddress)+len(usize)`: `Coherent::size():613`, `CoherentHandle::size:1071`이 `usize`라 정합
- `size()`命名: `Coherent::size`, `Resource::size` 관례 + clippy `len_without_is_empty` 회피
- `len==0 → EINVAL`: 기존 alloc 관례 따름, empty 존재 자체를 금지하면 `address_at` on empty 문제 소멸
- 생성시 `checked_add(len-1)` 기준: `MAX`번지 1바이트 `[MAX,MAX+1)` 살리기 위함 (`checked_add(len)`이면 오거부)
- `usize→DmaAddress try_from`: 64bit `usize` vs u32 `dma_addr_t` 폭 불일치 대비
- `subrange`의 `offset.checked_add(len)` 선검사: naive `offset+len <= self.len` 랩 방지

### 의미 예시
```text
Range(0x1000, 0x1000) = [0x1000, 0x2000)
address_at(0xfff) → 0x1fff OK
address_at(0x1000) → EINVAL
subrange(0xf00,0x100) → [0x1f00,0x2000) OK
subrange(0xf00,0x101) → EINVAL
```

## 4. 최소성 판단
- 이슈가 `addresses + sub-ranges` 둘 다 요구 → `address_at`, `subrange` 둘 다 필수
- `new` 필수, `base()/size()`는 관례상 조회용 최소 포함
- 제외 (v2/후속): `Coherent::dma_range()`, `project_view:1181` 교체, `contains()`/이터레이터/`Deref`/generic 프레임워크, 드라이버 전환, streaming/scatterlist

## 5. 다음 단계
- [ ] 브랜치: `dma-range-001` on `rust/rust-next` (완료)
- [ ] 빌드: `scripts/build-kernel.sh` (진행중)
- [ ] `dma.rs:50` 직후 `Range` 구현 + `DmaMask`식 doctest (§21 매트릭스)
- [ ] L1: build + `CLIPPY=1` + `checkpatch`, warning 0
- [ ] L2: 경계/오버플로우/zero-length 테스트
- [ ] L3: `./qemu/run.sh` 부팅 + KUnit
- [ ] L4: RPi5 실기 + `dmesg` (`CONFIG_DMA_API_DEBUG=y` 권장)
- [ ] 제출: `git commit -s` + `Suggested-by/Link` (Danilo 실 주소는 `git log`에서 확인할 것) + `b4`
