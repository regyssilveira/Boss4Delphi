# Autoatualização segura

`boss4d self-update` consulta a release oficial mais recente no GitHub e
atualiza a instalação Windows pelo instalador Inno Setup publicado.

O comando não confia somente na origem do download. Ele baixa
`Boss4D_Setup.exe` e `SHA256SUMS.txt`, calcula o SHA-256 sobre os bytes exatos
do instalador e só o inicia quando o resumo confere. Artefato ausente, resposta
inválida, falha no download ou divergência de checksum interrompem a operação.
Um instalador rejeitado é removido da área temporária.

```text
boss4d self-update
```

Se a versão semântica instalada já for a atual, nenhum artefato é baixado ou
executado. O instalador verificado é iniciado silenciosamente e sem reinício
automático. A substituição transacional e o rollback continuam sob
responsabilidade do instalador Inno Setup existente.

Somente artefatos retornados pela API da release oficial mais recente são
aceitos. A verificação de integridade detecta corrupção ou substituição após a
publicação; o pipeline de release continua responsável por proteger e publicar
o manifesto de checksums.
