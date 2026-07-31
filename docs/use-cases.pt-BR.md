# Casos de uso do Boss4D

Este guia começa pela tarefa que você precisa realizar e aponta o fluxo mais
seguro. Ele complementa o [manual completo de comandos](usage.pt-BR.md), que
continua sendo a referência autoritativa da CLI.

## Como usar estes guias

Cada caso de uso segue a mesma estrutura:

1. **Situação** — quando o fluxo se aplica.
2. **Antes de começar** — arquivos, ferramentas e acessos necessários.
3. **Fluxo** — a menor sequência segura de comandos.
4. **Resultado esperado** — evidência que comprova o sucesso.
5. **Controles de risco** — decisões que protegem reprodutibilidade,
   credenciais, estado da IDE ou pacotes publicados.
6. **Recuperação** — como diagnosticar e desfazer uma falha parcial.

Os comandos partem da raiz do projeto, exceto quando indicado. Versione
`boss.json` e `boss-lock.json`; não versione credenciais, árvores de build ou
estado da IDE específico da máquina.

## Escolha sua situação

| Área | Situação cotidiana | Sensibilidade | Guia |
|---|---|---|---|
| Ciclo do projeto | Iniciar projeto, adicionar/atualizar/remover dependências, reproduzir restore, investigar o grafo e recuperar cache ou lock | Uma mudança no lock afeta builds de toda a equipe e da CI | [Fluxos de projeto e dependências](use-cases-project-lifecycle.pt-BR.md) |
| Registry e credenciais | Selecionar fontes públicas/privadas, autenticar, trabalhar offline, verificar pacotes e publicar versões imutáveis | Segredos e fronteiras de confiança da cadeia de suprimentos | [Registry, credenciais e publicação](use-cases-registry-security.pt-BR.md) |
| Conformidade e auditoria | Gerar CycloneDX/SPDX, publicar VEX, aplicar política de vulnerabilidade e criar atestações | Evidências precisam ser completas e reproduzíveis | [Fluxos de conformidade e auditoria](use-cases-compliance.pt-BR.md) |
| Build Multi-Delphi | Detectar packages, selecionar compilador/plataforma/configuração e usar incremental/paralelismo | Identidade incorreta pode misturar DCUs/BPLs incompatíveis | Planejado para a fase 5 |
| Ciclo da IDE | Instalar, registrar, atualizar, remover, reparar e recuperar falha de design package | Registro e Library Path afetam a IDE globalmente | Planejado para a fase 6 |
| Linux e automação | Executar FPC/Linux, CI, empacotamento de release, autoatualização e rollback | Automação deve ser determinística e não interativa | Planejado para a fase 7 |

## Níveis de segurança

- **Rotineiro** — local e reversível; ainda exige conferência do resultado.
- **Repositório inteiro** — altera manifest ou lock compartilhado pela equipe.
- **Máquina inteira** — altera cache, ferramentas globais, PATH ou registro da
  IDE.
- **Externo/imutável** — publica metadados ou artefatos que não podem ser
  sobrescritos.

Para operações no repositório ou externas, revise o diff antes do commit. Para
operações na máquina, execute `boss4d doctor` antes e depois. Para publicação
imutável, faça dry run e preserve as evidências geradas.

## Referências relacionadas

- [Manual completo](usage.pt-BR.md)
- [Ciclo de dependências](dependency-lifecycle.pt-BR.md)
- [Instalação reproduzível](reproducible-install.pt-BR.md)
- [Contrato da matriz de build](build-matrix-contract.pt-BR.md)
- [Política de confiança](trust-policy.pt-BR.md)
- [Guia de SBOM](sbom.pt-BR.md)
- [Publicação de pacotes](publish.pt-BR.md)
