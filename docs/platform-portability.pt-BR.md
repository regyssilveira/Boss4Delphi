# Portabilidade de plataforma

O Boss4D separa as regras portáveis de gerenciamento de pacotes das integrações
do sistema operacional hospedeiro. Os serviços do Core consomem três contratos:

- `IBoss4DProcessRunner` executa comandos e captura seu resultado;
- `IBoss4DPlatformEnvironment` expõe diretórios, tratamento de arquivos e
  capacidades do host;
- `IBoss4DFileLinkService` cria e remove links de diretórios dos workspaces.

A CLI e a GUI Windows mantêm `CreateProcess`, atributos de arquivos, junctions,
descoberta do RAD Studio no Registro, MSBuild e GetIt fora do domínio portátil.

## Limites de capacidade

Comandos portáveis não presumem a existência de RAD Studio, GetIt, Registro do
Windows ou `cmd.exe`. Comandos específicos consultam capacidades e retornam erro
explícito quando a plataforma não é suportada. A GUI VCL e o plugin do RAD
Studio permanecem produtos Windows; a CLI é o alvo da portabilidade.

## Estado atual no Linux

O host nativo FPC 3.2.2 para Linux x86-64 é compilado e testado em Docker. Ele
oferece inicialização do manifesto, `add`, `remove`, `list`, instalação Git,
lock schema v3, escopos runtime/desenvolvimento, modo de produção, instalações
frozen e offline, modo CI, seleção SemVer highest/minimal, descoberta Registry
v1/v2, fontes persistentes e cache offline. O mapa legado string/string de
dependências no `boss.json` possui cobertura FPCUnit.

`package install` seleciona variantes do Registry v2 por plataforma e
compilador, verifica hashes SHA-256 externos e internos, assinaturas OpenPGP
opcionais e proveniência in-toto Statement v1. A extração é transacional e a
instalação verificada é registrada no manifesto compatível e no lock v3.

O host Windows ainda é necessário para comandos SBOM/audit, armazenamento de
credenciais, integração RAD Studio/GetIt, GUI, plugins da IDE e
autoatualização. Esses limites são explícitos.

## Próximas etapas de portabilidade

1. Portar geração SBOM lock-only, auditoria OSV e progresso estruturado.
2. Adicionar adaptadores POSIX de credenciais, links de workspace e cache de
   artefatos.
3. Adicionar builds macOS após os contratos Linux atingirem paridade funcional.

Cada nova capacidade portátil exige testes unitários e build no sistema alvo.
