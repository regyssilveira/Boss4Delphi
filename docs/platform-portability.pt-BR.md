# Portabilidade de plataforma

O Boss4D separa as regras portáveis de gerenciamento de pacotes das integrações
do sistema operacional hospedeiro. Os serviços do Core consomem três contratos:

- `IBoss4DProcessRunner` executa comandos e captura o resultado;
- `IBoss4DPlatformEnvironment` expõe diretórios home/atual, tratamento de
  arquivos somente leitura e capacidades do host;
- `IBoss4DFileLinkService` cria e remove links de diretório dos workspaces.

A CLI e a GUI Windows configuram implementações Windows durante a
inicialização. Esses adaptadores mantêm `CreateProcess`, atributos de arquivos,
junctions, descoberta do RAD Studio no Registro, MSBuild e GetIt fora do domínio
portável.

## Limites de capacidade

Comandos portáveis não podem presumir a existência de RAD Studio, GetIt,
Registro do Windows ou `cmd.exe`. Comandos específicos consultam as capacidades
e retornam erro explícito quando a plataforma não é suportada. A GUI VCL e o
plugin do RAD Studio permanecem produtos Windows; a aplicação de linha de
comando é o alvo da portabilidade.

## Estado atual no Linux

O host nativo FPC 3.2.2 para Linux x86-64 é compilado e testado em Docker. Ele
oferece inicialização do manifesto, `add`, `remove`, `list`, instalação Git,
lock schema v3, escopos runtime/desenvolvimento, modo de produção, instalações
frozen e offline, modo CI e seleção SemVer highest/minimal. O mapa legado
string/string de dependências no `boss.json` possui cobertura FPCUnit.

O host Windows ainda é necessário para descoberta no Registry v2, instalação
verificada de `.b4dpkg`, comandos SBOM/audit, OpenPGP, armazenamento de
credenciais, integração RAD Studio/GetIt, GUI, plugins da IDE e autoatualização.
Esses limites são explícitos e não são simulados silenciosamente.

## Próximas etapas de portabilidade

1. Compartilhar com o host FPC o leitor do Registry v2 e de pacotes verificados.
2. Portar geração SBOM lock-only, auditoria OSV e progresso estruturado.
3. Adicionar adaptadores POSIX de credenciais, links de workspace e cache de
   artefatos.
4. Adicionar builds macOS após os contratos Linux atingirem paridade funcional.

Cada nova capacidade portável exige testes unitários e build no sistema alvo.
Hoje o Linux é suportado para o fluxo de dependências listado acima; a paridade
completa entre hosts ainda está em evolução.
