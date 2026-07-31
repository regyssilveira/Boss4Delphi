# Casos de uso de Linux, CI, release e atualização

Automação deve partir de fonte revisada e produzir evidência imutável. Fluxos
Linux/FPC são nativos; RAD Studio, GetIt, Registro do Windows, GUI e plugin da
IDE permanecem capacidades Windows.

## 1. Validar a CLI Linux nativa localmente

**Situação:** desenvolvedor Windows quer reproduzir build Linux/FPC sem
instalar FPC no host.

```powershell
./scripts/ci-fpc-linux.ps1
```

**Resultado esperado:** o ambiente Docker `fpc-test:latest` compila CLI x86-64,
executa FPCUnit e smoke tests.

**Controles de risco:** use imagem/workflow do projeto e registre sua versão.
Build Delphi Windows não comprova o host Linux nativo.

**Recuperação:** confirme Docker ativo, reconstrua a imagem designada quando o
contrato mudar e repita. Não use silenciosamente outra versão FPC.

## 2. Executar restore Linux determinístico na CI

**Situação:** runner Linux deve restaurar exatamente o grafo revisado.

```bash
boss4d ci
```

Para runner isolado preparado:

```bash
boss4d ci --offline
```

**Resultado esperado:** `ci` exige locked/frozen, recusa drift e não altera o
lock.

**Controles de risco:** preencha e verifique cache antes do offline. Arquive
logs e `boss-lock.json` exato.

**Recuperação:** regenere/revise lock fora da CI ou preencha cache; nunca
transforme falha travada em instalação livre.

## 3. Instalar e manter ferramenta FPC global

**Situação:** utilitário deve ficar disponível em `$BOSS_HOME/bin`.

```bash
boss4d tool install -g github.com/example/my-tool
boss4d tool list
boss4d tool update my-tool github.com/example/my-tool
boss4d tool uninstall my-tool
```

**Resultado esperado:** install/update compila em staging, promove
transacionalmente, registra SHA-256 em `tools.json` e uninstall remove apenas a
ferramenta própria.

**Controles de risco:** ferramentas globais executam com privilégios do usuário
e afetam PATH. Revise fonte/revisão e mantenha `$BOSS_HOME/bin` após caminhos de
sistema confiáveis.

**Recuperação:** update falho preserva executável anterior. Verifique
`tools.json`, reinstale revisão confiável e procure comandos sombreados no PATH.

## 4. Validar contratos de release antes da tag

**Situação:** mantenedores querem prova local rápida de workflow e artefatos.

```powershell
./scripts/test-release-workflow.ps1
./scripts/test-release-artifact-matrix.ps1
./scripts/test-linux-release-artifact.ps1
./scripts/test-delphi-plugin-matrix.ps1
```

**Resultado esperado:** estrutura do workflow, targets, arquivo Linux e builds
de plugins disponíveis passam antes da tag.

**Controles de risco:** contratos complementam testes unitários, compiladores
reais, SBOM, instalador e Sonar; não os substituem.

**Recuperação:** corrija contrato ou implementação em branch. Não crie tag com
toolchain ou artefato obrigatório ausente.

## 5. Publicar release a partir de tag imutável

**Situação:** commit, changelog, testes e artefatos foram aprovados.

```powershell
git tag -a vX.Y.Z -m "Boss4D vX.Y.Z"
git push origin vX.Y.Z
```

**Resultado esperado:** workflow compila Windows/Linux independentemente,
combina checksums, cria atestações e publica apenas após ambos aprovarem.

**Controles de risco:** marque somente commit revisado. Tags e identidades
`(nome, versão)` são contratos imutáveis; nunca mova tag publicada.

**Recuperação:** se falhar antes da publicação, corrija em novo commit e use a
próxima versão conforme política. Se ativos foram publicados, não os substitua
na mesma identidade.

## 6. Verificar artefatos baixados

**Situação:** usuário ou deploy baixou arquivos Windows/Linux e manifest.

No Linux:

```bash
sha256sum --check SHA256SUMS.txt
```

No PowerShell:

```powershell
Get-FileHash .\boss4d-windows.zip -Algorithm SHA256
Get-FileHash .\Boss4D_Setup.exe -Algorithm SHA256
```

**Resultado esperado:** bytes exatos correspondem ao manifest combinado.

**Controles de risco:** obtenha manifest da mesma release confiável e valide
proveniência quando exigido. Checksum de local não confiável não autentica.

**Recuperação:** apague divergentes e baixe da release oficial. Não execute nem
redistribua artefato divergente.

## 7. Fazer autoatualização segura

**Situação:** instalação Boss4D deve ir para a release oficial mais recente.

```powershell
boss4d self-update
```

**Resultado esperado:** seleciona artefato oficial, baixa `SHA256SUMS.txt`,
verifica bytes, usa staging e promove após validação. Versão atual não é
substituída.

**Controles de risco:** não ignore checksum nem use URL arbitrária. Windows usa
instalador verificado; Linux usa `boss4d-linux-x86_64.tar.gz`.

**Recuperação:** falha de verificação remove staging; falha de promoção Linux
restaura executável anterior. Preserve instalação antiga até `boss4d version`.

## 8. Diagnosticar autoatualização falha ou suspeita

**Situação:** resposta latest inválida, ativo ausente ou checksum divergente.

1. Pare; não execute staging.
2. Inspecione nomes oficiais e `SHA256SUMS.txt`.
3. Verifique proxy/cache de rede.
4. Preserve o binário atual.

```powershell
boss4d version
boss4d doctor
```

**Resultado esperado:** instalação existente continua utilizável e nenhum
artefato não verificado é promovido.

**Controles de risco:** divergência de checksum é falha de segurança, não
motivo para desabilitar validação.

**Recuperação:** após corrigir publicação, baixe da release oficial, verifique
manualmente e repita.

## 9. Respeitar fronteiras de capacidade por plataforma

**Situação:** uma automação atende Windows e Linux.

Use Linux para dependências, Registry, conformidade, publicação, atualização,
cache, workspaces e ferramentas FPC. Direcione ao Windows:

- descoberta do RAD Studio e MSBuild;
- registro/reparo da IDE;
- integração GetIt;
- GUI e instalador Windows.

**Resultado esperado:** cada job usa capacidade nativa, sem emular estado da
máquina.

**Controles de risco:** manifest portátil não torna todo recurso portátil.
Falhe claramente quando capacidade não existir.

**Recuperação:** mova a etapa ao runner rotulado correto e passe somente
artefatos/evidências imutáveis entre jobs.

## Tabela de decisão

| Necessidade | Fluxo |
|---|---|
| Reproduzir suíte Linux | `./scripts/ci-fpc-linux.ps1` |
| Restore Linux determinístico | `boss4d ci` |
| Restore Linux offline | Cache preenchido e `boss4d ci --offline` |
| Validar formato da release | Scripts de contrato |
| Publicar release | Tag `v*` aprovada e imutável |
| Atualizar CLI instalada | `boss4d self-update` |
| Conferir bytes baixados | `SHA256SUMS.txt` e ferramenta de hash |

Veja [CLI FPC/Linux](posix-cli.pt-BR.md),
[portabilidade](platform-portability.pt-BR.md),
[matriz de artefatos](release-artifact-matrix.pt-BR.md) e
[autoatualização segura](self-update.pt-BR.md).

