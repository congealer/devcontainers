# TODO

`tidy` 마무리 → `rohd` 이식 → `ubuntu` 재설계 → 개발 워크플로 정비 순으로 본다.
**섹션 번호는 대략의 시간 순이다.** 조사 근거는 각 항목에 파일:줄 로 달아뒀다.

---

## 정해진 것

| | |
|---|---|
| 릴리스 위치 | `ghcr.io/congealer/devcontainers` — `git remote` 와 일치하므로 **리포 개명 불필요** |
| 네임스페이스 | `congealer` 로 통일 |
| 발행 경로 | **로컬이 주**(`templates publish` / 나중에 `make release`). CI 는 `workflow_dispatch` 전용으로 **보조**만 |
| 개발 워크플로 | `congealer/devcon-features` 방식 이식 — Makefile + `prepare.py` + CI 가 make 호출 |
| rohd 범위 | `rohd-template/src/` 아래만 건진다. `test/rohd/` 는 새로 만든다 |
| prezto | **ubuntu 와 rohd 둘 다 넣는다.** 안 쓸 사람은 옵션을 고치게 안내 (§2-2) |
| 도구 목록 | **지금 rohd 에 설치되는 것 + `lsd`.** 즉 둘이 같아진다 — `bat` `fd-find` `ripgrep` `tig` `tldr` `xxd` `file` `lsd`. `lsd` 는 **apt 로 설치 가능할 때만** (noble/jammy/resolute 모두 있음을 확인) |
| `git-lfs` | **뺀다.** 필요하면 그때 feature 로 넣으면 된다 |
| 문서 체계 | **`generate-docs` 를 쓴다** — `src/<id>/README.md` 는 자동 생성물, 손으로 쓸 내용은 `NOTES.md` (§4-3). **적용은 나중에**, 지금은 끈 채로 둔다 |
| ubuntu 의 성격 | **개인 go-to 템플릿** |
| ubuntu 재설계 방식 | 상류 `devcontainers/templates/ubuntu` 를 **다시 적용**해서 베이스를 갈고, 피쳐만 얹는다 (§3) |
| LICENSE | MS 표시 유지 + `Copyright (c) 2026 congealer` 추가 (MIT 의무) |

## 진행 상황

작업 브랜치는 `rohd`.

- [x] **hello/color 제거**
      템플릿 둘과 테스트 삭제, 루트 README 목록 정리, `.gitignore` 추가, `devcontainer-lock.json` 커밋
- [x] **tidy 마무리** (§1) — 아래 8 건
      - [x] 자잘한 것 — 네임스페이스 6 곳, `documentationURL` 경로, 매달린 `---`, 루트 README 문구
      - [x] LICENSE 저작권 줄 + `licenseURL` (§1-1)
      - [x] `release.yaml` 교체 (§1-1)
      - [x] 하네스 — `build.sh` 가 옵션 값을 컨테이너로 전달 (§1-2)
      - [x] 하네스 — `build.sh` 가 옵션 값을 밖에서 받음 (`TEMPLATE_ARGS`) (§1-2)
      - [x] 하네스 — `test.sh` 에 `trap` + `KEEP` (§1-2)
      - [x] `test/ubuntu/test.sh` 의 `distro` 체크 재작성 (§1-2)
      - [x] `dev.md` — 하네스 개발 가이드 (§4-4). **CI 절은 §5 이후의 형상을 적어뒀다**

      로컬에서 실제로 돌려 확인했다 — `build.sh` → `test.sh` 3/3 통과(exit 0),
      옵션을 어긋나게 하면 `distro` 가 RED(exit 1), 정리까지 동작.

- [x] **rohd 이식 + Makefile** (§2 → §4) — 완료
      - [x] `src/rohd/` 이식, 네임스페이스 치환, Dart 3.13.2 정렬, `NOTES.md`
      - [x] `test/rohd/` — 검사 11 개, `my_design`/`zzz_top` 둘 다 통과
      - [x] `Makefile` — 스크립트를 감싸는 입구 (§4-1)
      - [x] `prepare.py` (§4-2), 개발 컨테이너 재구성 (§4-5)
      - [x] 문서 — `dev.md` 에 Makefile·문서·릴리스 절, 루트 README 를 `dev.md` 로 (§4-4)
      - [x] **발행** — `0.0.2` 로 GHCR 에 올렸다. 패키지를 public 으로 바꾸고 리포에
            연결했다. 인증 없이 `templates apply` 가 되는 것까지 확인
- [ ] **ubuntu 재설계** (§3) ← **진행 중.** 브랜치 `ubuntu`
      - [x] 상류 v3.0.0 재적용, prezto·도구 목록·메타데이터
      - [x] 테스트 재작성 — 검사 18 개. `resolute`/`noble` 둘 다 18/18
      - [ ] **발행** — `make prepare` 로 `2.0.0`. 발행된 `1.0.0` 의
            `documentationURL` 이 `src/hello` 라 404 다
- [ ] **CI 정비** (§5) — 그 다음

---

## 0. 정해야 할 것

**지금은 없다.** 방향을 가르는 결정은 전부 위 표로 옮겨졌다.

남아 있는 "정한다" 항목들은 각 섹션 안의 구현 시점 선택이지 선행 조건이 아니다 —
rohd 의 `version`(§2-1), Makefile 의 테스트 타깃 설계(§4-1),
`name`/`description`(§3-2), CI 트리거와 composite action 의 거취(§5).

---

## 1. tidy — **완료**

목표는 **rohd 를 얹기 좋은 바닥을 만드는 것**이었다. 아래는 무엇을 왜 했는지의 기록이다.

> **완료 여부는 위 「진행 상황」에서만 관리한다.** 여기는 무엇을 왜 하는지만 적는다.
> 체크박스를 두 군데 두면 어긋난다 — 실제로 한 번 어긋났다.

### 1-1. 자잘한 것

#### 네임스페이스 치환

옛 주소 → `congealer/devcontainers`, 총 6 곳:

| 파일 | 곳 |
|---|---|
| `README.md` | apply 예시 2 |
| `src/ubuntu/README.md` | publish 1, apply 2 |
| `src/ubuntu/devcontainer-template.json` | `documentationURL` (`src/hello` → `src/ubuntu` 경로 버그도 함께) |
| `.github/workflows/release.yaml` | `images:` |

#### `src/ubuntu/README.md` 끝의 매달린 `---`

자동 생성 README 골격(`---` + 각주)에서 각주만 지운 흔적이었다.

#### 루트 README 의 "다양한"

템플릿이 하나뿐이라 안 맞았다.

#### LICENSE 저작권 줄 + `licenseURL`

```
Copyright (c) 2022 Microsoft Corporation
Copyright (c) 2026 congealer
```

MS 줄은 **지울 수 없다.** MIT 가 저작권 표시를 사본에 포함할 것을 요구하는데, 상류 코드가
실질적으로 남아 있다 — `smoke-test/{build,test}.sh`, `test-utils.sh` 는 거의 그대로고,
워크플로와 `.devcontainer/devcontainer.json` 도 상류 골격이다.

그 다음 `licenseURL` 을 `https://github.com/congealer/devcontainers/blob/main/LICENSE` 로.

#### `release.yaml` 교체

지금 것은 `docker/build-push-action` 으로 컨텍스트 `.` 를 빌드하는데 **Dockerfile 이 없다**
(hello 를 지운 지금은 리포 전체에 하나도 없다). 설령 빌드된대도 **template 은 Docker 이미지가
아니다** — `application/vnd.devcontainers` 미디어 타입의 OCI 아티팩트이고 `templates publish`
만 만들 수 있다. 그래서 이 워크플로는 **한 번도 성공한 적이 없다.**

→ `rohd-dev/rohd-template/.github/workflows/release.yaml` 로 교체
(`devcontainers/action@v1` + `publish-templates: true` + `base-path-to-templates: ./src`).

**고쳐서 가져올 것 둘:**

- 트리거는 **`workflow_dispatch` 전용**. 자동으로 안 뜨니 로컬이 자연스럽게 주 경로가 된다.
  (`v*` 태그 트리거는 애초에 맞지 않는다 — 버전은 리포가 아니라 **템플릿마다** 붙는다.
  리포 태그 하나로 "ubuntu 1.2.0 과 rohd 0.3.1 을 올린다" 를 표현할 수 없다.
  상류 template-starter 도 devcon-features 도 `workflow_dispatch` 전용인 이유다)
- **`generate-docs` 는 일단 끈다.** 쓰기로는 정해졌지만 적용이 나중이라(§4-3),
  지금 켜면 아직 손으로 쓴 README 가 날아간다. §4-3 을 실제로 할 때 켠다.

### 1-2. 하네스 — rohd 를 얹기 위한 것

`.github/actions/smoke-test/` 의 두 스크립트. **왜 지금 하냐면, 셋 다 rohd 이식에서 바로 걸린다.**

#### `test.sh` 에 `trap` + `KEEP=1`

지금은 `set -e` 가 `devcontainer exec` 줄에서 스크립트를 끝내버려서 아래 `docker rm -f` /
`rm -rf` 에 **도달하지 못한다.** 실패할 때마다 컨테이너가 샌다.

```bash
cleanup() {
    docker rm -f $(docker container ls -f "label=${ID_LABEL}" -q) 2>/dev/null || true
    rm -rf "${SRC_DIR}"
}
trap '[ -n "${KEEP:-}" ] || cleanup' EXIT
```

**`set -e` 는 빼면 안 된다.** 빼면 스크립트 종료 코드가 마지막 명령인 `rm -rf` 의 것이 되어
**테스트가 실패해도 성공으로 보고한다.** 실측:

```
set -e 있음 → exit 1
set -e 없음 → exit 0
```

(devcon-features 에서 뺐던 `set -e` 는 **테스트 스크립트** 쪽이다. 이 리포의
`test/ubuntu/test.sh` 에는 애초에 없어서 그 교훈은 이미 충족돼 있다)

`KEEP=1` 은 devcon-features 가 CLI 의 `--preserve-test-containers` 로 얻던 것을 직접 만드는
것이다. 새 템플릿을 붙일 때 실패한 컨테이너를 들여다보는 수단.

#### `build.sh` 가 옵션 값을 컨테이너로 전달한다

`test-project/template-options.env` 에 `TEMPLATE_OPTION_<name>=<value>` 로 떨군다.
테스트는 `source` 만 하면 된다.

**그전에는 테스트가 옵션 값을 알 방법이 아예 없었다.** `test/<id>/` 를 sed **뒤에** 복사하기
때문이다 — 즉 `test.sh` 에는 placeholder 치환이 안 걸린다.

rohd 에 직접 필요하다: `pubspec.yaml` 의 `name` 과 import 경로가 `projectName` 으로
치환되므로, 테스트가 그 값을 알아야 검증할 수 있다.

(`devcontainer exec --remote-env name=value` 도 있지만, 그러면 하네스 `test.sh` 가 값을
다시 알아내야 한다. `build.sh` 가 파일로 떨구는 쪽이 간단하고 로컬·CI 가 같다)

#### `build.sh` 가 옵션 값을 밖에서 받는다

`TEMPLATE_ARGS='{"imageVariant":"jammy"}'` — `templates apply -a` 와 같은 JSON 형태.
잘못된 JSON 은 조용히 default 로 떨어지지 않고 거부한다.

**딸려온 것**: `rm -rf "${SRC_DIR}"` 를 앞에 넣었다. `KEEP=1` 로 남긴 디렉터리가 있으면
`cp -R` 이 그 안에 중첩 복사하기 때문에 `KEEP` 을 넣는 이상 필요하다.

HANDOFF.md 가 명시적으로 요구한다:

> 이름을 두 개로 해보세요 — 알파벳 앞(`my_design`)과 뒤(`zzz_top`).
> 정렬 관련 문제는 한 이름으로만 보면 안 드러납니다.

실제로 그 절차가 버그를 하나 잡았다 (`directives_ordering` lint). 그전 하네스로는 그 검증을
재현할 수 없었다.

#### `test/ubuntu/test.sh` 의 `distro` 체크

지금은 항상 통과한다:

```bash
check "distro" [ ! $(lsb_release -c | grep nobel) ]
```

세 개가 겹쳐 있다 — (1) `nobel` 오타라 grep 출력이 항상 빈 문자열,
(2) 그래서 `[ ! ]` 가 되는데 이건 "문자열 `!` 가 비어있지 않은가" → **항상 참**,
(3) 부정이 거꾸로 — "noble 이 **아닐** 것" 을 주장한다. 실측:

```
[ ! $(echo "" | grep nobel) ]        → PASS  (공허하게 통과)
[ ! $(<noble 출력> | grep noble) ]   → bash: [: unary operator expected → FAIL
```

**오타만 고치면 오히려 깨진다.** 위 옵션 전달이 생겼으니 제대로 쓸 수 있다:
전달받은 `imageVariant` 와 `lsb_release -cs` 를 비교. 그러면 **배선 테스트를 겸한다** —
옵션이 죽어 있으면 값이 어긋나 RED 가 된다.

지금은 옵션 default(`noble`)와 하드코딩된 이미지(`noble`)가 우연히 같아 GREEN 이다.
재설계에서 default 가 `resolute` 로 가면 배선 없이는 RED 가 된다 — 원하는 신호다.
**이 체크는 재설계 후에도 살아남는다.**

> 나머지 커버리지 보강(zsh 로그인 셸, oh-my-zsh 부재, fzf 실동작, 도구 실행 검증)은
> **여기서 하지 않는다.** ubuntu 재설계에서 `common-utils` → prezto 로 가면 검사 대상이
> 통째로 바뀐다 (`~/.zshrc` 가 심볼릭 링크가 되어 지금의 grep 검사는 대상 파일 자체가 없어진다).
> 교체될 템플릿에 테스트를 붙이는 건 순서가 거꾸로다. §3 에서 목표 동작을 향해 쓴다.

> **CI 는 tidy 에서 하지 않는다** (§5). CI 가 make 타깃을 부르는 형태로 갈 것이므로,
> Makefile(§4) 보다 먼저 손대면 `run:` 줄을 두 번 쓰게 된다. 그때까지 검증은 위의 로컬
> 실행으로 한다.

---

## 2. rohd 템플릿 이식

출처: `rohd-dev/rohd-template/` (`.git` 없음, 120K — 복사 자체는 깨끗).
**`src/rohd` 아래만 건진다.** 루트의 세 파일은 독립 리포를 전제로 만들어진 것이라 그대로 오면 안 된다.

### 2-1. 옮기기

- [x] ~~`rohd-dev/rohd-template/src/rohd/` → `src/rohd/`~~ 17 개 파일, `diff -r` 로 원본과
      동일 확인. `.gitignore` 수정 덕에 `.devcontainer/` 가 빠지지 않았다.

      옵션 정합성도 확인했다 — 선언 3 개(`projectName`, `description`, `dartVersion`)가 전부
      실제로 쓰이고 모두 `default` 가 있어서 `build.sh` 치환이 그대로 돈다.

- [x] ~~**네임스페이스 치환**~~ — `congealer/rohd-devcontainer-template` →
      `congealer/devcontainers`, 2 곳 (`documentationURL`, README 의 apply 예시).
      **`licenseURL` 은 필드 자체가 없어서 새로 넣었다** — ubuntu 와 같은 값.

      **건드리지 않았다:** `src/rohd/.devcontainer/devcontainer.json` 의
      `ghcr.io/congealer/devcon-features/prezto:1`. 별개의 공개 feature 이고 이미 `congealer`
      네임스페이스다.

- [x] ~~**`lsd` 를 apt 목록에 추가한다.**~~ 도구 목록 결정에 따라 rohd 쪽에서 바뀐 유일한 것이다.

- [x] ~~**README 를 NOTES.md 로.**~~ `generate-docs` 가 만들 부분 — 제목, 설명 한 줄,
      옵션 표 — 은 **지웠고** 나머지만 `NOTES.md` 로 옮겼다.
      `dartVersion` 의 `proposals` 는 생성 표에 안 나오므로 NOTES 에 문장으로 적었다.

      `src/rohd/README.md` 는 지금 **없다.** `make docs`(§4-3) 를 돌리면 생긴다.
      지금 `generate-docs` 를 한 번 돌려 만들 수도 있지만, 그러면 아직 손으로 쓴
      `src/ubuntu/README.md` 까지 같이 재생성돼 날아간다 — 템플릿 하나만 고르는 옵션이 없다.

### 2-2. 가져오지 않을 것 / 흡수할 것

- [x] ~~`rohd-template/README.md`~~ — 독립 리포용이라 버린다. 거기 있던
      "`templates apply` 는 OCI 참조만 받는다"(= 발행 전에는 apply 를 시험할 수 없다)는
      제약은 **어디에도 옮기지 않기로 했다.** `dev.md` 의 유일한 섹션은 테스트 하네스라
      발행 얘기가 뜬금없고, `-t ./src/rohd` 를 시도하면 CLI 가 즉시 거부하므로 발견도 쉽다.
      발행 절(§4-2)을 쓰게 되면 그때 자연히 들어갈 내용이다.
- [x] ~~`rohd-template/.github/workflows/release.yaml`~~ — §1-1 에서 이미 가져다 썼다.

- [x] ~~`rohd-template/HANDOFF.md`~~ — **삭제함.** 통과 기준은
      [test/rohd/test.md](test/rohd/test.md) 로 옮겼고, 나머지 근거도 흩어 놓았다.
      지우기 전에 대조해서, **HANDOFF 에만 있던 근거 둘**을 파일 주석으로 옮겼다:
      `dart.checkForSdkUpdates: false` 의 이유(feature 메타데이터)와 `pubspec.lock` 을
      넣지 않는 이유(`pubspec.yaml`). `rohd-dev/` 는 gitignore 라 히스토리에도 없어서
      그냥 지웠으면 영영 사라질 것이었다.

- [x] ~~**prezto 를 빼는 방법을 안내한다.**~~ → `docs/rohd.md` 에 `### prezto 빼기` 추가.
      그냥 feature 를 지우면 **fzf 의 `^R` 이 같이 사라지고**(연동이 `extraZshrc` 에 얹혀
      있어서) **로그인 셸이 bash 로 돌아간다**(zsh 를 로그인 셸로 만드는 것도 prezto 다).
      bash 로 fzf 를 옮기는 법과, `dev.containers.defaultFeatures` 로 개인 설정에 두는
      방법도 같이 적었다.

      같은 파일의 "컨테이너가 주는 것" 표도 고쳤다 — Dart 를 `3.12.2` 고정이라고
      적어놨고, CLI 도구 목록에 `lsd` `xxd` `file` `fzf` 가 빠져 있었다.

### 2-3. `test/rohd/test.sh`

HANDOFF.md 가 "CI 하네스를 전제로 하는데 아직 리포도 워크플로도 없다" 며 일부러 안 만들었다고
적어뒀다. 이제 생겼으니 만들었다. **§1-2 의 옵션 전달이 전제였다** — `projectName` 을 알아야
`pubspec.yaml` 과 import 를 검증할 수 있다.

- [x] ~~작성~~ — 검사 11 개. **목록과 근거는 [test/rohd/test.md](test/rohd/test.md) 에 있다.**
      HANDOFF 의 수용 기준을 그대로 옮기지 않았다. 그건 씨앗을 처음 만들 때 "다 됐나" 를
      보는 체크리스트였고, 매 PR 스모크 테스트와는 목적이 다르다.
      뺀 것(`dart test` 개수, RTL 해시·grep, 유틸리티 목록)과 이유도 그 문서에 적어뒀다.
      판단 기준 자체는 [dev.md](dev.md) 의 "무엇을 검사할 것인가" 로 일반화했다.

- [x] ~~**돌려서 확인**~~ — `my_design`(기본)과 `zzz_top` 둘 다 **11/11 통과**.
      기대던 가정 셋도 전부 실측했다:
      - `Dart SDK version: 3.12.2 (stable) ...` — 가정한 형식 맞음
      - `package_config.json` 의 `"name": "rohd"` — 공백 표기 맞음
      - **feature 안에 선언한 lifecycle hook 도 실패하면 빌드가 실패한다** —
        로컬 feature 탐침으로 확인. 에러가 출처까지 밝힌다:
        `updateContentCommand from Feature './features/boom' failed.`

      검출력도 확인했다 — placeholder 를 심고, fzf 함수 이름과 dart 버전을 틀리게 하면
      각각 RED 가 난다.

- [x] ~~**`projectName` 두 개로 시험**~~ — `my_design` / `zzz_top` 수동으로 돌려 둘 다 통과.
      `dart analyze` 가 무경고인 것이 핵심이다 — HANDOFF 가 이 절차로 잡았던 정렬 lint 가
      재발하지 않는다는 뜻이다.

- [x] ~~**dart feature 의 자체 default**~~ → `3.13.2` 로 맞췄다. **두 군데였다** —
      `devcontainer-feature.json` 의 옵션 기본값과 `install.sh` 의
      `VERSION=${VERSION:-...}` 폴백. 정상 경로에서는 CLI 가 옵션 값을 넘기므로 후자는
      안 쓰이지만, 어긋나 있으면 나중에 헷갈린다.

- [x] ~~**`devcontainer.json` 헤더 주석이 상류 ubuntu 를 가리킨다.**~~ → **지웠다.**
      `// README at: .../devcontainers/templates/tree/main/src/ubuntu` 는 씨앗에 딸려온
      것으로 rohd 와 무관했고, 사용자 프로젝트로 복사되는 자리였다. 두 줄이 한 문장이라
      앞줄도 같이 고쳐 `// For format details, see https://aka.ms/devcontainer.json` 만
      남겼다. `src/ubuntu` 도 같이.

### 2-4. 에디터 함정 — **막지 않기로 했다**

`.vscode/settings.json` 에 `dart.analysisExcludedFolders` 를 넣는 안을 검토했고 **안 넣는다.**
이 리포에 Dart 확장을 설치할 일이 없어서 관리 부담만 남는다.

**위험 자체는 실재한다** — 기록해 둔다. `src/rohd/pubspec.yaml` 이 있으므로 Dart 확장이
`src/rohd` 를 프로젝트로 잡으면, import 안의 `${templateOption:projectName}` 을 문자열
보간으로 읽어 **에러 13 건**을 낸다. 그중 `unnecessary_brace_in_string_interps` 의 자동
수정을 수락하면 중괄호가 빠져 **placeholder 가 영구히 망가진다** —
`$templateOption:projectName}`. `dart.updateImportsOnRename`(기본 `true`) 도 같은 위험이다.

성립 조건은 **Dart 확장이 깔린 에디터로 이 리포를 여는 것**이다. 루트 개발 컨테이너는
`bash-ide-vscode` 와 `vscode-eslint` 만 설치하므로 컨테이너 안에서는 안 걸린다.
컨테이너 밖에서 열 때만 조심하면 된다.

그리고 §2-3 의 "`${templateOption:` 이 남아 있지 않을 것" 검사가 사후 방어가 된다 —
망가뜨렸다면 스모크 테스트가 잡는다.

---

## 3. ubuntu 재설계

> 개인 go-to 템플릿. **rohd 와 도구 목록을 통일하지 않는다.** 급하지 않다.

### 3-0. 방식 — 상류를 다시 적용해서 베이스를 간다

상류 `devcontainers/templates/ubuntu` v3.0.0 을 실제로 받아 지금 것과 비교했다.
**diff 가 딱 네 덩어리다:**

| | 상류 | 우리 |
|---|---|---|
| image | `base:resolute` | `base:noble` |
| features | 주석 처리됨 | common-utils, git-lfs, github-cli, fzf, apt-packages |
| postCreateCommand | 주석 처리됨 | fzf zshrc 추가 |
| customizations | 주석 처리됨 | 확장 7 개 |

**그 외에는 한 글자도 안 다르다.** 헤더 주석까지 동일하다
(`// README at: https://github.com/devcontainers/templates/tree/main/src/ubuntu`).

즉 지금 ubuntu 는 이미 "상류 ubuntu + 내 피쳐" 다. 재설계는 재작성이 아니라 **베이스를
최신으로 갈아끼우는 것**이고, 붙일 것은 위 표의 오른쪽 칸이다.

```bash
devcontainer templates apply -t ghcr.io/devcontainers/templates/ubuntu -w /tmp/base
```

이점:
- 옵션 블록(`proposals` / `default` / `description`)을 통째로 물려받는다 →
  **`Nobel` 오타와 description/proposals 불일치가 논의 없이 소멸한다**
- 다음에 상류가 올라가면 다시 적용해서 diff 만 보면 된다
- 적용 결과에는 `image` 가 이미 치환돼 있으니 `${templateOption:imageVariant}` **한 줄만
  되돌리면 배선도 끝난다**

상류의 옵션 블록:

```json
"proposals": ["resolute", "noble", "jammy"],
"default": "resolute"
```

지원 끝난 `focal`(20.04, 2025-05)·`bionic`(18.04, 2023-05)이 이미 빠져 있다.

**가져오지 말 것: `optionalPaths` + `.github/dependabot.yml`.**
상류는 `dependabot.yml` 을 `optionalPaths` 로 선언하는데, **CLI 가 그걸 무시하고 그냥
적용해버리는 것을 실측으로 확인했다.** rohd HANDOFF 의 기록과 일치한다 — VS Code 는
체크박스를 띄우되 전부 `picked: false` 라 그냥 넘기면 빠지고, CLI 는 `optionalPaths` 를
읽지도 않아 항상 포함한다. **같은 템플릿에서 다른 프로젝트가 나온다.**

### 3-1. 코드네임 ↔ 버전 (MCR 실측)

| 코드네임 | 버전 | 표준 지원 종료 | MCR 태그 |
|---|---|---|---|
| `bionic` | 18.04 LTS | 2023-05 (지남) | 있음 |
| `focal` | 20.04 LTS | 2025-05 (지남) | 있음 |
| `jammy` | 22.04 LTS | 2027-04 | 있음 |
| `noble` | 24.04 LTS | 2029-04 | 있음 |
| **`resolute`** | **26.04 LTS** | **2031-04** | **있음** |

다이제스트 비교로 확인한 것: **부동 태그 `base:ubuntu` 가 이미 `resolute` 를 가리킨다.**

```
ubuntu     sha256:1f8bb87ca6d342a587a
resolute   sha256:1f8bb87ca6d342a587a   ← 동일
noble      sha256:cfd5dd36c0d0d88de01
```

태그 명명이 상류에서 어긋나 있다 — `ubuntu-18.04`~`ubuntu-24.04` 는 하이픈 형태가 있는데
26.04 는 `ubuntu26.04` 만 있고 `ubuntu-26.04` 는 없다. **코드네임 태그를 쓰는 게 안전하다.**

### 3-2. 할 일

- [x] ~~**도구 목록을 rohd 것 + `lsd` 로 맞춘다**~~ → 최종 7 개:
      `bat` `lsd` `fd-find` `ripgrep` `tig` `xxd` `file`.
      **뺀 것**: `vim-gtk3`, `bc`, `git-lfs`(feature). **더한 것**: `file`, `lsd`.

      **`tldr` 은 결국 못 넣었다.** Haskell 클라이언트가 Rust 의 `tealdeer` 로 교체되면서
      22.04 에는 `tldr`, 24.04 에는 둘 다, 26.04 에는 `tealdeer` 만 남았다. 세 배포판
      모두에서 `tldr` 명령을 주는 패키지가 없다 (`tldr-py` 는 셋 다 있지만 명령이
      `tldr-py`).

      **여기 적어뒀던 "`lsd` 는 noble/jammy/resolute 모두 apt 에 있다"는 틀렸다.**
      jammy 에는 없다 (`E: Unable to locate package lsd`). 그래서 `lsd` 를 살리고
      **`jammy` 를 `proposals` 에서 뺐다** — 옵션 `description` 과 `NOTES.md` 도 같이.

      "없는 배포판이면 빌드가 실패하므로 조건이 자동으로 강제된다"고도 적어뒀는데,
      **아무도 그 조합을 빌드하지 않으면 강제되지 않는다.** 기본값을 `resolute` 로 올린
      뒤에야 드러났다.

- [x] ~~**prezto 를 넣는다**~~ 그러면 fzf 배선을 `postCreateCommand` 에서
      `extraZshrc` 로 옮겨야 한다 — prezto 가 `~/.zshrc` 를 자기 runcoms 로 심볼릭 링크하므로
      `>> ~/.zshrc` 는 **prezto 가 소유한 파일을 건드리는 것**이 된다. rohd 가 쓰는 값에는
      가드가 있어 fzf feature 를 빼도 셸이 안 깨진다:
      `(( $+commands[fzf] )) && source <(fzf --zsh)`

      **`common-utils` 도 같이 정리된다.** 지금 ubuntu 는 그걸로 zsh 를 깔고 로그인 셸을
      바꾸는데, prezto 가 그 일을 대신한다. rohd 의 주석이 근거다 —
      base 이미지가 이미 `vscode` 유저·sudo·zsh 를 갖고 있어서 feature 로 나열할 필요가 없다.
- [x] ~~**상류 재적용** → 피쳐 블록 이식 → `${templateOption:imageVariant}` 복원~~
      상류 파일 둘을 그대로 덮고 나서 고쳤다. `image` 가 `base:noble` 로 하드코딩돼 있어
      **옵션이 아무 데도 안 쓰이던 것**이 이때 드러났다.

- [x] ~~**`name` / `description` / `publisher`**~~ → `Ubuntu` / prezto·fzf·gh·유틸리티를
      나열하는 한 줄 / `congealer`. `optionalPaths` 는 §3-0 결정대로 안 가져왔다.

- [x] ~~**테스트를 목표 동작에 맞춰 새로 쓴다**~~ → 검사 3 개에서 18 개로.
      RED→GREEN 순서는 못 지켰다 (재설계를 먼저 해버렸다).

      **`which` 말고 실행하라고 적어뒀던 건 뒤집었다.** 배포판 저장소의 apt 패키지는
      의존성이 풀려 설치된 것이라 실행이 더 잡아주는 게 없고, 도구마다 버전 플래그를
      명시해야 해서 값에 비해 번잡하다. 실제로 잡고 싶은 `bat`→`batcat` 류의 이름
      어긋남은 `command -v` 로 충분하다. rohd 의 `dart --version` 은 사정이 달랐다 —
      tarball 을 root 가 깔아서 remote 유저 PATH 가 진짜 위험이었다.

      **oh-my-zsh 는 "부재" 가 아니라 "소유권" 을 본다.** 베이스 이미지가 깔아둔 것이
      디스크에 그대로 남으므로, `~/.zshrc` 가 prezto 를 가리키는지를 검사한다.

- [x] ~~**도구 목록 이중 관리 해소**~~ → 목록은 `devcontainer.json` 에만 두고, test.sh 는
      패키지→명령 매핑만 갖는다. 둘이 어긋나면 검사가 실패한다. 목록에 `jq` 를 끼워넣어
      RED 가 나는 것까지 확인했다.
- [ ] **재발행.** `documentationURL` 이 **이미 발행된 아티팩트에 잘못 박혀 있다**:

      ```
      "documentationURL":"https://github.com/congealer/devcontainers/tree/main/src/hello"
      ```

      `src/hello` 가 없어졌으니 이제 진짜 404 다. 에디터 hover 에 뜨는 링크다.
      **소스를 고쳐도 `version` 범프 + 재발행 전까지는 안 고쳐진다.**

---

## 4. 개발 워크플로 — devcon-features 방식 이식

출처: `rohd-dev/devcon-features/` 의 `Makefile`, `prepare.py`, `CONTRIBUTING.md`.

### 4-0. features 와 templates 의 차이 (먼저 읽을 것)

그대로 복사되지 않는다. CLI 0.83.3 으로 확인:

| | features | templates |
|---|---|---|
| `<kind> test` 서브커맨드 | **있음** | **없음** |
| 시나리오 / `duplicate.sh` | 있음 | 없음 |
| `generate-docs -p` | `src` | `.` (`src` 와 `test` 를 가진 **프로젝트 루트**) |
| `generate-docs -n` | 있음 | **없음** (`--github-owner`/`--github-repo` 만) |
| 생성 틀의 `## Example Usage` | 있음 | **없음** |
| 테스트 라이브러리 | CLI 제공 `dev-container-features-test-lib` | 자체 `test/test-utils/test-utils.sh` |
| 옵션 전달 | `install.sh` 에 **환경 변수** 주입 | **텍스트 치환뿐.** 런타임이 없음 |

서브커맨드는 `apply` / `publish` / `metadata` / `generate-docs` 넷뿐이다.

### 4-1. Makefile

- [x] **`Makefile`.** devcon-features 것을 뼈대로 하되 테스트 부분은 다시 짠다.
      가져올 것: `.DEFAULT_GOAL := help` + `## ` 주석 자기문서화, 덮어쓸 수 있는 기본값,
      `TEMPLATES := $(notdir $(wildcard src/*))`, `require-template` 가드,
      `clean` / `distclean`.

- [x] **테스트 타깃 설계.** `templates test` 가 없으므로 대응물이 없다.
      Makefile 이 `smoke-test/{build,test}.sh` 를 감쌀지, 로직을 흡수하고 스크립트를 없앨지.

- [x] **`clean` 의 이미지 패턴.** devcon-features 의 `vsc-<타임스탬프>-<해시>-features` 는
      템플릿 쪽과 다르다. `devcontainer up` 은 폴더 이름 기반 이미지를 남긴다.

### 4-2. `make prepare` / `make release` / `make docs`

- [x] **`prepare.py`.** `devcontainer-feature.json` → `devcontainer-template.json` 만 바꾸면
      나머지는 그대로 동작한다. 핵심(버전이 박힌 커밋 이후에 바뀐 템플릿을 git 로그로 찾아
      미리 체크)은 템플릿에도 유효하다. 버전만 쓰고 커밋은 사람에게 남긴다.

- [x] **`make release`** — `gh auth status` 확인 후
      `GITHUB_TOKEN=$(gh auth token) devcontainer templates publish -r ghcr.io -n congealer/devcontainers ./src`.
      docker 불필요.

- [x] **`make docs`** — 인자가 features 와 다르다:
      `devcontainer templates generate-docs -p src --github-owner congealer --github-repo devcontainers`.
      `-p` 는 도움말과 달리 **템플릿이 들어 있는 폴더**를 원한다. `.` 를 주면 리포 루트의
      모든 하위를 훑는다.

- [x] **릴리스 전 체크리스트 문서화** (§4-4):
      - **`version` 이 발행 여부를 정하는 유일한 스위치다.** 안 올리면 조용히 아무 일도 안 일어난다
      - **태그가 움직인다.** `1.3.0` 을 올리면 `1.3.0`/`1.3`/`1`/`latest` 가 함께 올라가는데
        `1` 과 `latest` 는 **기존에서 옮겨온다** → `:1` 로 고정한 사용자가 다음 빌드에서 바로 받는다
      - **GHCR 패키지는 처음 올리면 private.** 공개 전환과 리포 연결이 한 번 필요하다

> **발행 현황 (확인됨)**: `ghcr.io/congealer/devcontainers/ubuntu` 는 **이미 공개 발행돼 있다.**
> 익명으로 태그가 조회된다 — `1`, `1.0`, `1.0.0`, `latest`. 매니페스트도 정상적인 템플릿
> 아티팩트다. 주소가 옛 이름으로 바뀌기 전에 **로컬에서 올린 것**이다 (깨진 release
> 워크플로는 한 번도 성공한 적이 없으므로). `rohd` 는 발행된 적 없다.

### 4-3. 문서 체계 — README 자동 생성 + NOTES.md

> **쓰기로 정해졌다.** 다만 적용은 나중이라, 그때까지 `make docs` 와 release 의
> `generate-docs` 는 꺼둔다. **단 rohd 는 이식할 때부터 이 형태로 넣는다** (§2-1) —
> 나중에 도입하면 다시 쪼개야 하므로.

**`generate-docs` 는 `src/<id>/README.md` 를 덮어쓴다.** CLI 0.83.3 소스에서 확인한 틀:

```
# #{Name}

#{Description}

#{OptionsTable}

#{Notes}            ← src/<id>/NOTES.md 를 여기 끼워 넣는다

---

_Note: This file was auto-generated from the devcontainer-template.json.
 Add additional notes to a `NOTES.md`._
```

`templates apply` 는 **`devcontainer-template.json`, `README.md`, `NOTES.md` 를 제외한다**
(상류 ubuntu 를 적용할 때 CLI 로그로 확인:
`Files to omit: 'devcontainer-template.json, README.md, NOTES.md'`).
그래서 사용자에게 갈 안내서는 다른 파일에 둬야 한다 (rohd 는 `docs/rohd.md`).

<details>
<summary>실물 샘플 — 지워진 <code>src/hello/README.md</code></summary>

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
- 옵션 표는 `description`/`type`/`default` 만 옮긴다 — **`proposals` 는 안 나온다**

</details>

- [x] **손으로 쓴 한국어 README 를 `NOTES.md` 로 옮긴다** — ubuntu, rohd.
      옮기지 않으면 릴리스 때 날아간다.
- [x] **apply 예시는 NOTES.md 에 직접 쓴다.** 템플릿 틀에는 `## Example Usage` 가 **없다.**
- [x] **옵션 표를 손으로 쓰지 않는다.** `#{OptionsTable}` 이 만든다. 지금
      [src/ubuntu/README.md](src/ubuntu/README.md#L7-L11) 에 손으로 쓴 표가 있는데 드리프트 원인이다.

### 4-4. `dev.md`

개발자용 문서는 루트 [dev.md](dev.md) 로 분리했다 (devcon-features 의 `CONTRIBUTING.md`
자리). 절 구성은 **Makefile / 테스트 하네스 / 문서 / 릴리스 / CI**.

- [x] **`make` 타깃 표와 `clean`/`distclean` 이 지우는 것** — §4-1 이후.
- [x] **문서 생성 규칙** — README 는 자동 생성물이니 `NOTES.md` 를 고치라는 안내 (§4-3).
- [x] **릴리스 절차와 주의점** — §4-2 의 체크리스트.
- [ ] **CI 절 갱신** — §5 가 끝나면 실제 형상과 맞는지 대조. 지금은 목표 형상을 적어뒀다.
- [x] **루트 README 의 "Testing Templates" 절을 dev.md 로 넘긴다** — 지금 로컬 실행법이
      양쪽에 중복돼 있다.

### 4-5. 개발 컨테이너

> **완료.** base 를 `base:ubuntu-24.04` 로 바꾸고 feature 로 다시 짰다.

- [x] **base 이미지 교체** — `javascript-node:1-18-bullseye` → `base:ubuntu-24.04`.
- [x] **Node 는 넣지 않는다.** `devcontainers-cli` feature 가 node 18 을 끌어오고 CLI
      0.83.3 이 붙는다. `engines: node >=20` 은 권고일 뿐이라 실제로 동작하며, 20+ 가
      있어야만 되는 기능도 없었다. node feature 는 중복이라 뺐다.
- [x] **`github-cli` feature 추가** — `make release` 의 `gh auth token` 에 필요.
- [x] **python + questionary** — `make prepare` 용. base:ubuntu 의 Python 3.12 가
      PEP 668 externally-managed 라 `--break-system-packages` 가 필요하다.
- [x] **`dbaeumer.vscode-eslint` 확장 제거** — template-starter 가 JS 기반이라 붙어 있던 것.
- [x] **`json.schemas` 설정 제거.**
- [x] **`npm install -g @devcontainers/cli` 제거** — feature 로 대체.
- [x] **docker-in-docker 4 로 올렸다.**

---

## 5. CI 정비 — **Makefile(§4) 이후**

**한 번에 make 를 부르는 형태로 만든다.** 스크립트를 직접 부르는 중간 단계를 거치지
않는다 — 그러면 `run:` 줄을 두 번 쓰게 된다.

그때까지 CI 는 죽어 있다. paths-filter 에 `color`, `hello` 만 적혀 있는데 둘 다 없으니
매트릭스가 비고 job 이 스킵된다. **어떤 템플릿도 테스트되지 않는다.** 게다가
`continue-on-error: true` 라 실패해도 초록으로 뜬다. 그 사이 검증은 로컬에서 한다
([dev.md](dev.md) 참고).

### 5-1. 테스트 워크플로

- [ ] **매트릭스를 리포에서 읽는다.** devcon-features 의 `test.yaml` 방식:

      ```bash
      all=$(ls src | jq -R . | jq -sc .)
      ```

      주석에 이유가 적혀 있다 — "feature 를 추가해도 테스트가 빠질 수 없게".
      지금은 정확히 반대라 손으로 적은 목록을 쓴다. 이 방식이면 **죽은 필터 문제가
      통째로 사라진다** — paths-filter 자체가 없어지므로.

- [ ] **`continue-on-error: true` 를 뗀다.**
      [test-pr.yaml:21](.github/workflows/test-pr.yaml#L21).
      **테스트가 실패해도 PR 체크가 초록으로 뜬다.** 위 필터 문제와 겹쳐서, `distro` 체크가
      공허하게 통과한다는 걸 CI 가 잡을 수 없었던 이유이기도 하다.

- [ ] **`run:` 을 make 타깃으로.** `run: make test-${{ matrix.template }}` 형태.
      로컬과 CI 가 같은 경로를 탄다.

- [ ] **`npm install -g @devcontainers/cli` 를 워크플로에 넣는다.** `build.sh` 에 있던 것을
      뺐다 — 개발 컨테이너에는 feature 로 이미 깔려 있어 root 소유 설치와 충돌(EACCES)했다.
      러너에는 CLI 가 없으므로 **CI 쪽에서 다시 넣어야 한다.** 상류(features, templates,
      template-starter)도 전부 워크플로 스텝으로 설치한다.

- [ ] **`smoke-test` composite action 의 거취.** Makefile 이 `build.sh`/`test.sh` 로직을
      흡수하면 이 action 은 사라진다. 감싸기만 하면 남는다 (§4-1 결정에 따라).

- [ ] **`ci:` 집계 job.** 매트릭스가 늘어도 이름이 안 바뀌는 체크 하나 —
      branch ruleset 이 하나만 걸면 되게. devcon-features `test.yaml` 의 마지막 job.

- [ ] **위생.** `actions/checkout@v3` → `v4`
      ([test-pr.yaml:26](.github/workflows/test-pr.yaml#L26),
      [smoke-test/action.yaml:12](.github/actions/smoke-test/action.yaml#L12)),
      `concurrency` 그룹 추가, 중복 checkout 정리
      (test-pr.yaml 에서 이미 했는데 composite action 이 또 한다).

- [ ] **`push: branches: [main]` 트리거를 넣을지.** 지금은 `pull_request` 뿐이라 main 에
      직접 푸시하면 아무것도 안 돈다. devcon-features 는 push/PR/dispatch 셋 다.

### 5-2. 그 밖

- [ ] **`validate` 워크플로.** devcon-features 의 `validate.yml` 이
      `devcontainers/action@v1` 의 `validate-only: "true"` 로 메타데이터를 검증한다.
- [ ] **버전 범프 검사.** PR 에서 "바뀐 템플릿의 `version` 이 올랐는가". `make prepare` 를
      빠뜨렸을 때 조용히 no-op 되는 걸 막는다.
- [ ] **문서 PR 스텝.** §4-3 을 하면 `generate-docs` 를 켜고, 뒤에
      `automated-documentation-update-*` PR 을 여는 스텝을 붙인다 (devcon-features 방식).
      `release.yaml` 의 `generate-docs: "false"` 도 그때 켠다.
- [ ] **[dev.md](dev.md) 의 CI 절 대조.** 지금 목표 형상을 적어둔 상태다. 실제와 맞는지
      확인하고, 범위 밖으로 뺀 `release.yaml` 과 `action.yaml` 파일명을 넣을지 정한다.

---

## 6. 정리

- [x] ~~`.devcontainer/devcontainer-lock.json` 을 커밋할지~~ → **커밋함.**
      docker-in-docker 2.17.0 을 digest 로 고정. §4-5 에서 feature 를 추가하면 바뀐다.

- [x] ~~`hello`/`color` 를 남길지~~ → **제거함.** 발행된 적이 없어 소비자 영향 0.

- [x] ~~`.gitignore` 의 `.*` 규칙~~ → **해결됨.**
      `.*` 가 `src/rohd/.devcontainer/**` 와 `.vscode/**` 를 조용히 삼키고 있었다.
      `!.devcontainer` 와 `!.vscode` 로 되살렸고 종료 코드로 확인:

      ```
      src/rohd/.devcontainer/features/dart/install.sh   ok
      .vscode/settings.json                             ok
      .env  .DS_Store  .dart_tool/x                     IGNORED   ← 원래 목적은 유지
      ```

- [x] **루트 README 갱신** — `rohd` 를 템플릿 목록에 추가, 개발자용 내용은 [dev.md](dev.md) 로
      이관(§4-4).

- [ ] **리포 토픽에 `devcontainer-templates` 추가.** 없으면 containers.dev 색인에 안 잡히고
      VS Code 의 hover·자동완성이 안 된다 (HANDOFF.md 가 `congealer/devcon-features` 에서
      같은 문제를 겪었다고 기록).

---

## 7. 순서 의존성 (조사 결과)

**제안이 아니라 확인된 제약이다.**

### rohd 는 ubuntu 재설계에 의존하지 않는다

`src/rohd/`, `test/rohd/` 는 전부 신규 파일이고 ubuntu 쪽과 겹치는 파일이 하나도 없다.
**rohd 를 먼저 해도 된다** — 당장 쓸 것도 그쪽이다.

### tidy(§1) 가 rohd 앞에 온 이유 — 끝났다

| | 왜 |
|---|---|
| **§1-2 하네스 옵션 전달** | rohd 테스트가 `projectName` 을 알아야 한다. 없으면 `pubspec.yaml` 과 import 검증을 못 한다 |
| **§1-2 밖에서 옵션 지정** | HANDOFF 가 요구하는 "이름 두 개(`my_design`/`zzz_top`)로 시험" 이 불가능하다 |
| **§1-2 `trap` + `KEEP`** | 새 템플릿을 붙일 땐 실패를 여러 번 겪는다. 그전에는 실패마다 컨테이너가 샜다 |

### rohd 는 CI 없이 들어온다

CI 정비(§5)가 Makefile(§4) 뒤로 갔으므로, **rohd 를 붙이고 검증하는 내내 CI 는 죽어 있다.**
검증은 로컬 루프로 한다 — `build.sh` → `KEEP=1 test.sh` → 고쳐서 재실행. 실제로 이 루프가
도는 것은 tidy 에서 확인했다.

### rohd 보다 앞서면 이득인 것 (tidy 밖)

| | 왜 |
|---|---|
| **§4-3 문서 체계** | `generate-docs` 가 `README.md` 를 덮어쓴다. rohd 를 손으로 쓴 README 째로 넣으면 나중에 NOTES.md 로 다시 쪼개야 한다. 처음부터 그 형태면 **재작업 0** — 그래서 rohd 만은 이식할 때부터 NOTES.md 형태로 넣기로 했다 |
| **§4-5 Node 20** | 현재 v18.20.8, CLI 요구는 20+. rohd 스모크 테스트는 Dart SDK 를 받고 컨테이너를 띄우는 무거운 작업이라 헛시간 쓰기 쉽다 |

### rohd 발행에만 걸리는 것

**§4-1/4-2 Makefile** — 이식과 테스트 작성까지는 없어도 된다. GHCR 에 올리는 시점에 필요.

### 의존성이 아닌 것

- **네임스페이스** — 정해졌고 `git remote` 와 이미 일치한다
- **ubuntu 재설계** — rohd 와 파일이 안 겹치고, 도구 목록을 통일하지 않기로 했으므로
  설계 결정도 공유하지 않는다
