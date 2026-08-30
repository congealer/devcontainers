# 개발 가이드

이 저장소의 템플릿을 고칠 때 필요한 내용입니다. 템플릿을 **사용하는** 방법은
[README.md](README.md) 에 있습니다.

## Makefile

입구는 `make` 입니다. `make` 또는 `make help` 로 타깃 목록이 나옵니다.

| 타깃 | |
|---|---|
| `test` | 모든 템플릿을 빌드하고 테스트 |
| `test-<id>` | 하나만. `build-<id>` 를 의존하므로 이것만 불러도 됨 |
| `build-<id>` | 컨테이너만 띄우고 테스트는 안 함 |
| `clean` / `clean-<id>` | 실행이 남긴 컨테이너·이미지·`/tmp/<id>`·빌드 캐시 |
| `distclean` | 위 전부 + 남은 베이스 이미지 |
| `prepare` | 버전을 올리고 문서를 새로 만듦 |
| `docs` | 문서만 새로 만듦 |
| `release` | GHCR 에 발행 |

없는 템플릿 이름을 주면 스크립트로 넘기기 전에 걸러냅니다.

```console
$ make test-nope
Makefile:49: *** unknown template 'nope'. available: rohd ubuntu.  Stop.
```

옵션 값은 환경 변수로 넘깁니다. `devcontainer templates apply -a` 와 같은 JSON 형태입니다.

```bash
make build-rohd TEMPLATE_ARGS='{"projectName":"zzz_top"}'
make test-rohd  KEEP=1
```

### 무엇이 쌓이고 무엇이 지워지나

`test.sh` 는 끝날 때 컨테이너를 지우지만 **이미지는 남깁니다.** 지우면 다음 실행이 처음부터
다시 빌드해야 하기 때문입니다 — rohd 라면 Dart SDK 를 매번 다시 받습니다. 그래서 이미지는
`clean` 을 부를 때까지 쌓입니다.

`clean` 은 이미지와 함께 **빌드 캐시도 지웁니다.** 선택이 아닙니다. 이미지만 지우면 buildkit
이 사라진 이미지를 참조하는 스냅샷을 붙들고 있어, 다음 빌드가
`parent snapshot ... does not exist` 로 죽습니다.

`clean` 의 구현은 [build.sh](script/build.sh) 안에 있습니다
(`build.sh clean [<id>]`). 이미지 이름이 `vsc-<id>-<해시>-features` 인 것은 `build.sh` 가
작업 폴더를 `/tmp/<id>` 로 정하기 때문이라, 그 이름 규칙을 아는 쪽이 지우는 것도 맡습니다.

## 테스트 하네스

템플릿 하나를 실제로 적용해 컨테이너를 띄우고, 그 안에서 검증 스크립트를 돌리는 구조입니다.
`devcontainer templates test` 같은 명령이 **없기 때문에**(features 쪽에만 있습니다) 이
저장소가 직접 갖고 있는 스크립트 두 개로 돌아갑니다. `make` 는 그 둘을 부를 뿐입니다.

```bash
./script/build.sh ubuntu   # 컨테이너를 만든다
./script/test.sh  ubuntu   # 그 안에서 테스트를 돌리고 치운다
```

`build.sh` 가 `src/<id>` 와 `test/<id>` 를 상대 경로로 찾으므로 **반드시 저장소 루트에서**
실행해야 합니다. CI 도 같은 두 스크립트를 같은 방식으로 부릅니다.

### 콜 체인

```
build.sh <id>                                     [호스트 / 저장소 루트]
  │
  ├─ rm -rf /tmp/<id>                             앞선 실행이 남긴 것을 치운다
  ├─ docker rm -f <같은 라벨의 컨테이너>          같은 이유. 아래 참고
  ├─ cp -R src/<id> /tmp/<id>                     템플릿 본체를 작업 사본으로
  ├─ ${templateOption:X} 치환                     TEMPLATE_ARGS 또는 각 옵션의 default
  ├─ cp test/<id>/*        → /tmp/<id>/test-project/    ← 치환 '뒤에' 복사된다
  ├─ cp test/test-utils/*  → /tmp/<id>/test-project/
  ├─ template-options.env  → /tmp/<id>/test-project/    치환에 쓴 값
  └─ devcontainer up --id-label test-container=<id> --workspace-folder /tmp/<id>

test.sh <id>                                      [호스트]
  │
  └─ devcontainer exec --id-label test-container=<id> ...
       └─ cd test-project && ./test.sh            [컨테이너 안 / remoteUser 로 실행]
            ├─ source test-utils.sh               check / reportResults
            ├─ source template-options.env        TEMPLATE_OPTION_<옵션이름>
            ├─ check "..." <명령>                  실패를 모아둔다
            └─ reportResults                      → exit 0 또는 1
```

**치환은 템플릿 본체에만 걸립니다.** `test/<id>/` 는 치환이 끝난 **뒤에** 복사되므로,
테스트 스크립트 안에 `${templateOption:...}` 를 써도 그대로 남습니다. 테스트가 옵션 값을
알아야 할 때 `template-options.env` 를 쓰는 이유가 이것입니다.

종료 코드는 이 체인을 그대로 타고 올라옵니다:

```
reportResults (exit 1)  →  test-project/test.sh  →  devcontainer exec  →  test.sh  →  CI
```

`check` 는 실패를 배열에 모아두기만 하고, `reportResults` 가 마지막에 목록을 보고하며
종료 코드를 정합니다. 그래서 **한 번 돌리면 실패한 검사가 전부 보입니다.**

#### 옵션 값 넘기기

기본값은 `devcontainer-template.json` 의 각 옵션 `default` 입니다. 다른 조합을 시험하려면
`TEMPLATE_ARGS` 로 덮어씁니다 — `devcontainer templates apply -a` 와 같은 JSON 형태입니다.

```bash
TEMPLATE_ARGS='{"imageVariant":"jammy"}' ./script/build.sh ubuntu
```

JSON 이 잘못됐으면 조용히 기본값으로 떨어지지 않고 **거부합니다.** 덮어쓴 줄 알았는데 안
덮어쓴 실행이 생기지 않도록 하기 위해서입니다.

실제로 쓰인 값은 `test-project/template-options.env` 에 이렇게 적힙니다:

```sh
TEMPLATE_OPTION_imageVariant=noble
```

옵션이 없는 템플릿이어도 파일은 항상 만들어집니다 — `build.sh` 는 `test/<id>/` 가 있을 때
이 파일을 쓰는데, 그 디렉터리가 있어야 테스트도 실행되기 때문입니다. 그래도 아래 뼈대는
존재를 한 번 확인합니다. 하네스를 거치지 않고 손으로 돌릴 때 원인이 분명해집니다.

### 정리와 종료 코드

`test.sh` 는 끝날 때 컨테이너를 지우고 `/tmp/<id>` 를 치웁니다. 그 정리는 **`EXIT` trap** 에
달려 있습니다.

```bash
trap cleanup EXIT
```

정리를 스크립트 끝에 두면 안 됩니다. `set -e` 때문에 테스트가 실패하는 순간
`devcontainer exec` 줄에서 스크립트가 끝나고 **그 아래에 도달하지 못합니다** — 실패할
때마다 컨테이너가 새게 됩니다. trap 은 어떻게 끝나든 돌므로 통과·실패 어느 쪽에서도
컨테이너가 남지 않습니다.

**종료 코드는 테스트 결과만 따릅니다** — 통과면 `0`, 실패면 `1`. trap 은 종료 코드를 바꾸지
않고, 뒤에 나오는 `KEEP` 도 마찬가지입니다. 이 둘은 정리에만 관여합니다.

`set -e` 는 남겨둡니다. 지금 구조에서는 `devcontainer exec` 가 마지막 명령이라 빼도 종료
코드가 그대로 올라오지만, **`exec` 앞쪽에서 실패하거나 뒤에 명령이 덧붙을 때를 위한
방어**입니다.

### `KEEP=1` — 컨테이너 남기기

`KEEP` 은 **정리만** 끕니다. 종료 코드는 위와 같습니다.

새 템플릿을 붙이다 보면 실패를 여러 번 겪게 되는데, 그때 컨테이너가 사라지면 안을 들여다볼
수 없습니다. `KEEP=1` 이 그 탈출구입니다.

```bash
KEEP=1 ./script/test.sh ubuntu
```

남겨두면 다시 붙을 수 있습니다 (스크립트가 이 명령을 출력해 줍니다):

```bash
devcontainer exec --workspace-folder /tmp/ubuntu --id-label test-container=ubuntu bash
```

컨테이너 안의 `test-project/test.sh` 는 워크스페이스에 마운트돼 있으므로, **다시 빌드하지
않고** 고쳐서 다시 돌릴 수 있습니다. 검사가 실제로 검출력이 있는지(일부러 틀리게 만들어
RED 를 내보는 것) 확인할 때 이렇게 씁니다.

남겨둔 것은 다음 `build.sh` 가 **디렉터리와 컨테이너를 모두** 먼저 지우므로 재시도를
오염시키지 않습니다. `KEEP` 은 "테스트 뒤에 남겨두라"는 뜻이지 "다음에 재사용하라"가
아닙니다.

컨테이너까지 지우는 이유가 있습니다. 디렉터리만 지우면 `devcontainer up` 이 같은 라벨의
남은 컨테이너를 **새로 만드는 대신 채택**하는데, 그 컨테이너의 바인드 마운트는 방금 지워진
디렉터리를 가리킵니다. 그러면 `exec` 가 이렇게 실패합니다:

```
current working directory is outside of container mount namespace root
  -- possible container breakout detected
```

docker 가 고장 난 것처럼 읽히지만 원인은 낡은 컨테이너입니다.

### 무엇을 검사할 것인가

**이 저장소의 산출물은 템플릿입니다.** 템플릿이 만들어낸 프로젝트가 업무적으로 잘 도는지는
그 프로젝트의 관심사이지 여기의 관심사가 아닙니다. 검사는 세 가지를 봅니다:

| | |
|---|---|
| **렌더링** | 옵션이 선언대로 치환됐는가 |
| **환경** | `devcontainer.json` 이 선언한 것이 실제로 만들어졌는가 |
| **출발 상태** | 만들어진 프로젝트가 깨끗하게 시작하는가 |

상류 `template-starter` 의 예제 테스트가 딱 앞의 둘이었습니다 — "컨테이너가 떴나"와
"옵션이 반영됐나". 그 이상은 신중하게 더하세요.

**넣지 않는 기준 둘:**

- **빌드가 이미 잡는 것.** lifecycle 명령이 실패하면 `devcontainer up` 이 실패합니다
  (실측 확인). 그래서 apt 패키지 이름 오타 같은 것은 테스트가 아니라 빌드에서 걸립니다.
  같은 것을 두 번 검사할 이유가 없습니다.
- **템플릿이 바뀌어서 깨지는 게 아닌 것.** 상류 의존성이 바뀌어 깨지는 종류는 회귀
  테스트의 몫이지 매 PR 스모크 테스트의 몫이 아닙니다.

**반대로, 목적이 뚜렷하면 커버리지가 겹쳐도 넣습니다.** 다른 검사가 어차피 잡더라도,
전용 검사는 **실패 지점에 이름을 붙여줍니다** — 분석기 출력 더미를 읽는 대신 어느 층이
깨졌는지 한 줄로 알게 됩니다.

목록을 표로 정리해 두면 나중에 "이건 왜 있지"를 다시 묻지 않게 됩니다. 실물 예:
[`test/rohd/test.md`](test/rohd/test.md) — 검사별 목적, **일부러 뺀 것과 그 이유**,
그리고 **이 테스트로는 검출되지 않는 것**까지 적어뒀습니다.

### 템플릿 테스트 작성하기

`test/<id>/test.sh` 를 만들면 됩니다. 뼈대는 이렇습니다:

```bash
#!/bin/bash
cd $(dirname "$0")
source test-utils.sh

if [ -f ./template-options.env ] ; then
    source ./template-options.env
fi

check "<라벨>" <명령> [인자...]

reportResults
```

알아야 할 것들:

- **`set -e` 를 쓰지 마세요.** `check` 는 실패하면 `return 1` 하는데, `set -e` 가 켜져 있으면
  거기서 스크립트가 죽어 **뒤의 검사가 하나도 안 돌고 `reportResults` 도 실행되지 않습니다.**
  CI 결과는 어느 쪽이든 실패지만, 한 번에 얻는 정보량이 다릅니다.
  대신 `check` 밖의 맨 명령은 실패해도 그냥 넘어가므로, 준비 단계는 `check` 로 감싸거나
  `|| exit 1` 을 붙이세요.
- **기대값을 하드코딩하지 말고 옵션에서 읽으세요.** 그러면 검사가 **배선 테스트를 겸합니다** —
  옵션이 선언만 되고 `devcontainer.json` 에 치환되지 않았다면 값이 어긋나 실패합니다.

  ```bash
  check "distro is ${TEMPLATE_OPTION_imageVariant}" \
        [ "$(lsb_release -cs)" = "${TEMPLATE_OPTION_imageVariant}" ]
  ```

- **실행 유저는 `remoteUser` 입니다** (보통 `vscode`). root 가 아니므로 권한이 필요한 검사는
  `sudo` 를 붙여야 합니다.
- **`test/<id>/` 안의 파일은 전부 컨테이너로 복사됩니다.** 그래서 검사가 길어지면
  `source ./_common.sh` 처럼 헬퍼 파일로 쪼개도 됩니다.
- 라벨에 기대값을 넣어두면 실패 출력만 보고도 무엇을 기대했는지 알 수 있습니다.

검사를 새로 쓰면 **일부러 틀리게 만들어 RED 가 나오는지 한 번 확인하세요.** 통과만 봐서는
그 검사에 검출력이 있는지 알 수 없습니다 — 조건을 잘못 쓰면 아무것도 검증하지 않으면서
늘 통과하는 검사가 되기 쉽습니다. 위의 `KEEP=1` 이 그 확인을 재빌드 없이 하게 해줍니다.

## 문서

`src/<id>/README.md` 는 **자동 생성물입니다.** 직접 고치면 `make docs` 나 `make prepare` 가
덮어씁니다. 손으로 쓸 내용은 같은 디렉터리의 `NOTES.md` 에 넣으세요.

```
# <name> (<id>)                     ← devcontainer-template.json 의 name, id
<description>                       ← 같은 파일의 description
## Options                          ← options 에서 만든 표
─────────────────────────────
NOTES.md 내용이 여기 들어갑니다
─────────────────────────────
---
_Note: This file was auto-generated from the devcontainer-template.json..._
```

옵션 표에는 `description` / `type` / `default` 만 들어갑니다. **`proposals` 는 안 나옵니다** —
사용자에게 선택지를 보이려면 `NOTES.md` 에 적거나 `description` 에 녹여야 합니다.

feature 쪽 생성 틀에는 있는 `## Example Usage` 절이 **템플릿 틀에는 없습니다.** apply
예시도 `NOTES.md` 에 직접 씁니다.

템플릿 하나만 다시 생성할 수는 없습니다. `generate-docs` 에 템플릿을 고르는 옵션이 없어서
`-p` 에 준 디렉터리의 하위를 전부 훑습니다. 생성이 결정적이라 내용이 바뀐 것에만 diff 가
생깁니다.

`templates apply` 는 `devcontainer-template.json` / `README.md` / `NOTES.md` 를 **제외하고**
복사합니다. 그래서 사용자가 만든 프로젝트에는 이 셋이 안 들어갑니다 — 만들어진 프로젝트를
쓰는 방법은 다른 파일에 둬야 합니다 (rohd 는 `docs/rohd.md`).

## 릴리스

```bash
make prepare     # 버전을 올리고 docs 를 새로 만든다. 커밋은 안 한다
git commit
make release     # GHCR 에 발행
```

`make prepare` 는 **버전이 박힌 커밋 이후에 내용이 바뀐 템플릿을 미리 체크해 줍니다.**
그게 이 단계의 존재 이유입니다 — 아래 첫 항목 때문입니다.

올리기 전에 알아야 할 것들:

- **`version` 이 발행 여부를 정하는 유일한 스위치입니다.** 이미 발행된 버전이면 CLI 가
  그 템플릿을 건너뜁니다. **덮어쓰는 게 아니라 요청 자체를 안 보내고, 종료 코드는 0 입니다.**
  경고 한 줄만 나오니 그것만이 단서입니다:

  ```
  (!) WARNING: Version 1.0.0 already exists, skipping 1.0.0...
  ```

  **그런데 컬렉션 메타데이터는 버전 검사 없이 매번 다시 올라갑니다.** 그래서 패키지 페이지에
  "방금 발행됨" 이 떠도 템플릿이 올라갔다는 뜻이 아니고, 소스만 고치고 버전을 안 올리면
  **컬렉션은 새 메타데이터를, 템플릿 아티팩트는 옛 것을** 갖게 됩니다. 확인은 이렇게 합니다:

  ```bash
  devcontainer templates metadata ghcr.io/congealer/devcontainers/ubuntu
  ```
- **태그가 움직입니다.** `1.3.0` 을 올리면 `1.3.0`/`1.3`/`1`/`latest` 가 함께 올라가는데
  `1` 과 `latest` 는 **기존 것에서 옮겨옵니다.** `:1` 로 고정한 사용자가 다음 빌드에서 바로
  받으므로, 올리기 전에 `make test` 가 통과했는지 확인하세요
- **GHCR 패키지는 처음 올리면 private 입니다.** 공개 전환과 저장소 연결을 패키지 설정에서
  한 번 해줘야 합니다
- `make release` 는 `gh auth token` 으로 **개인 자격증명**을 씁니다. `gh auth login` 이
  먼저입니다

발행 전에는 `templates apply` 로 시험해 볼 수 없습니다. `--template-id` 가 **OCI 참조만**
받고 로컬 경로를 안 받기 때문입니다. 그래서 하네스가 apply 를 부르지 않고 스스로 복사하고
치환합니다 — **하네스가 검증하는 것은 우리 치환기이지 진짜 렌더러가 아닙니다.**

## CI

`.github/workflows/test-pr.yaml` 이 PR 과 main 푸시에서 돕니다.

```
test-pr.yaml
  ├ templates      ls src 로 템플릿 목록을 만든다
  ├ test           매트릭스: 템플릿마다
  │   ├ npm install -g @devcontainers/cli
  │   └ make test-<id>  →  script/build.sh  →  script/test.sh
  └ ci             집계 — 위가 하나라도 실패하면 실패
```

**CI 는 `make` 를 부릅니다.** 로컬에서 치는 것과 같은 명령이라, "템플릿 X 를 테스트한다"의
정의가 Makefile 한 곳에만 있습니다. 스크립트를 직접 부르면 호출 규격이 바뀔 때마다 양쪽을
고쳐야 하고, `test-%` 가 `build-%` 를 의존한다는 것도 워크플로에 다시 써야 합니다.

**CLI 는 워크플로가 깝니다.** 러너에는 없고, `build.sh` 는 일부러 설치하지 않습니다 — 개발
컨테이너는 CLI 를 feature 로 받는데 거기서 root 소유로 한 번 더 설치하면 충돌합니다.

**템플릿 목록은 `ls src` 로 저장소에서 읽습니다.** 손으로 관리하는 목록이 없다는 뜻이고,
`src/` 에 템플릿을 추가하면 그것만으로 CI 에 들어옵니다. 목록에 적어넣는 걸 잊어서 새
템플릿이 조용히 테스트를 건너뛰는 일을 구조적으로 막습니다.

**`ci` job 은 이름이 매트릭스와 무관하게 고정된 집계 체크입니다.** 템플릿이 늘어도 이름이
바뀌지 않으므로 branch ruleset 에는 이것 하나만 걸면 됩니다.

같은 브랜치에 연달아 푸시하면 앞선 실행은 `cancel-in-progress` 로 취소됩니다. 템플릿마다
컨테이너를 빌드하는 만큼 그냥 두면 비쌉니다. `release.yaml` 에는 넣지 않았습니다 — 발행이
중간에 잘리면 안 됩니다.

## 트러블슈팅

### 빌드가 `content ... not found` / `parent snapshot ... does not exist` 로 죽는다

**템플릿 문제가 아닙니다.** 실패가 **어디서** 났는지로 갈립니다.

| 실패 지점 | 판정 |
|---|---|
| feature 의 설치 스크립트 안 — `apt install ... Return Code: 100` 같은 | 템플릿이 틀렸다 |
| `exporting to image` / `unpacking` / 스냅샷 단계 | 저장소가 상했다 |

아래쪽이면 이런 문구가 나옵니다.

```
failed to extract layer sha256:... : failed to get reader from content store:
  content digest sha256:...: not found

failed to solve: parent snapshot ... does not exist
```

**처방은 `make clean` 입니다.** 마지막에 빌드 캐시를 비우는 것이 핵심이고, 같이 지워지는
이미지는 어차피 캐시 없이 다시 만들어야 하므로 잃는 게 없습니다. 베이스 이미지는 남습니다.

```bash
make clean            # 전부
make clean-rohd       # 한 템플릿. 캐시 정리는 어느 쪽이든 전체에 걸립니다
```

시간을 아끼는 두 가지:

- **재시도로는 안 낫습니다.** 아무것도 바꾸지 않고 다시 돌리면 **같은 다이제스트로** 똑같이
  죽습니다. 그 결정성이 일시적 장애와 구분되는 지점이고, 하네스에 재시도가 없는 이유입니다
- **이미지만 지워도 안 낫습니다.** 상한 기록은 빌드 캐시에 있어서, 이미지를 지워도 buildkit
  이 그 캐시로 같은 결과물을 다시 조립합니다

**무엇이 캐시를 상하게 하는지는 모릅니다.** 이틀에 두 번 났고 다이제스트는 매번 달랐습니다.
재시작과 엮어 보려 했지만 두 번째는 32시간 연속 가동 중에 났습니다. 미리 비울 근거가 없으니
위 증상이 나오면 그때 비우세요.

### 빌드가 끝나지 않는다

lifecycle 명령이 **실패가 아니라 정지**할 수 있습니다. 실제로 `dart pub get` 이 pub.dev 와
연결은 맺힌 채 데이터가 오지 않아 두 시간을 기다린 적이 있습니다 — 그 사이 CPU 는 0%,
네트워크는 멀쩡했습니다. `dart pub get` 에는 타임아웃이 없고, 환경 변수도 `PUB_CACHE` 와
`PUB_HOSTED_URL` 뿐이라 밖에서 끊는 수밖에 없습니다.

정상이라면 템플릿당 **1~2분**입니다. 그보다 한참 넘어가면 멈춘 것이니 이렇게 확인하세요.

```bash
ps -eo etime,cmd | grep -E "devcontainer up|dart pub"   # 얼마나 됐나
docker exec <컨테이너> ps -eo stat,pcpu,comm             # CPU 0% 면 정지
```

`Ctrl-C` 로 끊고 남은 컨테이너를 지운 뒤 다시 돌리면 됩니다. CI 는 job 에
`timeout-minutes: 15` 가 걸려 있어 저절로 끊깁니다.

**CI 에는 해당 없습니다.** 러너는 job 마다 빈 상태로 시작해서 재사용할 캐시가 없습니다.
`actions/cache` 나 buildx 캐시를 붙이면 이 실패 모드를 CI 로 들여오게 됩니다.
