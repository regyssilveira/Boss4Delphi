# Build de componentes e ciclo de vida da IDE

O Boss4D compila, armazena em cache, instala, repara e remove um componente em
vários targets do RAD Studio sem compartilhar DCUs ou packages incompatíveis.
O manifesto representa o estado desejado; os inventários de build e IDE
registram o que foi realmente produzido e instalado.

## Por que isso é necessário

Um componente Delphi pode incluir packages runtime e design-time, aplicações,
ferramentas, binários prontos, templates, ajuda, DLLs e configurações da IDE.
Cada artefato pertence a um compilador, plataforma e configuração exatos.
Copiar o mesmo BPL para várias IDEs ou ampliar indiscriminadamente o Library
Path torna atualização e remoção inseguras.

Por isso, o Boss4D:

- isola outputs por pacote/compilador/plataforma/configuração;
- compila dependências antes dos consumidores e paraleliza targets independentes;
- ignora targets válidos e recompila alterações ou outputs ausentes;
- valida cache local e compartilhado por SHA-256 antes de restaurar;
- registra somente o package design produzido para o target selecionado;
- controla propriedade para não remover estado do usuário no reparo/uninstall;
- reverte arquivos e Registro quando uma transação da IDE falha.

## Níveis de suporte

Não é necessário instalar todas as versões modeladas na mesma máquina:

```console
boss4d support
boss4d support --compiler d13 --platform Win64 --kind application
boss4d support --compiler d10 --platform Win32 --kind design
boss4d support --compiler d13 --platform Win64 --kind application \
  --project packages/client.cbproj
```

| Nível | Significado |
|---|---|
| `certified` | A combinação participa da matriz real de compiladores do projeto. |
| `compatible` | O contrato é suportado e testado unitariamente, mas não integra a certificação atual. |
| `experimental` | O fluxo existe e tem teste estrutural, mas precisa de mais validação em projetos reais. |
| `unsupported` | A toolchain não produz a combinação; a CLI informa o motivo. |

O catálogo vai do Delphi XE ao Delphi 13. As plataformas Win32, Win64,
Linux64, macOS, iOS e Android seguem a disponibilidade de cada geração do RAD
Studio. Sem uma IDE antiga ainda é possível validar manifesto e comandos, mas
o resultado não deve ser chamado de certificação real daquele compilador.

## Manifesto declarativo

Consulte o [exemplo completo e copiável](../examples/component-build-and-ide/boss.json).
Os tipos aceitos são `runtime`, `design`, `application`, `tool` e `binary`.
Projetos Delphi `.dproj` e C++Builder `.cbproj` usam MSBuild. C++Builder é
experimental e, neste momento, limitado a Win32/Win64. Um projeto `binary` é
copiado para o output `bin` isolado sem executar compilador.

`ideAssets` declara ferramentas, templates e valores gerenciados do Registro.
Os paths devem ficar dentro do pacote e o Registro é restrito à subárvore BDS
correspondente do usuário atual. São aceitos os tokens `{compiler}`,
`{platform}`, `{root}`, `{bpl}`, `{tools}` e `{templates}`.

## Fluxos cotidianos

```console
boss4d spec --detect
git diff -- boss.json
boss4d doctor

boss4d build --compiler d13 --platform Win64 \
  --configuration Debug --explain

boss4d build --all-installed --configuration Release

boss4d build --affected --with-dependents --jobs 4 \
  --remote-cache X:\boss4d-cache --explain
```

Em CI isolado, nenhum estado da IDE é alterado:

```console
boss4d restore --ci --remote-cache X:\boss4d-cache
boss4d install --build-only --locked --remote-cache X:\boss4d-cache
```

O modo CI sempre usa o lock, começa com módulos limpos e desativa o registro na
IDE, mesmo que uma opção conflitante seja informada pelo chamador.

## Instalação, conflitos, reparo e remoção

```console
boss4d build --compiler d13 --platform Win32 \
  --configuration Release --register --conflict fail
```

Políticas de conflito:

- `fail`: interrompe antes de substituir um package não gerenciado;
- `warn`: continua e registra o alerta;
- `adopt`: adota o package existente sem trocar seu BPL;
- `replace`: substitui pelo artefato compilado dentro de uma transação.

Use `fail` em automação. Use `adopt` ou `replace` somente depois de confirmar
propriedade e compatibilidade binária.

O reparo verifica Registro e artefatos. Se um arquivo gerenciado estiver
ausente, recompila o target exato antes de restaurar o registro:

```console
boss4d doctor
boss4d ide repair
boss4d doctor
```

Remoção exata ou completa:

```console
boss4d ide unregister AcmeDesign370 --compiler d13 --platform Win32
boss4d ide uninstall acme-controls
boss4d ide uninstall acme-controls --cascade
```

O uninstall normal recusa remover um pacote com consumidores instalados.
`--cascade` remove o fechamento transitivo de consumidores em ordem inversa.
`--force` ignora essa proteção para o produto selecionado e deve ser reservado
para recuperação.

## Arquivos e recuperação

- outputs: `modules/artifacts/<pacote>/<compilador>/<plataforma>/<configuração>/`;
- estado incremental: `.boss4d-state/` de cada target;
- inventário global: `%BOSS_HOME%/build-inventory.json`;
- estado desejado da IDE: `%BOSS_HOME%/ide-registrations.json`.

Não copie BPLs manualmente nem apague todo o cache para corrigir um target.
Use `build --explain`, remova apenas o target afetado quando necessário e rode
`ide repair`. DLLs, ajuda CHM, ferramentas, templates, valores gerenciados,
Library Paths e entradas no `PATH` participam de propriedade, rollback, reparo
e uninstall.

Veja também o [contrato da matriz](build-matrix-contract.pt-BR.md), os
[casos de uso da IDE](use-cases-ide.pt-BR.md) e o
[exemplo completo](../examples/component-build-and-ide/README.md).
