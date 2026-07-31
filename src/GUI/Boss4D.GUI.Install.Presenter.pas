unit Boss4D.GUI.Install.Presenter;

interface

type
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

implementation

uses
  System.SysUtils;

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

end.
