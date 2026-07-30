unit Boss4D.Posix.Registry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs;

type
  TBoss4DArtifactVariant = class
  private
    FPlatform: string;
    FCompiler: string;
    FArtifactUrl: string;
    FArtifactDigest: string;
    FSignatureUrl: string;
    FProvenanceUrl: string;
  public
    property Platform: string read FPlatform write FPlatform;
    property Compiler: string read FCompiler write FCompiler;
    property ArtifactUrl: string read FArtifactUrl write FArtifactUrl;
    property ArtifactDigest: string read FArtifactDigest write FArtifactDigest;
    property SignatureUrl: string read FSignatureUrl write FSignatureUrl;
    property ProvenanceUrl: string read FProvenanceUrl write FProvenanceUrl;
  end;

  TBoss4DRegistryFetcher = function(const ASource: string): string of object;

  TBoss4DRegistryHttpResponse = record
    StatusCode: Integer;
    Content: string;
    ETag: string;
    LastModified: string;
  end;

  TBoss4DRegistryConditionalFetcher = function(const ASource, AETag,
    ALastModified: string): TBoss4DRegistryHttpResponse of object;

  TBoss4DRegistryEntry = class
  private
    FName: string;
    FRepository: string;
    FDescription: string;
    FVersion: string;
    FLicenseName: string;
    FArtifactUrl: string;
    FArtifactDigest: string;
    FSignatureUrl: string;
    FProvenanceUrl: string;
    FSource: string;
    FRevoked: Boolean;
    FRevocationReason: string;
    FVariants: TFPObjectList;
  public
    constructor Create;
    destructor Destroy; override;
    function SelectVariant(const APlatform,
      ACompiler: string): TBoss4DArtifactVariant;
    property Name: string read FName write FName;
    property Repository: string read FRepository write FRepository;
    property Description: string read FDescription write FDescription;
    property Version: string read FVersion write FVersion;
    property LicenseName: string read FLicenseName write FLicenseName;
    property ArtifactUrl: string read FArtifactUrl write FArtifactUrl;
    property ArtifactDigest: string read FArtifactDigest write FArtifactDigest;
    property SignatureUrl: string read FSignatureUrl write FSignatureUrl;
    property ProvenanceUrl: string read FProvenanceUrl write FProvenanceUrl;
    property Source: string read FSource write FSource;
    property Revoked: Boolean read FRevoked write FRevoked;
    property RevocationReason: string read FRevocationReason
      write FRevocationReason;
    property Variants: TFPObjectList read FVariants;
  end;

  TBoss4DRegistryEntries = class(TFPObjectList)
  private
    function GetEntry(const AIndex: Integer): TBoss4DRegistryEntry;
  public
    constructor Create;
    function Find(const AName: string): TBoss4DRegistryEntry;
    function Search(const AQuery: string): TBoss4DRegistryEntries;
    property Entries[const AIndex: Integer]: TBoss4DRegistryEntry
      read GetEntry; default;
  end;

  TBoss4DRegistryService = class
  private
    FCacheDirectory: string;
    FFetcher: TBoss4DRegistryFetcher;
    FConditionalFetcher: TBoss4DRegistryConditionalFetcher;
    FOffline: Boolean;
    function ReadSource(const ASource: string): string;
    procedure LoadInternal(const ASource: string;
      const AEntries: TBoss4DRegistryEntries; const AVisited: TStringList);
  public
    constructor Create(const ACacheDirectory: string = '';
      const AFetcher: TBoss4DRegistryFetcher = nil);
    function Load(const ASource: string;
      const AOffline: Boolean = False): TBoss4DRegistryEntries;
    property ConditionalFetcher: TBoss4DRegistryConditionalFetcher
      read FConditionalFetcher write FConditionalFetcher;
  end;

function PublicRegistryUrl: string;
function ResolveRegistryReference(const ASource, AReference: string): string;

implementation

uses
  fpjson, jsonparser, fphttpclient, opensslsockets,
  Boss4D.Posix.Operations;

function PublicRegistryUrl: string;
begin
  Result :=
    'https://raw.githubusercontent.com/regyssilveira/Boss4Delphi/' +
    'main/registry/index-v2.json';
end;

function IsHttp(const ASource: string): Boolean;
begin
  Result := (Pos('http://', LowerCase(ASource)) = 1) or
    (Pos('https://', LowerCase(ASource)) = 1);
end;

function NativeReadSource(const ASource: string): string;
var
  LStream: TStringStream;
  LClient: TFPHTTPClient;
begin
  if not IsHttp(ASource) then
  begin
    LStream := TStringStream.Create('', TEncoding.UTF8);
    try
      LStream.LoadFromFile(ExpandFileName(ASource));
      Exit(LStream.DataString);
    finally
      LStream.Free;
    end;
  end;
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.AllowRedirect := True;
    Result := LClient.Get(ASource);
  finally
    LClient.Free;
  end;
end;

function NativeConditionalFetch(const ASource, AETag,
  ALastModified: string): TBoss4DRegistryHttpResponse;
var
  LClient: TFPHTTPClient;
begin
  Result.StatusCode := 0;
  Result.Content := '';
  Result.ETag := '';
  Result.LastModified := '';
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.AllowRedirect := True;
    if AETag <> '' then LClient.AddHeader('If-None-Match', AETag);
    if ALastModified <> '' then
      LClient.AddHeader('If-Modified-Since', ALastModified);
    try
      Result.Content := LClient.Get(ASource);
    except
      on E: EHTTPClient do
        if LClient.ResponseStatusCode <> 304 then raise;
    end;
    Result.StatusCode := LClient.ResponseStatusCode;
    Result.ETag := LClient.ResponseHeaders.Values['ETag'];
    Result.LastModified := LClient.ResponseHeaders.Values['Last-Modified'];
  finally
    LClient.Free;
  end;
end;

function RegistryCacheName(const ASource: string): string;
var
  I: Integer;
  LHash: QWord;
begin
  LHash := QWord($CBF29CE484222325);
  for I := 1 to Length(ASource) do
  begin
    LHash := LHash xor Ord(ASource[I]);
    LHash := LHash * QWord($100000001B3);
  end;
  Result := LowerCase(IntToHex(LHash, 16)) + '.json';
end;

constructor TBoss4DRegistryService.Create(const ACacheDirectory: string;
  const AFetcher: TBoss4DRegistryFetcher);
var
  LHome: string;
begin
  inherited Create;
  FFetcher := AFetcher;
  if ACacheDirectory <> '' then
    FCacheDirectory := ExpandFileName(ACacheDirectory)
  else
  begin
    LHome := GetEnvironmentVariable('BOSS_HOME');
    if LHome = '' then
      LHome := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
        '.boss';
    FCacheDirectory := IncludeTrailingPathDelimiter(LHome) + 'registry-cache';
  end;
end;

function TBoss4DRegistryService.ReadSource(const ASource: string): string;
var
  LCachePath, LMetadataPath, LETag, LLastModified: string;
  LContent: TStringList;
  LMetadataData: TJSONData;
  LMetadata, LNewMetadata: TJSONObject;
  LResponse: TBoss4DRegistryHttpResponse;
begin
  if not IsHttp(ASource) then Exit(NativeReadSource(ASource));
  LCachePath := IncludeTrailingPathDelimiter(FCacheDirectory) +
    RegistryCacheName(ASource);
  LMetadataPath := LCachePath + '.meta.json';
  if FOffline then
  begin
    if not FileExists(LCachePath) then
      raise Exception.Create('offline registry cache miss: ' + ASource);
    Exit(NativeReadSource(LCachePath));
  end;
  try
    LETag := '';
    LLastModified := '';
    if FileExists(LMetadataPath) then
    begin
      LMetadataData := GetJSON(NativeReadSource(LMetadataPath));
      try
        if LMetadataData is TJSONObject then
        begin
          LMetadata := TJSONObject(LMetadataData);
          LETag := LMetadata.Get('etag', '');
          LLastModified := LMetadata.Get('lastModified', '');
        end;
      finally
        LMetadataData.Free;
      end;
    end;
    if Assigned(FConditionalFetcher) then
      LResponse := FConditionalFetcher(ASource, LETag, LLastModified)
    else if not Assigned(FFetcher) then
      LResponse := NativeConditionalFetch(ASource, LETag, LLastModified)
    else
    begin
      LResponse.StatusCode := 200;
      LResponse.Content := FFetcher(ASource);
      LResponse.ETag := '';
      LResponse.LastModified := '';
    end;
    if LResponse.StatusCode = 304 then
    begin
      if not FileExists(LCachePath) then
        raise Exception.Create('registry returned 304 without cache: ' + ASource);
      Exit(NativeReadSource(LCachePath));
    end;
    if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 300) then
      raise Exception.CreateFmt('registry HTTP status %d: %s',
        [LResponse.StatusCode, ASource]);
    Result := LResponse.Content;
    ForceDirectories(FCacheDirectory);
    LContent := TStringList.Create;
    try
      LContent.Text := Result;
      LContent.SaveToFile(LCachePath);
    finally
      LContent.Free;
    end;
    LNewMetadata := TJSONObject.Create;
    try
      LNewMetadata.Add('etag', LResponse.ETag);
      LNewMetadata.Add('lastModified', LResponse.LastModified);
      LContent := TStringList.Create;
      try
        LContent.Text := LNewMetadata.AsJSON;
        LContent.SaveToFile(LMetadataPath);
      finally
        LContent.Free;
      end;
    finally
      LNewMetadata.Free;
    end;
  except
    if FileExists(LCachePath) then Result := NativeReadSource(LCachePath)
    else raise;
  end;
end;

function ResolveReference(const ASource, AReference: string): string;
var
  LPosition: Integer;
begin
  if IsHttp(AReference) or (ExtractFileDrive(AReference) <> '') or
     ((Length(AReference) > 0) and (AReference[1] = DirectorySeparator)) then
    Exit(AReference);
  if IsHttp(ASource) then
  begin
    LPosition := LastDelimiter('/', ASource);
    Exit(Copy(ASource, 1, LPosition) +
      StringReplace(AReference, '\', '/', [rfReplaceAll]));
  end;
  Result := ExpandFileName(IncludeTrailingPathDelimiter(
    ExtractFileDir(ExpandFileName(ASource))) + AReference);
end;

function FindArray(const AObject: TJSONObject;
  const AName: string): TJSONArray;
var
  LData: TJSONData;
begin
  Result := nil;
  LData := AObject.Find(AName);
  if LData is TJSONArray then Result := TJSONArray(LData);
end;

function ResolveRegistryReference(const ASource, AReference: string): string;
begin
  if AReference = '' then Exit('');
  Result := ResolveReference(ASource, AReference);
end;

constructor TBoss4DRegistryEntry.Create;
begin
  inherited Create;
  FVariants := TFPObjectList.Create(True);
end;

destructor TBoss4DRegistryEntry.Destroy;
begin
  FVariants.Free;
  inherited Destroy;
end;

function TBoss4DRegistryEntry.SelectVariant(const APlatform,
  ACompiler: string): TBoss4DArtifactVariant;
var
  I, LScore, LBestScore: Integer;
  LVariant: TBoss4DArtifactVariant;
begin
  Result := nil;
  LBestScore := -1;
  for I := 0 to FVariants.Count - 1 do
  begin
    LVariant := TBoss4DArtifactVariant(FVariants[I]);
    if (LVariant.Platform <> '') and
       not SameText(LVariant.Platform, APlatform) then Continue;
    if (LVariant.Compiler <> '') and
       not SameText(LVariant.Compiler, ACompiler) then Continue;
    LScore := 0;
    if LVariant.Platform <> '' then Inc(LScore, 2);
    if LVariant.Compiler <> '' then Inc(LScore);
    if LScore > LBestScore then
    begin
      Result := LVariant;
      LBestScore := LScore;
    end;
  end;
end;

constructor TBoss4DRegistryEntries.Create;
begin
  inherited Create(True);
end;

function TBoss4DRegistryEntries.GetEntry(
  const AIndex: Integer): TBoss4DRegistryEntry;
begin
  Result := TBoss4DRegistryEntry(Items[AIndex]);
end;

function TBoss4DRegistryEntries.Find(
  const AName: string): TBoss4DRegistryEntry;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if SameText(Entries[I].Name, AName) or
       SameText(Entries[I].Repository, AName) then
      Exit(Entries[I]);
end;

function TBoss4DRegistryEntries.Search(
  const AQuery: string): TBoss4DRegistryEntries;
var
  I: Integer;
  J: Integer;
  LEntry, LCopy: TBoss4DRegistryEntry;
  LVariant, LVariantCopy: TBoss4DArtifactVariant;
  LNeedle: string;
begin
  Result := TBoss4DRegistryEntries.Create;
  LNeedle := LowerCase(AQuery);
  for I := 0 to Count - 1 do
  begin
    LEntry := Entries[I];
    if (LNeedle <> '') and
       (Pos(LNeedle, LowerCase(LEntry.Name)) = 0) and
       (Pos(LNeedle, LowerCase(LEntry.Repository)) = 0) and
       (Pos(LNeedle, LowerCase(LEntry.Description)) = 0) then Continue;
    LCopy := TBoss4DRegistryEntry.Create;
    LCopy.Name := LEntry.Name;
    LCopy.Repository := LEntry.Repository;
    LCopy.Description := LEntry.Description;
    LCopy.Version := LEntry.Version;
    LCopy.LicenseName := LEntry.LicenseName;
    LCopy.ArtifactUrl := LEntry.ArtifactUrl;
    LCopy.ArtifactDigest := LEntry.ArtifactDigest;
    LCopy.SignatureUrl := LEntry.SignatureUrl;
    LCopy.ProvenanceUrl := LEntry.ProvenanceUrl;
    LCopy.Source := LEntry.Source;
    LCopy.Revoked := LEntry.Revoked;
    LCopy.RevocationReason := LEntry.RevocationReason;
    for J := 0 to LEntry.Variants.Count - 1 do
    begin
      LVariant := TBoss4DArtifactVariant(LEntry.Variants[J]);
      LVariantCopy := TBoss4DArtifactVariant.Create;
      LVariantCopy.Platform := LVariant.Platform;
      LVariantCopy.Compiler := LVariant.Compiler;
      LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
      LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
      LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
      LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
      LCopy.Variants.Add(LVariantCopy);
    end;
    Result.Add(LCopy);
  end;
end;

procedure TBoss4DRegistryService.LoadInternal(const ASource: string;
  const AEntries: TBoss4DRegistryEntries; const AVisited: TStringList);
var
  LData: TJSONData;
  LRoot, LObject, LLatest, LVariantOwner, LVariantObject: TJSONObject;
  LIncludes, LSparse, LPackages, LVersions, LVariants, LRevocations: TJSONArray;
  LEntry: TBoss4DRegistryEntry;
  LVariant: TBoss4DArtifactVariant;
  I, J, K: Integer;
  LKey: string;
  LRevocation: TJSONObject;
begin
  CheckCancelled;
  LKey := LowerCase(ASource);
  if AVisited.IndexOf(LKey) >= 0 then Exit;
  AVisited.Add(LKey);
  LData := GetJSON(ReadSource(ASource));
  try
    if not (LData is TJSONObject) then
      raise Exception.Create('registry root must be an object: ' + ASource);
    LRoot := TJSONObject(LData);
    if not (LRoot.Get('schemaVersion', 0) in [1, 2]) then
      raise Exception.Create('unsupported registry schema: ' + ASource);
    LIncludes := FindArray(LRoot, 'includes');
    if Assigned(LIncludes) then
      for I := 0 to LIncludes.Count - 1 do
        LoadInternal(ResolveReference(ASource, LIncludes.Strings[I]),
          AEntries, AVisited);
    LSparse := FindArray(LRoot, 'sparse');
    if Assigned(LSparse) then
      for I := 0 to LSparse.Count - 1 do
        LoadInternal(ResolveReference(ASource, LSparse.Strings[I]),
          AEntries, AVisited);
    LPackages := FindArray(LRoot, 'packages');
    if not Assigned(LPackages) then Exit;
    for I := 0 to LPackages.Count - 1 do
      if LPackages.Items[I] is TJSONObject then
      begin
        LObject := TJSONObject(LPackages.Items[I]);
        LEntry := TBoss4DRegistryEntry.Create;
        LEntry.Name := LObject.Get('name', '');
        LEntry.Repository := LObject.Get('repository', '');
        LEntry.Description := LObject.Get('description', '');
        LEntry.Version := LObject.Get('version', '');
        LEntry.LicenseName := LObject.Get('license', '');
        LEntry.ArtifactUrl := LObject.Get('artifact', '');
        LEntry.ArtifactDigest := LObject.Get('sha256', '');
        LEntry.SignatureUrl := LObject.Get('signature', '');
        LEntry.ProvenanceUrl := LObject.Get('provenance', '');
        LVariantOwner := LObject;
        LVersions := FindArray(LObject, 'versions');
        if Assigned(LVersions) and (LVersions.Count > 0) then
        begin
          LLatest := nil;
          for K := 0 to LVersions.Count - 1 do
            if (LVersions.Items[K] is TJSONObject) and
               not TJSONObject(LVersions.Items[K]).Get('revoked', False) then
            begin
              LLatest := TJSONObject(LVersions.Items[K]);
              Break;
            end;
          if not Assigned(LLatest) and (LVersions.Items[0] is TJSONObject) then
            LLatest := TJSONObject(LVersions.Items[0]);
          if not Assigned(LLatest) then
          begin
            LEntry.Free;
            Continue;
          end;
          LVariantOwner := LLatest;
          LEntry.Version := LLatest.Get('version', LEntry.Version);
          LEntry.Revoked := LLatest.Get('revoked', False);
          LEntry.RevocationReason := LLatest.Get('revocationReason', '');
          LEntry.ArtifactUrl := LLatest.Get('artifact', LEntry.ArtifactUrl);
          LEntry.ArtifactDigest := LLatest.Get('sha256',
            LEntry.ArtifactDigest);
          LEntry.SignatureUrl := LLatest.Get('signature',
            LEntry.SignatureUrl);
          LEntry.ProvenanceUrl := LLatest.Get('provenance',
            LEntry.ProvenanceUrl);
        end;
        LVariants := FindArray(LVariantOwner, 'variants');
        if Assigned(LVariants) then
          for J := 0 to LVariants.Count - 1 do
            if LVariants.Items[J] is TJSONObject then
            begin
              LVariantObject := TJSONObject(LVariants.Items[J]);
              LVariant := TBoss4DArtifactVariant.Create;
              LVariant.Platform := LVariantObject.Get('platform', '');
              LVariant.Compiler := LVariantObject.Get('compiler', '');
              LVariant.ArtifactUrl := LVariantObject.Get('artifact', '');
              LVariant.ArtifactDigest := LVariantObject.Get('sha256', '');
              LVariant.SignatureUrl := LVariantObject.Get('signature', '');
              LVariant.ProvenanceUrl := LVariantObject.Get('provenance', '');
              if (LVariant.ArtifactUrl <> '') and
                 (LVariant.ArtifactDigest <> '') then
                LEntry.Variants.Add(LVariant)
              else
                LVariant.Free;
            end;
        LEntry.Source := ASource;
        if (LEntry.Name <> '') and (LEntry.Repository <> '') and
           not Assigned(AEntries.Find(LEntry.Name)) then
          AEntries.Add(LEntry)
        else
          LEntry.Free;
      end;
    LRevocations := FindArray(LRoot, 'revocations');
    if Assigned(LRevocations) then
      for I := 0 to LRevocations.Count - 1 do
        if LRevocations.Items[I] is TJSONObject then
        begin
          LRevocation := TJSONObject(LRevocations.Items[I]);
          LEntry := AEntries.Find(LRevocation.Get('name', ''));
          if Assigned(LEntry) and
             ((LRevocation.Get('version', '') = '') or
              SameText(LEntry.Version, LRevocation.Get('version', ''))) then
          begin
            LEntry.Revoked := True;
            LEntry.RevocationReason := LRevocation.Get('reason', '');
          end;
        end;
  finally
    LData.Free;
  end;
end;

function TBoss4DRegistryService.Load(const ASource: string;
  const AOffline: Boolean): TBoss4DRegistryEntries;
var
  LVisited: TStringList;
begin
  FOffline := AOffline;
  Result := TBoss4DRegistryEntries.Create;
  LVisited := TStringList.Create;
  try
    try
      LVisited.Sorted := True;
      LVisited.Duplicates := dupIgnore;
      LoadInternal(ASource, Result, LVisited);
    except
      Result.Free;
      raise;
    end;
  finally
    LVisited.Free;
  end;
end;

end.
