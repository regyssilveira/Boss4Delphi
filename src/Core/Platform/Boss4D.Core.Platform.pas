unit Boss4D.Core.Platform;

interface

uses
  Boss4D.Core.Ports;

procedure ConfigureBoss4DPlatform(const AProcessRunner: IBoss4DProcessRunner;
  const AEnvironment: IBoss4DPlatformEnvironment;
  const AFileLinks: IBoss4DFileLinkService;
  const ASelfUpdate: IBoss4DSelfUpdateApplier = nil);
procedure ResetBoss4DPlatform;
function Boss4DProcessRunner: IBoss4DProcessRunner;
function Boss4DPlatformEnvironment: IBoss4DPlatformEnvironment;
function Boss4DFileLinkService: IBoss4DFileLinkService;
function Boss4DSelfUpdateApplier: IBoss4DSelfUpdateApplier;

implementation

uses
  System.SysUtils;

var
  GProcessRunner: IBoss4DProcessRunner;
  GEnvironment: IBoss4DPlatformEnvironment;
  GFileLinks: IBoss4DFileLinkService;
  GSelfUpdate: IBoss4DSelfUpdateApplier;

procedure ConfigureBoss4DPlatform(const AProcessRunner: IBoss4DProcessRunner;
  const AEnvironment: IBoss4DPlatformEnvironment;
  const AFileLinks: IBoss4DFileLinkService;
  const ASelfUpdate: IBoss4DSelfUpdateApplier);
begin
  if not Assigned(AProcessRunner) then
    raise EArgumentNilException.Create('AProcessRunner');
  if not Assigned(AEnvironment) then
    raise EArgumentNilException.Create('AEnvironment');
  if not Assigned(AFileLinks) then
    raise EArgumentNilException.Create('AFileLinks');
  GProcessRunner := AProcessRunner;
  GEnvironment := AEnvironment;
  GFileLinks := AFileLinks;
  GSelfUpdate := ASelfUpdate;
end;

procedure ResetBoss4DPlatform;
begin
  GSelfUpdate := nil;
  GFileLinks := nil;
  GEnvironment := nil;
  GProcessRunner := nil;
end;

function Boss4DSelfUpdateApplier: IBoss4DSelfUpdateApplier;
begin
  if not Assigned(GSelfUpdate) then
    raise EInvalidOpException.Create(
      'Plataforma Boss4D nao oferece autoatualizacao.');
  Result := GSelfUpdate;
end;

function Boss4DFileLinkService: IBoss4DFileLinkService;
begin
  if not Assigned(GFileLinks) then
    raise EInvalidOpException.Create(
      'Plataforma Boss4D nao configurada: file links indisponiveis.');
  Result := GFileLinks;
end;

function Boss4DProcessRunner: IBoss4DProcessRunner;
begin
  if not Assigned(GProcessRunner) then
    raise EInvalidOpException.Create(
      'Plataforma Boss4D nao configurada: process runner indisponivel.');
  Result := GProcessRunner;
end;

function Boss4DPlatformEnvironment: IBoss4DPlatformEnvironment;
begin
  if not Assigned(GEnvironment) then
    raise EInvalidOpException.Create(
      'Plataforma Boss4D nao configurada: ambiente indisponivel.');
  Result := GEnvironment;
end;

initialization

finalization
  ResetBoss4DPlatform;

end.
