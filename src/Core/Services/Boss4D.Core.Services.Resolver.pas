unit Boss4D.Core.Services.Resolver;

interface

type
  TBoss4DResolutionStrategy = (HighestCompatible, MinimalCompatible);

  TBoss4DVersionResolver = class
  public
    function Resolve(const ARange: string; const AVersions: TArray<string>;
      const AStrategy: TBoss4DResolutionStrategy): string;
  end;

implementation

uses
  System.SysUtils, Boss4D.Core.Domain.SemVer;

function TBoss4DVersionResolver.Resolve(const ARange: string;
  const AVersions: TArray<string>;
  const AStrategy: TBoss4DResolutionStrategy): string;
var
  LRange: TBoss4DSemVerRange;
  LSelected, LCandidate: TBoss4DSemVer;
  LHasSelected: Boolean;
begin
  Result := '';
  LRange := TBoss4DSemVerRange.Create(ARange);
  LSelected := Default(TBoss4DSemVer);
  LHasSelected := False;
  for var LVersion in AVersions do
  begin
    LCandidate := TBoss4DSemVer.Create(LVersion);
    if not LCandidate.IsValid or not LRange.IsSatisfiedBy(LCandidate) then
      Continue;
    if not LHasSelected or
       ((AStrategy = HighestCompatible) and (LCandidate > LSelected)) or
       ((AStrategy = MinimalCompatible) and (LCandidate < LSelected)) then
    begin
      LSelected := LCandidate;
      LHasSelected := True;
    end;
  end;
  if LHasSelected then
    Result := LSelected.ToString;
end;

end.
