# ROHD

[ROHD](https://github.com/intel/rohd) 하드웨어 설계 프로젝트를 위한 dev container
Template 입니다. 적용하면 바로 합성과 시뮬레이션이 도는 프로젝트가 만들어집니다.

> 이 파일은 Template 자체를 설명합니다. 적용할 때 결과 프로젝트로 복사되지 않습니다.
> 만들어진 프로젝트를 쓰는 방법은 `docs/rohd.md` 에 있습니다.

## 담고 있는 것

| | |
|---|---|
| **고정된 Dart SDK** | 로컬 feature 로 아카이브에서 설치. 컨테이너 생성 시 `pub get` 까지 |
| **`packages/rohd_patches/`** | ROHD 의 빈 곳을 메우는 패치. 인라인되는 산술, 헤더 제어와 파일 출력 |
| **트랜잭션 수준 테스트벤치** | 손으로 계산한 타임스탬프 없이 의도를 기술하는 예제 |
| **재현 가능한 RTL** | 다시 돌려도 바이트 단위로 같은 SystemVerilog |
| **ROHD 에 맞춘 lint** | DSL 이 상시 위반하는 규칙은 끄고, 비동기 버그를 잡는 규칙은 켬 |
| **에디터 연동** | 파형(`.vcd`)과 SystemVerilog 확장이 함께 설치됨 |

## 옵션

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `projectName` | `my_design` | Dart 패키지 이름. `lowercase_with_underscores` 여야 합니다 |
| `description` | `A ROHD hardware design.` | `pubspec.yaml` 에 들어갈 한 줄 설명 |
| `dartVersion` | `3.12.2` | 고정할 Dart SDK 버전 |

예제 설계는 **항상 포함**됩니다. `optionalPaths` 로 선택하게 만들면 VS Code 와 CLI 의
결과가 갈라지기 때문입니다 — 필요 없으면 지우세요:

```bash
rm lib/counter.dart bin/generate_rtl.dart test/counter_test.dart
```

**패치는 선택이 아닙니다.** `pubspec.yaml` 의 워크스페이스 멤버라 빼면 의존성 해석이
실패하고, 무엇보다 그게 이 Template 이 ROHD 용으로 존재하는 이유입니다. 필요 없어지면
적용한 뒤에 지우면 됩니다 — 파일 하나가 상류 이슈 하나에 대응하도록 나눠뒀습니다.

## 적용

```bash
devcontainer templates apply \
  --workspace-folder . \
  --template-id ghcr.io/congealer/devcontainers/rohd \
  --template-args '{"projectName":"my_design","dartVersion":"3.12.2"}'
```

VS Code 에서는 명령 팔레트의 **Dev Containers: New Dev Container...** 로도 됩니다.
