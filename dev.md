# 개발 가이드

이 저장소의 템플릿을 고칠 때 필요한 내용입니다. 템플릿을 **사용하는** 방법은
[README.md](README.md) 에 있습니다.

## 테스트 하네스

템플릿 하나를 실제로 적용해 컨테이너를 띄우고, 그 안에서 검증 스크립트를 돌리는 구조입니다.
`devcontainer templates test` 같은 명령이 **없기 때문에**(features 쪽에만 있습니다) 이
저장소가 직접 갖고 있는 스크립트 두 개로 돌아갑니다.

로컬에서는 **저장소 루트에서** 이렇게 실행합니다:

```bash
./.github/actions/smoke-test/build.sh ubuntu   # 컨테이너를 만든다
./.github/actions/smoke-test/test.sh  ubuntu   # 그 안에서 테스트를 돌리고 치운다
```

`build.sh` 가 `src/<id>` 와 `test/<id>` 를 상대 경로로 찾으므로 **반드시 루트에서** 실행해야
합니다. CI 도 같은 두 스크립트를 같은 방식으로 부릅니다.

### 콜 체인

```
build.sh <id>                                     [호스트 / 저장소 루트]
  │
  ├─ rm -rf /tmp/<id>                             앞선 실행이 남긴 것을 치운다
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
TEMPLATE_ARGS='{"imageVariant":"jammy"}' ./.github/actions/smoke-test/build.sh ubuntu
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
KEEP=1 ./.github/actions/smoke-test/test.sh ubuntu
```

남겨두면 다시 붙을 수 있습니다 (스크립트가 이 명령을 출력해 줍니다):

```bash
devcontainer exec --workspace-folder /tmp/ubuntu --id-label test-container=ubuntu bash
```

컨테이너 안의 `test-project/test.sh` 는 워크스페이스에 마운트돼 있으므로, **다시 빌드하지
않고** 고쳐서 다시 돌릴 수 있습니다. 검사가 실제로 검출력이 있는지(일부러 틀리게 만들어
RED 를 내보는 것) 확인할 때 이렇게 씁니다.

남겨둔 `/tmp/<id>` 는 다음 `build.sh` 가 먼저 지우므로 재시도를 오염시키지 않습니다.

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

- **`which` 로 끝내지 마세요.** 바이너리가 있어도 초기화가 안 됐을 수 있습니다.
  `gh --version` 처럼 실제로 실행해 보는 편이 낫습니다.
- **실행 유저는 `remoteUser` 입니다** (보통 `vscode`). root 가 아니므로 권한이 필요한 검사는
  `sudo` 를 붙여야 합니다.
- **`test/<id>/` 안의 파일은 전부 컨테이너로 복사됩니다.** 그래서 검사가 길어지면
  `source ./_common.sh` 처럼 헬퍼 파일로 쪼개도 됩니다.
- 라벨에 기대값을 넣어두면 실패 출력만 보고도 무엇을 기대했는지 알 수 있습니다.

검사를 새로 쓰면 **일부러 틀리게 만들어 RED 가 나오는지 한 번 확인하세요.** 통과만 봐서는
그 검사에 검출력이 있는지 알 수 없습니다 — 조건을 잘못 쓰면 아무것도 검증하지 않으면서
늘 통과하는 검사가 되기 쉽습니다. 위의 `KEEP=1` 이 그 확인을 재빌드 없이 하게 해줍니다.

### CI

`.github/workflows/test-pr.yaml` 이 PR 에서 돕니다.

```
test-pr.yaml
  ├ templates      ls src 로 템플릿 목록을 만든다
  ├ test           매트릭스: 템플릿마다
  │   └ .github/actions/smoke-test        (composite)
  │       ├ build.sh <id>
  │       └ test.sh  <id>
  └ ci             집계 — 위가 하나라도 실패하면 실패
```

action 이 하는 일은 위의 두 스크립트를 순서대로 실행하는 것뿐입니다. **CI 와 로컬이 같은
경로를 타므로**, 로컬에서 통과한 것이 CI 에서만 다르게 도는 일이 없습니다.

**템플릿 목록은 `ls src` 로 저장소에서 읽습니다.** 손으로 관리하는 목록이 없다는 뜻이고,
`src/` 에 템플릿을 추가하면 그것만으로 CI 에 들어옵니다. 목록에 적어넣는 걸 잊어서 새
템플릿이 조용히 테스트를 건너뛰는 일을 구조적으로 막습니다.

**`ci` job 은 이름이 매트릭스와 무관하게 고정된 집계 체크입니다.** 템플릿이 늘어도 이름이
바뀌지 않으므로 branch ruleset 에는 이것 하나만 걸면 됩니다.

같은 PR 에 연달아 푸시하면 앞선 실행은 `concurrency` 로 취소됩니다. 템플릿마다 컨테이너를
빌드하는 만큼 그냥 두면 비쌉니다.
