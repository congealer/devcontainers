# Rocky

이 이미지는 Rocky linux를 바탕으로한 devcontainer 이미지입니다.

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| imageVariant | Rocky linux version (9, 8, or latest): | string | 9 |

## Publish

템플릿을 ghcr.io에 퍼블리시하려면:

```bash
devcontainer templates publish ./src/rocky -n congealer/devcontainers -r ghcr.io
```

## Apply

템플릿을 프로젝트에 적용하려면:

```bash
devcontainer templates apply -t ghcr.io/congealer/devcontainers/rocky --workspace-folder <my-project>
```

특정 Ubuntu 버전을 선택하려면:

```bash
devcontainer templates apply -t ghcr.io/congealer/devcontainers/rocky -v noble --workspace-folder <my-project>
```

---
