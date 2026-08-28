
# Ubuntu (ubuntu)

An Ubuntu container with zsh under prezto, fzf history search, the GitHub CLI and a set of everyday command-line tools.

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| imageVariant | Ubuntu version (use ubuntu-26.04 or ubuntu-24.04 on local arm64/Apple Silicon): | string | resolute |

## 베이스 이미지

[상류 `ubuntu` 템플릿](https://github.com/devcontainers/templates/tree/main/src/ubuntu)을 그대로
두고 아래의 feature 만 얹었습니다. 이미지는 미리 빌드된 것이라
[devcontainer.json 메타데이터를 자체적으로 갖고 옵니다](https://containers.dev/implementors/reference/#prebuilding).

* **이미지**: `mcr.microsoft.com/devcontainers/base` ([소스](https://github.com/devcontainers/images/tree/main/src/base-ubuntu))
* **이미지의 devcontainer.json 내용 적용**: 예 ([소스](https://github.com/devcontainers/images/blob/main/src/base-ubuntu/.devcontainer/devcontainer.json))

그래서 `common-utils` 와 `git` 은 feature 로 적지 않았습니다 — `vscode` 유저, `sudo`, zsh,
git 이 이미지에 이미 들어 있어서 나열하면 두 번 설치하는 셈이 됩니다. `remoteUser` 도
같은 이유로 없습니다. 이미지 메타데이터가 `vscode` 를 지정합니다.

## 더한 것

| feature | |
|---|---|
| **prezto** | zsh 를 로그인 셸로 만들고 `~/.zshrc` 를 자기 runcom 으로 대체합니다. 베이스 이미지의 oh-my-zsh 를 밀어냅니다 |
| **github-cli** | `gh` |
| **fzf** | `^R` 히스토리 검색. 배선은 prezto 의 `extraZshrc` 로 들어갑니다 |
| **apt-packages** | 아래 도구들 |

**fzf 는 apt 것을 쓰지 않습니다.** 오래된 배포판의 fzf 는 `fzf --zsh` 를 모르고
zsh 키 바인딩 파일도 없습니다.

배선을 `postCreateCommand` 가 아니라 `extraZshrc` 에 둔 이유는 **`~/.zshrc` 가 prezto 의
runcom 을 가리키는 심볼릭 링크**이기 때문입니다. `>> ~/.zshrc` 는 prezto 가 소유한 파일을
건드리게 됩니다. 값에는 가드가 있어서 fzf feature 를 빼도 셸이 안 깨집니다:

```sh
(( $+commands[fzf] )) && source <(fzf --zsh)
```

### 도구

명령 이름이 패키지 이름과 다른 것이 셋 있습니다.

| 패키지 | 명령 | |
|---|---|---|
| `bat` | **`batcat`** | 문법 강조되는 `cat` |
| `fd-find` | **`fdfind`** | `find` 대체 |
| `ripgrep` | **`rg`** | 재귀 grep |
| `lsd` | `lsd` | 아이콘 붙는 `ls` |
| `tig` | `tig` | git 텍스트 UI |
| `xxd` | `xxd` | 헥스 덤프 |
| `file` | `file` | 파일 종류 판별 |

## Ubuntu 버전

`imageVariant` 로 고릅니다. 기본값은 `resolute`(26.04 LTS)이고 `noble`(24.04)을 쓸 수
있습니다. 코드네임을 쓰는 이유는 MCR 의 숫자 태그 명명이 26.04 에서 어긋나 있기
때문입니다.

**스모크 테스트는 기본값만 빌드합니다.** 다른 값으로 바꾸면 위 도구들이 그 배포판에도
있는지는 확인되지 않은 상태입니다.

## 적용

```bash
devcontainer templates apply \
  --workspace-folder . \
  --template-id ghcr.io/congealer/devcontainers/ubuntu \
  --template-args '{"imageVariant":"resolute"}'
```

VS Code 에서는 명령 팔레트의 **Dev Containers: New Dev Container...** 로도 됩니다.

이 파일과 `README.md` 는 적용할 때 결과 프로젝트로 복사되지 않습니다.


---

_Note: This file was auto-generated from the [devcontainer-template.json](https://github.com/congealer/devcontainers/blob/main/src/ubuntu/devcontainer-template.json).  Add additional notes to a `NOTES.md`._
