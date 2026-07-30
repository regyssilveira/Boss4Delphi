# Compatibilidade com Delphi legado

O Boss4D distribui dois perfis de integração com a IDE:

- Delphi 11, 12 e 13 recebem o wizard completo.
- Delphi 10.1 Berlin recebe um wizard legado compacto, compilado sem variáveis
  inline ou premissas de RTL mais recente.

O plug-in legado preserva a descoberta do pacote e um ponto estável de
integração, direcionando as operações de dependência ao mesmo `boss4d.exe`.
Ele tem como alvo o compilador BDS 18.0 na matriz de release e é publicado em
`dist/plugins/10.1`.

```text
dist/plugins/10.1/Boss4D.IDE.Plugin.bpl
dist/plugins/11/Boss4D.IDE.Plugin.bpl
dist/plugins/12/Boss4D.IDE.Plugin.bpl
dist/plugins/13/Boss4D.IDE.Plugin.bpl
```

O CLI continua sendo produzido pelo compilador atual da release, pois
resolução, SBOM, HTTP e criptografia dependem de APIs modernas da RTL. Projetos
gerenciados pelo CLI ainda podem selecionar toolchains Delphi antigas por
`toolchain.compiler`.
