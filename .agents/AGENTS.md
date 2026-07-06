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
9. **Inferência de Genéricos no DUnitX (Assert.AreEqual)**: Para garantir portabilidade de testes in 64-bit, explicite o tipo genérico na chamada das assertivas do DUnitX (ex: `Assert.AreEqual<string>`, `Assert.AreEqual<Integer>`), pois a inferência automática falha em assinaturas genéricas com sobrecargas de tipos no compilador Delphi x64.
10. **Tratamento de Falsos Positivos do Sonar (RTTI/SOLID)**: Silencie falsos positivos recorrentes do SonarQube (como `UnusedProperty` em DTOs/RTTI, `UnusedType` em Portas/SOLID, e `UnusedRoutine` em closures assíncronas) usando exclusões de regras multicritério (`sonar.issue.ignore.multicriteria`) no `sonar-project.properties` para manter o código-fonte limpo.
11. **Configuração do NUnit no SonarQube**: O caminho de relatórios de testes NUnit (`sonar.delphi.nunit.reportPaths`) é interpretado como um diretório no plugin de Delphi do Sonar. Aponte para a pasta e mantenha-a limpa de arquivos XML não relacionados a testes (como logs de cobertura ou metadados de DTD) para evitar falhas de análise de XML no scanner.
12. **Compilação e Lote (Batch/CMD)**: Ao escrever scripts `.bat` ou `.cmd` para o Windows que executem o compilador Delphi (`dcc32` / `dcc64`), sempre preceda as invocações com o comando `call` (ex: `call dcc32 ...`). Caso contrário, o interpretador de lote do Windows encerrará a execução imediatamente após a execução do primeiro compilador, impedindo comandos e renomeações subsequentes.
13. **Publicação de Versões e Executáveis (Releases)**: Quando uma nova tag de versão for liberada e os executáveis precisarem ser gerados para download direto dos usuários no GitHub, utilize a ferramenta GitHub CLI (`gh`) localmente para publicar a release e fazer o upload dos binários Win32 e Win64 (usando `gh release create <tag> <arquivos>`) caso o runner remoto do GitHub Actions não esteja disponível ou seja self-hosted.

## Conformidade Estrita com DelphiSonar (Regras do SonarQube)

Ao escrever ou modificar código Delphi neste repositório, você deve seguir estritamente as regras de análise estática do DelphiSonar para garantir Confiabilidade e Manutenibilidade máximas:

### 1. Confiabilidade (Prevenção de Bugs)
*   **Construtores e Destrutores**:
    *   Todo construtor deve invocar `inherited;` (ou `inherited Create;`) na primeira linha ou onde for adequado (`ConstructorWithoutInherited`).
    *   Todo destrutor deve ser declarado com `override;` e invocar `inherited;` (ou `inherited Destroy;`) como sua última instrução (`DestructorWithoutInherited`).
    *   Destrutores de classes personalizadas devem sempre sobrescrever `TObject.Destroy` em vez de criar nomes customizados (`DestructorName`).
*   **Retorno de Métodos (Functions)**:
    *   Toda função deve obrigatoriamente ter um valor atribuído a `Result` (`RoutineResultAssigned`).
*   **Inicialização e Liberação de Objetos**:
    *   Variáveis locais devem ser declaradas e inicializadas antes do uso para prevenir valores indefinidos em memória (`VariableInitialization`).
    *   `FreeAndNil` deve ser utilizado exclusivamente com instâncias descendentes de `TObject` (`FreeAndNilTObject`).
    *   Ao utilizar a propriedade `Duplicates` de um `TStringList`, certifique-se de que o objeto está ordenado (`Sorted := True`) para evitar comportamento indefinido (`StringListDuplicates`).

### 2. Manutenibilidade e Estilo de Código (Code Smells)
*   **Validação de Ponteiros/Objetos**:
    *   Sempre utilize a função nativa `System.Assigned(LObj)` ou `not System.Assigned(LObj)` para checagem de ponteiros em vez de comparar diretamente com `nil` (`NilComparison`).
*   **Liberação de Recursos**:
    *   Não utilize checagens redundantes de atribuição antes de liberar objetos. Use simplesmente `LObj.Free;` em vez de `if Assigned(LObj) then LObj.Free;` (`AssignedAndFree`).
*   **Espaços em Branco**:
    *   Nenhum arquivo ou linha de código deve conter espaços em branco no final (Trailing Whitespace) (`TrailingWhitespace`).
*   **Seções de Visibilidade**:
    *   As diretivas de visibilidade em classes devem seguir a ordem ascendente de acessibilidade: `private`, `protected`, `public`, `published` (`VisibilitySectionOrder`).
    *   Seções de visibilidade que estejam vazias ou redundantes devem ser removidas (`EmptyVisibilitySection`).
    *   Seções de visibilidade consecutivas de mesmo nível devem ser combinadas (`ConsecutiveVisibilitySection`).
*   **Consistência de Nomenclatura**:
    *   Mantenha a capitalização de nomes (variáveis, classes, propriedades) estritamente consistente com a declaração original (`MixedNames`). Ex: use `MainFormOnTaskBar` e não `MainFormOnTaskbar`.
*   **Construção com 'with'**:
    *   Nunca utilize a instrução `with` para acessar membros de objetos, pois isso prejudica a legibilidade e induz a erros silenciosos de escopo (`WithStatement`).

### 3. Gerenciamento de Falsos Positivos e Métricas
*   **Imports de Interface vs. Implementation (`ImportSpecificity`)**:
    *   Regra geral: Mova as units importadas na cláusula `uses` da interface para a cláusula `uses` da implementação sempre que possível.
    *   *Exceção (Falso Positivo)*: Se a unit for necessária para declarar tipos de campos privados, propriedades ou parâmetros da interface, o import deve permanecer na seção `interface`. Nesse caso, a regra deve ser silenciada via configuração do projeto.
*   **Variáveis Inline (`UnusedLocalVariable` / `UnusedImport`)**:
    *   O parser do Sonar para Delphi possui limitações ao rastrear variáveis declaradas de forma inline (`var LVar := ...`) introduzidas no Delphi Rio, frequentemente acusando falsos positivos. Em caso de alertas incorretos de variáveis não utilizadas na linha seguinte, mova a declaração para a seção `var` tradicional da rotina.
*   **Configuração de Supressões no `sonar-project.properties`**:
    *   Falsos positivos frequentes de `ImportSpecificity`, `UnusedLocalVariable` e `UnusedRoutine` sob Conditional Compilations, bem como métricas de estilo puras como `TooLongLine`, `CognitiveComplexityRoutine` e `CyclomaticComplexityRoutine` devem ser silenciadas via `sonar.issue.ignore.multicriteria` no `sonar-project.properties`.
    *   Boilerplate de telas (GUI) e stubs de wizards devem ser excluídos da verificação de duplicidade de código via `sonar.cpd.exclusions` para manter a densidade do CPD abaixo do limite do Quality Gate (3.0%).