# Gerenciamento de componentes e perfis isolados da IDE

O Boss4D trata um componente Delphi como um produto, não como uma única BPL.
Um produto pode conter packages runtime e design-time, aplicações, ferramentas,
templates, arquivos de ajuda, DLLs e valores gerenciados do Registro. A CLI e
a GUI standalone usam exatamente o mesmo modelo.

## Por que existem perfis

Normalmente o RAD Studio lê sua configuração em
`HKCU\Software\Embarcadero\BDS\<versão>`. Instalar todos os componentes nesse
branch faz experimentos, CI, upgrades e recuperações afetarem a IDE principal
do desenvolvedor.

Um perfil nomeado do Boss4D possui:

- uma versão do compilador Delphi/BDS;
- um executável;
- um Registry branch como `Boss4D-equipe-a`;
- um inventário privado de registros;
- plataforma e configuração padrão;
- a lista de produtos instalados no perfil.

O Boss4D inicia um perfil nomeado com `bds.exe /r:<branch>`. O perfil
`default` usa intencionalmente o branch padrão `BDS`. O inventário legado de
registros do Boss4D é copiado uma única vez para o perfil default e nunca é
sobrescrito depois disso.

## Packages runtime e design-time

Declare os papéis em `buildMatrix.projects`:

```json
{
  "buildMatrix": {
    "compilers": ["37.0"],
    "platforms": ["Win32"],
    "configurations": ["Release"],
    "projects": [
      {
        "path": "packages/AcmeRuntime.dproj",
        "kind": "runtime"
      },
      {
        "path": "packages/AcmeDesign.dproj",
        "kind": "design",
        "dependsOn": ["packages/AcmeRuntime.dproj"]
      }
    ]
  }
}
```

Packages runtime compilam antes de seus consumidores design-time. Um package
runtime não pode depender de um package design. Somente BPLs design-time são
gravadas em `Known Packages`; BPLs runtime e DLLs ficam disponíveis pelos paths
runtime/search gerenciados.

## Ciclo seguro da operação

Uma instalação segue estas etapas:

1. valida o plano completo de targets e arquivos;
2. adquire o lock entre processos do perfil/toolchain;
3. aplica a política escolhida para IDE aberta;
4. compila ou restaura targets runtime/design compatíveis;
5. prepara arquivos e alterações do Registro;
6. confirma o lote de registros atomicamente;
7. persiste o inventário do perfil e o journal da operação.

Em caso de falha, o Boss4D restaura arquivos, valores do Registro e inventários.
Previews nunca alteram a IDE. A remoção usa o inventário de propriedade,
preserva artefatos compartilhados e recusa cascatas inseguras. Um perfil com
produtos instalados não pode ser apagado; desinstale-os primeiro.

A operação mais recente e sua instrução de recuperação ficam em
`%BOSS_HOME%\ide-operation-results`.

## Fluxo pela CLI

Crie e inspecione perfis:

```console
boss4d ide profile list
boss4d ide profile create Equipe-A --compiler 37.0 \
  --description "Conjunto isolado de componentes" \
  --executable "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\bds.exe"
boss4d ide profile show equipe-a
boss4d ide profile target equipe-a --platform Win64 --configuration Debug
boss4d ide profile clone equipe-a Equipe-A-Revisao
boss4d ide profile export equipe-a --output equipe-a.json
boss4d ide profile import equipe-a.json
boss4d ide profile snapshot equipe-a --output equipe-a.snapshot.json
boss4d ide profile diff equipe-a equipe-a.snapshot.json
boss4d ide profile restore equipe-a.snapshot.json
boss4d ide profile undo
boss4d ide profile history
```

O export de perfil contem sua declaracao portavel. O snapshot tambem captura a
lista exata de packages e o inventario de registros, protege o inventario com
SHA-256, detecta drift e restaura o estado capturado com substituicao atomica do
arquivo. Em outra maquina, o path do inventario e recalculado sob o diretorio
de perfis do Boss4D daquela maquina.

Antes de install ou uninstall concluido, o Boss4D cria automaticamente um
snapshot e o registra no diario da operacao. `profile undo` reverte o ultimo
install ou uninstall concluido: produtos removidos sao recompilados e
registrados novamente, enquanto produtos recem-instalados sao removidos antes
da restauracao do inventario anterior.

`profile history` lista cada entrada imutavel do diario com data, status,
operacao, perfil e alvo. A GUI apresenta a mesma lista em **Historico** e
mantem `latest.json` apenas como um ponteiro de conveniencia. A linha do tempo
visual exibe primeiro as entradas mais recentes, indica quando ha dados para
desfazer e apresenta acoes concluidas, erros e instrucoes de recuperacao no
painel de detalhes.

Projetos podem se vincular a um perfil no `boss.json`:

```json
{
  "ideProfile": "equipe-a"
}
```

Execute `boss4d ide profile project` no diretorio do projeto para resolver o
vinculo. O Boss4D recusa um perfil cujo compilador Delphi seja diferente do
compilador solicitado pelo projeto, evitando build ou instalacao acidental em
outro ambiente da IDE.

Faça preview e execute as operações:

```console
boss4d ide profile preview-install equipe-a acme-controls
boss4d ide profile install equipe-a acme-controls \
  --conflict fail --ide-open fail
boss4d ide profile repair equipe-a
boss4d ide profile preview-uninstall equipe-a acme-controls
boss4d ide profile uninstall equipe-a acme-controls
boss4d ide profile launch equipe-a
boss4d ide profile remove equipe-a
```

Políticas de conflito:

- `fail`: interrompe antes de sobrescrever uma entrada conflitante;
- `warn`: preserva o conflito e o informa;
- `adopt`: passa a gerenciar uma entrada existente equivalente;
- `replace`: substitui a entrada de forma transacional.

Políticas para IDE aberta:

- `fail`: exige que a IDE alvo esteja fechada;
- `defer`: registra que a operação deve ser repetida depois;
- `force`: continua somente quando o operador aceita explicitamente o risco.

## Fluxo pela GUI

Abra `Boss4D.GUI.exe` e selecione **Componentes e IDEs**:

1. crie, clone, selecione, remova ou inicie um perfil;
2. escolha plataforma e configuração padrão;
3. selecione um produto do inventário global de builds;
4. consulte **Preview instalar** antes de alterar a IDE;
5. escolha as políticas de conflito e IDE aberta e instale;
6. use **Reparar** para reconciliar drift;
7. use **Desfazer** ou abra a linha do tempo estruturada em **Historico** para
   recuperar ou auditar operacoes;
8. consulte **Preview remover** e remova o produto gerenciado.

A grade diferencia produtos disponíveis no inventário de builds dos instalados
no perfil selecionado. A lista de targets mostra as identidades exatas afetadas
pela próxima operação.

## Situações cotidianas

### Manter a IDE diária estável

Use o perfil default somente para componentes aprovados. Clone um perfil
nomeado de revisão, instale nele as versões candidatas, abra seu branch isolado
e apague-o depois de desinstalar todos os produtos.

### Manter builds Win32 e Win64

Crie dois perfis para o mesmo compilador e escolha um target padrão diferente
em cada um. O preview confirma que o componente declara o target solicitado
antes do início da compilação.

### Recuperar alterações manuais na IDE

Feche a IDE e execute `repair`. O Boss4D compara Registro e artefatos com o
inventário do perfil, restaura entradas recuperáveis e grava um journal. Se
faltarem artefatos de origem, recompile o produto e repita a instalação.

### Validar em CI sem uma IDE antiga

Use testes de suporte/matriz e mocks de compilador para toolchains não
instaladas. Certifique IDEs presentes com builds reais. Escritas no Registro
continuam exclusivas do Windows; builds FPC/Linux validam contratos portáveis
sem simular instalação no RAD Studio.

## Solução de problemas

- **Package não aparece:** faça antes o build/install do componente para
  registrá-lo no inventário global.
- **Nenhum target compatível:** compare compilador/plataforma/configuração do
  perfil com o `buildMatrix` do produto.
- **IDE aberta:** feche o `bds.exe` correspondente ou escolha deliberadamente
  `defer`/`force`.
- **Perfil não pode ser apagado:** desinstale cada produto exibido como
  instalado.
- **Conflito no Registro:** use o preview, identifique o proprietário e escolha
  `adopt` ou `replace` somente após confirmar que a entrada pode ser gerenciada.

Consulte também o [ciclo de build de componentes](component-build-and-ide.pt-BR.md),
o [contrato da matriz](build-matrix-contract.pt-BR.md) e os
[casos de uso da IDE](use-cases-ide.pt-BR.md).
