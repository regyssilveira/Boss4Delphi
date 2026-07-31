# Casos de uso de instalação e ciclo da IDE

O registro do RAD Studio é estado da máquina. O Boss4D registra o estado
desejado de pacote/compilador/plataforma em
`%BOSS_HOME%\ide-registrations.json` e altera somente chaves e caminhos
correspondentes.

## 1. Instalar Boss4D em estação com várias IDEs

**Situação:** a estação possui mais de uma versão suportada do RAD Studio.

1. Feche todos os processos do RAD Studio.
2. Execute `Boss4D_Setup.exe`.
3. Selecione somente as IDEs detectadas que devem receber integração.
4. Finalize e execute:

```powershell
boss4d doctor
```

**Resultado esperado:** CLI/GUI instaladas, PATH atualizado e cada IDE
selecionada recebe somente seu plugin específico.

**Controles de risco:** não copie BPL de uma versão para diretório de outro BDS.
Delphi 10, 10.1, 11, 12 e 13 têm convenções distintas.

**Recuperação:** execute novamente o instalador e ajuste as IDEs ou desinstale
antes de reinstalar. `doctor` não deve apontar paths obsoletos.

## 2. Compilar e registrar um design package

**Situação:** mantenedor quer o design-time recém-compilado em uma IDE.

```powershell
boss4d build --compiler d13 --platform Win32 `
  --configuration Release --register --explain
```

**Resultado esperado:** dependências runtime compilam primeiro, BPL vem do
target exato e somente o registro Delphi 13/Win32 é alterado.

**Controles de risco:** feche a IDE antes de substituir BPL carregado. Registre
design packages em Win32 porque o processo do RAD Studio carrega packages
Win32; bibliotecas runtime ainda podem ter target Win64.

**Recuperação:** se o build falhar, o registro não inicia. Se o registro falhar,
a transação restaura valores anteriores e não persiste inventário parcial.

## 3. Atualizar package já registrado

**Situação:** novo build move caminhos de BPL/DCU/fonte.

```powershell
boss4d build --compiler d12 --platform Win32 `
  --configuration Release --force --register
boss4d doctor
```

**Resultado esperado:** registro anterior do mesmo
pacote/compilador/plataforma é removido e substituído.

**Controles de risco:** não acrescente manualmente diretórios antigos e novos à
Library Path. Mantenha identidade estável quando a operação for atualização.

**Recuperação:** execute `boss4d ide repair`; se o binário novo for inválido,
compile o commit anterior e registre aquele target.

## 4. Remover um package sem afetar outras IDEs

**Situação:** design package deve sair de uma versão Delphi.

```powershell
boss4d ide unregister ComponentDesign370 `
  --compiler d13 --platform Win32
```

**Resultado esperado:** somente BPL e paths pertencentes à entrada exata são
removidos. Outros packages, versões, plataformas e paths do usuário permanecem.

**Controles de risco:** informe nome, compilador e plataforma exatos. Evite
scripts que limpam grandes áreas do Registro.

**Recuperação:** recompile com `--register` para restaurar o target.

## 5. Reparar drift após mudança manual na IDE

**Situação:** alguém editou Library Path ou Known Packages e o Registro diverge
do inventário Boss4D.

```powershell
boss4d doctor
boss4d ide repair
boss4d doctor
```

**Resultado esperado:** `repair` reaplica apenas entradas divergentes e o
segundo diagnóstico fica limpo.

**Controles de risco:** inspecione paths antes. Inventário é fonte de estado
desejado do Boss4D; paths não relacionados são preservados.

**Recuperação:** remova a entrada exata se ela não deve mais ser gerenciada e
reaplique paths manuais intencionais.

## 6. Recuperar falha em transação de registro

**Situação:** acesso ao Registro, persistência do inventário ou alteração de
path falha durante registro.

1. Preserve a mensagem de erro.
2. Execute:

```powershell
boss4d doctor
boss4d ide repair
```

**Resultado esperado:** a operação falha já restaurou snapshots em ordem
inversa. Repair reconcilia somente inventário anteriormente confirmado.

**Controles de risco:** não escreva manualmente metade dos valores. Verifique
Known Packages, Search Path, Browsing Path e Debug DCU Path como estado único.

**Recuperação:** corrija permissão ou path inválido e repita o
`build --register` exato.

## 7. Instalar plugin de terceiro por repositório

**Situação:** extensão de IDE é distribuída como pacote Git compatível.

```powershell
boss4d plugin install github.com/user/my-plugin
boss4d doctor
```

**Resultado esperado:** repositório resolvido, plugin compilado para Delphi
ativo, copiado ao diretório Boss4D e registrado em Known Packages.

**Controles de risco:** revise publisher, revisão, scripts de build,
assinatura/proveniência antes de instalar código executado dentro da IDE.

**Recuperação:** remova registro e arquivos pelo fluxo do pacote proprietário;
não deixe Known Packages apontando para BPL ausente.

## 8. Instalar pacote oficial pelo GetIt

**Situação:** o projeto depende de pacote do catálogo Embarcadero GetIt.

```powershell
boss4d getit mode-online
boss4d getit install Jcl
boss4d doctor
```

**Resultado esperado:** `GetItCmd.exe` da instalação selecionada instala o
pacote e a IDE permanece detectável.

**Controles de risco:** GetIt altera ambiente da máquina fora do lock. Registre
pacote/versão na evidência do projeto quando for dependência de build.

**Recuperação:** use o ciclo da IDE/GetIt para remover ou reparar. Não trate
todo pacote GetIt instalado como dependência comprovada do projeto.

## 9. Colocar GetIt em modo offline corporativo

**Situação:** política proíbe acesso do GetIt à rede.

```powershell
boss4d getit mode-offline
```

Retorne somente quando aprovado:

```powershell
boss4d getit mode-online
```

**Resultado esperado:** a instalação Delphi selecionada usa o modo solicitado.

**Controles de risco:** modo é estado da máquina/IDE, não do projeto. Coordene
em máquinas de build compartilhadas.

**Recuperação:** restaure o modo anterior e execute `boss4d doctor` se operações
continuarem falhando.

## Tabela de decisão

| Necessidade | Ação |
|---|---|
| Registrar BPL de design | Target Win32 exato com `--register` |
| Substituir registro próprio | Recompilar target e registrar novamente |
| Remover um registro | `ide unregister` com pacote/compilador/plataforma |
| Corrigir drift | `doctor`, `ide repair`, `doctor` |
| Recuperar transação | Corrigir causa, reparar inventário e repetir |
| Alterar conectividade GetIt | `getit mode-online` ou `mode-offline` |

Veja [compatibilidade Delphi legada](legacy-delphi.pt-BR.md),
[contrato da matriz](build-matrix-contract.pt-BR.md) e o
[manual completo](usage.pt-BR.md).

