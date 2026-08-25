# Dev Container Templates

이 repo는 [https://github.com/devcontainers/template-starter](https://github.com/devcontainers/template-starter)로부터 출발했습니다.
커스텀 Dev Container 템플릿들을 추가하여 관리하고 있습니다. (예: `ubuntu`)

## Template 사용 방법

이 저장소의 템플릿(`src` 폴더 내)은 새로운 Dev Container 환경을 설정할 때 사용할 수 있습니다.

### 사용 가능한 템플릿

각 템플릿의 **상세한 설명과 옵션 정보**는 `src/<template-name>/README.md` 파일을 참조하세요.

- **ubuntu**: 기본 Ubuntu 환경에 유용한 도구들이 미리 설치된 템플릿

### 템플릿 적용 (Apply)

`devcontainer` CLI를 사용하여 게시된 템플릿을 프로젝트에 적용할 수 있습니다.

**템플릿 적용 예시 (Ubuntu):**

```bash
devcontainer templates apply \
    -t ghcr.io/congealer/devcontainers/ubuntu:latest \
    --workspace-folder .
```

**옵션 지정:**

각 템플릿은 고유한 옵션을 가질 수 있습니다. 예를 들어 `ubuntu` 템플릿의 OS 버전을 지정하려면 다음과 같이 실행합니다.

```bash
devcontainer templates apply \
    -t ghcr.io/congealer/devcontainers/ubuntu:latest \
    -a '{"imageVariant": "noble"}' \
    --workspace-folder .
```

사용 가능한 전체 옵션 목록과 설명은 해당 템플릿의 `README.md` (`src/<template-name>/README.md`)를 확인하시기 바랍니다.

## Testing Templates

이 항목은 템플릿 개발자를 위한 내용입니다.

### Running Tests

로컬에서 템플릿을 수정하고 테스트하려면 repo에 포함된 스크립트를 사용합니다.

```bash
# 1. 템플릿 빌드 (Docker 이미지 빌드)
./.github/actions/smoke-test/build.sh ubuntu

# 2. 테스트 실행
./.github/actions/smoke-test/test.sh ubuntu
```

각 템플릿의 테스트 코드는 `test/<template-id>/test.sh`에 위치합니다.
테스트는 `devcontainer up`을 통해 컨테이너를 실행하고, 정의된 검증 스크립트를 수행하는 방식으로 동작합니다.
