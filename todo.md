# TODO

`ubuntu` 정리, `rohd` 이식, 그리고 `congealer/devcon-features` 에서 정리한 기법을 이 리포에
가져오는 일까지. **번호는 순서가 아니라 참조용이다.** 순서는 미정.

조사 근거는 각 항목에 파일:줄 로 달아뒀다.

---

## 정해진 것

| | |
|---|---|
| 릴리스 위치 | `ghcr.io/congealer/devcontainers` — `git remote` 와 일치하므로 **리포 개명 불필요** |
| 네임스페이스 | `congealer` 로 통일 (커밋 `08b6e07` 을 되돌리는 방향) |
| CI 정비 시점 | **맨 마지막.** 그 전까지 릴리스는 로컬에서 (`make release`) |
| 개발 워크플로 | `congealer/devcon-features` 방식 이식 — Makefile + `prepare.py` + CI 가 make 호출 |
| rohd 범위 | `rohd-template/src/` 아래만 건진다. `test/rohd/` 는 새로 만든다 |

## 진행 상황

작업 브랜치는 `tidy`.

- [x] **페이즈 1 — hello/color 제거** (`7131ce4`)
      템플릿 둘과 테스트 삭제, 루트 README 목록 정리, `.gitignore` 추가(§5),
      `devcontainer-lock.json` 커밋(§5). CI 는 일부러 안 건드림 — 죽은 필터가 남아 있다.
- [ ] **페이즈 2 — ubuntu 정리** (§3). 절차는 §3-0.
- [ ] 이후 페이즈 미정 (§6 의존성 참고)

---

## 0. 아직 정할 것

- [ ] **`src/*/README.md` 를 자동 생성으로 넘길지 정한다.** → 넘긴다면 §1-3.
      넘기지 않으면 `make docs` 와 release 워크플로의 `generate-docs` 를 둘 다 꺼야 한다.
      **이 결정이 rohd 이식보다 앞선다** (§6 의존성 참고).

- [ ] **release 트리거 정책** — CI 를 붙이는 시점에. 기존은 태그 `v*` + `workflow_dispatch`,
      devcon-features 는 `workflow_dispatch` 전용. 템플릿은 각자
      `devcontainer-template.json` 의 `version` 으로 버전이 매겨지므로 리포 태그와 1:1 이 아니다.

---

## 1. 개발 워크플로 정비 — devcon-features 방식 이식

출처: `rohd-dev/devcon-features/` 의 `Makefile`, `prepare.py`, `CONTRIBUTING.md`,
`.github/workflows/`.

### 1-0. features 와 templates 의 차이 (먼저 읽을 것)

그대로 복사되지 않는다. CLI 0.83.3 으로 확인한 차이:

| | features | templates |
|---|---|---|
| `<kind> test` 서브커맨드 | **있음** | **없음** |
| 시나리오 / `duplicate.sh` | 있음 | 없음 |
| `generate-docs -p` | `src` | `.` (`src` 와 `test` 를 가진 **프로젝트 루트**) |
| `generate-docs -n` | 있음 | **없음** (`--github-owner`/`--github-repo` 만) |
| 생성 틀의 `## Example Usage` | 있음 | **없음** |
| 테스트 라이브러리 | CLI 제공 `dev-container-features-test-lib` | 자체 `test/test-utils/test-utils.sh` |

`devcontainer templates --help` 로 확인한 서브커맨드는 `apply` / `publish` / `metadata` /
`generate-docs` 넷뿐이다.

### 1-1. Makefile 도입

- [ ] **`Makefile` 을 만든다.** devcon-features 것을 뼈대로 하되 테스트 부분은 다시 짠다.

      가져올 것:
      - `.DEFAULT_GOAL := help` + `## ` 주석으로 자기 문서화하는 `help` 타깃
      - `NAMESPACE ?=`, `DEVCONTAINER ?=` 같은 덮어쓸 수 있는 기본값
      - `TEMPLATES := $(notdir $(wildcard src/*))` — 목록을 리포에서 읽는다
      - `require-template` 가드 — 오타난 이름을 CLI 에 넘기기 전에 걸러낸다
      - `clean` / `distclean` — 테스트가 남긴 컨테이너·이미지·빌드 캐시 정리

- [ ] **테스트 타깃을 어떻게 만들지 정한다.** `devcontainer templates test` 가 없으므로
      대응물이 없다. 지금 있는 건 `.github/actions/smoke-test/{build,test}.sh` 뿐이다
      (옵션 default 치환 → `devcontainer up` → `devcontainer exec` 로 `test/<id>/test.sh`).

      두 갈래:
      - Makefile 이 그 두 스크립트를 감싼다 (변경 최소)
      - 로직을 Makefile 로 흡수하고 스크립트를 없앤다 (devcon-features 에 더 가까움)

- [ ] **옵션 조합 테스트 경로를 만든다.** `build.sh` 는 **옵션의 `default` 만 치환한다**
      ([build.sh:20-38](.github/actions/smoke-test/build.sh#L20-L38)). 그래서
      `imageVariant=jammy` 같은 조합을 검증할 방법이 지금 없다 — features 의
      `scenarios.json` 이 하던 자리가 비어 있다. ubuntu 옵션(§3-1)을 제대로 테스트하려면 필요.

- [ ] **`clean` 의 이미지 매칭 패턴을 다시 잡는다.** devcon-features 의 `TEST_IMAGE` 는
      `vsc-<타임스탬프>-<해시>-features` 를 노린 것인데, 템플릿 스모크 테스트는
      `devcontainer up` 이 만드는 폴더 이름 기반 이미지를 남긴다. 패턴이 다르다.

### 1-2. `make prepare` / `make release`

- [ ] **`prepare.py` 를 가져온다.** `devcontainer-feature.json` →
      `devcontainer-template.json` 로 바꾸면 나머지는 그대로 동작한다.
      핵심 로직(버전이 박힌 커밋 이후에 바뀐 템플릿을 git 로그로 찾아 미리 체크)은 템플릿에도
      똑같이 유효하다. 버전만 쓰고 커밋은 사람에게 남긴다.

- [ ] **`make release`** — `gh auth status` 확인 후
      `GITHUB_TOKEN=$(gh auth token) devcontainer templates publish -r ghcr.io -n congealer/devcontainers ./src`.
      docker 불필요.

- [ ] **`make docs`** — 인자가 features 와 다르다:
      `devcontainer templates generate-docs -p . --github-owner congealer --github-repo devcontainers`
      (`-n/--namespace` 없음, `-p` 는 `src` 가 아니라 프로젝트 루트)

- [ ] **릴리스 전 체크리스트를 문서화한다** (CONTRIBUTING.md, §1-4):
      - **`version` 이 발행 여부를 정하는 유일한 스위치다.** 안 올리면 조용히 아무 일도 안 일어난다
      - **태그가 움직인다.** `1.3.0` 을 올리면 `1.3.0`/`1.3`/`1`/`latest` 가 함께 올라가는데
        `1` 과 `latest` 는 **기존에서 옮겨온다** → `:1` 로 고정한 사용자가 다음 빌드에서 바로 받는다.
        로컬에서 손으로 올리는 만큼 테스트 통과 확인이 CI 보다 더 중요하다
      - **GHCR 패키지는 처음 올리면 private 다.** 공개 전환과 리포 연결을 패키지 설정에서
        한 번 해줘야 한다. `ubuntu` 는 이미 끝나 있다 (아래 참고)

> **현황 (확인됨)**: `ghcr.io/congealer/devcontainers/ubuntu` 는 **이미 공개 발행돼 있다.**
> 익명으로 태그가 조회된다 — `1`, `1.0`, `1.0.0`, `latest`. 매니페스트도 정상적인 템플릿
> 아티팩트다 (`com.github.package.type: devcontainer_template`, `dev.containers.metadata` 에
> 옵션·featureIds 포함). `Hyper-Accel` 로 주소를 바꾸기 전에 로컬에서 올린 것으로 보인다.
> 따라서 §4-4 의 깨진 release 워크플로는 **한 번도 성공한 적이 없고**, 지금 배포본은 전부
> 로컬 발행의 결과다. `hello`/`color`/`rohd` 는 발행된 적 없다.

### 1-3. 문서 체계 — README 자동 생성 + NOTES.md

**`devcontainer templates generate-docs` 는 `src/<id>/README.md` 를 덮어쓴다.**
CLI 0.83.3 소스에서 확인한 템플릿용 생성 틀:

```
# #{Name}

#{Description}

#{OptionsTable}

#{Notes}            ← src/<id>/NOTES.md 를 여기 끼워 넣는다

---

_Note: This file was auto-generated from the devcontainer-template.json.
 Add additional notes to a `NOTES.md`._
```

<details>
<summary>실물 샘플 — 지워진 <code>src/hello/README.md</code> (상류가 생성해 둔 것)</summary>

`hello`/`color` 를 지우기 전에 떠 둔다. 이 리포에 있던 **유일한 템플릿용 생성 결과물**이라
위 틀이 실제로 무엇을 만드는지 보여주는 유일한 증거다. (git 히스토리에도 남아 있다)

```markdown

# Hello, World (hello)

A hello world Template

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| imageVariant | Ubuntu version (use ubuntu-22.04 or ubuntu-18.04 on local arm64/Apple Silicon): | string | jammy |
| greeting | Select a pre-made greeting, or enter your own | string | hey |



---

_Note: This file was auto-generated from the [devcontainer-template.json](https://github.com/devcontainers/template-starter/blob/main/src/hello/devcontainer-template.json).  Add additional notes to a `NOTES.md`._
```

읽을 점 셋:

- 맨 앞에 **빈 줄**이 하나 붙는다 (틀이 개행으로 시작)
- `NOTES.md` 가 없으면 `#{Notes}` 자리가 **빈 줄 세 개**로 남는다
- 옵션 표는 `devcontainer-template.json` 의 `description`/`type`/`default` 를 그대로 옮긴다 —
  **`proposals` 는 안 나온다**

</details>

- [ ] **손으로 쓴 한국어 README 를 `NOTES.md` 로 옮긴다.**
      [src/ubuntu/README.md](src/ubuntu/README.md) 와 rohd 것(§2).
      옮기지 않으면 릴리스 때 날아간다.

- [ ] **apply 예시는 NOTES.md 에 직접 쓴다.** feature 틀에는 있는 `## Example Usage`
      섹션이 **템플릿 틀에는 없다.** 자동 생성되지 않는다.

- [ ] **옵션 표는 손으로 쓰지 않는다.** `#{OptionsTable}` 이 `devcontainer-template.json` 의
      `options` 에서 만든다. 지금 [src/ubuntu/README.md](src/ubuntu/README.md#L7-L11) 에
      손으로 쓴 표가 있는데 중복이자 드리프트 원인이다.

### 1-4. `CONTRIBUTING.md`

- [ ] **개발자용 문서를 루트 README 에서 분리한다.** 지금 [README.md](README.md) 가
      사용법과 테스트 실행법을 같이 담고 있다. devcon-features 처럼
      README(사용) / CONTRIBUTING(개발) 로 가른다.

      담을 것: make 타깃 표, 수동 실행법, `clean`/`distclean` 이 지우는 것,
      문서 생성 규칙(README 는 자동 생성물이니 NOTES.md 를 고칠 것), 릴리스 절차와 주의점.

### 1-5. 개발 컨테이너

- [ ] **Node 를 20 으로 올린다.** [.devcontainer/devcontainer.json:3](.devcontainer/devcontainer.json#L3)
      이 `javascript-node:1-18-bullseye` 다. 확인해보니 실제로 **v18.20.8** 이고
      `@devcontainers/cli` 는 **Node 20+** 를 요구한다 (CLI 0.83.3 은 깔려서 돌지만 경고).
      → `javascript-node:1-20-bookworm`. devcon-features 가 이미 이 이미지를 쓴다.

- [ ] **`make release` 용 `github-cli` feature 추가** — `gh auth token` 이 필요하다.

- [ ] **`make prepare` 용 python + questionary 추가** — devcon-features 의
      `postCreateCommand` 를 그대로:
      `pip install --break-system-packages questionary`

- [ ] **`json.schemas` 설정 추가** — 에디터에서 `devcontainer-template.json` 을 스키마 검증.
      devcon-features 가 `devContainerFeature.schema.json` 을 걸어둔 것과 같은 방식
      (템플릿용 스키마 파일명 확인 필요).

- [ ] **`npm install -g @devcontainers/cli` 를 `updateContentCommand` 로 옮긴다** —
      지금은 `postCreateCommand`. devcon-features 는 `updateContentCommand` 를 쓴다.

---

## 2. rohd 템플릿 이식

출처: `rohd-dev/rohd-template/` (`.git` 없음, 120K — 복사 자체는 깨끗).
**`src/rohd` 아래만 건진다.** 루트의 세 파일은 독립 리포를 전제로 만들어진 것이라 그대로 오면 안 된다.

### 2-1. 옮기기

- [ ] `rohd-dev/rohd-template/src/rohd/` → `src/rohd/`

      옵션 정합성은 확인했다 — 선언 3 개(`projectName`, `description`, `dartVersion`)가 전부
      실제로 쓰이고 모두 `default` 가 있어서 `build.sh` 치환이 그대로 돈다.

- [ ] **네임스페이스 치환** — `congealer/rohd-devcontainer-template` → `congealer/devcontainers`:
      - `src/rohd/devcontainer-template.json` 의 `documentationURL`
        → `https://github.com/congealer/devcontainers/tree/main/src/rohd`
      - `src/rohd/README.md` 의 apply 예시
        → `ghcr.io/congealer/devcontainers/rohd`

      **건드리지 말 것:** `src/rohd/.devcontainer/devcontainer.json` 의
      `ghcr.io/congealer/devcon-features/prezto:1`. 별개의 공개 feature 이고 이미 `congealer`
      네임스페이스다. GHCR 태그 조회로 공개 확인 완료 (`1`, `1.0`, `1.0.0`, `1.2`, `1.2.1`, `latest`).

- [ ] **README 를 NOTES.md 형태로 넣는다** (§1-3 결정에 따라). 처음부터 이 형태로 넣으면
      재작업이 없다 — 나중에 도입하면 손으로 쓴 한국어 README 를 다시 쪼개야 한다.

- [ ] **`version` 을 어떻게 할지 정한다.** 지금 `0.0.1` (다른 템플릿은 `1.0.0`).
      컨테이너를 띄운 검증이 아직 안 끝난 상태라 `0.0.1` 이 맞지만, 이 리포에 들어오면
      스모크 테스트가 그 검증을 대신하게 된다 → 통과 후 `1.0.0` 으로.

### 2-2. 가져오지 않을 것 / 흡수할 것

- [ ] `rohd-template/README.md` — 독립 리포용 README. 이 리포의 [README.md](README.md) 와
      충돌한다. **발행/개발 루프 설명만 흡수**하고 파일은 버린다.
- [ ] `rohd-template/.github/workflows/release.yaml` — CI 정비(§4) 때 쓴다.
      `devcontainers/action@v1` + `publish-templates` 로, 지금 리포의 깨진 것보다 올바르다.
- [ ] `rohd-template/HANDOFF.md` — 일회용 인수인계 문서. 본문 스스로 "검증 끝나면 지우라"고
      한다. **단, 2-3 을 먼저 하고 나서 지울 것** — 통과 기준이 여기에만 있다.

### 2-3. `test/rohd/test.sh` 를 만든다

HANDOFF.md 가 "devcontainers CI 하네스(`test-utils.sh`)를 전제로 하는데 아직 리포도 워크플로도
없다" 며 일부러 안 만들었다고 적어뒀다. 이제 그 리포가 생긴 셈이니 만들어야 한다.

HANDOFF.md 의 검증 표가 그대로 테스트 내용이다:

- [ ] `dart analyze` — 무경고
- [ ] `dart test` — 8 개 통과 (예제 설계)
- [ ] `cd packages/rohd_patches && dart test` — 38 개 통과
- [ ] `find . -name package_config.json -not -path './build/*'` — **1 개만**
      (루트에만. 서브패키지에도 생기면 워크스페이스 배선이 깨진 것)
- [ ] `dart run bin/generate_rtl.dart` — `build/counter.sv` 생성
- [ ] 재실행 후 sha256 **동일** (헤더 타임스탬프 회귀 검출). 해시값 자체는 비교하지 말 것 —
      모듈 이름과 헤더가 프로젝트마다 다르다
- [ ] `grep 'val <= (val + ' build/counter.sv` — 있어야 함 (증가가 `always_ff` 안에 인라인)
- [ ] `grep carry build/counter.sv` — **없어야 함** (있으면 `.inl` 패치가 안 먹은 것)
- [ ] `getent passwd $(id -un)` — `/usr/bin/zsh` 로 끝남
- [ ] `zsh -i -c 'bindkey "^R"'` — `fzf-history-widget`

- [ ] **예제 없이도 서는지** — `rm lib/counter.dart bin/generate_rtl.dart test/counter_test.dart`
      후에도 `dart pub get && dart analyze` 통과. (`packages/rohd_patches` 는 워크스페이스
      멤버라 지우면 안 됨)

> 뒤의 두 개는 ubuntu 테스트(§3-2)와 같은 검사다. 나중에 `test/test-utils/` 로 뽑을 때
> 한 번 손보게 된다 — §6 참고.

### 2-4. 에디터 함정 막기

- [ ] **`.vscode/settings.json` 에 `{"dart.analysisExcludedFolders": ["src/rohd"]}` 추가.**

      이 리포를 VS Code 로 열면 `src/rohd/pubspec.yaml` 때문에 Dart 확장이 `src/rohd` 를
      프로젝트로 잡고, `${templateOption:projectName}` 을 Dart 문자열 보간으로 읽어 **에러
      13 건**을 낸다. 더 나쁜 건 `unnecessary_brace_in_string_interps` 자동 수정을 수락하면
      placeholder 가 **영구히 망가진다**는 것 — `$templateOption:projectName}`.
      `dart.updateImportsOnRename`(기본 `true`) 도 같은 위험이 있다.

      트레이드오프: 끄면 진짜 문제도 같이 안 보인다. 그래서 2-3 의 테스트가 그 역할을 해야 한다.

      대안으로 리포 루트 `analysis_options.yaml` 에 `analyzer: exclude: [src/**]` 도 있는데,
      HANDOFF.md 기준 **반쯤만 확인된** 방법이다.

---

## 3. ubuntu 템플릿 정리

> 잘 모르던 시절에 급하게 만든 것이라 전반적으로 손볼 예정. 급하지는 않음.

### 3-0. 절차 (합의됨)

CI 가 보류라 **검증은 전부 로컬에서** 한다. 각 단계마다 한 번씩 돌린다:

```bash
./.github/actions/smoke-test/build.sh ubuntu
./.github/actions/smoke-test/test.sh ubuntu
```

1. **테스트부터 고친다** (§3-2 의 `distro`). 배선보다 **먼저**.
   지금 체크는 항상 통과한다. 안 고치고 배선을 먼저 하면 배선이 맞는지 확인할 방법이 없다 —
   깨진 자를 먼저 고쳐야 그 다음 변경을 잰다. 현재 이미지가 noble 하드코딩이므로
   **이 단계에서는 통과해야 정상**이다.
2. **커버리지 보강** (§3-2 나머지). 아직 아무것도 안 바꾼 상태에서 돌려 **기준선**을 만든다.
   여기서 실패가 나오면 그게 진짜 버그다 — 지금까지 안 보이던 것.
3. **`imageVariant` 배선** (§3-1). 1 번 테스트가 **그대로 통과해야** 한다
   (default 가 noble 이니 결과가 같아야 정상). 바뀌면 배선이 잘못된 것.
4. **`documentationURL` + 네임스페이스, `bionic` 재검토** (§3-1).

**1 번과 3 번을 한 커밋에 넣지 말 것.** 섞이면 테스트가 통과하는 게 자가 제대로여서인지
배선 덕인지 구분이 안 된다.

`version` 은 올리지 않는다 — 재발행이 보류이고, `prepare.py`(§1-2) 가 "버전이 박힌 커밋
이후에 바뀐 템플릿" 을 잡아주므로 지금 안 올려두는 편이 낫다.

### 3-1. 버그

- [ ] **`imageVariant` 옵션이 죽어 있다.**
      [devcontainer-template.json](src/ubuntu/devcontainer-template.json#L9-L21) 은 옵션을
      선언하는데 [.devcontainer/devcontainer.json:5](src/ubuntu/.devcontainer/devcontainer.json#L5)
      는 `base:noble` 을 하드코딩한다. `jammy`/`focal` 을 골라도 noble 이 뜬다.
      → `"image": "mcr.microsoft.com/devcontainers/base:${templateOption:imageVariant}"`

      대조 결과 (선언된 옵션 vs 실제로 쓰인 placeholder):

      | 템플릿 | 선언 | 사용 |
      |---|---|---|
      | ubuntu | `imageVariant` | **(없음)** |
      | ~~hello~~ | `greeting`, `imageVariant` | `greeting`, `imageVariant` |
      | ~~color~~ | `favorite`, `imageVariant` | `favorite`, `imageVariant` |

      (hello/color 는 제거됨 — 대조 결과만 남긴다. 이제 이 리포에서 placeholder 치환이
      실제로 동작하는 예는 rohd 가 들어와야 생긴다)

- [ ] **`documentationURL` 이 `src/hello` 를 가리킨다** —
      [devcontainer-template.json:6](src/ubuntu/devcontainer-template.json#L6). 복붙 자국.
      네임스페이스 치환과 함께 `https://github.com/congealer/devcontainers/tree/main/src/ubuntu` 로.

      **긴급도 올라감.** 이 잘못된 URL 이 **이미 발행된 아티팩트에 박혀 있고**, 이제
      `src/hello` 가 없으니 진짜 404 다. 발행된 매니페스트에서 확인:

      ```
      "documentationURL":"https://github.com/congealer/devcontainers/tree/main/src/hello"
      ```

      에디터가 템플릿 hover 에 이 링크를 띄운다. 고침 + `version` 범프 + 재발행이 한 묶음.

- [ ] **`bionic` 제안값 재검토.** `proposals` 에 `bionic`(18.04) 이 있는데 `description`
      에는 없고, `mcr.microsoft.com/devcontainers/base:bionic` 태그가 아직 제공되는지 확인 필요.

- [ ] **네임스페이스 치환** — `Hyper-Accel/devcon-templates` → `congealer/devcontainers`:
      [src/ubuntu/README.md:16](src/ubuntu/README.md#L16) (publish),
      [:24](src/ubuntu/README.md#L24), [:30](src/ubuntu/README.md#L30) (apply).
      단 README 가 자동 생성물이 되면(§1-3) 이 내용은 NOTES.md 로 간다.

### 3-2. 테스트 — `test/ubuntu/test.sh`

- [ ] **`distro` 체크가 항상 통과한다.** [test/ubuntu/test.sh:6](test/ubuntu/test.sh#L6)

      ```bash
      check "distro" [ ! $(lsb_release -c | grep nobel) ]
      ```

      세 개가 겹쳐 있다:
      1. `nobel` 오타 (`noble` 이 맞음) → grep 출력이 항상 빈 문자열
      2. 그래서 `[ ! ]` 가 되는데, 이건 "문자열 `!` 가 비어있지 않은가" → **항상 참**
      3. 부정이 논리적으로 거꾸로 — "noble 이 **아닐** 것" 을 주장하고 있다

      실측:

      ```
      [ ! $(echo "" | grep nobel) ]             → PASS  (공허하게 통과)
      [ ! $(<noble 출력> | grep noble) ]        → bash: [: unary operator expected → FAIL
      ```

      오타만 고치면 오히려 깨진다. 다시 쓸 것:
      `check "distro" [ "$(lsb_release -cs)" = "noble" ]`
      — 그리고 이 기대값이 `imageVariant` 와 맞물리게 할 것 (3-1 과 한 몸).

- [ ] **fzf 바이너리 자체가 `REQUIRED_TOOLS` 에 없다.** 키바인딩 체크는 `~/.zshrc` 의 문자열을
      grep 할 뿐이라, fzf feature 가 통째로 빠져도 `postCreateCommand` 가 그 줄을 넣었으니
      통과한다. 실제 동작을 봐야 한다: `zsh -i -c 'bindkey "^R"'` 에 `fzf-history-widget`.

- [ ] **zsh 가 로그인 셸인지 미검증.** `configureZshAsDefaultShell: true` 를 켰는데 확인이 없다.
      → `getent passwd $(id -un)` 가 zsh 로 끝나는지.

- [ ] **oh-my-zsh 부재 미검증.** `installOhMyZsh` / `installOhMyZshConfig` 를 명시적으로
      `false` 로 뒀는데 확인이 없다. → `[ ! -d ~/.oh-my-zsh ]`

- [ ] **`which` 만 본다.** `git-lfs`, `gh` 는 바이너리가 있어도 초기화가 안 됐을 수 있다.
      → `git lfs version`, `gh --version` 처럼 실행해서 확인.

- [ ] **도구 목록이 이중 관리다.** devcontainer.json 의 `packages` 와 test.sh 의
      `REQUIRED_TOOLS` 가 따로 놀고, `vim-gtk3 → vim/gvim`, `bat → batcat`,
      `fd-find → fdfind` 매핑이 암묵적이다. 한쪽만 고치면 조용히 어긋난다.

- [ ] **옵션 조합 테스트** — `jammy`/`focal` 로도 도는지. §1-1 의 옵션 전달 경로가 있어야 한다.

- [ ] **비 root 사용자 / sudo 미검증** — 필요한지 판단 후 추가.

---

## 4. CI 정비 — **맨 마지막**

그 전까지 릴리스는 로컬에서 한다 (§1-2). 지금 CI 는 **테스트가 돌지도 않고, 돌아도 실패가
무시되고, 발행도 안 되는** 상태다.

### 4-1. 테스트가 아예 안 돈다

- [ ] **매트릭스를 리포에서 읽게 바꾼다.** devcon-features 의 `test.yaml` 이 이렇게 한다:

      ```bash
      all=$(ls src | jq -R . | jq -sc .)
      ```

      주석에 이유가 적혀 있다 — "feature 를 추가해도 테스트가 빠질 수 없게".
      지금 devcon-templates 는 정확히 그 반대다:
      [test-pr.yaml:13-15](.github/workflows/test-pr.yaml#L13-L15) 의 paths-filter 에
      손으로 적은 `color`, `hello` 만 있어서 **ubuntu 테스트는 CI 에서 한 번도 돌아본 적이 없고**,
      rohd 를 넣으면 또 빠뜨릴 자리다. 이 방식을 가져오면 구조적으로 없어진다.

      **지금은 그 두 필터가 죽은 채로 남아 있다** (페이즈 1 에서 hello/color 를 지우면서
      CI 는 일부러 안 건드림). 매칭될 파일이 없으니 매트릭스가 비고 job 이 스킵된다 —
      깨지지는 않지만 **어떤 템플릿도 테스트되지 않는다.** 그때까지 검증은 로컬에서:

      ```bash
      ./.github/actions/smoke-test/build.sh ubuntu
      ./.github/actions/smoke-test/test.sh ubuntu
      ```

- [ ] **`continue-on-error: true` 를 뗀다.**
      [test-pr.yaml:21](.github/workflows/test-pr.yaml#L21).
      **템플릿 테스트가 실패해도 PR 체크가 초록으로 뜬다.** 위 필터 문제와 겹쳐서, ubuntu 의
      `distro` 체크가 공허하게 통과한다는 걸(3-2) CI 가 잡을 수 없었던 이유이기도 하다.
      devcon-features 에는 이 플래그가 없다.

- [ ] **`ci:` 집계 job 을 둔다.** 매트릭스가 늘어도 이름이 안 바뀌는 체크 하나 —
      branch ruleset 이 하나만 걸면 되게. devcon-features 의 `test.yaml` 마지막 job.

- [ ] **트리거에 `push: branches: [main]` 을 넣을지 정한다.** 지금은 `pull_request` 뿐이라
      main 에 직접 푸시하면 아무것도 안 돈다. devcon-features 는 push/PR/dispatch 셋 다.

### 4-2. CI 가 make 를 호출하게

- [ ] **잡의 `run:` 을 make 타깃 호출로 바꾼다.** devcon-features 방식:

      ```yaml
      - run: npm install -g @devcontainers/cli
      - run: make unit-${{ matrix.features }} BASE_IMAGE=${{ matrix.baseImage }}
      ```

      로컬과 CI 가 같은 경로를 타게 된다. §1-1 의 테스트 타깃 설계가 선행.

- [ ] **`smoke-test` composite action 을 어떻게 할지 정한다.** Makefile 이 로직을 흡수하면
      이 action 은 사라진다. 감싸기만 하면 남는다 (§1-1 결정에 따라).

### 4-3. 워크플로 위생

- [ ] **액션 버전을 올린다.** 전부 낡았다 — `actions/checkout@v3` 3 곳
      ([test-pr.yaml:26](.github/workflows/test-pr.yaml#L26),
      [release.yaml:16](.github/workflows/release.yaml#L16),
      [smoke-test/action.yaml:12](.github/actions/smoke-test/action.yaml#L12)),
      `dorny/paths-filter@v2` ([test-pr.yaml:11](.github/workflows/test-pr.yaml#L11)).
      매트릭스를 리포에서 읽게 바꾸면(4-1) paths-filter 는 아예 사라진다.

- [ ] **`concurrency` 그룹 추가.** 같은 PR 에 연달아 푸시하면 이전 실행이 계속 돈다.

- [ ] **중복 checkout 정리.** [test-pr.yaml:26](.github/workflows/test-pr.yaml#L26) 에서
      이미 했는데 [smoke-test/action.yaml:10-12](.github/actions/smoke-test/action.yaml#L10-L12)
      이 또 한다 (스텝 이름은 `Checkout main` 인데 실제로는 PR 머지 커밋을 받는다).
      상류 template-starter 에서 온 자국.

- [ ] **`test.sh` 의 정리 단계가 실패 시 건너뛰어진다.**
      [smoke-test/test.sh:3](.github/actions/smoke-test/test.sh#L3) 의 `set -e` 때문에
      테스트가 실패하면 12 줄의 `docker rm -f` 와 `rm -rf` 가 안 돈다. `trap` 으로 옮길 것.

- [ ] **`validate` 워크플로 추가 검토.** devcon-features 의 `validate.yml` 이
      `devcontainers/action@v1` 의 `validate-only: "true"` 로 메타데이터를 검증한다.

### 4-4. 발행 워크플로

- [ ] **`release.yaml` 을 교체한다.** 지금 것은
      [.github/workflows/release.yaml](.github/workflows/release.yaml) 에서
      `docker/build-push-action` 으로 컨텍스트 `.` 를 빌드하는데 **Dockerfile 이 없다**
      (hello 를 지운 지금은 리포 전체에 하나도 없다. 그전에도 루트에는 없었고
      `src/hello/.devcontainer/` 에만 있었다).
      설령 빌드된대도 devcontainer template OCI 아티팩트가 아니라 Docker 이미지를 민다.
      `if:` 조건도 `refs/heads/main` 을 보는데 트리거는 태그뿐이라 어긋나 있다.

      → `rohd-dev/rohd-template/.github/workflows/release.yaml` 이 올바른 물건이다
      (`devcontainers/action@v1` + `publish-templates: true` + `base-path-to-templates: ./src`).

- [ ] **문서 PR 스텝을 붙일지 정한다.** devcon-features 의 release.yaml 은
      `generate-docs` 뒤에 `automated-documentation-update-*` 브랜치를 만들어 PR 을 연다.
      rohd-template 쪽에는 그 스텝이 없다. §1-3 을 따르면 붙이는 게 맞다.
      **§1-3 을 안 하기로 하면 `generate-docs` 를 꺼야 한다** — 안 그러면 손으로 쓴 한국어
      README 가 날아간다.

- [ ] **버전 범프 검사를 넣을지 검토.** PR 에서 "바뀐 템플릿의 `version` 이 올랐는가" 를
      확인하는 체크. `make prepare` 를 빠뜨렸을 때 조용히 no-op 되는 걸 막는다.

---

## 5. 정리

- [ ] **`rohd-dev/` 를 치운다.** `rohd-dev/rohd` (46M), `rohd-dev/rohd-project` (41M),
      `rohd-dev/devcon-features` 는 **중첩 git 리포**다. 커밋에 딸려 들어가면 안 된다.
      작업 중에는 `.git/info/exclude` 에 넣어두는 것도 방법.

- [x] ~~**`.devcontainer/devcontainer-lock.json` 을 커밋할지 정한다.**~~ → **커밋함**
      (`7131ce4`). docker-in-docker 2.17.0 을 digest 로 고정한다. §1-5 에서 `github-cli`
      와 `python` feature 를 추가하면 이 파일이 바뀐다.

- [ ] **루트 README 갱신** — `rohd` 를 템플릿 목록에 추가, 네임스페이스 치환
      ([README.md:24](README.md#L24), [:34](README.md#L34)),
      개발자용 내용은 CONTRIBUTING.md 로 이관(§1-4).
      (hello/color 항목 제거는 `7131ce4` 에서 끝남)

- [x] ~~**`hello`/`color` 를 남길지 정한다.**~~ → **제거함** (`tidy` 브랜치, 페이즈 1).
      상류 template-starter 의 예제였고 관리할 이유가 없었다. 발행된 적이 없어 소비자 영향 0.

- [x] ~~**`.gitignore` 의 `.*` 규칙을 손본다.**~~ → **해결됨** (`7131ce4`).
      `.*` 가 `src/rohd/.devcontainer/**` 와 `.vscode/**` 를 조용히 삼키고 있었다
      (`git add src/rohd` 가 성공한 것처럼 보이면서 템플릿의 핵심 디렉터리만 빠짐).
      `!.devcontainer` 와 `!.vscode` 를 넣어 되살렸고, 종료 코드로 확인했다:

      ```
      src/rohd/.devcontainer/features/dart/install.sh   ok
      .vscode/settings.json                             ok
      .env  .DS_Store  .dart_tool/x                     IGNORED   ← 원래 목적은 유지
      ```

- [ ] **리포 토픽에 `devcontainer-templates` 추가.** 없으면 containers.dev 색인에 안 잡히고
      VS Code 의 hover·자동완성이 안 된다 (HANDOFF.md 가 `congealer/devcon-features` 에서
      같은 문제를 겪었다고 기록).

---

## 6. 순서 의존성 (조사 결과)

순서를 정할 때 참고할 사실들. **제안이 아니라 확인된 제약이다.**

### rohd 는 ubuntu 정리에 의존하지 않는다

`src/rohd/`, `test/rohd/` 는 전부 신규 파일이고 ubuntu 쪽과 겹치는 파일이 하나도 없다.
네임스페이스 치환도 파일이 분리돼 있어 각자 간다.

### rohd 보다 앞서면 이득인 것 둘

| | 왜 |
|---|---|
| **§0 문서 체계 결정 + §1-3** | `generate-docs` 가 `src/<id>/README.md` 를 덮어쓴다. rohd 를 손으로 쓴 README 째로 넣으면 나중에 NOTES.md 로 다시 쪼개야 한다. 처음부터 그 형태로 넣으면 **재작업 0** |
| **§1-5 Node 20** | 현재 v18.20.8, CLI 요구는 20+. rohd 스모크 테스트는 Dart SDK 를 받고 컨테이너를 띄우는 무거운 작업이라 여기서 헛시간 쓰기 쉽다. 컨테이너 재빌드가 어차피 한 번은 필요 |

### rohd 발행에만 걸리는 것

**§1-1/1-2 Makefile** — 이식과 `test/rohd/test.sh` 작성까지는 없어도 된다.
GHCR 에 올리는 시점에 필요.

### 역방향 — 나중에 ubuntu 를 하면 rohd 를 다시 건드리는 지점

`test/test-utils/test-utils.sh`. rohd 테스트(§2-3)와 ubuntu 테스트(§3-2) **둘 다** zsh
로그인 셸과 fzf 키바인딩을 검사한다 (rohd 는 prezto feature 로, ubuntu 는 common-utils 로 —
경로는 다르지만 검사는 같다). rohd 에 인라인으로 써두면 나중에 공통 헬퍼로 뽑을 때 한 번
손보게 된다. 작은 비용.

### 의존성이 아닌 것

- **네임스페이스** — 이미 정해졌고, `git remote` 가 `congealer/devcontainers` 라 리포 개명도
  불필요하다. 주소가 이미 맞다
- **CI (§4)** — 맨 마지막으로 확정. 그 전까지 로컬 릴리스
