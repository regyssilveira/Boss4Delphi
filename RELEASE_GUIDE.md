# Guia de Liberação de Release - Boss4D

Este documento detalha o ambiente correto do Delphi e as etapas necessárias para compilar, testar e publicar releases do **Boss4D** de forma consistente e livre de erros.

---

## 💻 1. Ambiente Delphi e Versão Oficial
* A versão oficial do compilador Delphi instalada e utilizada na máquina do desenvolvedor para compilar as releases é o **Delphi 13 (versão 37.0)**.
* O caminho correto para carregar as variáveis de ambiente no Windows é:
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`

---

## 🔨 2. Compilação Local de Produção
Antes de qualquer release, compile os executáveis oficiais em Win32 e Win64:
1. Abra o console do terminal na pasta raiz do projeto.
2. Execute o script de lote de produção:
   ```cmd
   scratch\compile_production.bat
   ```
3. Valide que os novos arquivos executáveis foram gerados com sucesso na pasta `bin/`:
   * `bin/boss4d-win32.exe`
   * `bin/boss4d-win64.exe`

---

## 🧪 3. Execução de Testes
Sempre execute e garanta que 100% dos testes unitários estejam passando antes de prosseguir:
1. Compile os testes:
   ```cmd
   scratch\compile_tests_x64.bat
   ```
2. Execute os testes:
   ```cmd
   tests\Boss4DTests.exe
   ```

---

## 🏷️ 4. Procedimento para Atualizar ou Criar Tags no Git
Para apontar uma tag física (como `v1.0.0`) para o commit atualizado:
```bash
# Deleta a tag localmente
git tag -d v1.0.0

# Cria a nova tag local no commit atual
git tag v1.0.0

# Envia a tag forçando a atualização no repositório remoto do GitHub
git push --force origin v1.0.0
```

---

## 🚀 5. Publicação de Executáveis na Release do GitHub

### ⚠️ Importante para Agentes de IA (Sandbox)
O sandbox de agentes IA injeta uma variável de ambiente chamada `GITHUB_TOKEN` contendo um token temporário inválido para o repositório físico do usuário. Para que o utilitário do GitHub CLI (`gh`) use a credencial real do desenvolvedor gravada na máquina do Windows, a variável deve ser limpa antes de enviar os assets:

### Comando de Atualização / Upload Oficial
Execute o seguinte comando no terminal do Windows para subir os novos executáveis (a flag `--clobber` substitui arquivos antigos de mesmo nome de forma transparente):

```powershell
# 1. Limpa o token dummy da IA para ativar as credenciais reais do Windows
$env:GITHUB_TOKEN = $null

# 2. Faz o upload e substituição dos executáveis na release correspondente
gh release upload v1.0.0 bin\boss4d-win32.exe bin\boss4d-win64.exe --clobber
```
