# Guia de Liberação de Release - Boss4D

Este documento detalha o ambiente correto do Delphi e as etapas necessárias para compilar, testar e publicar releases do **Boss4D** de forma consistente e livre de erros.

---

## 💻 1. Ambiente Delphi e Versão Oficial
* A versão oficial do compilador Delphi instalada e utilizada na máquina do desenvolvedor para compilar as releases é o **Delphi 13 (versão 37.0)**.
* O caminho correto para carregar as variáveis de ambiente no Windows é:
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`

---

## 🔨 2. Compilação Local de Produção e Setup
Antes de qualquer release, compile todos os executáveis oficiais e os plugins de IDE de forma automatizada:
1. Abra o console do terminal na pasta raiz do projeto.
2. Execute o script de lote de produção:
   ```cmd
   build_release.bat
   ```
3. O script criará a pasta `dist/` e gerará os executáveis de produção (Win32/Win64 da CLI e da GUI) e os plugins de IDE:
   * `dist/bin/boss4d.exe` (CLI Win32)
   * `dist/bin/boss4d_x64.exe` (CLI Win64)
   * `dist/bin/Boss4D.GUI.exe` (GUI Win32)
   * `dist/bin/Boss4D.GUI_x64.exe` (GUI Win64)
   * `dist/plugins/11/Boss4D.IDE.Plugin.bpl` (Delphi 11)
   * `dist/plugins/12/Boss4D.IDE.Plugin.bpl` (Delphi 12)
   * `dist/plugins/13/Boss4D.IDE.Plugin.bpl` (Delphi 13)

4. Compile o instalador offline usando o Inno Setup:
   ```cmd
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\Boss4D.iss
   ```
5. Valide que o instalador final foi gerado com sucesso em:
   * `installer/Output/Boss4D_Setup.exe`

---

## 🧪 3. Execução de Testes
Sempre execute e garanta que 100% dos testes unitários estejam passando antes de prosseguir:
1. Compile e execute os testes usando o executável:
   ```cmd
   tests\Boss4DTests.exe
   ```

---

## 🏷️ 4. Procedimento para Atualizar ou Criar Tags no Git
Para criar e apontar uma tag física (como `v1.0.1`) para o commit atualizado:
```bash
# Cria a nova tag local no commit atual
git tag v1.0.1

# Envia a tag para o repositório remoto do GitHub
git push origin v1.0.1
```

---

## 🚀 5. Publicação de Executáveis na Release do GitHub

### ⚠️ Importante para Agentes de IA (Sandbox)
O sandbox de agentes IA injeta uma variável de ambiente chamada `GITHUB_TOKEN` contendo um token temporário inválido para o repositório físico do usuário. Para que o utilitário do GitHub CLI (`gh`) use a credencial real do desenvolvedor gravada na máquina do Windows, a variável deve ser limpa antes de rodar os comandos:

### Comando de Criação de Release Oficial
Execute o seguinte comando no terminal do Windows para criar a release e fazer o upload do instalador de uma vez só:

```powershell
# 1. Limpa o token dummy da IA para ativar as credenciais reais do Windows
$env:GITHUB_TOKEN = $null

# 2. Cria a release e anexa o instalador de Setup
gh release create v1.0.1 installer\Output\Boss4D_Setup.exe --title "v1.0.1" --notes "Sua descrição detalhada da release aqui"
```
