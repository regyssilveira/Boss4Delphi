unit Boss4D.Core.Services.SelfUpdate;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DSelfUpdateResult = record
    Version: string;
    StagedFile: string;
    Updated: Boolean;
  end;

  TBoss4DSelfUpdateService = class
  private
    FHttp: IBoss4DHttpClient;
    FLogger: IBoss4DLogger;
    FApplier: IBoss4DSelfUpdateApplier;
    function FindAssetUrl(const AJson, AName: string): string;
  public
    constructor Create(const AHttp: IBoss4DHttpClient;
      const ALogger: IBoss4DLogger;
      const AApplier: IBoss4DSelfUpdateApplier);
    function CheckAndDownload(const ACurrentVersion,
      AStagingDirectory: string): TBoss4DSelfUpdateResult;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.IOUtils, System.Hash,
  Boss4D.Core.Domain.SemVer;

const
  RELEASE_URL =
    'https://api.github.com/repos/regyssilveira/Boss4Delphi/releases/latest';

constructor TBoss4DSelfUpdateService.Create(const AHttp: IBoss4DHttpClient;
  const ALogger: IBoss4DLogger; const AApplier: IBoss4DSelfUpdateApplier);
begin
  inherited Create;
  FHttp := AHttp;
  FLogger := ALogger;
  FApplier := AApplier;
end;

function TBoss4DSelfUpdateService.FindAssetUrl(const AJson,
  AName: string): string;
var
  LRoot: TJSONObject;
  LAssets: TJSONArray;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    LAssets := LRoot.GetValue<TJSONArray>('assets');
    if not Assigned(LAssets) then
      Exit;
    for var LValue in LAssets do
      if SameText(LValue.GetValue<string>('name'), AName) then
        Exit(LValue.GetValue<string>('browser_download_url'));
  finally
    LRoot.Free;
  end;
end;

function TBoss4DSelfUpdateService.CheckAndDownload(const ACurrentVersion,
  AStagingDirectory: string): TBoss4DSelfUpdateResult;
var
  LJson, LVersion, LBinaryName, LBinaryUrl, LChecksumUrl: string;
  LChecksumText, LExpected, LActual: string;
  LRoot: TJSONObject;
  LHasher: THashSHA2;
  LBytes: TBytes;
begin
  Result := Default(TBoss4DSelfUpdateResult);
  if FHttp.Get(RELEASE_URL, LJson) <> 200 then
    raise Exception.Create('Nao foi possivel consultar a ultima release.');
  LRoot := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
  if not Assigned(LRoot) then
    raise Exception.Create('Resposta de release invalida.');
  try
    LVersion := LRoot.GetValue<string>('tag_name');
    if LVersion.StartsWith('v', True) then
      Delete(LVersion, 1, 1);
  finally
    LRoot.Free;
  end;
  Result.Version := LVersion;
  if not (TBoss4DSemVer.Create(ACurrentVersion) <
    TBoss4DSemVer.Create(LVersion)) then
    Exit;

  LBinaryName := 'Boss4D_Setup.exe';
  LBinaryUrl := FindAssetUrl(LJson, LBinaryName);
  LChecksumUrl := FindAssetUrl(LJson, 'SHA256SUMS.txt');
  if LBinaryUrl.IsEmpty or LChecksumUrl.IsEmpty then
    raise Exception.Create('Release sem instalador ou manifesto de checksum.');
  if FHttp.Get(LChecksumUrl, LChecksumText) <> 200 then
    raise Exception.Create('Nao foi possivel obter o checksum da release.');
  LExpected := '';
  for var LLine in LChecksumText.Split([sLineBreak]) do
    if LLine.ToLower.Contains(LBinaryName.ToLower) then
    begin
      LExpected := LLine.Trim.Split([' '])[0].ToUpper;
      Break;
    end;
  if LExpected.IsEmpty then
    raise Exception.Create('Checksum do instalador ausente no manifesto.');
  TDirectory.CreateDirectory(AStagingDirectory);
  Result.StagedFile := TPath.Combine(AStagingDirectory, LBinaryName);
  if FHttp.DownloadToFile(LBinaryUrl, Result.StagedFile) <> 200 then
    raise Exception.Create('Falha ao baixar a nova versao.');
  LBytes := TFile.ReadAllBytes(Result.StagedFile);
  LHasher := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  if Length(LBytes) > 0 then
    LHasher.Update(LBytes, Length(LBytes));
  LActual := LHasher.HashAsString.ToUpper;
  if not SameText(LExpected, LActual) then
  begin
    TFile.Delete(Result.StagedFile);
    raise Exception.Create('Checksum SHA-256 da atualizacao nao confere.');
  end;
  Result.Updated := True;
  FLogger.Log(TBoss4DLogLevel.Info,
    'Atualizacao %s verificada e preparada.', [LVersion]);
  if Assigned(FApplier) then
    FApplier.LaunchVerifiedInstaller(Result.StagedFile);
end;

end.
