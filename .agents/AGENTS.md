# Diretrizes de Desenvolvimento e Qualidade do Workspace

Você deve sempre seguir as diretivas abaixo ao trabalhar neste repositório:

## Qualidade de Código e TDD para Bugs
Todo bug encontrado ou reportado no **Boss4D** deve, obrigatoriamente, seguir a técnica de correção orientada a testes de regressão:
1. **Identificar o Bug**: Entender o cenário onde o bug ocorre.
2. **Escrever um Teste Unitário (TDD)**: Criar um caso de teste na suíte de testes correspondente (DUnitX) que simule o cenário do bug e comprove a falha (o teste deve falhar).
3. **Corrigir o Bug**: Somente após o teste ter sido registrado e validado como falho, implementar a correção lógica no código de produção.
4. **Validar a Correção**: Garantir que o teste criado (e toda a suíte de testes) agora passa com sucesso absoluto.

## Princípios de Engenharia de Software:
1. **SOLID**: Interfaces bem definidas, responsabilidade única por unidade/classe, facilidade de extensão sem alteração direta (Open/Closed),  segregação de interfaces e injeção de dependências.
2. **Clean Code**: Nomes expressivos de variáveis, funções e métodos. Funções pequenas e com uma única tarefa.
3. **DRY (Don't Repeat Yourself)**: Reutilização inteligente de rotinas comuns através de helpers e serviços utilitários bem isolados.
4. **KISS (Keep It Simple, Stupid)**: Evitar superengenharia. A simplicidade será priorizada em todas as decisões.

## Conformidade com Delphi Lint e SonarQube:
1. **Implementação sistemática de blocos try..finally** para garantir que todo recurso ou objeto criado localmente seja liberado adequadamente, evitando memory leaks.
2. **Sobrescrita correta de destrutores (destructor Destroy; override;)** chamando sempre inherited.
3. **Limitação da complexidade ciclomática de rotinas**, dividindo regras de fluxo complexas em subfunções menores.
4. **Evitar acoplamento excessivo**. Uso de injeção de dependência via construtores para facilitar a escrita de testes unitários.
5. **Nomenclatura padronizada**: Interfaces iniciando com I, classes com T, variáveis locais ou parâmetros com prefixos claros (ex: A para argumentos/parâmetros de entrada).
6. **Segurança de Tokens**: O token pessoal do SonarQube **nunca** deve ser persistido ou comitado no arquivo `sonar-project.properties` do repositório Git. Ele deve ser mantido de forma segura na pasta de rascunhos privada do agente (`scratch/sonar_credentials.json`) ou em variáveis locais.
7. **Execução de Análise do SonarQube**: Para atualizar o painel de qualidade, leia o token de `scratch/sonar_credentials.json` de forma segura e dispare o comando:
   `sonar-scanner -Dsonar.token=<token>` (ou configure a variável de ambiente correspondente).
8. **Compilação Multiplataforma (Win32 e Win64)**: Sempre valide o build e execute a suíte de testes em ambas as plataformas Win32 e Win64 usando `dcc32` e `dcc64`. Para a medição estável de cobertura de código, dê preferência à execução em Win64, pois sistemas modernos possuem restrições na camada WoW64 para hooks de depuração de processos 32-bit (o que pode retornar 0% de cobertura no x86).
9. **Inferência de Genéricos no DUnitX (Assert.AreEqual)**: Para garantir portabilidade de testes em 64-bit, explicite o tipo genérico na chamada das assertivas do DUnitX (ex: `Assert.AreEqual<string>`, `Assert.AreEqual<Integer>`), pois a inferência automática falha em assinaturas genéricas com sobrecargas de tipos no compilador Delphi x64.
10. **Tratamento de Falsos Positivos do Sonar (RTTI/SOLID)**: Silencie falsos positivos recorrentes do SonarQube (como `UnusedProperty` em DTOs/RTTI, `UnusedType` em Portas/SOLID, e `UnusedRoutine` em closures assíncronas) usando exclusões de regras multicritério (`sonar.issue.ignore.multicriteria`) no `sonar-project.properties` para manter o código-fonte limpo.
11. **Configuração do NUnit no SonarQube**: O caminho de relatórios de testes NUnit (`sonar.delphi.nunit.reportPaths`) é interpretado como um diretório no plugin de Delphi do Sonar. Aponte para a pasta e mantenha-a limpa de arquivos XML não relacionados a testes (como logs de cobertura ou metadados de DTD) para evitar falhas de análise de XML no scanner.