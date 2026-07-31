# Exemplo de perfil isolado da IDE

Este roteiro usa o manifesto runtime/design de
[`../component-build-and-ide`](../component-build-and-ide/).

No diretório daquele exemplo, detecte ou compile o componente para gravar o
produto no inventário global:

```console
boss4d spec --detect --compiler d13
boss4d build --compiler d13 --platform Win32 --configuration Release
```

Crie um perfil de revisão:

```console
boss4d ide profile create Revisao-Componente --compiler d13 \
  --description "Validacao temporaria de componente"
boss4d ide profile show revisao-componente
```

Substitua `<produto>` pelo campo `name` do `boss.json` do exemplo:

```console
boss4d ide profile preview-install revisao-componente <produto>
boss4d ide profile install revisao-componente <produto> \
  --conflict fail --ide-open fail
boss4d ide profile launch revisao-componente
```

Depois da validação:

```console
boss4d ide profile preview-uninstall revisao-componente <produto>
boss4d ide profile uninstall revisao-componente <produto>
boss4d ide profile remove revisao-componente
```

O perfil não pode ser removido enquanto o produto continuar instalado. Assim,
Registry branch e inventário de propriedade permanecem consistentes.
