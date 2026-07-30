# Posicionamento competitivo — 30 de julho de 2026

Esta análise compara comportamento entregue e testado. Adoção e escala do
registro são avaliadas separadamente da quantidade de comandos.

| Capacidade | Boss4D | BOSS | DPM | GetIt | Classe Cargo/npm/Composer |
|---|---|---|---|---|---|
| Dependências Delphi | CLI, GUI e IDE completas | CLI e complemento de IDE | Pacotes e IDE completos | Instalação por catálogo | Não específico para Delphi |
| Lazarus/FPC/Linux | CLI e release nativas em FPC 3.2.2 | Fluxo Delphi/Lazarus consolidado | Foco Delphi/Windows | Não | Nativo em cada ecossistema |
| CLI cotidiana | Install, update, tree, why, outdated, run e ferramentas globais | Install, update, dependencies, run e global | Create/push/install/restore no estilo NuGet | Orientado à IDE | Ampla e madura |
| Descoberta pública | Registry v2 Git com 55 entradas legadas e pacotes sparse | Atalhos de repositório/nome | Fonte hospedada `delphi.dev` | Catálogo do fornecedor | Grandes registros hospedados |
| Protocolo do Registry | Composição v1/v2, sparse, validadores HTTP, mirrors e revogação | Resolução orientada a Git | Múltiplas fontes locais/hospedadas | Controlado pelo fornecedor | APIs sparse/index e CDNs |
| Reprodutibilidade | Lock v3, frozen/locked/offline e CI | SemVer e cache | Restore por pacote/versão | Estado da IDE | Locks e modos offline/vendor maduros |
| Distribuição imutável | `.b4dpkg`, SHA-256, OpenPGP, in-toto e instalação transacional | Principalmente checkout Git | Pacotes hospedados e assinados | Pacotes hospedados | Arquivos imutáveis e checksums |
| Política de publicação | Dry-run, gates, token seguro, versões imutáveis e publishers revisados | Sem fluxo público equivalente documentado | Fonte central e push de pacotes | Submissão ao fornecedor | Publicação autenticada madura |
| Evidência de supply chain | CycloneDX, SPDX, VEX, OSV, in-toto e OpenPGP | Sem fluxo SBOM/audit documentado | SBOM e assinatura de autor/repositório | Controlado pelo fornecedor | Varia, geralmente maduro |
| Matriz compilador/plataforma | Plugins Delphi 10.1/11/12/13; Win32/Win64; Linux x86_64/FPC | Seleção de compilador/plataforma | Delphi XE2–13 e targets suportados | Releases atuais | Mecanismos ricos de target |
| Autoatualização | Atualização verificada e transacional no Windows/Linux | `upgrade`, inclusive pré-release | Entrega por instalador/pacote | Entrega pelo RAD Studio | Madura por toolchain |
| Progresso/automação | Plain, interativo, JSON, quiet, cancelamento e exit codes estáveis | Progresso interativo por dependência | Saída CLI convencional | UI da IDE | Automação madura e legível por máquina |

## Conclusão

Nos critérios trabalhados pelo projeto, o Boss4D atinge paridade técnica com o
BOSS e o supera em reprodutibilidade, artefatos imutáveis, política de Registry,
evidências de conformidade, automação estruturada e releases verificadas. O
BOSS continua sendo referência de CLI compacta e possui adoção histórica maior.

O DPM permanece à frente em duas dimensões de ecossistema: serviço central
hospedado em operação e suporte desde o Delphi XE2. Ele também possui assinatura
de pacotes e geração de SBOM; portanto, esses recursos não devem ser apresentados
como exclusivos do Boss4D. O Boss4D diferencia-se por VEX/auditoria OSV, dois
formatos SBOM, proveniência in-toto, escopo revisado de signatários, governança
Git do Registry e CLI Linux nativa.

O GetIt mantém a posição nativa no RAD Studio. Cargo, npm e Composer continuam
muito à frente em população de pacotes, escala de CDN, histórico do resolvedor,
ferramental de terceiros e operação de infraestrutura.

## Evidências neste repositório

- DUnitX Delphi 13: 143 testes em Win32 e 143 em Win64.
- FPC 3.2.2/Linux x86_64: 61 testes FPCUnit e smoke tests reais da CLI.
- Builds reais do plugin: Delphi 10.1, 11, 12 e 13.
- Arquivos de release Windows/Linux com SHA-256 e proveniência OIDC do GitHub.
- Checks de submissão: escopo do publisher, fingerprint OpenPGP, versões
  imutáveis, assinatura e proveniência.
- Quality gate do Sonar obrigatório com zero issues abertas.

## Trabalho restante de ecossistema

Estes itens aumentam escala e alcance; não são lacunas da paridade técnica
definida:

1. Popular o Registry sparse com releases `.b4dpkg` assinadas pelos mantenedores.
2. Adicionar frontend hospedado de leitura/busca e CDN, mantendo Git revisado
   como fonte autoritativa.
3. Adicionar release nativa para macOS e ampliar variantes mantidas.
4. Publicar benchmarks recorrentes de resolução e cache frio/quente.
5. Adicionar opcionalmente transparência/Sigstore junto ao OpenPGP.

## Fontes

- [Repositório e CLI atual do BOSS](https://github.com/HashLoad/boss)
- [Repositório e capacidades atuais do DPM](https://github.com/DelphiPackageManager/DPM)
- [Documentação do DPM](https://docs.delphi.dev/)
- [Documentação do GetIt](https://docwiki.embarcadero.com/RADStudio/en/GetIt_Package_Manager_Window)
- [Registries do Cargo](https://doc.rust-lang.org/cargo/reference/registries.html)
- [Índice sparse e cache do Cargo](https://doc.rust-lang.org/cargo/reference/registry-index.html)
- [Repositórios do Composer](https://getcomposer.org/doc/05-repositories.md)
