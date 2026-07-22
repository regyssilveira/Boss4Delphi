# Matriz de Priorização do Backlog (Pós-v1.0.1)

Este documento apresenta a matriz de priorização de novas funcionalidades e melhorias planejadas para o futuro do **Boss4D**, mapeadas com base nos melhores gerenciadores de pacotes de mercado (Cargo, npm, NuGet, Maven).

---

## 📊 Matriz de Priorização MoSCoW

| Funcionalidade / Story | Épico | Complexidade | Valor de Negócio | Prioridade (MoSCoW) |
| :--- | :--- | :--- | :--- | :--- |
| **Divisão de Dependências de Dev/Prod** (`--production`) | Épico 20 (Ciclo de Vida) | Baixa | Alto | **Must Have** (Essencial) |
| **Busca de Dependências via CLI/IDE** (`boss4d search`) | Épico 19 (Produtividade) | Baixa | Alto | **Must Have** (Essencial) |
| **Compartilhamento de Cache via Hardlinks** | Épico 17 (Performance) | Média | Alto | **Must Have** (Essencial) |
| **Registros Privados corporativos** (`boss4d registry`) | Épico 18 (Hospedagem) | Média | Alto | **Should Have** (Importante) |
| **Paralelização de Downloads e MSBuild** | Épico 17 (Performance) | Alta | Alto | **Should Have** (Importante) |
| **Inicialização com Templates** (`boss4d new <template>`) | Épico 19 (Produtividade) | Baixa | Médio | **Entregue** (`app` e `package`) |
| **Geração de Documentação de APIs** (`boss4d doc`) | Épico 20 (Ciclo de Vida) | Alta | Médio | **Should Have** (Importante) |
| **Auditoria de Segurança de Pacotes** (`boss4d audit`) | Épico 16 (Segurança) | Alta | Médio | **Should Have** (Importante) |
| **Resolução Estrita de Versões** (MVS) | Épico 20 (Ciclo de Vida) | Média | Médio | **Should Have** (Importante) |
| **Publicação Direta via CLI** (`boss4d publish`) | Épico 18 (Hospedagem) | Média | Médio | **Could Have** (Desejável) |
| **Assinatura Digital de Commits/Tags** | Épico 16 (Segurança) | Média | Médio | **Could Have** (Desejável) |
| **Notificações de Atualizações na IDE** | Épico 21 (Integração) | Baixa | Médio | **Could Have** (Desejável) |
| **Ferramentas Globais Executadas Localmente** | Épico 19 (Produtividade) | Média | Baixo | **Could Have** (Desejável) |
| **Modo Estrito Offline** (`--offline`) | Épico 17 (Performance) | Baixa | Médio | **Could Have** (Desejável) |
| **Painel Visual de Configurações na IDE** | Épico 21 (Integração) | Média | Baixo | **Won't Have** (Futuro) |

---

## 🔍 Resumo dos Critérios de Priorização:

* **Must Have (Essencial)**: Focado em produtividade diária e infraestrutura básica (separação de pacotes de testes para produção, busca rápida na IDE e economia drástica de espaço em disco na máquina de desenvolvimento com Hardlinks).
* **Should Have (Importante)**: Focado em requisitos de grandes corporações (registros internos privados de pacotes) e paralelização para grandes bases de código, além de diagnósticos de segurança e ferramentas automáticas de documentação.
* **Could Have (Desejável)**: Funcionalidades que enriquecem a experiência (notificações visuais e modo offline), mas que não impedem a adoção da ferramenta.
* **Won't Have (Futuro)**: Telas visuais de configuração na IDE que exigem esforço de UI (User Interface) e podem ser tratadas em atualizações muito posteriores.
