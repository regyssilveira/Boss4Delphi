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

## Estado atual em POSIX

O host nativo FPC 3.2.2 é compilado e testado em Linux x86-64 e macOS arm64.
Linux também possui um gate local reproduzível em Docker. A CLI POSIX
oferece inicialização do manifesto, `add`, `remove`, `list`, instalação Git,
lock schema v3, escopos runtime/desenvolvimento, modo de produção, instalações
frozen e offline, modo CI, seleção SemVer highest/minimal, descoberta Registry
v1/v2, fontes persistentes e cache offline. O mapa legado string/string de
dependências no `boss.json` possui cobertura FPCUnit.

`package install` seleciona variantes do Registry v2 por plataforma e
compilador, verifica hashes SHA-256 externos e internos, assinaturas OpenPGP
opcionais e proveniência in-toto Statement v1. A extração é transacional e a
instalação verificada é registrada no manifesto compatível e no lock v3.
O host também oferece progresso estruturado, códigos de saída estáveis,
cancelamento cooperativo por Ctrl+C e `doctor` para Git, SHA-256, GPG, FPC e
diretório home gravável.
Credenciais no Secret Service são uma integração Linux. Tokens efêmeros de CI,
mirrors Git bare, manutenção de cache e links simbólicos de workspace funcionam
nos dois hosts. SHA-256 usa `sha256sum` quando disponível e o fallback nativo
`shasum -a 256` no macOS.
Ferramentas globais FPC são compiladas e instaladas transacionalmente em
`~/.boss/bin`.

O host Windows ainda é necessário para integração RAD Studio/GetIt, GUI e
plugins da IDE. Esses limites são explícitos.

## Próximas etapas de portabilidade

1. Avaliar Linux ARM64 e publicar uma matriz de suporte por arquitetura.
2. Manter benchmarks recorrentes de cache e instalação nas plataformas
   distribuídas.

Cada nova capacidade portátil exige testes unitários e build no sistema alvo.
Linux e macOS suportam o fluxo de dependências descrito acima; Windows continua
sendo o único host para capacidades específicas do RAD Studio.
