unit Boss4D.Adapters.Sbom.Collectors;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Sbom, Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock;

type
  TBoss4DGetItInventoryParser = class
  public
    class procedure Enrich(const AOutput: string; const ADocument: TBoss4DSbomDocument); static;
  end;

  TBoss4DGetItSbomCollector = class(TInterfacedObject, IBoss4DSbomCollector)
  private
    FRegistry: IBoss4DRegistryService;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService);
    function Name: string;
    procedure Collect(const ADocument: TBoss4DSbomDocument;
      const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
      const AProjectDirectory: string);
  end;

  TBoss4DToolchainSbomCollector = class(TInterfacedObject, IBoss4DSbomCollector)
  private
    FRegistry: IBoss4DRegistryService;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService);
    function Name: string;
    procedure Collect(const ADocument: TBoss4DSbomDocument;
      const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
      const AProjectDirectory: string);
  end;

  TBoss4DArtifactSbomCollector = class(TInterfacedObject, IBoss4DSbomCollector)
  public
    function Name: string;
    procedure Collect(const ADocument: TBoss4DSbomDocument;
      const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
      const AProjectDirectory: string);
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Classes, System.RegularExpressions,
  System.Hash, System.Generics.Collections, Boss4D.Core.Domain.Env, Winapi.Windows;

function IdPart(const AValue: string): string;
begin
  Result := AValue.Trim.ToLower.Replace(' ', '-').Replace('\\', '/');
end;

function FileVersion(const APath: string): string;
var
  LHandle, LSize: DWORD;
  LBuffer: TBytes;
  LInfo: PVSFixedFileInfo;
  LInfoSize: UINT;
begin
  Result := '';
  LHandle := 0;
  LSize := GetFileVersionInfoSize(PChar(APath), LHandle);
  if LSize = 0 then Exit;
  SetLength(LBuffer, LSize);
  if not GetFileVersionInfo(PChar(APath), 0, LSize, @LBuffer[0]) then Exit;
  LInfo := nil;
  if VerQueryValue(@LBuffer[0], '\', Pointer(LInfo), LInfoSize) and Assigned(LInfo) then
    Result := Format('%d.%d.%d.%d', [HiWord(LInfo.dwFileVersionMS),
      LoWord(LInfo.dwFileVersionMS), HiWord(LInfo.dwFileVersionLS),
      LoWord(LInfo.dwFileVersionLS)]);
end;

function EnsureRelationship(const ADocument: TBoss4DSbomDocument;
  const AId: string): TBoss4DSbomRelationship;
begin
  Result := ADocument.FindRelationship(AId);
  if not Assigned(Result) then
  begin
    Result := TBoss4DSbomRelationship.Create;
    Result.ComponentId := AId;
    ADocument.Relationships.Add(Result);
  end;
end;

procedure Link(const ADocument: TBoss4DSbomDocument; const AFrom, ATo: string);
var
  LRelationship: TBoss4DSbomRelationship;
begin
  LRelationship := EnsureRelationship(ADocument, AFrom);
  if not LRelationship.DependsOn.Contains(ATo) then
    LRelationship.DependsOn.Add(ATo);
end;

procedure AddToolchainFile(const ADocument: TBoss4DSbomDocument;
  const AToolchainId, ARoot, ARelativePath, ARole, APlatform: string);
begin
  var LPath := TPath.Combine(ARoot, ARelativePath);
  if not TFile.Exists(LPath) then
  begin
    ADocument.Issues.Add('Arquivo da toolchain nao encontrado: ' + ARelativePath);
    Exit;
  end;
  var LDigest := THashSHA2.GetHashStringFromFile(LPath);
  var LComponent := TBoss4DSbomComponent.Create;
  LComponent.Id := 'boss4d:toolchain-file:' + IdPart(ARelativePath) + '@' +
    LDigest.Substring(0, 16).ToLower;
  LComponent.Name := TPath.GetFileName(LPath);
  LComponent.Version := FileVersion(LPath);
  LComponent.ComponentType := FileComponent;
  LComponent.Properties.AddOrSetValue('boss4d:role', ARole);
  LComponent.Properties.AddOrSetValue('boss4d:platform', APlatform);
  LComponent.Properties.AddOrSetValue('boss4d:installationRelativePath', ARelativePath);
  var LHash := TBoss4DSbomHash.Create;
  LHash.Algorithm := 'SHA-256';
  LHash.Value := LDigest;
  LComponent.Hashes.Add(LHash);
  ADocument.Components.Add(LComponent);
  Link(ADocument, AToolchainId, LComponent.Id);
end;

constructor TBoss4DGetItSbomCollector.Create(const ARegistry: IBoss4DRegistryService);
begin
  inherited Create;
  FRegistry := ARegistry;
end;

class procedure TBoss4DGetItInventoryParser.Enrich(const AOutput: string;
  const ADocument: TBoss4DSbomDocument);
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    for var LLine in LLines do
    begin
      var LMatch := TRegEx.Match(LLine, '^\s*(\S+)\s{2,}(\S+)\s{2,}(.+)$');
      if not LMatch.Success or SameText(LMatch.Groups[1].Value, 'Id') or
         LMatch.Groups[1].Value.StartsWith('--') then Continue;
      var LDeclaredComponent: TBoss4DSbomComponent := nil;
      for var LExistingComponent in ADocument.Components do
      begin
        var LSource: string;
        if LExistingComponent.Properties.TryGetValue('boss4d:source', LSource) and
           SameText(LSource, 'getit') and SameText(LExistingComponent.Name,
             LMatch.Groups[1].Value) and
           (LExistingComponent.Version.IsEmpty or
             SameText(LExistingComponent.Version, LMatch.Groups[2].Value)) then
        begin
          LDeclaredComponent := LExistingComponent;
          Break;
        end;
      end;
      if Assigned(LDeclaredComponent) then
      begin
        if LDeclaredComponent.Version.IsEmpty then
          LDeclaredComponent.Version := LMatch.Groups[2].Value;
        LDeclaredComponent.Properties.AddOrSetValue('boss4d:installed', 'true');
        LDeclaredComponent.Properties.AddOrSetValue('boss4d:discoveredBy', 'GetItCmd');
        Continue;
      end;
      var LComponent := TBoss4DSbomComponent.Create;
      LComponent.Id := 'boss4d:getit:' + IdPart(LMatch.Groups[1].Value) + '@' +
        IdPart(LMatch.Groups[2].Value);
      LComponent.Name := LMatch.Groups[1].Value;
      LComponent.Version := LMatch.Groups[2].Value;
      LComponent.Description := LMatch.Groups[3].Value.Trim;
      LComponent.ComponentType := LibraryComponent;
      LComponent.Properties.AddOrSetValue('boss4d:discoveredBy', 'GetItCmd');
      LComponent.Properties.AddOrSetValue('boss4d:inventoryScope', 'environment');
      LComponent.Properties.AddOrSetValue('boss4d:usage', 'unknown');
      ADocument.Components.Add(LComponent);
    end;
    for var LComponent in ADocument.Components do
    begin
      var LSource, LInstalled: string;
      if LComponent.Properties.TryGetValue('boss4d:source', LSource) and
         SameText(LSource, 'getit') and
         not (LComponent.Properties.TryGetValue('boss4d:installed', LInstalled) and
           SameText(LInstalled, 'true')) then
        ADocument.Issues.Add('Componente GetIt declarado nao esta instalado: ' +
          LComponent.Name + '@' + LComponent.Version);
    end;
    ADocument.Coverage := ADocument.Coverage + ',getit-installed';
  finally
    LLines.Free;
  end;
end;

function TBoss4DGetItSbomCollector.Name: string;
begin
  Result := 'getit';
end;

procedure TBoss4DGetItSbomCollector.Collect(const ADocument: TBoss4DSbomDocument;
  const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
  const AProjectDirectory: string);
var
  LVersions: TArray<string>;
  LRoot, LCommand, LOutput: string;
begin
  LVersions := FRegistry.GetInstalledDelphiVersions;
  TArray.Sort<string>(LVersions);
  LCommand := '';
  for var I := High(LVersions) downto 0 do
  begin
    LRoot := FRegistry.GetDelphiPath(LVersions[I]);
    var LCandidate := TPath.Combine(TPath.Combine(LRoot, 'bin'), 'GetItCmd.exe');
    if TFile.Exists(LCandidate) then
    begin
      LCommand := LCandidate;
      Break;
    end;
  end;
  if LCommand.IsEmpty then
    raise Exception.Create('GetItCmd.exe nao encontrado');
  if not ExecuteCommandLine('"' + LCommand + '" -l= -f=installed -v=normal',
    AProjectDirectory, LOutput) then
    raise Exception.Create('inventario GetIt nao pode ser consultado');

  TBoss4DGetItInventoryParser.Enrich(LOutput, ADocument);
end;

constructor TBoss4DToolchainSbomCollector.Create(const ARegistry: IBoss4DRegistryService);
begin
  inherited Create;
  FRegistry := ARegistry;
end;

function TBoss4DToolchainSbomCollector.Name: string;
begin
  Result := 'delphi-toolchain';
end;

procedure TBoss4DToolchainSbomCollector.Collect(const ADocument: TBoss4DSbomDocument;
  const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
  const AProjectDirectory: string);
begin
  var LVersions := FRegistry.GetInstalledDelphiVersions;
  if Length(LVersions) = 0 then
    raise Exception.Create('nenhuma instalacao Delphi detectada');
  TArray.Sort<string>(LVersions);
  for var LVersion in LVersions do
  begin
    var LDelphiRoot := FRegistry.GetDelphiPath(LVersion);
    if LDelphiRoot.IsEmpty then Continue;
    var LComponent := TBoss4DSbomComponent.Create;
    LComponent.Id := 'boss4d:toolchain:rad-studio@' + IdPart(LVersion);
    LComponent.Name := 'Embarcadero RAD Studio';
    LComponent.Version := LVersion;
    LComponent.Description := 'Delphi compiler, RTL and build toolchain';
    LComponent.ComponentType := ToolComponent;
    LComponent.Properties.AddOrSetValue('boss4d:includes', 'Delphi compiler;RTL');
    LComponent.Properties.AddOrSetValue('boss4d:discoveredBy', 'BDS registry');
    ADocument.Components.Add(LComponent);
    Link(ADocument, ADocument.RootComponentId, LComponent.Id);
    AddToolchainFile(ADocument, LComponent.Id, LDelphiRoot, 'bin\dcc32.exe',
      'compiler', 'Win32');
    AddToolchainFile(ADocument, LComponent.Id, LDelphiRoot, 'bin\dcc64.exe',
      'compiler', 'Win64');
    AddToolchainFile(ADocument, LComponent.Id, LDelphiRoot,
      'lib\win32\release\System.dcu', 'rtl', 'Win32');
    AddToolchainFile(ADocument, LComponent.Id, LDelphiRoot,
      'lib\win64\release\System.dcu', 'rtl', 'Win64');
  end;
  ADocument.Coverage := ADocument.Coverage + ',delphi-toolchain-rtl';
end;

function TBoss4DArtifactSbomCollector.Name: string;
begin
  Result := 'binary-artifacts';
end;

procedure TBoss4DArtifactSbomCollector.Collect(const ADocument: TBoss4DSbomDocument;
  const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
  const AProjectDirectory: string);

  procedure AddArtifacts(const AOwnerId, ADependencyName, ABase: string;
    const APaths: TList<string>);
  begin
    for var LDeclaredPath in APaths do
    begin
      var LPath := LDeclaredPath;
      var LBasePath := AProjectDirectory;
      if SameText(ABase, 'module') then
        LBasePath := TPath.Combine(TPath.Combine(AProjectDirectory, 'modules'), ADependencyName)
      else if SameText(ABase, 'absolute') then
      begin
        if not TPath.IsPathRooted(LPath) then
        begin
          ADocument.Issues.Add('Artefato com base absolute deve usar caminho absoluto: ' + LDeclaredPath);
          Continue;
        end;
      end
      else if not SameText(ABase, 'project') then
      begin
        ADocument.Issues.Add('Base de artefato desconhecida: ' + ABase);
        Continue;
      end;
      if not SameText(ABase, 'absolute') then
      begin
        if TPath.IsPathRooted(LPath) then
        begin
          ADocument.Issues.Add('Artefato absoluto nao permitido para base ' + ABase + ': ' + LDeclaredPath);
          Continue;
        end;
        LPath := TPath.GetFullPath(TPath.Combine(LBasePath, LPath));
        LBasePath := TPath.GetFullPath(LBasePath);
        if not LPath.StartsWith(LBasePath + TPath.DirectorySeparatorChar, True) and
           not SameText(LPath, LBasePath) then
        begin
          ADocument.Issues.Add('Artefato escapa da base ' + ABase + ': ' + LDeclaredPath);
          Continue;
        end;
      end;
      if not TFile.Exists(LPath) then
      begin
        ADocument.Issues.Add('Artefato declarado nao encontrado: ' + LDeclaredPath);
        Continue;
      end;
      var LComponent := TBoss4DSbomComponent.Create;
      LComponent.Id := 'boss4d:file:' + IdPart(LDeclaredPath);
      LComponent.Name := TPath.GetFileName(LPath);
      LComponent.ComponentType := FileComponent;
      LComponent.Properties.AddOrSetValue('boss4d:declaredPath', LDeclaredPath);
      LComponent.Properties.AddOrSetValue('boss4d:pathBase', ABase);
      LComponent.Properties.AddOrSetValue('boss4d:discoveredBy', 'boss-lock.json:artifacts');
      var LHash := TBoss4DSbomHash.Create;
      LHash.Algorithm := 'SHA-256';
      LHash.Value := THashSHA2.GetHashStringFromFile(LPath);
      LComponent.Hashes.Add(LHash);
      ADocument.Components.Add(LComponent);
      Link(ADocument, AOwnerId, LComponent.Id);
    end;
  end;

begin
  for var LPair in ALock.Installed do
  begin
    var LLocked := LPair.Value;
    var LIdentityVersion := LLocked.Revision;
    if LIdentityVersion.IsEmpty then LIdentityVersion := LLocked.Version;
    var LOwnerId := 'boss4d:git:' + IdPart(LLocked.Repository) + '@' + IdPart(LIdentityVersion);
    AddArtifacts(LOwnerId, LLocked.Name, LLocked.Artifacts.Base, LLocked.Artifacts.Bin);
    AddArtifacts(LOwnerId, LLocked.Name, LLocked.Artifacts.Base, LLocked.Artifacts.Dcp);
    AddArtifacts(LOwnerId, LLocked.Name, LLocked.Artifacts.Base, LLocked.Artifacts.Dcu);
    AddArtifacts(LOwnerId, LLocked.Name, LLocked.Artifacts.Base, LLocked.Artifacts.Bpl);
  end;
  ADocument.Coverage := ADocument.Coverage + ',declared-binary-artifacts';
end;

end.
