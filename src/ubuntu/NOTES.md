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
devcontainer templates apply -t ghcr.io/congealer/devcontainers/ubuntu -a '{"imageVariant": "noble"}' --workspace-folder <my-project>
```
