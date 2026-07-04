unit Boss4D.Core.Domain.SemVer;

interface

uses
  System.SysUtils;

type
  { Representa uma versao individual no padrao Semantic Versioning (SemVer 2.0.0) }
  TBoss4DSemVer = record
  private
    FMajor: Integer;
    FMinor: Integer;
    FPatch: Integer;
    FPreRelease: string;
    FBuild: string;
    FIsValid: Boolean;
    FRawVersion: string;

    class function ComparePreRelease(const APre1, APre2: string): Integer; static;
    class function SplitParts(const AInput: string; ASeparator: Char): TArray<string>; static;
    class function IsNumeric(const AStr: string): Boolean; static;
  public
    property Major: Integer read FMajor;
    property Minor: Integer read FMinor;
    property Patch: Integer read FPatch;
    property PreRelease: string read FPreRelease;
    property Build: string read FBuild;
    property IsValid: Boolean read FIsValid;
    property RawVersion: string read FRawVersion;

    constructor Create(const AVersionStr: string);

    function ToString: string;
    function CompareTo(const AOther: TBoss4DSemVer): Integer;

    class operator Equal(const ALeft, ARight: TBoss4DSemVer): Boolean;
    class operator GreaterThan(const ALeft, ARight: TBoss4DSemVer): Boolean;
    class operator GreaterThanOrEqual(const ALeft, ARight: TBoss4DSemVer): Boolean;
    class operator LessThan(const ALeft, ARight: TBoss4DSemVer): Boolean;
    class operator LessThanOrEqual(const ALeft, ARight: TBoss4DSemVer): Boolean;
    class operator NotEqual(const ALeft, ARight: TBoss4DSemVer): Boolean;
  end;

  { Representa uma faixa ou regra de versao (ex: ^1.2.3, ~1.2.3, >=1.0.0, etc.) }
  TBoss4DSemVerRange = record
  private
    FRawRange: string;
    FOperator: string;
    FMinVersion: TBoss4DSemVer;
    FMaxVersion: TBoss4DSemVer;
    FHasMaxVersion: Boolean;

    procedure Parse(const ARangeStr: string);
  public
    constructor Create(const ARangeStr: string);
    class function IsSemVerRange(const AVersionStr: string): Boolean; static;
    function IsSatisfiedBy(const AVersion: TBoss4DSemVer): Boolean; overload;
    function IsSatisfiedBy(const AVersionStr: string): Boolean; overload;
  end;

implementation

uses
  System.RegularExpressions, System.Classes;

function CompareInt(const AVal1, AVal2: Integer): Integer;
begin
  if AVal1 > AVal2 then Result := 1
  else if AVal1 < AVal2 then Result := -1
  else Result := 0;
end;

function CompareParts(const APart1, APart2: string): Integer;
var
  LIsNum1, LIsNum2: Boolean;
  LVal1, LVal2: Int64;
begin
  if APart1 = APart2 then
    Exit(0);

  LIsNum1 := TBoss4DSemVer.IsNumeric(APart1);
  LIsNum2 := TBoss4DSemVer.IsNumeric(APart2);

  if LIsNum1 and LIsNum2 then
  begin
    LVal1 := StrToInt64(APart1);
    LVal2 := StrToInt64(APart2);
    if LVal1 > LVal2 then Exit(1) else Exit(-1);
  end
  else if not LIsNum1 and not LIsNum2 then
  begin
    Exit(CompareStr(APart1, APart2));
  end;

  // Identificadores numericos tem menor precedencia que nao-numericos
  if LIsNum1 then Exit(-1) else Exit(1);
end;

{ TBoss4DSemVer }

constructor TBoss4DSemVer.Create(const AVersionStr: string);
var
  LCleanStr: string;
  LRegex: TRegEx;
  LMatch: TMatch;
begin
  FMajor := 0;
  FMinor := 0;
  FPatch := 0;
  FPreRelease := '';
  FBuild := '';
  FIsValid := False;
  FRawVersion := AVersionStr;

  LCleanStr := AVersionStr.Trim;
  if LCleanStr.IsEmpty then
    Exit;

  // Remove o prefixo 'v' ou 'V' se existir (ex: v1.0.0 -> 1.0.0)
  if LCleanStr.StartsWith('v', True) then
    LCleanStr := LCleanStr.Substring(1);

  // Normalizacoes basicas do BOSS para versoes incompletas (ex: "1" -> "1.0.0", "1.2" -> "1.2.0")
  var LParts := SplitParts(LCleanStr, '.');
  if Length(LParts) = 1 then
  begin
    // Se for apenas numero (ex: 1), ou numero com pre-release/build (ex: 1-alpha)
    var LSubParts := LParts[0].Split(['-', '+'], 2);
    if Length(LSubParts) > 0 then
    begin
      var LBuildOrPre := LParts[0].Substring(LSubParts[0].Length);
      LCleanStr := LSubParts[0] + '.0.0' + LBuildOrPre;
    end;
  end
  else if Length(LParts) = 2 then
  begin
    // Ex: "1.2" -> "1.2.0", ou "1.2-alpha" -> "1.2.0-alpha"
    var LSubParts := LParts[1].Split(['-', '+'], 2);
    if Length(LSubParts) > 0 then
    begin
      var LBuildOrPre := LParts[1].Substring(LSubParts[0].Length);
      LCleanStr := LParts[0] + '.' + LSubParts[0] + '.0' + LBuildOrPre;
    end;
  end;

  // Regex padrao SemVer 2.0.0
  var LPattern := '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)' +
                  '(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?' +
                  '(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$';

  LRegex := TRegEx.Create(LPattern);
  LMatch := LRegex.Match(LCleanStr);

  if LMatch.Success then
  begin
    FMajor := StrToInt(LMatch.Groups[1].Value);
    FMinor := StrToInt(LMatch.Groups[2].Value);
    FPatch := StrToInt(LMatch.Groups[3].Value);
    
    FPreRelease := '';
    if LMatch.Groups.Count > 4 then
      FPreRelease := LMatch.Groups[4].Value;
      
    FBuild := '';
    if LMatch.Groups.Count > 5 then
      FBuild := LMatch.Groups[5].Value;
      
    FIsValid := True;
  end;
end;

class function TBoss4DSemVer.IsNumeric(const AStr: string): Boolean;
var
  I: Integer;
begin
  Result := not AStr.IsEmpty;
  for I := 1 to Length(AStr) do
  begin
    if not CharInSet(AStr[I], ['0'..'9']) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

class function TBoss4DSemVer.SplitParts(const AInput: string; ASeparator: Char): TArray<string>;
var
  LList: TStringList;
  I: Integer;
begin
  LList := TStringList.Create;
  try
    LList.Delimiter := ASeparator;
    LList.StrictDelimiter := True;
    LList.DelimitedText := AInput;
    SetLength(Result, LList.Count);
    for I := 0 to LList.Count - 1 do
      Result[I] := LList[I];
  finally
    LList.Free;
  end;
end;

class function TBoss4DSemVer.ComparePreRelease(const APre1, APre2: string): Integer;
var
  LParts1, LParts2: TArray<string>;
  LCount, I: Integer;
begin
  if APre1 = APre2 then
    Exit(0);
  
  // Versoes sem prerelease tem maior precedencia (ex: 1.0.0 > 1.0.0-alpha)
  if APre1.IsEmpty then Exit(1);
  if APre2.IsEmpty then Exit(-1);

  LParts1 := SplitParts(APre1, '.');
  LParts2 := SplitParts(APre2, '.');

  if Length(LParts1) < Length(LParts2) then
    LCount := Length(LParts1)
  else
    LCount := Length(LParts2);

  for I := 0 to LCount - 1 do
  begin
    var LComp := CompareParts(LParts1[I], LParts2[I]);
    if LComp <> 0 then
      Exit(LComp);
  end;

  // Se empatou ate aqui, o que tiver mais identificadores vence
  if Length(LParts1) > Length(LParts2) then
    Result := 1
  else if Length(LParts1) < Length(LParts2) then
    Result := -1
  else
    Result := 0;
end;

function TBoss4DSemVer.CompareTo(const AOther: TBoss4DSemVer): Integer;
begin
  if not FIsValid and not AOther.FIsValid then
    Exit(CompareStr(FRawVersion, AOther.FRawVersion));
  if not FIsValid then
    Exit(-1);
  if not AOther.FIsValid then
    Exit(1);

  Result := CompareInt(FMajor, AOther.FMajor);
  if Result <> 0 then Exit;

  Result := CompareInt(FMinor, AOther.FMinor);
  if Result <> 0 then Exit;

  Result := CompareInt(FPatch, AOther.FPatch);
  if Result <> 0 then Exit;

  Result := ComparePreRelease(FPreRelease, AOther.FPreRelease);
end;

function TBoss4DSemVer.ToString: string;
begin
  if not FIsValid then
    Exit(FRawVersion);

  Result := Format('%d.%d.%d', [FMajor, FMinor, FPatch]);
  if not FPreRelease.IsEmpty then
    Result := Result + '-' + FPreRelease;
  if not FBuild.IsEmpty then
    Result := Result + '+' + FBuild;
end;

class operator TBoss4DSemVer.Equal(const ALeft, ARight: TBoss4DSemVer): Boolean;
begin
  Result := ALeft.CompareTo(ARight) = 0;
end;

class operator TBoss4DSemVer.GreaterThan(const ALeft, ARight: TBoss4DSemVer): Boolean;
begin
  Result := ALeft.CompareTo(ARight) > 0;
end;

class operator TBoss4DSemVer.GreaterThanOrEqual(const ALeft, ARight: TBoss4DSemVer): Boolean;
begin
  Result := ALeft.CompareTo(ARight) >= 0;
end;

class operator TBoss4DSemVer.LessThan(const ALeft, ARight: TBoss4DSemVer): Boolean;
begin
  Result := ALeft.CompareTo(ARight) < 0;
end;

class operator TBoss4DSemVer.LessThanOrEqual(const ALeft, ARight: TBoss4DSemVer): Boolean;
begin
  Result := ALeft.CompareTo(ARight) <= 0;
end;

class operator TBoss4DSemVer.NotEqual(const ALeft, ARight: TBoss4DSemVer): Boolean;
begin
  Result := ALeft.CompareTo(ARight) <> 0;
end;

{ TBoss4DSemVerRange }

class function TBoss4DSemVerRange.IsSemVerRange(const AVersionStr: string): Boolean;
var
  LTrimmed: string;
begin
  LTrimmed := AVersionStr.Trim;
  if LTrimmed.IsEmpty then
    Exit(False);

  // Se inicia com operadores clássicos de range SemVer
  if LTrimmed.StartsWith('^') or LTrimmed.StartsWith('~') or
     LTrimmed.StartsWith('>=') or LTrimmed.StartsWith('<=') or
     LTrimmed.StartsWith('>') or LTrimmed.StartsWith('<') or
     LTrimmed.StartsWith('=') or (LTrimmed = '*') then
  begin
    Exit(True);
  end;

  // Se contem curingas SemVer
  if LTrimmed.Contains('x') or LTrimmed.Contains('X') or LTrimmed.Contains('*') then
  begin
    if LTrimmed.Contains('.x') or LTrimmed.Contains('.X') or LTrimmed.Contains('.*') then
      Exit(True);
  end;

  // Se for uma versao SemVer pura valida (ex: "1.0.0", "1.2", "3")
  var LVer := TBoss4DSemVer.Create(LTrimmed);
  Result := LVer.IsValid;
end;

constructor TBoss4DSemVerRange.Create(const ARangeStr: string);
begin
  FRawRange := ARangeStr;
  FOperator := '';
  FMinVersion := Default(TBoss4DSemVer);
  FMaxVersion := Default(TBoss4DSemVer);
  FHasMaxVersion := False;
  Parse(ARangeStr);
end;

procedure TBoss4DSemVerRange.Parse(const ARangeStr: string);
var
  LStr: string;

  function ParseWildcards(const AStr: string): Boolean;
  var
    LStrCopy: string;
    LParts: TArray<string>;
  begin
    Result := False;
    if not (AStr.Contains('*') or AStr.Contains('x') or AStr.Contains('X')) then
      Exit;

    LStrCopy := AStr.Replace('*', 'x').Replace('X', 'x');
    LParts := LStrCopy.Split(['.']);
    
    if Length(LParts) > 0 then
    begin
      Result := True;
      if (LParts[0] = 'x') then
      begin
        FOperator := '>=';
        FMinVersion := TBoss4DSemVer.Create('0.0.0');
      end
      else if (Length(LParts) > 1) and (LParts[1] = 'x') then
      begin
        FOperator := '^';
        FMinVersion := TBoss4DSemVer.Create(LParts[0] + '.0.0');
      end
      else if (Length(LParts) > 2) and (LParts[2] = 'x') then
      begin
        FOperator := '~';
        FMinVersion := TBoss4DSemVer.Create(LParts[0] + '.' + LParts[1] + '.0');
      end
      else
        Result := False;
    end;
  end;

  procedure ParseExplicitOperators(const AStr: string);
  begin
    if AStr.StartsWith('^') then
    begin
      FOperator := '^';
      FMinVersion := TBoss4DSemVer.Create(AStr.Substring(1));
    end
    else if AStr.StartsWith('~') then
    begin
      FOperator := '~';
      FMinVersion := TBoss4DSemVer.Create(AStr.Substring(1));
    end
    else if AStr.StartsWith('>=') then
    begin
      FOperator := '>=';
      FMinVersion := TBoss4DSemVer.Create(AStr.Substring(2));
    end
    else if AStr.StartsWith('<=') then
    begin
      FOperator := '<=';
      FMinVersion := TBoss4DSemVer.Create(AStr.Substring(2));
    end
    else if AStr.StartsWith('>') then
    begin
      FOperator := '>';
      FMinVersion := TBoss4DSemVer.Create(AStr.Substring(1));
    end
    else if AStr.StartsWith('<') then
    begin
      FOperator := '<';
      FMinVersion := TBoss4DSemVer.Create(AStr.Substring(1));
    end
    else
    begin
      FOperator := '=';
      FMinVersion := TBoss4DSemVer.Create(AStr);
    end;
  end;

  procedure ComputeLimits;
  begin
    if FOperator = '^' then
    begin
      FHasMaxVersion := True;
      if FMinVersion.Major > 0 then
        FMaxVersion := TBoss4DSemVer.Create(Format('%d.0.0-0', [FMinVersion.Major + 1]))
      else if FMinVersion.Minor > 0 then
        FMaxVersion := TBoss4DSemVer.Create(Format('0.%d.0-0', [FMinVersion.Minor + 1]))
      else
        FMaxVersion := TBoss4DSemVer.Create(Format('0.0.%d-0', [FMinVersion.Patch + 1]));
    end
    else if FOperator = '~' then
    begin
      FHasMaxVersion := True;
      FMaxVersion := TBoss4DSemVer.Create(Format('%d.%d.0-0', [FMinVersion.Major, FMinVersion.Minor + 1]));
    end;
  end;

begin
  LStr := ARangeStr.Trim;
  if LStr.IsEmpty then
    Exit;

  if not ParseWildcards(LStr) then
    ParseExplicitOperators(LStr);

  ComputeLimits;
end;

function TBoss4DSemVerRange.IsSatisfiedBy(const AVersion: TBoss4DSemVer): Boolean;
begin
  if not AVersion.IsValid then
    Exit(AVersion.RawVersion = FMinVersion.RawVersion);

  if FOperator = '=' then
    Exit(AVersion = FMinVersion)
  else if FOperator = '^' then
    Exit((AVersion >= FMinVersion) and (AVersion < FMaxVersion))
  else if FOperator = '~' then
    Exit((AVersion >= FMinVersion) and (AVersion < FMaxVersion))
  else if FOperator = '>=' then
    Exit(AVersion >= FMinVersion)
  else if FOperator = '<=' then
    Exit(AVersion <= FMinVersion)
  else if FOperator = '>' then
    Exit(AVersion > FMinVersion)
  else if FOperator = '<' then
    Exit(AVersion < FMinVersion);

  Result := False;
end;

function TBoss4DSemVerRange.IsSatisfiedBy(const AVersionStr: string): Boolean;
begin
  Result := IsSatisfiedBy(TBoss4DSemVer.Create(AVersionStr));
end;

end.
