# Guia de Contribuição - Boss4D

Obrigado pelo interesse em contribuir para o **Boss4D**! Este guia foi feito para ajudar desenvolvedores e assistentes de IA a configurar o ambiente, entender a nossa arquitetura e submeter alterações em conformidade com as regras de qualidade do repositório.

---

## 🏛️ 1. Nossa Arquitetura (Hexagonal)

O Boss4D é projetado sob os princípios de **Arquitetura Hexagonal (Ports & Adapters)**. Isso garante o desacoplamento total entre o domínio e os detalhes de infraestrutura (como rede, console, compilador e registro do Windows).

* **Core/Domain**: Contém as regras puras de negócio do SemVer, Dependências e Pacotes. **Não deve importar nenhuma unidade de infraestrutura ou adaptadores (ex: não importa System.JSON, Registry ou Git)**.
* **Core/Ports**: Define as interfaces (`IBoss4DLogger`, `IBoss4DGitClient`, etc.) que servem como contratos de comunicação.
* **Core/Services**: Casos de uso da CLI que orquestram a lógica chamando exclusivamente as interfaces (Ports) por injeção de dependências.
* **Adapters**: Implementações concretas de infraestrutura (ex: `TBoss4DHttpNativeAdapter` que implementa `IBoss4DHttpClient`).

---

## 🎨 2. Guia de Estilo de Código Delphi

Para manter a consistência do repositório, siga rigorosamente as diretrizes de estilo de código:

### Nomenclatura e Prefixos
* **Classes**: Devem iniciar com `T` (ex: `TBoss4DPackage`).
* **Interfaces**: Devem iniciar com `I` (ex: `IBoss4DLogger`).
* **Parâmetros de Métodos**: Devem iniciar com `A` (ex: `const AVersionStr: string`).
* **Variáveis Locais**: Devem iniciar com `L` (ex: `var LResolvedVersion: string`).
* **Campos Privados (Fields)**: Devem iniciar com `F` (ex: `FLogger: IBoss4DLogger`).

### Sintaxe e Formatação
* **Indentação**: 2 espaços.
* **Variáveis Inline**: Utilize declaração de variáveis inline sempre que possível no Delphi 12/13 (ex: `var LVar := LJSONObj.FindValue('name');`).
* **Clean Code**: Funções curtas e focadas. Evite acúmulo de variáveis globais.

### Tratamento e Liberação de Recursos
* **try..finally**: Sempre que criar um objeto ou recurso localmente, envolva a sua liberação em um bloco `try..finally` para evitar memory leaks:
  ```pascal
  var LPkg := TBoss4DPackage.Create;
  try
    // Lógica com o pacote
  finally
    LPkg.Free;
  end;
  ```
* **Dicionários**: Se usar `TObjectDictionary`, inicialize-o com `TMapOption.doOwnsValues` para que a liberação de chaves/valores ocorra de forma automática.

---

## 🧪 3. Ciclo de Trabalho com Bugs (TDD Obrigatório)

Para manter a base de código estável, adotamos a diretiva de **TDD para Bugs**. Se você encontrar ou for corrigir um bug:

1. **Escreva um Teste Unitário com Falha**: Antes de alterar o código de produção, adicione uma procedure de teste na suíte correspondente do **DUnitX** (sob `tests/`) que simule o bug. O teste **deve falhar** na execução inicial.
2. **Implemente a Correção**: Altere as units sob `src/` até que o teste criado passe.
3. **Valide a Suíte**: Garanta que todos os outros testes continuem passando com sucesso total e sem vazamentos de memória.

---

## 🚀 4. Como Compilar e Testar Localmente

Certifique-se de que a sua alteração compila e passa nas ferramentas locais:

### Executando os Testes via Linha de Comando (DUnitX)
Utilizando o terminal de comandos do RAD Studio:
```cmd
msbuild tests\Boss4DTests.dpr /p:Configuration=Debug
tests\Win32\Debug\Boss4DTests.exe
```

### Compilando o Executável Final
```cmd
msbuild src\Boss4D.dpr /p:Configuration=Release
```

---

## 📝 5. Submetendo Pull Requests

Ao abrir um PR, preencha o template fornecido em `.github/pull_request_template.md`. Certifique-se de marcar o checklist garantindo a conformidade do seu código com as diretrizes deste guia.
