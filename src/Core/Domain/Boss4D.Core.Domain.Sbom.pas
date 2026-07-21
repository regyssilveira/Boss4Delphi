unit Boss4D.Core.Domain.Sbom;

interface

uses
  System.Generics.Collections;

type
  TBoss4DSbomComponentType = (ApplicationComponent, LibraryComponent, FrameworkComponent,
    ToolComponent, FileComponent, UnknownComponent);
  TBoss4DSbomCompleteness = (Complete, Incomplete, Unknown);
  TBoss4DSbomReferenceType = (VCS, Website, Distribution, Documentation, Other);
  TBoss4DSbomLicenseKind = (SpdxExpressionLicense, NamedLicense, ProprietaryLicense,
    MissingLicense, UnknownLicense);

  TBoss4DSbomHash = class
  private
    FAlgorithm: string;
    FValue: string;
  public
    property Algorithm: string read FAlgorithm write FAlgorithm;
    property Value: string read FValue write FValue;
  end;

  TBoss4DSbomLicense = class
  private
    FExpression: string;
    FName: string;
    FSource: string;
    FKind: TBoss4DSbomLicenseKind;
  public
    property Expression: string read FExpression write FExpression;
    property Name: string read FName write FName;
    property Source: string read FSource write FSource;
    property Kind: TBoss4DSbomLicenseKind read FKind write FKind;
  end;

  TBoss4DSbomExternalReference = class
  private
    FReferenceType: TBoss4DSbomReferenceType;
    FURL: string;
  public
    property ReferenceType: TBoss4DSbomReferenceType read FReferenceType write FReferenceType;
    property URL: string read FURL write FURL;
  end;

  TBoss4DSbomComponent = class
  private
    FId: string;
    FName: string;
    FVersion: string;
    FDescription: string;
    FComponentType: TBoss4DSbomComponentType;
    FRevision: string;
    FHashes: TObjectList<TBoss4DSbomHash>;
    FLicenses: TObjectList<TBoss4DSbomLicense>;
    FExternalReferences: TObjectList<TBoss4DSbomExternalReference>;
    FProperties: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;

    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property Description: string read FDescription write FDescription;
    property ComponentType: TBoss4DSbomComponentType read FComponentType write FComponentType;
    property Revision: string read FRevision write FRevision;
    property Hashes: TObjectList<TBoss4DSbomHash> read FHashes;
    property Licenses: TObjectList<TBoss4DSbomLicense> read FLicenses;
    property ExternalReferences: TObjectList<TBoss4DSbomExternalReference> read FExternalReferences;
    property Properties: TDictionary<string, string> read FProperties;
  end;

  TBoss4DSbomRelationship = class
  private
    FComponentId: string;
    FDependsOn: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    property ComponentId: string read FComponentId write FComponentId;
    property DependsOn: TList<string> read FDependsOn;
  end;

  TBoss4DSbomDocument = class
  private
    FRootComponentId: string;
    FToolName: string;
    FToolVersion: string;
    FLifecycle: string;
    FCoverage: string;
    FCompleteness: TBoss4DSbomCompleteness;
    FComponents: TObjectList<TBoss4DSbomComponent>;
    FRelationships: TObjectList<TBoss4DSbomRelationship>;
    FIssues: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    function FindComponent(const AId: string): TBoss4DSbomComponent;
    function FindRelationship(const AComponentId: string): TBoss4DSbomRelationship;

    property RootComponentId: string read FRootComponentId write FRootComponentId;
    property ToolName: string read FToolName write FToolName;
    property ToolVersion: string read FToolVersion write FToolVersion;
    property Lifecycle: string read FLifecycle write FLifecycle;
    property Coverage: string read FCoverage write FCoverage;
    property Completeness: TBoss4DSbomCompleteness read FCompleteness write FCompleteness;
    property Components: TObjectList<TBoss4DSbomComponent> read FComponents;
    property Relationships: TObjectList<TBoss4DSbomRelationship> read FRelationships;
    property Issues: TList<string> read FIssues;
  end;

implementation

uses
  System.SysUtils;

constructor TBoss4DSbomComponent.Create;
begin
  inherited Create;
  FComponentType := UnknownComponent;
  FHashes := TObjectList<TBoss4DSbomHash>.Create(True);
  FLicenses := TObjectList<TBoss4DSbomLicense>.Create(True);
  FExternalReferences := TObjectList<TBoss4DSbomExternalReference>.Create(True);
  FProperties := TDictionary<string, string>.Create;
end;

destructor TBoss4DSbomComponent.Destroy;
begin
  FProperties.Free;
  FExternalReferences.Free;
  FLicenses.Free;
  FHashes.Free;
  inherited Destroy;
end;

constructor TBoss4DSbomRelationship.Create;
begin
  inherited Create;
  FDependsOn := TList<string>.Create;
end;

destructor TBoss4DSbomRelationship.Destroy;
begin
  FDependsOn.Free;
  inherited Destroy;
end;

constructor TBoss4DSbomDocument.Create;
begin
  inherited Create;
  FCompleteness := Unknown;
  FComponents := TObjectList<TBoss4DSbomComponent>.Create(True);
  FRelationships := TObjectList<TBoss4DSbomRelationship>.Create(True);
  FIssues := TList<string>.Create;
end;

destructor TBoss4DSbomDocument.Destroy;
begin
  FIssues.Free;
  FRelationships.Free;
  FComponents.Free;
  inherited Destroy;
end;

function TBoss4DSbomDocument.FindComponent(const AId: string): TBoss4DSbomComponent;
begin
  for var LComponent in FComponents do
    if SameText(LComponent.Id, AId) then
      Exit(LComponent);
  Result := nil;
end;

function TBoss4DSbomDocument.FindRelationship(const AComponentId: string): TBoss4DSbomRelationship;
begin
  for var LRelationship in FRelationships do
    if SameText(LRelationship.ComponentId, AComponentId) then
      Exit(LRelationship);
  Result := nil;
end;

end.
