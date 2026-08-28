# rohd 템플릿 스모크 테스트

[`test.sh`](test.sh) 가 무엇을 검사하는지, 무엇을 일부러 검사하지 않는지 적어둔 문서입니다.
하네스가 어떻게 돌아가는지는 [dev.md](../../dev.md) 에 있습니다.

검사는 `build.sh` 가 만든 컨테이너 안에서 `test-project/` 를 작업 디렉터리로 돕니다.
렌더링된 프로젝트는 한 단계 위(`..`)입니다.

## 목적 1 — 렌더링이 옵션대로 됐는가

| # | 검사 | 무엇을 잡나 | 방법 |
|---|---|---|---|
| 1 | `${templateOption:` 잔여 없음 | **선언되지 않은 이름**으로 쓴 placeholder. 치환은 `devcontainer-template.json` 에 선언된 옵션에 대해서만 돌므로, 오타나 선언 누락이면 그 문자열이 사용자 프로젝트로 그대로 간다 | 프로젝트 전체 grep (`.dart_tool`/`build`/`test-project` 제외) |
| 2 | pubspec `name` == `projectName` | 엉뚱한 옵션으로 치환 | `grep -qxF` |
| 3 | pubspec `description` == `description` | 같음 | `grep -qxF` |
| 4 | `bin/generate_rtl.dart` 의 import | 같음 | `grep -qF` |
| 5 | `test/counter_test.dart` 의 import | 같음 | `grep -qF` |

1번이 "치환이 아예 안 된 것"을, 2~5번이 "엉뚱한 값으로 치환된 것"을 맡습니다. 반대 방향
— 선언은 했는데 아무 데도 안 쓴 죽은 옵션 — 은 2~5번과 6번이 값이 어긋나는 것으로 드러납니다.

> **4·5번은 11번(`dart analyze`)과 겹칩니다.** 잘못된 import 는 analyzer 가 해석 실패로
> 잡습니다. 그럼에도 두는 이유는 **실패 지점에 이름을 주기 위해서**입니다. analyzer 출력
> 더미 대신 "import in bin/generate_rtl.dart 실패" 한 줄을 먼저 보게 됩니다.

## 목적 2 — 선언한 환경이 실제로 만들어졌는가

| # | 검사 | 무엇을 잡나 | 방법 |
|---|---|---|---|
| 6 | `dart --version` == `dartVersion` | 로컬 dart feature 가 동작했는가 + `dartVersion` 이 거기로 흘렀는가 + **remote user 의 PATH 에 있는가** | `dart --version \| grep -qF` |
| 7 | 로그인 셸이 zsh | prezto feature | `getent passwd $(id -un)` 의 7 번째 필드 |
| 8 | fzf 위젯 함수가 정의됨 | prezto 의 `extraZshrc` + fzf feature | `zsh -i -c '(( $+functions[fzf-history-widget] ))'` |

**6번이 한 줄로 셋을 봅니다.** 특히 마지막이 중요한데, `install.sh` 는 root 로 돌고 이
테스트는 remote user 로 돕니다. "root 에선 되는데 사용자 PATH 엔 없는" 종류는 여기서만
드러납니다.

**8번은 출력이 아니라 상태를 봅니다.** `bindkey "^R"` 의 출력을 grep 하지 않는 이유는,
zsh-autosuggestions 가 로드돼 있으면 위젯을 감싸서 키에 실제로 묶이는 것이
`_zsh_autosuggest_bound_1_fzf-history-widget` 이 되기 때문입니다. 함수 존재로 보면 감싸든
말든 통과합니다.

`-i` 가 필요한 것은 **`~/.zshrc` 가 대화형 셸에서만 소싱되기 때문**입니다. tty 없이도
동작하는 것은 확인했습니다 — 비대화형에서는 함수가 안 보이고, `-i` 를 주면 보입니다.

> **`can't change option: zle` 경고는 정상입니다.** tty 가 없으니 zle(대화형 라인 편집기)을
> 켤 수 없다는 뜻인데, 우리가 보려는 것은 함수 정의라 무관합니다. 없는 함수 이름으로 바꾸면
> 종료 코드 1 이 나오는 것을 확인했으므로 공허하게 통과하는 검사가 아닙니다.
>
> `script -qec` 로 pty 를 붙이면 경고가 사라지고 종료 코드도 그대로 전달되지만, 쓰지
> 않습니다. `script`(util-linux) 가 모든 템플릿의 베이스 이미지에 있으리라는 보장이 없고,
> pty 가 붙으면 job control 과 zle 초기화 경로가 달라져 실사용과 어긋날 수 있습니다.
> 노이즈 한 줄이 그만한 값은 아닙니다.

## 목적 3 — 생성된 프로젝트가 깨끗하게 출발하는가

| # | 검사 | 무엇을 잡나 | 방법 |
|---|---|---|---|
| 9 | `pub get` 이 rohd 를 해석했나 | 최종 상태 단언 (아래 단서 참고) | `.dart_tool/package_config.json` 존재 + `rohd` 항목 |
| 10 | `package_config.json` 이 1 개 | 워크스페이스 배선(`workspace:` / `resolution: workspace`) 이 깨져 서브패키지가 따로 해석된 것 | `find` 후 개수 |
| 11 | `dart analyze` 무경고 | **치환 후에만 드러나는** 문제 | `cd .. && dart analyze` |

11번의 실제 사례가 있습니다. 씨앗에는 `directives_ordering` 이 켜져 있었는데, 생성되는
패키지 이름이 `rohd` 와 `rohd_patches` 사이 어디로 정렬될지 템플릿이 알 수 없어서
**모든 생성 프로젝트에 lint 2 건**이 따라붙었습니다. 씨앗만 봐서는 안 보이고 `dart test`
로도 안 잡히는, `analyze` 로만 보이는 종류입니다. (규칙은 그 뒤 껐습니다.)

## 검출되지 않는 것

**9번은 이 하네스에서는 사실상 발동하지 않습니다.**

`dart pub get` 은 dart feature 의 `updateContentCommand` 로 돕니다. 그런데 클라이언트마다
실패 처리가 다릅니다:

| | lifecycle 명령 실패 시 |
|---|---|
| `devcontainer up` (하네스가 쓰는 CLI) | **exit 1** — 빌드가 실패하므로 테스트까지 오지 않는다 |
| VS Code Dev Containers 확장 (실사용자) | 알림·로그만 남기고 **컨테이너를 연다** |

즉 하네스는 CLI 를 쓰므로 `pub get` 이 깨지면 **빌드에서 멈추고**, 9번은 도달하지
못합니다. 정작 조용히 지나가는 쪽은 VS Code 인데 그건 이 테스트로 재현할 수 없습니다.

그래도 두는 이유는 **빌드의 실패 처리 동작에 기대지 않고 최종 상태를 직접 단언**하기
위해서입니다. 나중에 `pub get` 을 `updateContentCommand` 밖으로 옮기거나 클라이언트 동작이
바뀌면 그때 의미가 생깁니다.

CLI 가 빌드를 실패시키는 것은 두 경우 모두 실측했습니다 — `devcontainer.json` 에 직접 선언한
hook 과, rohd 처럼 **feature 안**에 선언한 hook. 후자는 에러 메시지가 출처까지 밝힙니다:

```
"description": "updateContentCommand from Feature './features/boom' failed."
```

## 일부러 넣지 않은 것

| | 이유 |
|---|---|
| `dart test` (예제 8 개), `dart test packages/rohd_patches` (38 개) | **ROHD 프로젝트의 회귀 테스트**지 템플릿 테스트가 아니다. 우리가 그 파일을 고칠 때만 깨지고, 그때는 손으로 확인하면 된다. 개수를 고정하면 테스트를 하나 추가할 때마다 이유 없이 빨개진다 |
| RTL 생성, 재실행 sha256 일치, `grep 'val <= ('`, `grep carry` | 같음. 패치가 동작하는지는 ROHD 쪽 관심사다 |
| 유틸리티 목록 (`batcat` `lsd` `fdfind` …) | 패키지 이름이 틀리면 apt feature 가 **빌드를 실패**시킨다. 테스트가 더 잡는 것은 바이너리 개명(`bat`→`batcat`)뿐인데 그건 변하지 않는 정적 지식이라, 목록을 이중 관리할 값어치가 없다 |
| 예제 3 개(`lib/counter.dart`, `bin/generate_rtl.dart`, `test/counter_test.dart`) 삭제 후 `dart analyze` | 셋이 서로만 참조하므로 **함께 지우면 매달리는 참조가 남지 않는다.** 실패할 수 없는 시나리오다. 진짜 위험한 것은 `packages/rohd_patches` 삭제인데 문서가 하지 말라고 안내한다 |

## 하네스 밖에서 해야 하는 것

**`projectName` 을 두 개로 바꿔 두 번 돌리기** — 알파벳 앞(`my_design`)과 뒤(`zzz_top`).

```bash
TEMPLATE_ARGS='{"projectName":"zzz_top"}' ./.github/actions/smoke-test/build.sh rohd
./.github/actions/smoke-test/test.sh rohd
```

정렬에 얽힌 문제는 이름 하나로만 보면 안 드러납니다 — 위의 `directives_ordering` 버그가
정확히 이 절차로 발견됐습니다. `test.sh` 안에는 넣을 수 없고(하네스를 두 번 돌리는
것이므로), CI 매트릭스에 넣기 전까지는 수동입니다.
