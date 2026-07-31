unit Boss4D.GUI.Install.Presenter;

interface

uses
  System.SysUtils;

type
  TBoss4DGUICancellationProbe = reference to function: Boolean;

  IBoss4DGUICancellableProcessRunner = interface
    ['{9D198061-DAB1-4A22-A43D-09178F88FA8E}']
    function Execute(const ACommandLine, AWorkingDirectory: string;
      const ACancellation: TBoss4DGUICancellationProbe;
      out AOutput: string; out ACancelled: Boolean): Boolean;
  end;

  TBoss4DGUIInstallRequest = record
    PackageName: string;
    Version: string;
    Compiler: string;
    Platform: string;
    AllowSourceFallback: Boolean;
  end;

  TBoss4DGUIInstallPresenter = class
  private
    class function Quote(const AValue: string): string; static;
  public
    class procedure Validate(const ARequest: TBoss4DGUIInstallRequest); static;
    class function BuildArguments(
      const ARequest: TBoss4DGUIInstallRequest): string; static;
    class function BuildEquivalentCommand(
      const ARequest: TBoss4DGUIInstallRequest): string; static;
  end;

  TBoss4DGUIInstallExecutor = class
  private
    FRunner: IBoss4DGUICancellableProcessRunner;
  public
    constructor Create(const ARunner: IBoss4DGUICancellableProcessRunner);
    function Execute(const AExecutable, AWorkingDirectory: string;
      const ARequest: TBoss4DGUIInstallRequest;
      const ACancellation: TBoss4DGUICancellationProbe;
      out ACancelled: Boolean): string;
  end;

implementation

class function TBoss4DGUIInstallPresenter.Quote(
  const AValue: string): string;
begin
  Result := '"' + StringReplace(AValue, '"', '\"', [rfReplaceAll]) + '"';
end;

class procedure TBoss4DGUIInstallPresenter.Validate(
  const ARequest: TBoss4DGUIInstallRequest);
begin
  if Trim(ARequest.PackageName) = '' then
    raise EArgumentException.Create('Selecione um pacote.');
  if Trim(ARequest.Version) = '' then
    raise EArgumentException.Create('Selecione uma versao.');
  if Trim(ARequest.Compiler) = '' then
    raise EArgumentException.Create('Selecione um compilador.');
  if Trim(ARequest.Platform) = '' then
    raise EArgumentException.Create('Selecione uma plataforma.');
end;

class function TBoss4DGUIInstallPresenter.BuildArguments(
  const ARequest: TBoss4DGUIInstallRequest): string;
begin
  Validate(ARequest);
  Result := 'package install ' +
    Quote(Trim(ARequest.PackageName) + '@' + Trim(ARequest.Version)) +
    ' --compiler ' + Quote(Trim(ARequest.Compiler)) +
    ' --platform ' + Quote(Trim(ARequest.Platform));
  if not ARequest.AllowSourceFallback then
    Result := Result + ' --no-source-fallback';
end;

class function TBoss4DGUIInstallPresenter.BuildEquivalentCommand(
  const ARequest: TBoss4DGUIInstallRequest): string;
begin
  Result := 'boss4d ' + BuildArguments(ARequest);
end;

constructor TBoss4DGUIInstallExecutor.Create(
  const ARunner: IBoss4DGUICancellableProcessRunner);
begin
  inherited Create;
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  FRunner := ARunner;
end;

function TBoss4DGUIInstallExecutor.Execute(const AExecutable,
  AWorkingDirectory: string;
  const ARequest: TBoss4DGUIInstallRequest;
  const ACancellation: TBoss4DGUICancellationProbe;
  out ACancelled: Boolean): string;
var
  LCommand: string;
begin
  if Trim(AExecutable) = '' then
    raise EArgumentException.Create('Executavel Boss4D nao encontrado.');
  LCommand := '"' + AExecutable + '" ' +
    TBoss4DGUIInstallPresenter.BuildArguments(ARequest);
  if not FRunner.Execute(LCommand, AWorkingDirectory, ACancellation, Result,
    ACancelled) and not ACancelled then
    raise Exception.Create('A instalacao falhou.' + sLineBreak + Result);
end;

end.
