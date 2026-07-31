unit Boss4D.Core.Services.BuildCapabilities;

interface

type
  TBoss4DSupportLevel = (Unsupported, Experimental, Compatible, Certified);

  TBoss4DBuildCapability = record
    Level: TBoss4DSupportLevel;
    Reason: string;
    class function LevelName(const ALevel: TBoss4DSupportLevel): string;
      static;
  end;

  TBoss4DBuildCapabilities = class
  public
    class function Evaluate(const ACompiler, APlatform, AProjectKind,
      AProjectPath: string): TBoss4DBuildCapability; static;
    class procedure RequireSupported(const ACompiler, APlatform,
      AProjectKind, AProjectPath: string); static;
    class function SupportedPlatforms: TArray<string>; static;
    class function NormalizePlatform(const APlatform: string): string;
      static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Services.BuildConventions;

function LowerLevel(const ALeft,
  ARight: TBoss4DSupportLevel): TBoss4DSupportLevel;
begin
  if Ord(ALeft) < Ord(ARight) then
    Result := ALeft
  else
    Result := ARight;
end;

function BDSMajor(const ACompiler: string): Integer;
begin
  var LConvention := TBoss4DBuildConventions.ResolveCompiler(ACompiler);
  Result := StrToIntDef(LConvention.BDSVersion.Split(['.'])[0], 0);
end;

class function TBoss4DBuildCapability.LevelName(
  const ALevel: TBoss4DSupportLevel): string;
begin
  case ALevel of
    TBoss4DSupportLevel.Experimental:
      Result := 'experimental';
    TBoss4DSupportLevel.Compatible:
      Result := 'compatible';
    TBoss4DSupportLevel.Certified:
      Result := 'certified';
  else
    Result := 'unsupported';
  end;
end;

class function TBoss4DBuildCapabilities.SupportedPlatforms:
  TArray<string>;
begin
  Result := TArray<string>.Create(
    'Win32', 'Win64', 'Linux64', 'OSX32', 'OSX64',
    'iOSSimulator', 'iOSDevice32', 'iOSDevice64',
    'Android32', 'Android64');
end;

class function TBoss4DBuildCapabilities.NormalizePlatform(
  const APlatform: string): string;
begin
  for var LPlatform in SupportedPlatforms do
    if SameText(LPlatform, APlatform.Trim) then
      Exit(LPlatform);
  raise EArgumentException.CreateFmt(
    'Plataforma Delphi nao suportada: %s.', [APlatform]);
end;

class function TBoss4DBuildCapabilities.Evaluate(const ACompiler,
  APlatform, AProjectKind, AProjectPath: string): TBoss4DBuildCapability;
begin
  Result.Level := TBoss4DSupportLevel.Unsupported;
  Result.Reason := '';
  var LBDS := BDSMajor(ACompiler);
  var LCompilerLevel := TBoss4DSupportLevel.Experimental;
  if (LBDS = 17) or (LBDS = 22) or (LBDS = 23) or (LBDS = 37) then
    LCompilerLevel := TBoss4DSupportLevel.Certified
  else if LBDS = 18 then
    LCompilerLevel := TBoss4DSupportLevel.Compatible;

  var LPlatformLevel := TBoss4DSupportLevel.Unsupported;
  if SameText(APlatform, 'Win32') then
    LPlatformLevel := TBoss4DSupportLevel.Certified
  else if SameText(APlatform, 'Win64') and (LBDS >= 9) then
    LPlatformLevel := TBoss4DSupportLevel.Certified
  else if SameText(APlatform, 'Linux64') and (LBDS >= 19) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'OSX32') and (LBDS >= 9) and (LBDS <= 20) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'OSX64') and (LBDS >= 21) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'iOSSimulator') and (LBDS >= 10) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'iOSDevice32') and (LBDS >= 11) and
          (LBDS <= 20) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'iOSDevice64') and (LBDS >= 14) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'Android32') and (LBDS >= 12) and
          (LBDS <= 22) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible
  else if SameText(APlatform, 'Android64') and (LBDS >= 20) then
    LPlatformLevel := TBoss4DSupportLevel.Compatible;

  Result.Level := LowerLevel(LCompilerLevel, LPlatformLevel);
  if Result.Level = TBoss4DSupportLevel.Unsupported then
  begin
    Result.Reason := Format('%s nao oferece o target %s.',
      [TBoss4DBuildConventions.ResolveCompiler(ACompiler).Alias, APlatform]);
    Exit;
  end;

  if not SameText(AProjectKind, 'runtime') and
     not SameText(AProjectKind, 'design') and
     not SameText(AProjectKind, 'application') and
     not SameText(AProjectKind, 'tool') and
     not SameText(AProjectKind, 'binary') then
  begin
    Result.Level := TBoss4DSupportLevel.Unsupported;
    Result.Reason := 'Tipo de projeto desconhecido: ' + AProjectKind;
    Exit;
  end;

  if SameText(AProjectKind, 'design') then
  begin
    if SameText(APlatform, 'Win32') then
      { Mantem o nivel combinado. }
    else if SameText(APlatform, 'Win64') then
      Result.Level := LowerLevel(Result.Level,
        TBoss4DSupportLevel.Experimental)
    else
    begin
      Result.Level := TBoss4DSupportLevel.Unsupported;
      Result.Reason :=
        'Pacotes design-time devem corresponder a arquitetura da IDE.';
      Exit;
    end;
  end;

  if SameText(TPath.GetExtension(AProjectPath), '.cbproj') then
  begin
    if not SameText(APlatform, 'Win32') and
       not SameText(APlatform, 'Win64') then
    begin
      Result.Level := TBoss4DSupportLevel.Unsupported;
      Result.Reason :=
        'C++Builder esta habilitado inicialmente para Win32 e Win64.';
      Exit;
    end;
    Result.Level := LowerLevel(Result.Level,
      TBoss4DSupportLevel.Experimental);
  end;

  if Result.Reason.IsEmpty then
    Result.Reason := Format('%s/%s/%s: %s.',
      [TBoss4DBuildConventions.ResolveCompiler(ACompiler).Alias,
       APlatform, AProjectKind,
       TBoss4DBuildCapability.LevelName(Result.Level)]);
end;

class procedure TBoss4DBuildCapabilities.RequireSupported(
  const ACompiler, APlatform, AProjectKind, AProjectPath: string);
begin
  var LCapability := Evaluate(ACompiler, APlatform, AProjectKind,
    AProjectPath);
  if LCapability.Level = TBoss4DSupportLevel.Unsupported then
    raise EArgumentException.CreateFmt(
      'Target nao suportado (%s/%s/%s): %s',
      [ACompiler, APlatform, AProjectKind, LCapability.Reason]);
end;

end.
