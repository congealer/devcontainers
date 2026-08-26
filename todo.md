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

작업 브랜치는 `tidy`.

- [x] **hello/color 제거**
      템플릿 둘과 테스트 삭제, 루트 README 목록 정리, `.gitignore` 추가, `devcontainer-lock.json` 커밋
- [ ] **tidy 마무리** (§1) ← **지금 여기.** 아래 12 건
      - [x] 자잘한 것 — 네임스페이스 6 곳, `documentationURL` 경로, 매달린 `---`, 루트 README 문구
      - [x] LICENSE 저작권 줄 + `licenseURL` (§1-1)
      - [ ] `release.yaml` 교체 (§1-1)
      - [x] 하네스 — `build.sh` 가 옵션 값을 컨테이너로 전달 (§1-2)
      - [x] 하네스 — `build.sh` 가 옵션 값을 밖에서 받음 (`TEMPLATE_ARGS`) (§1-2)
      - [x] 하네스 — `test.sh` 에 `trap` + `KEEP` (§1-2)
      - [x] `test/ubuntu/test.sh` 의 `distro` 체크 재작성 (§1-2)
      - [x] `dev.md` — 하네스 개발 가이드 (§4-4). **CI 절은 §1-3 이후의 형상을 적어뒀다**
      - [ ] CI — 매트릭스를 `ls src` 에서 (§1-3)
      - [ ] CI — `continue-on-error` 제거 (§1-3)
      - [ ] CI — `ci:` 집계 job (§1-3)
      - [ ] CI — 위생: checkout v4, `concurrency`, 중복 checkout 제거 (§1-3)
- [ ] **rohd 이식** (§2) — 새 브랜치. **당장 쓸 것은 이쪽**
- [ ] **ubuntu 재설계** (§3) — 새 브랜치. 급하지 않음
- [ ] 개발 워크플로 (§4), 남은 CI (§5)

---

## 0. 정해야 할 것

**지금은 없다.** 방향을 가르는 결정은 전부 위 표로 옮겨졌다.

남아 있는 "정한다" 항목들은 각 섹션 안의 구현 시점 선택이지 선행 조건이 아니다 —
rohd 의 `version`(§2-1), Makefile 의 테스트 타깃 설계(§4-1),
`name`/`description`(§3-2), CI 트리거와 composite action 의 거취(§5).

---

## 1. tidy 마무리 — **지금 하는 것**

여기까지 하고 `tidy` 를 닫는다. 목표는 **rohd 를 얹기 좋은 바닥을 만드는 것**이다.

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

### 1-3. CI

#### 매트릭스를 리포에서 읽는다

devcon-features 의 `test.yaml` 방식:

```bash
all=$(ls src | jq -R . | jq -sc .)
```

주석에 이유가 적혀 있다 — "feature 를 추가해도 테스트가 빠질 수 없게".
지금은 정확히 반대다: paths-filter 에 손으로 적은 `color`, `hello` 만 있어서
**ubuntu 는 CI 에서 한 번도 돌아본 적이 없고**, rohd 를 넣으면 또 빠뜨릴 자리다.

**덤으로 죽은 필터 문제가 통째로 사라진다** — paths-filter 자체가 없어지므로.
(지금 그 두 필터는 매칭될 파일이 없어 매트릭스가 비고 job 이 스킵된다. 깨지진 않지만
어떤 템플릿도 테스트되지 않는다)

#### `continue-on-error: true` 를 뗀다

[test-pr.yaml:21](.github/workflows/test-pr.yaml#L21).
**테스트가 실패해도 PR 체크가 초록으로 뜬다.** 위 필터 문제와 겹쳐서, `distro` 체크가
공허하게 통과한다는 걸 CI 가 잡을 수 없었던 이유이기도 하다.
devcon-features 에는 이 플래그가 없다.

#### `ci:` 집계 job

매트릭스가 늘어도 이름이 안 바뀌는 체크 하나 — branch ruleset 이 하나만 걸면 되게.
devcon-features `test.yaml` 의 마지막 job.

#### 위생

`actions/checkout@v3` → `v4` (3 곳: [test-pr.yaml:26](.github/workflows/test-pr.yaml#L26),
release.yaml, [smoke-test/action.yaml:12](.github/actions/smoke-test/action.yaml#L12)),
`concurrency` 그룹 추가, 중복 checkout 정리
([test-pr.yaml:26](.github/workflows/test-pr.yaml#L26) 에서 이미 했는데
[smoke-test/action.yaml:10-12](.github/actions/smoke-test/action.yaml#L10-L12) 이 또 한다).

**Makefile 은 여기서 안 한다** (§4). 로컬 편의와 `prepare`/`release` 용이라 위 목적과 무관하고,
넣으면 tidy 가 부풀어 오른다. 나중에 CI 의 `run:` 두 줄만 바꾸면 된다.

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
      - `src/rohd/README.md` 의 apply 예시 → `ghcr.io/congealer/devcontainers/rohd`

      **건드리지 말 것:** `src/rohd/.devcontainer/devcontainer.json` 의
      `ghcr.io/congealer/devcon-features/prezto:1`. 별개의 공개 feature 이고 이미 `congealer`
      네임스페이스다. GHCR 태그 조회로 공개 확인 완료 (`1`, `1.0`, `1.0.0`, `1.2`, `1.2.1`, `latest`).

- [ ] **`lsd` 를 apt 목록에 추가한다.** 도구 목록 결정에 따라 rohd 쪽에서 유일하게 바뀌는 것이다.

- [ ] **README 를 NOTES.md 형태로 넣는다.** `generate-docs` 를 쓰기로 정해졌으므로(§4-3),
      처음부터 이 형태로 넣으면 재작업이 없다 — 나중에 도입하면 손으로 쓴 한국어 README 를
      다시 쪼개야 한다.

- [ ] **`version`.** 지금 `0.0.1`. 컨테이너를 띄운 검증이 안 끝난 상태라 그게 맞지만, 이 리포에
      들어오면 스모크 테스트가 그 검증을 대신한다 → 통과 후 `1.0.0`.

### 2-2. 가져오지 않을 것 / 흡수할 것

- [ ] `rohd-template/README.md` — 독립 리포용. 이 리포의 [README.md](README.md) 와 충돌한다.
      **발행/개발 루프 설명만 흡수**하고 버린다.
- [ ] `rohd-template/.github/workflows/release.yaml` — §1-1 에서 이미 가져다 쓴다.
- [ ] `rohd-template/HANDOFF.md` — 일회용. 본문 스스로 "검증 끝나면 지우라"고 한다.
      **단, 2-3 을 먼저 하고 지울 것** — 통과 기준이 여기에만 있다.

- [ ] **prezto 를 빼는 방법을 안내한다.** 유지하기로 정해졌지만, 로그인 셸을 바꾸는 건
      개인 취향에 가깝다. rohd 의 `devcontainer.json` 이 스스로 같은 논리를 적어뒀다:

      > AI agent tooling is deliberately absent — it is **per-developer preference,
      > not a project dependency.** Put it in your own VS Code settings instead:
      > `dev.containers.defaultFeatures`

      안 쓸 사람은 feature 를 지우면 되는데, **fzf 배선이 prezto 의 `extraZshrc` 에 얹혀 있어서**
      같이 옮겨야 한다. `docs/rohd.md` 에 그 절차를 적을 것.

### 2-3. `test/rohd/test.sh` 를 만든다

HANDOFF.md 가 "CI 하네스를 전제로 하는데 아직 리포도 워크플로도 없다" 며 일부러 안 만들었다고
적어뒀다. 이제 생겼으니 만든다. **§1-2 의 옵션 전달이 전제다** — `projectName` 을 알아야 한다.

- [ ] `dart analyze` — 무경고
- [ ] `dart test` — 8 개 통과 (예제 설계)
- [ ] `cd packages/rohd_patches && dart test` — 38 개 통과
- [ ] `find . -name package_config.json -not -path './build/*'` — **1 개만**
      (루트에만. 서브패키지에도 생기면 워크스페이스 배선이 깨진 것)
- [ ] `dart run bin/generate_rtl.dart` — `build/counter.sv` 생성
- [ ] 재실행 후 sha256 **동일** (헤더 타임스탬프 회귀 검출). 해시값 자체는 비교하지 말 것
- [ ] `grep 'val <= (val + ' build/counter.sv` — 있어야 함 (증가가 `always_ff` 안에 인라인)
- [ ] `grep carry build/counter.sv` — **없어야 함** (있으면 `.inl` 패치가 안 먹은 것)
- [ ] `getent passwd $(id -un)` — `/usr/bin/zsh` 로 끝남 (prezto)
- [ ] `zsh -i -c 'bindkey "^R"'` — `fzf-history-widget`
- [ ] **`${templateOption:` 이 하나도 안 남아 있을 것**
- [ ] `pubspec.yaml` 의 `name` 과 import 경로가 전달받은 `projectName` 과 일치
- [ ] **예제 없이도 서는지** — `rm lib/counter.dart bin/generate_rtl.dart test/counter_test.dart`
      후에도 `dart pub get && dart analyze` 통과 (`packages/rohd_patches` 는 워크스페이스
      멤버라 지우면 안 됨)
- [ ] **`projectName` 두 개로 시험** — `my_design` / `zzz_top`. §1-2 의 "밖에서 옵션 지정" 이 전제.

### 2-4. 에디터 함정 막기

- [ ] **`.vscode/settings.json` 에 `{"dart.analysisExcludedFolders": ["src/rohd"]}`.**

      이 리포를 VS Code 로 열면 `src/rohd/pubspec.yaml` 때문에 Dart 확장이 `src/rohd` 를
      프로젝트로 잡고, `${templateOption:projectName}` 을 Dart 문자열 보간으로 읽어 **에러
      13 건**을 낸다. 더 나쁜 건 `unnecessary_brace_in_string_interps` 자동 수정을 수락하면
      placeholder 가 **영구히 망가진다**는 것 — `$templateOption:projectName}`.
      `dart.updateImportsOnRename`(기본 `true`) 도 같은 위험이 있다.

      트레이드오프: 끄면 진짜 문제도 안 보인다. 그래서 2-3 의 테스트가 그 역할을 해야 한다.

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

- [ ] **도구 목록을 rohd 것 + `lsd` 로 맞춘다** (결정됨).
      `bat` `fd-find` `ripgrep` `tig` `tldr` `xxd` `file` `lsd`.
      **빠지는 것**: `vim-gtk3`, `bc` (apt 패키지), `git-lfs` (feature — 필요하면 그때 넣는다).
      **더해지는 것**: `file`, `lsd`.
      `lsd` 는 noble/jammy/resolute 모두 apt 에 있다 (`packages.ubuntu.com` 확인).
      없는 배포판이면 apt-packages feature 가 빌드에서 실패하므로 조건이 자동으로 강제된다.

- [ ] **prezto 를 넣는다** (결정됨). 그러면 fzf 배선을 `postCreateCommand` 에서
      `extraZshrc` 로 옮겨야 한다 — prezto 가 `~/.zshrc` 를 자기 runcoms 로 심볼릭 링크하므로
      `>> ~/.zshrc` 는 **prezto 가 소유한 파일을 건드리는 것**이 된다. rohd 가 쓰는 값에는
      가드가 있어 fzf feature 를 빼도 셸이 안 깨진다:
      `(( $+commands[fzf] )) && source <(fzf --zsh)`

      **`common-utils` 도 같이 정리된다.** 지금 ubuntu 는 그걸로 zsh 를 깔고 로그인 셸을
      바꾸는데, prezto 가 그 일을 대신한다. rohd 의 주석이 근거다 —
      base 이미지가 이미 `vscode` 유저·sudo·zsh 를 갖고 있어서 feature 로 나열할 필요가 없다.
- [ ] **상류 재적용** → 피쳐 블록 이식 → `${templateOption:imageVariant}` 복원
- [ ] **`name` / `description` / `publisher`.** 지금은 `"My ubuntu dev container"` /
      `"...with some useful tools"` 로 아무 정보가 없다. **발행 메타데이터라 VS Code 템플릿
      목록과 에디터 hover, 생성 README 첫 줄에 뜬다.** 상류에는 `publisher` 필드가 있는데
      우리 것엔 없다.
- [ ] **테스트를 목표 동작에 맞춰 새로 쓴다.** 순서: 목표 테스트 작성 → **RED**(아직 재설계 전) →
      재설계 → **GREEN**. §1-2 에서 `distro` 체크를 먼저 고쳐두는 이유가 이것이다 —
      항상 통과하는 체크를 두고는 재설계가 됐는지 잴 수 없다.
      담을 것: zsh 로그인 셸, oh-my-zsh 부재(prezto 로 가면 무의미), fzf 실동작
      (`bindkey "^R"` → `fzf-history-widget`), 도구를 `which` 말고 실행해서 검증
      (`git lfs version`, `gh --version`), 옵션 조합(jammy 등).
- [ ] **도구 목록 이중 관리 해소.** devcontainer.json 의 `packages` 와 test.sh 의
      `REQUIRED_TOOLS` 가 따로 놀고 `vim-gtk3 → vim/gvim`, `bat → batcat`,
      `fd-find → fdfind` 매핑이 암묵적이다.
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

- [ ] **`Makefile`.** devcon-features 것을 뼈대로 하되 테스트 부분은 다시 짠다.
      가져올 것: `.DEFAULT_GOAL := help` + `## ` 주석 자기문서화, 덮어쓸 수 있는 기본값,
      `TEMPLATES := $(notdir $(wildcard src/*))`, `require-template` 가드,
      `clean` / `distclean`.

- [ ] **테스트 타깃 설계.** `templates test` 가 없으므로 대응물이 없다.
      Makefile 이 `smoke-test/{build,test}.sh` 를 감쌀지, 로직을 흡수하고 스크립트를 없앨지.

- [ ] **`clean` 의 이미지 패턴.** devcon-features 의 `vsc-<타임스탬프>-<해시>-features` 는
      템플릿 쪽과 다르다. `devcontainer up` 은 폴더 이름 기반 이미지를 남긴다.

### 4-2. `make prepare` / `make release` / `make docs`

- [ ] **`prepare.py`.** `devcontainer-feature.json` → `devcontainer-template.json` 만 바꾸면
      나머지는 그대로 동작한다. 핵심(버전이 박힌 커밋 이후에 바뀐 템플릿을 git 로그로 찾아
      미리 체크)은 템플릿에도 유효하다. 버전만 쓰고 커밋은 사람에게 남긴다.

- [ ] **`make release`** — `gh auth status` 확인 후
      `GITHUB_TOKEN=$(gh auth token) devcontainer templates publish -r ghcr.io -n congealer/devcontainers ./src`.
      docker 불필요.

- [ ] **`make docs`** — 인자가 features 와 다르다:
      `devcontainer templates generate-docs -p . --github-owner congealer --github-repo devcontainers`

- [ ] **릴리스 전 체크리스트 문서화** (§4-4):
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

- [ ] **손으로 쓴 한국어 README 를 `NOTES.md` 로 옮긴다** — ubuntu, rohd.
      옮기지 않으면 릴리스 때 날아간다.
- [ ] **apply 예시는 NOTES.md 에 직접 쓴다.** 템플릿 틀에는 `## Example Usage` 가 **없다.**
- [ ] **옵션 표를 손으로 쓰지 않는다.** `#{OptionsTable}` 이 만든다. 지금
      [src/ubuntu/README.md](src/ubuntu/README.md#L7-L11) 에 손으로 쓴 표가 있는데 드리프트 원인이다.

### 4-4. `dev.md`

개발자용 문서는 루트 [dev.md](dev.md) 로 분리했다 (devcon-features 의 `CONTRIBUTING.md`
자리). 지금은 **테스트 하네스** 절 하나뿐이다 — 콜 체인, `KEEP`/`trap`, 템플릿 `test.sh`
작성법, CI.

- [ ] **`make` 타깃 표와 `clean`/`distclean` 이 지우는 것** — §4-1 이후.
- [ ] **문서 생성 규칙** — README 는 자동 생성물이니 `NOTES.md` 를 고치라는 안내 (§4-3).
- [ ] **릴리스 절차와 주의점** — §4-2 의 체크리스트.
- [ ] **CI 절 갱신** — §1-3 이 끝나면 실제 형상과 맞는지 대조. 지금은 목표 형상을 적어뒀다.
- [ ] **루트 README 의 "Testing Templates" 절을 dev.md 로 넘긴다** — 지금 로컬 실행법이
      양쪽에 중복돼 있다.

### 4-5. 개발 컨테이너

> 전면 재검토가 필요하다 (docker-in-docker 2 → 4 업데이트 알림 등). 아래는 이미 확인된 것.

- [ ] **Node 를 20 으로.** [.devcontainer/devcontainer.json:3](.devcontainer/devcontainer.json#L3)
      이 `javascript-node:1-18-bullseye` 이고 실제로 **v18.20.8** 인데
      `@devcontainers/cli` 는 **Node 20+** 를 요구한다. devcon-features 는 `1-20-bookworm`.
- [ ] **`github-cli` feature 추가** — `make release` 의 `gh auth token` 에 필요.
      **지금 이 컨테이너에 `gh` 가 없다** (`command not found` 확인).
- [ ] **python + questionary** — `make prepare` 용.
      `pip install --break-system-packages questionary`
- [ ] **`dbaeumer.vscode-eslint` 확장 제거** — template-starter 가 JS 기반이라 붙어 있던 것.
      이 리포는 셸과 JSON 뿐이다.
- [ ] **`json.schemas` 설정** — 에디터에서 `devcontainer-template.json` 스키마 검증.
- [ ] **`npm install -g @devcontainers/cli` 를 `updateContentCommand` 로.**
- [ ] **docker-in-docker 4 로 올릴지 검토.**

---

## 5. 남은 CI

§1-3 으로 안 올라간 것들.

- [ ] **CI 가 make 를 호출하게** (§4-1 이후). `run: make test-${{ matrix.templates }}` 형태로.
      로컬과 CI 가 같은 경로를 탄다.
- [ ] **`smoke-test` composite action 의 거취.** Makefile 이 로직을 흡수하면 사라진다.
- [ ] **`validate` 워크플로.** devcon-features 의 `validate.yml` 이
      `devcontainers/action@v1` 의 `validate-only: "true"` 로 메타데이터를 검증한다.
- [ ] **버전 범프 검사.** PR 에서 "바뀐 템플릿의 `version` 이 올랐는가". `make prepare` 를
      빠뜨렸을 때 조용히 no-op 되는 걸 막는다.
- [ ] **`push: branches: [main]` 트리거를 넣을지.** 지금은 `pull_request` 뿐이라 main 에
      직접 푸시하면 아무것도 안 돈다. devcon-features 는 push/PR/dispatch 셋 다.
- [ ] **문서 PR 스텝.** §4-3 을 하기로 하면 `generate-docs` 뒤에
      `automated-documentation-update-*` PR 을 여는 스텝을 붙인다 (devcon-features 방식).

---

## 6. 정리

- [ ] **`rohd-dev/` 를 치운다.** `rohd-dev/rohd` (46M), `rohd-dev/rohd-project` (41M),
      `rohd-dev/devcon-features` 는 **중첩 git 리포**다. `.gitignore` 에 넣어뒀다.
      **rohd 이식이 끝나면 별도 브랜치에서 정리** (결정됨).

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

- [ ] **루트 README 갱신** — `rohd` 를 템플릿 목록에 추가, 개발자용 내용은 [dev.md](dev.md) 로
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

### tidy(§1) 가 rohd 앞에 오면 이득인 것

| | 왜 |
|---|---|
| **§1-2 하네스 옵션 전달** | rohd 테스트가 `projectName` 을 알아야 한다. 없으면 `pubspec.yaml` 과 import 검증을 못 한다 |
| **§1-2 밖에서 옵션 지정** | HANDOFF 가 요구하는 "이름 두 개(`my_design`/`zzz_top`)로 시험" 이 불가능하다 |
| **§1-2 `trap` + `KEEP`** | 새 템플릿을 붙일 땐 실패를 여러 번 겪는다. 지금은 실패마다 컨테이너가 샌다 |
| **§1-3 매트릭스를 `ls src` 에서** | 안 하면 rohd 를 넣어도 CI 가 안 돈다 (paths-filter 에 없으므로) |
| **§1-3 `continue-on-error` 제거** | 안 하면 rohd 실패가 초록으로 보인다 |

### rohd 보다 앞서면 이득인 것 둘 (tidy 밖)

| | 왜 |
|---|---|
| **§0 문서 체계 + §4-3** | `generate-docs` 가 `README.md` 를 덮어쓴다. rohd 를 손으로 쓴 README 째로 넣으면 나중에 NOTES.md 로 다시 쪼개야 한다. 처음부터 그 형태면 **재작업 0** |
| **§4-5 Node 20** | 현재 v18.20.8, CLI 요구는 20+. rohd 스모크 테스트는 Dart SDK 를 받고 컨테이너를 띄우는 무거운 작업이라 헛시간 쓰기 쉽다 |

### rohd 발행에만 걸리는 것

**§4-1/4-2 Makefile** — 이식과 테스트 작성까지는 없어도 된다. GHCR 에 올리는 시점에 필요.

### 의존성이 아닌 것

- **네임스페이스** — 정해졌고 `git remote` 와 이미 일치한다
- **ubuntu 재설계** — rohd 와 파일이 안 겹치고, 도구 목록을 통일하지 않기로 했으므로
  설계 결정도 공유하지 않는다
