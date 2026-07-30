# Portabilidade de plataforma

O Boss4D separa as regras portáveis de gerenciamento de pacotes das integrações
do sistema operacional hospedeiro. Os serviços do Core consomem três contratos:

- `IBoss4DProcessRunner` executa comandos e captura seu resultado;
- `IBoss4DPlatformEnvironment` expõe diretórios home/atual, tratamento de
  arquivos somente leitura e capacidades do host;
- `IBoss4DFileLinkService` cria e remove links de diretório dos workspaces.

A CLI e a GUI Windows configuram as implementações Windows durante a
inicialização. Esses adaptadores mantêm `CreateProcess`, atributos de arquivos,
junctions, descoberta do RAD Studio no Registro, MSBuild e GetIt fora do domínio
portável.

## Limites de capacidade

Comandos portáveis não podem presumir a existência de RAD Studio, GetIt,
Registro do Windows ou `cmd.exe`. Comandos específicos consultarão as
capacidades e retornarão um erro explícito quando a plataforma não for
suportada. A GUI VCL e o plugin do RAD Studio permanecem produtos Windows; a
aplicação de linha de comando é o alvo da portabilidade.

## Roadmap

1. Mover as execuções e operações de filesystem restantes para esses contratos.
2. Adicionar renderizadores de progresso plain, interativo, JSON e quiet sobre
   um modelo portável de eventos.
3. Adicionar adaptadores POSIX de processos, ambiente, links, console e
   credenciais.
4. Validar a CLI portável no Linux64 e, depois, no macOS.

Toda implementação de plataforma exige testes de contrato. Uma plataforma só é
considerada suportada depois que build da CLI, testes unitários, fluxo de lock,
registry, auditoria e validação de SBOM passarem na CI.
