unit Boss4D.Core.Services.DependencySubmission;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Lock;

type
  TBoss4DDependencySubmissionService = class
  private
    FLockRepo: IBoss4DLockRepository;
    FHttp: IBoss4DHttpClient;
    function PackageUrl(const AName, AVersion: string): string;
  public
    constructor Create(const ALockRepo: IBoss4DLockRepository;
      const AHttp: IBoss4DHttpClient);
    function BuildPayload(const ALock: TBoss4DLock; const ASha,
      ARef, AJobId: string): string;
    procedure Submit(const ALockPath, ARepository, ASha, ARef,
      AToken, AJobId: string);
  end;

implementation

uses
  System.SysUtils, System.JSON, System.NetEncoding;

constructor TBoss4DDependencySubmissionService.Create(
  const ALockRepo: IBoss4DLockRepository; const AHttp: IBoss4DHttpClient);
begin
  inherited Create;
  FLockRepo := ALockRepo;
  FHttp := AHttp;
end;

function TBoss4DDependencySubmissionService.PackageUrl(const AName,
  AVersion: string): string;
begin
  Result := 'pkg:generic/' + TNetEncoding.URL.Encode(AName) + '@' +
    TNetEncoding.URL.Encode(AVersion);
end;

function TBoss4DDependencySubmissionService.BuildPayload(
  const ALock: TBoss4DLock; const ASha, ARef, AJobId: string): string;
var
  LRoot, LJob, LDetector, LManifests, LManifest, LResolved: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('version', TJSONNumber.Create(0));
    LRoot.AddPair('sha', ASha);
    LRoot.AddPair('ref', ARef);
    LJob := TJSONObject.Create;
    LJob.AddPair('correlator', 'boss4d-' + AJobId);
    LJob.AddPair('id', AJobId);
    LRoot.AddPair('job', LJob);
    LDetector := TJSONObject.Create;
    LDetector.AddPair('name', 'Boss4D');
    LDetector.AddPair('version', '1.7.1');
    LDetector.AddPair('url', 'https://github.com/regyssilveira/Boss4Delphi');
    LRoot.AddPair('detector', LDetector);

    LResolved := TJSONObject.Create;
    for var LPair in ALock.Installed do
    begin
      var LEntry := TJSONObject.Create;
      LEntry.AddPair('package_url',
        PackageUrl(LPair.Value.Name, LPair.Value.Version));
      LEntry.AddPair('relationship', 'direct');
      if not ALock.RootDependencies.Contains(LPair.Key) and
         not ALock.RootDevDependencies.Contains(LPair.Key) then
        LEntry.RemovePair('relationship').Free;
      if not LEntry.GetValue<string>('relationship', '').IsEmpty then
        { direct already set }
      else
        LEntry.AddPair('relationship', 'indirect');
      LEntry.AddPair('scope', LPair.Value.Scope);
      var LDependencies := TJSONArray.Create;
      for var LChild in LPair.Value.Dependencies do
        if ALock.Installed.ContainsKey(LChild) then
          LDependencies.Add(PackageUrl(ALock.Installed[LChild].Name,
            ALock.Installed[LChild].Version));
      LEntry.AddPair('dependencies', LDependencies);
      LResolved.AddPair(PackageUrl(LPair.Value.Name,
        LPair.Value.Version), LEntry);
    end;
    LManifest := TJSONObject.Create;
    LManifest.AddPair('name', 'boss-lock.json');
    LManifest.AddPair('file', TJSONObject.Create.AddPair(
      'source_location', 'boss-lock.json'));
    LManifest.AddPair('resolved', LResolved);
    LManifests := TJSONObject.Create;
    LManifests.AddPair('boss-lock.json', LManifest);
    LRoot.AddPair('manifests', LManifests);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TBoss4DDependencySubmissionService.Submit(const ALockPath,
  ARepository, ASha, ARef, AToken, AJobId: string);
var
  LLock: TBoss4DLock;
  LResponse: string;
  LStatus: Integer;
begin
  if AToken.IsEmpty then
    raise EArgumentException.Create('Token GitHub ausente.');
  LLock := FLockRepo.Load(ALockPath);
  try
    LStatus := FHttp.PostJsonAuthorized(
      'https://api.github.com/repos/' + ARepository +
      '/dependency-graph/snapshots',
      BuildPayload(LLock, ASha, ARef, AJobId), AToken, LResponse);
    if (LStatus < 200) or (LStatus >= 300) then
      raise Exception.CreateFmt(
        'GitHub Dependency Submission respondeu HTTP %d: %s',
        [LStatus, LResponse]);
  finally
    LLock.Free;
  end;
end;

end.
