# Guia de Liberação de Release - Boss4D

Este documento detalha o ambiente correto do Delphi e as etapas necessárias para compilar, testar e publicar releases do **Boss4D** de forma consistente e livre de erros.

O script `scripts/ci-verify-sbom.ps1` é a verificação autoritativa e pode ser
executado localmente. Ele valida Win32, Win64, os testes, a reprodutibilidade entre
arquiteturas, VEX, atestações e os formatos com CycloneDX CLI e SPDX tools-java.
O workflow opcional `.github/workflows/sbom-ci.yml` pode ser iniciado manualmente
pela ação `workflow_dispatch` e executa a mesma matriz quando
houver um runner self-hosted com os rótulos `windows` e `delphi-13`, Delphi 13,
Docker, Java e GitHub CLI. A ausência desse runner não bloqueia a release local.
O workflow de tag, porém, exige um runner Windows com os rótulos
`self-hosted`, `windows` e `delphi-13`. Ele pode ser registrado como efêmero:
atende somente um job e é removido automaticamente ao terminar. O runner deve
disponibilizar Windows PowerShell, Delphi 10 Seattle, Delphi 13 e Inno Setup 6.
Delphi 10.1, 11 e 12 são opcionais e compilados quando instalados.
Antes de promover o PR ou publicar uma tag, preencha
[`docs/sbom-release-checklist.pt-BR.md`](docs/sbom-release-checklist.pt-BR.md).

---

## 💻 1. Ambiente Delphi e Versão Oficial
* A versão oficial do compilador Delphi instalada e utilizada na máquina do desenvolvedor para compilar as releases é o **Delphi 13 (versão 37.0)**.
* O caminho correto para carregar as variáveis de ambiente no Windows é:
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`

---

## 🔨 2. Compilação Local de Produção e Setup
Antes de qualquer release, compile todos os executáveis oficiais e os plugins de IDE de forma automatizada:
1. Abra o console do terminal na pasta raiz do projeto.
2. Execute o script de lote de produção:
   ```cmd
   build_release.bat
   ```
3. O script criará a pasta `dist/` e gerará os executáveis de produção (Win32/Win64 da CLI e da GUI) e os plugins de IDE:
   * `dist/bin/boss4d.exe` (CLI Win32)
   * `dist/bin/boss4d_x64.exe` (CLI Win64)
   * `dist/bin/Boss4D.GUI.exe` (GUI Win32)
   * `dist/bin/Boss4D.GUI_x64.exe` (GUI Win64)
   * `dist/plugins/10/Boss4D.IDE.Plugin.bpl` (Delphi 10 Seattle, obrigatório)
   * `dist/plugins/10.1/Boss4D.IDE.Plugin.bpl` (Delphi 10.1 Berlin, quando instalado)
   * `dist/plugins/11/Boss4D.IDE.Plugin.bpl` (Delphi 11, quando instalado)
   * `dist/plugins/12/Boss4D.IDE.Plugin.bpl` (Delphi 12, quando instalado)
   * `dist/plugins/13/Boss4D.IDE.Plugin.bpl` (Delphi 13)
   * `dist/sbom/boss4d.cdx.json` (CycloneDX 1.7)
   * `dist/sbom/boss4d.spdx.json` (SPDX 2.3)
   * `dist/sbom/boss4d.cdx.intoto.json` (atestação destacada CycloneDX)
   * `dist/sbom/boss4d.spdx.intoto.json` (atestação destacada SPDX)

   O build interrompe a release se a validação semântica de qualquer SBOM falhar.
   Antes de publicar, valide também com consumidores externos, como CycloneDX CLI
   e SPDX tools-java, conforme `docs/sbom-migration.pt-BR.md`.

4. Compile o instalador offline usando o Inno Setup:
   ```cmd
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\Boss4D.iss
   ```
5. Valide que o instalador final foi gerado com sucesso em:
   * `installer/Output/Boss4D_Setup.exe`

6. Empacote o CLI FPC compilado no contêiner Linux:
   ```powershell
   docker run --rm -v "${PWD}:/work" -w /work fpc-test:latest sh -lc "tar -czf installer/Output/boss4d-linux-x86_64.tar.gz -C .fpc-build boss4d"
   ```

   O job macOS 15 arm64 da release compila a mesma fonte, executa toda a suíte
   FPCUnit e publica `boss4d-macos-arm64.tar.gz`. Esse artefato deve vir do
   runner macOS nativo, não de cross-compilação local.

7. Gere o pacote imutável do Registry e sua proveniência:

```powershell
$version = (Get-Content boss.json -Raw | ConvertFrom-Json).version
dist\bin\boss4d.exe pack --output "dist\boss4d-$version.b4dpkg"
```

   A release automatizada publica o `.b4dpkg`, o
   `.b4dpkg.intoto.json`, inclui o pacote em `SHA256SUMS.txt` e envia
   atestação OIDC do GitHub. A entrada no Registry v2 ainda exige a assinatura
   OpenPGP destacada.

8. Gere `installer/Output/SHA256SUMS.txt` cobrindo o instalador, os arquivos
   Linux/macOS, os dois SBOMs e as atestações.

---

## 🧪 3. Execução de Testes
Sempre execute e garanta que 100% dos testes unitários estejam passando antes de prosseguir:
1. Compile e execute os testes usando o executável:
   ```cmd
   tests\Boss4DTests.exe
   ```

---

## 🏷️ 4. Procedimento para Atualizar ou Criar Tags no Git
Defina uma versão SemVer nova e aponte a tag para o commit validado:
```powershell
$releaseVersion = "vX.Y.Z"
git tag $releaseVersion
git push origin $releaseVersion
```

Não mova uma tag depois que uma release pública válida existir. Se uma execução
falhar antes da publicação, corrija o workflow, cancele a execução antiga e
confirme que nenhum ativo foi publicado antes de recriar a tag.

---

## 🚀 5. Publicação de Executáveis na Release do GitHub

### ⚠️ Importante para Agentes de IA (Sandbox)
O sandbox de agentes IA injeta uma variável de ambiente chamada `GITHUB_TOKEN` contendo um token temporário inválido para o repositório físico do usuário. Para que o utilitário do GitHub CLI (`gh`) use a credencial real do desenvolvedor gravada na máquina do Windows, a variável deve ser limpa antes de rodar os comandos:

### Comando de Criação de Release Oficial
A publicação normal é feita por `.github/workflows/release.yml` após o push da
tag. O workflow compila e testa Linux, macOS e Windows, normaliza os layouts
baixados, gera o checksum combinado, cria attestations OIDC e publica os ativos.

O comando abaixo é somente um fallback manual. Use os artefatos produzidos
pelos runners nativos, incluindo o arquivo macOS; não substitua esses arquivos
por cross-compilações:

```powershell
# 1. Limpa o token dummy da IA para ativar as credenciais reais do Windows
$env:GITHUB_TOKEN = $null

# 2. Cria a release e anexa binários, manifesto, SBOMs e atestações
gh release create $releaseVersion `
  installer\Output\Boss4D_Setup.exe `
  installer\Output\boss4d-linux-x86_64.tar.gz `
  installer\Output\SHA256SUMS.txt `
  "dist\boss4d-$version.b4dpkg" `
  "dist\boss4d-$version.b4dpkg.intoto.json" `
  dist\sbom\boss4d.cdx.json `
  dist\sbom\boss4d.spdx.json `
  dist\sbom\boss4d.cdx.intoto.json `
  dist\sbom\boss4d.spdx.intoto.json `
  --title "Boss4D $releaseVersion" `
  --notes "Sua descrição detalhada da release aqui"
```
