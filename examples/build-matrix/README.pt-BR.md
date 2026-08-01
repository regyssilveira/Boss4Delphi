# Exemplo de matriz Multi-Delphi

O `boss.json` adjacente declara pacotes runtime e design-time para Delphi 10,
10.1, 11, 12 e 13. Após aplicar as restrições do pacote design, ele expande
para 23 targets compatíveis.

O pacote design também declara uma dependência opcional e condicional em
`dependencies`. Targets opcionais não distribuídos são ignorados; quando
presentes, participam da ordenação somente nos valores correspondentes de
compilador, plataforma e configuração.

Em um repositório real, adapte os caminhos dos projetos e execute:

```console
boss4d spec --detect
boss4d build --compiler d13 --platform Win64 --configuration Release --explain
boss4d build --compiler all --platform Win32 --configuration Release --jobs 4
boss4d build --full
boss4d build --compiler d13 --platform Win32 --configuration Release --register
boss4d doctor
```

`--full` seleciona todos os eixos e força a recompilação. `--force` recompila
somente os targets selecionados. `--register` registra as BPLs design-time no
par exato de compilador e plataforma que as produziu.

Para remover ou reparar registros:

```console
boss4d ide unregister ComponentDesign370 --compiler d13 --platform Win32
boss4d ide repair
```

Manifestos legados não precisam dessa seção e continuam usando os valores
existentes de `projects`, `toolchain` e `engines`.
