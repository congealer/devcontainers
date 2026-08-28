
# ROHD (Rapid Open Hardware Development) (rohd)

A ROHD hardware design project: a pinned Dart SDK, a transaction-level testbench, reproducible SystemVerilog output, and workarounds for the ROHD gaps you would otherwise hit on day one.

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| projectName | Dart package name for this project. Must be lowercase_with_underscores; it becomes the package that `bin/` and `test/` import. | string | my_design |
| description | One line describing the project, written into pubspec.yaml. | string | A ROHD hardware design. |
| dartVersion | Dart SDK version to pin. Must satisfy the `sdk:` constraint in pubspec.yaml. | string | 3.13.2 |

## 담고 있는 것

| | |
|---|---|
| **고정된 Dart SDK** | 로컬 feature 로 아카이브에서 설치. 컨테이너 생성 시 `pub get` 까지 |
| **`packages/rohd_patches/`** | ROHD 의 빈 곳을 메우는 패치. 인라인되는 산술, 헤더 제어와 파일 출력 |
| **트랜잭션 수준 테스트벤치** | 손으로 계산한 타임스탬프 없이 의도를 기술하는 예제 |
| **재현 가능한 RTL** | 다시 돌려도 바이트 단위로 같은 SystemVerilog |
| **ROHD 에 맞춘 lint** | DSL 이 상시 위반하는 규칙은 끄고, 비동기 버그를 잡는 규칙은 켬 |
| **에디터 연동** | 파형(`.vcd`)과 SystemVerilog 확장이 함께 설치됨 |

`dartVersion` 은 `3.13.2`(기본값)와 `3.12.2` 중에 고를 수 있습니다. 둘 다 스모크 테스트를
통과합니다. 목록에 없는 버전을 넣어도 되지만 `pubspec.yaml` 의 `sdk: ^3.12.2` 를 만족해야
합니다.

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
  --template-args '{"projectName":"my_design","dartVersion":"3.13.2"}'
```

**`projectName` 은 `lowercase_with_underscores` 여야 합니다.** 그대로 Dart 패키지 이름이
되기 때문입니다. 하이픈을 넣으면 적용은 되지만 컨테이너를 띄울 때 `pub get` 이 이렇게
실패합니다:

```
Error on line 1, column 7 of pubspec.yaml: "name" field must be a valid Dart identifier.
```

디렉터리 이름까지 맞출 필요는 없습니다 — `rohd-practice/` 안에 `rohd_practice` 패키지여도
됩니다.

VS Code 에서는 명령 팔레트의 **Dev Containers: New Dev Container...** 로도 됩니다.

만들어진 프로젝트를 쓰는 방법은 `docs/rohd.md` 에 있습니다 — 이 파일과 `README.md` 는
적용할 때 결과 프로젝트로 복사되지 않습니다.


---

_Note: This file was auto-generated from the [devcontainer-template.json](https://github.com/congealer/devcontainers/blob/main/src/rohd/devcontainer-template.json).  Add additional notes to a `NOTES.md`._
