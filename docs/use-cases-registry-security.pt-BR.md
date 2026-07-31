# Casos de uso de Registry, credenciais e publicação

Estes fluxos atravessam fronteiras de confiança. Metadados do Registry escolhem
o que pode ser instalado, credenciais concedem acesso a repositórios ou
publicação e uma identidade `(nome, versão)` publicada é imutável.

## 1. Adicionar uma fonte privada de Registry

**Situação:** a equipe publica catálogo interno além do Registry público do
Boss4D.

```powershell
boss4d registry list
boss4d registry add https://packages.example.com/index-v2.json
boss4d registry list
```

**Resultado esperado:** a fonte privada fica persistida na configuração global
e aparece depois da fonte pública.

**Controles de risco:** use HTTPS, restrinja escrita no índice e revise
identidade do publisher, revisão, digest e revogação. A ordem das fontes é
significativa quando catálogos contêm a mesma identidade.

**Recuperação:** remova a fonte incorreta ou comprometida:

```powershell
boss4d registry remove https://packages.example.com/index-v2.json
```

Depois remova metadados afetados do cache e repita uma instalação travada com
fontes confiáveis.

## 2. Usar Registry local em rede isolada

**Situação:** ambiente air-gapped espelha metadados aprovados em arquivo local.

```powershell
boss4d registry add C:\empresa\boss4d-index.json
boss4d registry list
boss4d install --locked --offline
```

**Resultado esperado:** a resolução usa o índice local configurado e conteúdo
já presente no cache verificado.

**Controles de risco:** proteja o índice contra escrita sem revisão. Caminho
local não dispensa digest, assinatura, proveniência ou revogação.

**Recuperação:** restaure índice e cache de snapshot confiável. Não edite
versões imutáveis para fazer pacote com falha passar.

## 3. Autenticar dependência Git privada na estação

**Situação:** uma dependência está em repositório privado GitHub ou GitLab.

```powershell
boss4d config auth github <token-de-acesso-pessoal>
boss4d install --locked
```

Use `gitlab` no lugar de `github` para GitLab.

**Resultado esperado:** o token fica no serviço de credenciais do sistema
operacional e o Git autentica sem credencial embutida na URL.

**Controles de risco:** use token com privilégio mínimo. O argumento pode ficar
visível na inspeção local de processos ou histórico do shell; informe-o apenas
em estação confiável e remova histórico sensível conforme a política da
empresa. Nunca coloque token em `boss.json`, `boss-lock.json`, URLs Git ou logs.

**Recuperação:** revogue o token no provedor, substitua a credencial armazenada
e inspecione logs e configuração Git em busca de exposição acidental.

## 4. Fornecer credencial temporária na CI

**Situação:** job automatizado precisa de acesso temporário sem persistir
credencial.

```powershell
$env:BOSS4D_GITHUB_TOKEN = $env:CI_GITHUB_TOKEN
boss4d install --locked
Remove-Item Env:\BOSS4D_GITHUB_TOKEN
```

**Resultado esperado:** a credencial de ambiente prevalece no processo e não é
gravada na configuração do repositório.

**Controles de risco:** obtenha `CI_GITHUB_TOKEN` do cofre da CI, mascare nos
logs, limite ao job e evite tracing do shell. Prefira tokens de curta duração.

**Recuperação:** cancele o job e rotacione a credencial se qualquer saída a
revelar. Instalação bem-sucedida não comprova logs sem segredo; revise a saída.

## 5. Instalar por mirrors sem enfraquecer verificação

**Situação:** host primário de metadados ou artefatos está indisponível.

```powershell
boss4d install --locked
boss4d audit
```

**Resultado esperado:** o Boss4D tenta mirrors na ordem declarada, mas aceita
somente conteúdo cuja evidência imutável corresponde à versão selecionada.

**Controles de risco:** nunca altere o digest do lock porque um mirror devolveu
bytes diferentes. Versões revogadas continuam rejeitadas mesmo disponíveis.

**Recuperação:** restaure artefato confiável no primário ou mirror. Se nenhum
candidato corresponder, interrompa o deploy e publique versão nova revisada em
vez de sobrescrever a identidade antiga.

## 6. Inspecionar publicação sem acesso à rede

**Situação:** mantenedor quer revisar exatamente o que seria enviado.

```powershell
boss4d publish --dry-run --output publish.json
```

**Resultado esperado:** `publish.json` contém identidade, revisão, checksum,
escopo e evidências determinísticas; nenhum envio ocorre.

**Controles de risco:** rode testes antes, exija worktree limpo e evidência do
lock e revise caminhos privados ou metadados indevidos. Preserve o arquivo como
evidência de release.

**Recuperação:** corrija manifest, lock ou estado do repositório e gere
novamente. Não edite `publish.json` manualmente.

## 7. Publicar uma versão imutável

**Situação:** o payload de dry run foi aprovado e a versão exata está pronta.

```powershell
$env:BOSS4D_PUBLISH_TOKEN = $env:RELEASE_REGISTRY_TOKEN
boss4d publish --registry https://registry.example/api
Remove-Item Env:\BOSS4D_PUBLISH_TOKEN
```

**Resultado esperado:** o Registry aceita o novo registro `(nome, versão)` e os
metadados retornados correspondem ao payload revisado.

**Controles de risco:** use credencial limitada à release, proteja o ambiente,
arquive checksums e proveniência e não use `--allow-dirty` em releases normais.

**Recuperação:** HTTP 409 indica identidade existente. Não sobrescreva nem
repita com bytes alterados; compare o registro e publique nova versão se o
conteúdo mudou.

## 8. Enviar pacote ao Registry público oficial

**Situação:** publisher está entrando no catálogo ou adicionando versão
revisada pelo fluxo Git.

1. Cadastre publisher e prefixos controlados em `registry/publishers.json`.
2. Adicione fingerprint OpenPGP completo.
3. Reserve a URL imutável da release para as evidências do pacote.
4. Execute:

```console
boss4d publish --official --open-pr \
  --publisher meu-publisher \
  --repository github.com/owner/meu-pacote \
  --fingerprint <fingerprint-hex-40> \
  --sign <id-da-chave> \
  --artifact-url <url-https-imutavel> \
  --registry-root /src/Boss4Delphi
```

**Resultado esperado:** escopo, fingerprint, imutabilidade, evidência do
artefato, commit limitado aos arquivos esperados e composição do índice passam
antes da revisão; a CLI mostra a URL do pull request criado.

Envie o pacote, assinatura e proveniência gerados para a URL declarada antes
do merge; o check do Registry valida esses assets externos de forma
independente.

**Controles de risco:** nunca edite ou remova objeto de versão existente.
Adicione nova versão ou revogação explícita. Preserve propriedade de publisher
e signer revisável no histórico Git.

**Recuperação:** corrija o commit proposto e rode os dois validadores. Se versão
publicada for insegura, envie revogação em vez de reescrever o histórico.

## Tabela de decisão

| Necessidade | Ação segura |
|---|---|
| Adicionar catálogo confiável | `boss4d registry add <fonte>` |
| Inspecionar fontes configuradas | `boss4d registry list` |
| Inspecionar publicação deterministicamente | `boss4d publish --dry-run --output publish.json` |
| Publicar pela CI | Token de ambiente e `boss4d publish --registry <url>` |
| Abrir submissão oficial | `boss4d publish --official --open-pr ...` |
| Resolver conflito imutável | Publicar versão nova; não sobrescrever |
| Tratar release comprometida | Revogar em metadados revisados do Registry |

Veja [índice de pacotes](package-index.pt-BR.md),
[resolução e credenciais](resolution-and-credentials.pt-BR.md),
[política de confiança](trust-policy.pt-BR.md),
[publicação](publish.pt-BR.md) e
[onboarding de publishers](publisher-onboarding.pt-BR.md).

