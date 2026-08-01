# Índices e descoberta de pacotes

## Saúde do catálogo

Execute `boss4d registry health [raiz-do-checkout]` antes de publicar mudanças
no Registry. A auditoria percorre includes locais e documentos sparse v2,
rejeita referências ausentes ou duplicadas, detecta identidades de pacote
duplicadas, valida os metadados obrigatórios do repositório e verifica escopo
do publisher e autorização do signatário nos pacotes schema v2. Entradas v1
continuam instaláveis, mas são contabilizadas como avisos de migração; versões
legadas ausentes adicionam outro aviso. Qualquer erro estrutural ou de
confiança retorna código de saída de falha.

O Boss4D consulta o registro público oficial por padrão e combina múltiplos
índices privados, HTTP ou arquivos JSON locais. Se o registro público estiver
temporariamente indisponível, a busca continua funcionando com o catálogo
inicial offline embutido e todas as demais fontes configuradas.

```console
boss4d registry add https://packages.example.com/boss4d-index.json
boss4d registry add C:\empresa\boss4d-index.json
boss4d registry list
boss4d search database
boss4d info InternalLib
boss4d package versions InternalLib
boss4d package install InternalLib@^2.0.0
boss4d registry remove C:\empresa\boss4d-index.json
```

Nomes simples de dependência no `boss.json` são aliases do Registry:

```json
{
  "dependencies": {
    "Horse": "^3.0.0"
  }
}
```

Na primeira instalação, o Boss4D resolve o nome exato nos catálogos
configurados e grava no lock a identidade canônica do repositório. Depois,
`--locked` e `--offline` recuperam esse mapeamento exclusivamente do lock, sem
precisar acessar o Registry. Valores que já identificam URL, host, caminho ou
repositório com escopo nunca são reescritos como aliases.

O ponto de entrada oficial usa o schema v2 e fica versionado no Git. A versão
2 compõe catálogos por referências relativas, permitindo manter famílias de
pacotes em arquivos ou repositórios separados:

```json
{
  "schemaVersion": 2,
  "includes": [
    "community/index-v1.json",
    "company/index-v2.json"
  ],
  "packages": [{
    "name": "InternalLib",
    "repository": "git.example.com/team/internal",
    "publisherRepository": "git.example.com/team/internal",
    "distributionRepository": "github.com/distribuidor/pacote-interno",
    "description": "Biblioteca Delphi interna",
    "license": "MIT",
    "versions": [{
      "version": "2.4.0",
      "artifact": "https://packages.example.com/InternalLib-2.4.0.b4dpkg",
      "sha256": "...",
      "signature": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.asc",
      "provenance": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.intoto.json",
      "changelog": "https://packages.example.com/InternalLib/2.4.0/changes",
      "sbom": "https://packages.example.com/InternalLib-2.4.0.cdx.json",
      "dependencies": ["RuntimeCore", "JsonCore"],
      "variants": [{
        "platform": "Win64",
        "compiler": "37.0",
        "artifact": "https://packages.example.com/InternalLib-2.4.0-win64-d37.b4dpkg",
        "sha256": "..."
      }, {
        "platform": "Linux64",
        "artifact": "https://packages.example.com/InternalLib-2.4.0-linux64.b4dpkg",
        "sha256": "..."
      }]
    }]
  }]
}
```

`repository` identifica a origem canônica usada pelo fallback Git e exibida
aos usuários. `publisherRepository` identifica o repositório canônico do
publisher original e normalmente coincide com `repository`. Quando um
distribuidor cadastrado empacota e assina esse upstream em outro repositório,
o campo opcional `distributionRepository` identifica o host dos artefatos para
validação do namespace e do signatário. URLs de artefato, assinatura e
proveniência podem permanecer ali; isso não altera a autoria do upstream.

As referências podem ser URLs HTTP(S), caminhos locais absolutos ou caminhos
relativos ao índice que as declara. Ciclos são detectados e carregados apenas
uma vez. O validador de conformidade rejeita travessia insegura para diretórios
pais.

O schema v1 continua totalmente suportado. Índices existentes e o mapa
string/string original de `dependencies` no `boss.json` não precisam de
migração. No v2, `versions` é opcional, e um pacote ainda pode expor os campos
compatíveis com v1 `version`, `artifact` e `sha256` no nível superior.

`dependencies`, `changelog` e `sbom` são opcionais no pacote ou na versão.
Os metadados da versão selecionada têm precedência. Assim, clientes do
catálogo podem apresentar o grafo declarado e navegar com segurança para as
notas da release e seu SBOM publicado, sem baixar ou executar o pacote.

## Metadados esparsos e revogação

Registros grandes no schema v2 podem manter um documento de metadados por
pacote. O índice principal referencia esses documentos em `sparse`; cada um
segue o contrato normal de `packages`:

```json
{
  "schemaVersion": 2,
  "sparse": [
    "packages/horse.json",
    {
      "path": "packages/dext.json",
      "mirrors": ["https://mirror.example/packages/dext.json"]
    }
  ],
  "revocations": [{
    "name": "InternalLib",
    "version": "2.4.0",
    "reason": "solicitação do publisher"
  }],
  "packages": []
}
```

Uma versão também pode declarar `"revoked": true` e `revocationReason`. A
resolução escolhe a primeira versão não revogada. Uma revogação no índice raiz
prevalece sobre metadados incluídos ou esparsos, e a instalação recusa a versão
selecionada quando revogada. O histórico permanece disponível para preservar
as evidências de lockfiles e auditorias.

Objetos de metadados esparsos tentam primeiro `path` e depois cada item de
`mirrors` na ordem declarada. Versões e variantes de plataforma/compilador
também podem declarar `mirrors` com URLs alternativas do artefato. Todo
candidato precisa corresponder ao mesmo SHA-256 imutável; um mirror acessível,
mas alterado, é rejeitado e a resolução continua na próxima origem.

As variantes de artefato são opcionais e não alteram o `boss.json`. Para
selecioná-las:

```text
boss4d package install InternalLib --platform Win64 --compiler 37.0
```

A seleção é determinística: plataforma e compilador exatos, somente plataforma,
somente compilador e, por fim, uma variante genérica. Uma variante com seletor
não vazio incompatível nunca é escolhida. Quando não há artefato compatível, a
instalação usa a fonte Git indexada, exceto com `--no-source-fallback`.

As fontes adicionais ficam na configuração global. A falha de uma fonte gera
aviso sem ocultar resultados das demais. Schemas desconhecidos são rejeitados,
e a URL de um artefato sempre deve estar acompanhada de seu SHA-256 imutável,
inclusive dentro de `versions`.

O catálogo da GUI e a busca do RAD Studio usam o mesmo serviço da CLI. A GUI
expõe grafo de dependências, matriz de compatibilidade, versão/revogação e
cadeia de fornecimento, além de navegação HTTP validada para repositório,
changelog e SBOM quando esses links são declarados, e invoca o mesmo
contrato `package install` por um fluxo guiado de versão, compilador e
plataforma. A barra da operação separa sucesso, falha e cancelamento, acompanha
o tempo decorrido e preserva solicitações que falharam ou foram canceladas para
retry.

Para hospedagem estática e serviços externos de descoberta, gere um snapshot
consolidado:

```text
boss4d registry search-index registry/index-v2.json registry/search-index.json
```

O snapshot resolve `includes` e metadados `sparse` locais, aplica revogações e
expõe identidade normalizada de publishers sem substituir a entrada oficial do
protocolo.

Metadados HTTP são persistidos após cada resposta válida. Falhas de rede ou do
servidor usam a última cópia válida. O cliente POSIX também utiliza requisições
condicionais com `ETag` e `Last-Modified` e oferece resolução estrita somente
por cache com `--offline`.
