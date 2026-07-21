# Checklist de release SBOM

Uma release com suporte SBOM só pode ser promovida quando todos os itens abaixo
forem comprovados para o mesmo commit:

- [ ] `boss-lock.json` foi produzido por `boss4d install`, possui `root`, hash e timestamp.
- [ ] `scripts/ci-verify-sbom.ps1` passou em Win32 e Win64.
- [ ] Todos os testes DUnitX passaram nas duas arquiteturas, sem leaks.
- [ ] CycloneDX básico e com VEX passaram no CycloneDX CLI oficial.
- [ ] SPDX passou no SPDX tools-java oficial.
- [ ] SBOMs reproduzíveis e atestações são idênticos entre Win32 e Win64.
- [ ] As duas atestações foram verificadas contra os SBOMs publicados.
- [ ] `build_release.bat` terminou e promoveu `dist.new` para `dist`.
- [ ] `dist/sbom` contém CycloneDX, SPDX e suas atestações.
- [ ] Falhas de lock root, flags incompatíveis, traversal, VEX ausente e adulteração são cobertas por testes negativos.
- [ ] `git diff --check` está limpo e arquivos locais da IDE não estão no commit.
- [ ] A documentação de migração em português e inglês corresponde à CLI atual.

O workflow GitHub Actions é opcional e requer runner self-hosted Windows com Delphi
13, Docker, Java e `gh`. Na ausência do runner, a execução local completa de
`scripts/ci-verify-sbom.ps1` no commit da release é a evidência autoritativa e não
impede a promoção. Se o runner for usado, execute antes
`scripts/test-sbom-runner.ps1 -RequireDockerDaemon` com a mesma conta do serviço.
