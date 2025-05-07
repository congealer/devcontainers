# Ubuntu

이 이미지는 ubuntu devcontainer에 기본 utility commands를 설치한 이미지입니다.

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| imageVariant | Ubuntu version (Nobel: v24.04.2 LTS, Jammy: v22.04.5 LTS, or Focal: v20.04.6): | string | noble |

## Publish

템플릿을 ghcr.io에 퍼블리시하려면:

```bash
devcontainer templates publish ./src/ubuntu -n congealer/devcontainers -r ghcr.io
```

## Apply

템플릿을 프로젝트에 적용하려면:

```bash
devcontainer templates apply -t ghcr.io/congealer/devcontainers/ubuntu --workspace-folder <my-project>
```

특정 Ubuntu 버전을 선택하려면:

```bash
devcontainer templates apply -t ghcr.io/congealer/devcontainers/ubuntu -v noble --workspace-folder <my-project>
```

---
