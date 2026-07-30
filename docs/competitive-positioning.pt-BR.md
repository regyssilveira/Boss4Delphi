# Posicionamento competitivo — julho de 2026

Esta análise compara capacidades entregues, não promessas de roadmap.

| Capacidade | Boss4D | BOSS | DPM | GetIt | Classe Cargo/npm/Composer |
|---|---|---|---|---|---|
| Dependências de fontes Delphi | Forte | Forte | Forte | Orientado a catálogo | Não específico para Delphi |
| Lazarus/FPC | Fluxo Linux nativo, paridade parcial | Suporte consolidado | Foco em Delphi | Não | Específico de cada ecossistema |
| Descoberta pública | Registry v2 em Git, catálogo com 55 entradas | Atalhos nome/repositório | Fonte hospedada padrão | Catálogo oficial RAD Studio | Grandes registros hospedados |
| Reprodutibilidade | Lock v3, frozen/offline/CI | SemVer e cache | Modelo pacote/versão | Estado de instalação da IDE | Lock/offline/vendor maduros |
| Distribuição imutável | `.b4dpkg` verificado com fallback para fontes | Principalmente fontes Git | Pacotes hospedados | Pacotes hospedados | Arquivos de pacote maduros |
| Evidência de supply chain | CycloneDX, SPDX, VEX, OSV, in-toto e OpenPGP | Não é o foco central | Assinatura de pacotes | Controlado pelo fornecedor | Varia por ecossistema |
| Variantes compilador/plataforma | Seleção determinística no Registry v2 | Flags no install | Consumo orientado a projeto/plataforma | Catálogo por release RAD Studio | Mecanismos variam |
| Experiência de IDE | CLI, GUI VCL e plugins RAD Studio | CLI e complemento de IDE | CLI e integração com IDE | Embutido no RAD Studio | Geralmente independente do editor |

## Onde o Boss4D se diferencia

O Boss4D combina dependências Delphi/Lazarus com uma cadeia de evidências de
conformidade incomum neste ecossistema: artefatos imutáveis, digests externos e
internos, OpenPGP, in-toto, CycloneDX/SPDX, VEX, auditoria OSV, dependency
submission e geração estrita de release apenas pelo lock. O Registry v2 pode
ser mantido em Git, compor índices v1/v2 e distribuir artefatos específicos por
compilador/plataforma sem alterar o `boss.json` legado.

O projeto também valida builds reais de plugins para Delphi 10.1/11/12/13,
testes Win32 e Win64, build nativo FPC/Linux, empacotamento determinístico e
instalador completo.

## Onde os concorrentes continuam à frente

- O BOSS possui base instalada maior e uma experiência de CLI portátil mais
  madura. Sua CLI documenta progresso, autoatualização, instalação global,
  seleção entre Git embutido/nativo e flags de compilador/plataforma.
- O DPM possui fonte de pacotes hospedada por padrão e fluxo convencional de
  publicação, reduzindo o esforço para descobrir e distribuir pacotes.
- O GetIt tem presença nativa no RAD Studio e catálogo mantido pelo fornecedor.
- Cargo, npm e Composer possuem escala de registro, mirrors/CDNs, protocolos
  incrementais de metadados, políticas maduras de publicação e amplo ferramental.

## Próximos trabalhos de maior valor

1. Alimentar o Registry v2 com releases `.b4dpkg` reais e assinadas; hoje a
   maioria das entradas ainda aponta para repositórios Git.
2. Levar Registry v2, artefatos verificados, SBOM lock-only, auditoria, progresso
   e credenciais ao host Linux/FPC.
3. Adicionar metadados sparse por pacote, validação de cache HTTP, mirrors,
   revogação e retirada controlada de versões.
4. Automatizar onboarding de publicadores e atualização de metadados assinados
   por pull requests revisados.
5. Adicionar macOS e ampliar a matriz de artefatos compilador/plataforma com
   pacotes gerados por seus mantenedores.

## Fontes

- [Repositório e CLI do BOSS](https://github.com/HashLoad/boss)
- [Documentação do DPM](https://docs.delphi.dev/)
- [Fontes de pacotes do DPM](https://docs.delphi.dev/concepts/package-sources.html)
- [Visão geral do GetIt](https://tp.embarcadero.com/overview/)
- [Código do Online Package Manager do Lazarus](https://gitlab.com/freepascal.org/lazarus/lazarus/-/tree/main/components/onlinepackagemanager)
- [Registros do Cargo](https://doc.rust-lang.org/cargo/reference/registries.html)
- [Índice de registro do Cargo](https://doc.rust-lang.org/cargo/reference/registry-index.html)
- [Repositórios do Composer](https://getcomposer.org/doc/05-repositories.md)

