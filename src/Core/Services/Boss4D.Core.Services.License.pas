unit Boss4D.Core.Services.License;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico de caso de uso para auditoria e relatorios de conformidade de licencas }
  TBoss4DLicenseService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLogger: IBoss4DLogger;
    function DetectLicenseFromFile(const ADirPath: string): string;
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
    procedure GenerateReport;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Sbom, Boss4D.Core.Domain.License;

{ TBoss4DLicenseService }

constructor TBoss4DLicenseService.Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLogger := ALogger;
end;

function TBoss4DLicenseService.DetectLicenseFromFile(const ADirPath: string): string;
var
  LFiles: TArray<string>;
  LFirstLine: string;
  LReader: TStreamReader;
begin
  Result := '';
  if not TDirectory.Exists(ADirPath) then
    Exit;

  // Busca arquivos com nomes comuns de licenca no diretorio
  LFiles := TDirectory.GetFiles(ADirPath, '*LICENSE*', TSearchOption.soTopDirectoryOnly);
  if Length(LFiles) = 0 then
    LFiles := TDirectory.GetFiles(ADirPath, '*COPYING*', TSearchOption.soTopDirectoryOnly);

  if Length(LFiles) > 0 then
  begin
    try
      LReader := TStreamReader.Create(LFiles[0], TEncoding.UTF8);
      try
        if not LReader.EndOfStream then
        begin
          LFirstLine := LReader.ReadLine.Trim;
          if LFirstLine.IsEmpty and not LReader.EndOfStream then
            LFirstLine := LReader.ReadLine.Trim; // Tenta a proxima linha caso a primeira seja em branco

          if not LFirstLine.IsEmpty then
          begin
            if LFirstLine.Contains('MIT') then
              Result := 'MIT'
            else if LFirstLine.Contains('Apache') then
              Result := 'Apache-2.0'
            else if LFirstLine.Contains('GNU') or LFirstLine.Contains('GPL') then
              Result := 'GPL'
            else if LFirstLine.Contains('BSD') then
              Result := 'BSD'
            else
              Result := LFirstLine; // Retorna a primeira linha do arquivo
          end;
        end;
      finally
        LReader.Free;
      end;
    except
      on E: Exception do
        FLogger.Log(TBoss4DLogLevel.Warning, 'Falha silenciosa ao ler arquivo de licenca: ' + E.Message);
    end;
  end;

  if Result.IsEmpty then
    Result := 'Nao especificada';
end;

procedure TBoss4DLicenseService.GenerateReport;
var
  LMainPkg: TBoss4DPackage;
  LModulesDir: string;
  LSubDirs: TArray<string>;
  LMarkdownReport: string;
  LCSVReport: string;
  LDocsDir: string;
  LDepName: string;
  LDepVersion: string;
  LDepLicense: string;
  LSourceInfo: string;
  LSubPkgPath: string;
  LSubPkg: TBoss4DPackage;
  LNormalizedLicense: TBoss4DSbomLicense;
  LLicenseKind: string;
begin
  FLogger.Log(TBoss4DLogLevel.Info, '📄 Iniciando auditoria de licenças...');

  if not FPackageRepo.Exists(GetBossFile) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Arquivo boss.json nao encontrado no diretorio atual.');
    Exit;
  end;

  LMainPkg := FPackageRepo.Load(GetBossFile);
  try
    LModulesDir := GetModulesDir;
    if not TDirectory.Exists(LModulesDir) then
    begin
      FLogger.Log(TBoss4DLogLevel.Warning, 'Pasta modules/ nao encontrada. Rode boss install primeiro.');
      Exit;
    end;

    LSubDirs := TDirectory.GetDirectories(LModulesDir);
    if Length(LSubDirs) = 0 then
    begin
      FLogger.Log(TBoss4DLogLevel.Info, 'Nenhum modulo instalado em modules/.');
      Exit;
    end;

    // Cabecalhos do Relatorio Markdown
    LMarkdownReport := '# Relatório de Conformidade de Licenças (Compliance)' + sLineBreak + sLineBreak;
    LMarkdownReport := LMarkdownReport + 'Este documento lista todas as dependências de terceiros instaladas no projeto e suas respectivas licenças.' + sLineBreak + sLineBreak;
    LMarkdownReport := LMarkdownReport + '| Dependência | Versão | Licença | Tipo | Origem da Informação |' + sLineBreak;
    LMarkdownReport := LMarkdownReport + '| --- | --- | --- | --- | --- |' + sLineBreak;

    // Cabecalhos do Relatorio CSV
    LCSVReport := 'dependency,version,license,licenseKind,source' + sLineBreak;

    for var LSubDir in LSubDirs do
    begin
      LDepName := TPath.GetFileName(LSubDir);
      LDepVersion := 'Desconhecida';
      LDepLicense := '';
      LSourceInfo := 'Arquivo LICENSE';

      LSubPkgPath := TPath.Combine(LSubDir, FILE_PACKAGE);
      if TFile.Exists(LSubPkgPath) then
      begin
        try
          LSubPkg := FPackageRepo.Load(LSubPkgPath);
          try
            LDepVersion := LSubPkg.Version;
            LDepLicense := LSubPkg.License;
            if not LDepLicense.IsEmpty then
              LSourceInfo := 'boss.json'
            else
            begin
              LDepLicense := DetectLicenseFromFile(LSubDir);
              LSourceInfo := 'Arquivo LICENSE';
            end;
          finally
            LSubPkg.Free;
          end;
        except
          on E: Exception do
            FLogger.Log(TBoss4DLogLevel.Warning, 'Falha ao ler boss.json da dependencia ' + LDepName + ': ' + E.Message);
        end;
      end
      else
      begin
        LDepLicense := DetectLicenseFromFile(LSubDir);
      end;

      if LDepLicense.IsEmpty then
        LDepLicense := 'Nao especificada';

      LNormalizedLicense := TBoss4DLicenseNormalizer.Normalize(LDepLicense, LSourceInfo);
      try
        LLicenseKind := TBoss4DLicenseNormalizer.KindName(LNormalizedLicense.Kind);
        if not LNormalizedLicense.Expression.IsEmpty then
          LDepLicense := LNormalizedLicense.Expression
        else if not LNormalizedLicense.Name.IsEmpty then
          LDepLicense := LNormalizedLicense.Name
        else
          LDepLicense := 'NOASSERTION';
      finally
        LNormalizedLicense.Free;
      end;

      // Remove quebras de linha e virgulas para formatacao adequada do Markdown/CSV
      LDepLicense := LDepLicense.Replace(sLineBreak, ' ').Replace(',', ' ').Trim;

      LMarkdownReport := LMarkdownReport + Format('| %s | %s | %s | %s | %s |',
        [LDepName, LDepVersion, LDepLicense, LLicenseKind, LSourceInfo]) + sLineBreak;
      LCSVReport := LCSVReport + Format('%s,%s,%s,%s,%s',
        [LDepName, LDepVersion, LDepLicense, LLicenseKind, LSourceInfo]) + sLineBreak;
    end;

    // Salva na pasta docs/
    LDocsDir := TPath.Combine(GetCurrentDir, 'docs');
    if not TDirectory.Exists(LDocsDir) then
      TDirectory.CreateDirectory(LDocsDir);

    TFile.WriteAllText(TPath.Combine(LDocsDir, 'license_report.md'), LMarkdownReport, TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LDocsDir, 'license_report.csv'), LCSVReport, TEncoding.UTF8);

    FLogger.Log(TBoss4DLogLevel.Info, 'Relatórios de licença gerados em:');
    FLogger.Log(TBoss4DLogLevel.Info, '  -> docs/license_report.md');
    FLogger.Log(TBoss4DLogLevel.Info, '  -> docs/license_report.csv');
  finally
    LMainPkg.Free;
  end;
end;

end.
