# Exemplo completo de componente

Este manifesto demonstra pacotes runtime/design-time, aplicação, ferramenta,
binário pré-compilado, ferramentas/templates da IDE e um valor gerenciado do
Registry por versão BDS. Substitua os caminhos ilustrativos pelos arquivos do
repositório do componente.

```console
boss4d support --compiler d13 --platform Win32 --kind design
boss4d doctor
boss4d build --compiler d13 --platform Win32 --configuration Release \
  --register --conflict fail --explain
boss4d build --compiler d13 --platform Win64 --configuration Release \
  --remote-cache X:\boss4d-cache
```

Para CI:

```console
boss4d restore --ci --remote-cache X:\boss4d-cache
```

Para recuperação:

```console
boss4d ide repair
boss4d ide uninstall acme-controls
```

O exemplo é interpretado e expandido pela suíte de testes unitários para que
seu schema não possa divergir silenciosamente.
