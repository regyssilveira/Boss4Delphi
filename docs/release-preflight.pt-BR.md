# Pre-flight de Release GitHub

Este checklist evita o caso em que a tag existe no GitHub, mas a release nao
aparece na lista porque o workflow ainda esta aguardando o runner Windows/Delphi.

## Antes de publicar a tag

1. Garanta que todas as alteracoes de versao foram commitadas.

```powershell
git status --short --branch
git log -1 --oneline
```

2. Confirme que a tag ainda nao existe localmente nem no remoto.

```powershell
git tag --list "vX.Y.Z"
git ls-remote --tags origin refs/tags/vX.Y.Z
```

3. Confirme que o runner Windows/Delphi esta online.

```powershell
$env:GITHUB_TOKEN = $null
gh api repos/regyssilveira/Boss4Delphi/actions/runners `
  --jq '.runners[] | select(.labels[].name == "delphi-13") | {name, status, busy}'
```

O workflow `.github/workflows/release.yml` exige um runner self-hosted com os
labels `self-hosted`, `windows` e `delphi-13` para o job
`Delphi 13 / Win32 + Win64`. Sem esse runner, Linux e macOS podem passar, mas o
job final `Publish immutable release` nao roda.

## Publicacao normal

```powershell
$releaseVersion = "vX.Y.Z"
git tag -a $releaseVersion -m "Boss4D $releaseVersion"
git push origin main
git push origin $releaseVersion
```

Depois acompanhe:

```powershell
$env:GITHUB_TOKEN = $null
gh run list --repo regyssilveira/Boss4Delphi --limit 5
gh run view <run-id> --repo regyssilveira/Boss4Delphi
gh release view $releaseVersion --repo regyssilveira/Boss4Delphi
```

## Quando a tag existe mas a release nao aparece

Se `gh release view` retornar `release not found`, verifique a tag:

```powershell
git ls-remote --tags origin refs/tags/$releaseVersion
```

Se a tag existir e o workflow estiver apenas aguardando o runner
Windows/Delphi, crie uma release visivel sem assets:

```powershell
$env:GITHUB_TOKEN = $null
gh release create $releaseVersion `
  --repo regyssilveira/Boss4Delphi `
  --title "Boss4D $releaseVersion" `
  --notes-file "docs/releases/$($releaseVersion.TrimStart('v')).md" `
  --verify-tag
```

Isso nao substitui o workflow. Quando o job Windows/Delphi terminar, a etapa
`softprops/action-gh-release` deve anexar os assets oficiais na release
existente.

## Regras importantes

- Nao mova tag publica depois que ela foi enviada.
- Nao recrie tag se algum asset ja tiver sido publicado.
- Nao anexe manualmente artefatos incompletos ou gerados fora dos runners
  previstos no workflow.
- Se o job Windows/Delphi ficar preso, suba o runner self-hosted correto em vez
  de considerar Linux/macOS como release completa.
- Em sessoes de agente/IA, limpe `GITHUB_TOKEN` antes de usar `gh`, para que o
  GitHub CLI use a credencial real da maquina.
