unit Boss4D.Core.Ports;

interface

uses
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Sbom;

type
  { Niveis de log suportados pelo sistema }
  TBoss4DLogLevel = (Debug, Info, Warning, Error);

  { Execucao de processos isolada do sistema operacional hospedeiro. }
  IBoss4DProcessRunner = interface
    ['{69527D56-F14E-43D4-A746-2D7227D6000D}']
    function Execute(const ACommandLine, AWorkingDirectory: string;
      out AOutput: string): Boolean;
  end;

  { Operacoes de ambiente e filesystem que variam entre plataformas. }
  IBoss4DPlatformEnvironment = interface
    ['{69527D56-F14E-43D4-A746-2D7227D6000E}']
    function PlatformName: string;
    function HomePath: string;
    function CurrentDirectory: string;
    procedure MakeFileWritable(const APath: string);
    function SupportsWindowsRegistry: Boolean;
    function SupportsGetIt: Boolean;
  end;

  { Criacao e remocao de links de diretorio sem expor comandos do host. }
  IBoss4DFileLinkService = interface
    ['{69527D56-F14E-43D4-A746-2D7227D6000F}']
    function RemoveDirectoryLink(const ALinkPath: string): Boolean;
    function CreateDirectoryLink(const ATargetPath, ALinkPath: string): Boolean;
  end;

  { Contrato para logs e diagnosticos }
  IBoss4DLogger = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60001}']
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string); overload;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const); overload;
    procedure SetDebugMode(const AEnabled: Boolean);
  end;

  { Contrato para persistencia do arquivo boss.json }
  IBoss4DPackageRepository = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60002}']
    function Load(const APackagePath: string): TBoss4DPackage;
    procedure Save(const APackage: TBoss4DPackage; const APackagePath: string);
    function Exists(const APackagePath: string): Boolean;
  end;

  { Contrato para persistencia do arquivo boss.lock }
  IBoss4DLockRepository = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60003}']
    function Load(const ALockPath: string): TBoss4DLock;
    procedure Save(const ALock: TBoss4DLock; const ALockPath: string);
    function Exists(const ALockPath: string): Boolean;
  end;

  { Contrato para serializadores SBOM interoperaveis }
  IBoss4DSbomWriter = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60008}']
    function Serialize(const ADocument: TBoss4DSbomDocument;
      const AReproducible: Boolean = False): string;
    function Validate(const AContent: string; out AError: string): Boolean;
  end;

  { Coletor opcional que enriquece o modelo neutro com evidencia do ambiente }
  IBoss4DSbomCollector = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60009}']
    function Name: string;
    procedure Collect(const ADocument: TBoss4DSbomDocument;
      const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
      const AProjectDirectory: string);
  end;

  { Extensao neutra para merge, enriquecimento SCA e documentos VEX }
  IBoss4DSbomTransformer = interface
    ['{69527D56-F14E-43D4-A746-2D7227D6000A}']
    procedure Transform(const ADocument: TBoss4DSbomDocument);
  end;

  { Extensao pos-serializacao para assinatura/atestacao sem acoplar o dominio }
  IBoss4DSbomSigner = interface
    ['{69527D56-F14E-43D4-A746-2D7227D6000B}']
    function Sign(const AContent, AFormat: string): string;
  end;

  { Atestacao destacada, verificavel sem alterar o documento SBOM original }
  IBoss4DSbomAttestor = interface
    ['{69527D56-F14E-43D4-A746-2D7227D6000C}']
    function CreateAttestation(const AContent, AFormat: string): string;
    function VerifyAttestation(const AContent, AAttestation: string;
      out AError: string): Boolean;
  end;

  { Contrato para operacoes de Git }
  IBoss4DGitClient = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60004}']
    procedure CloneCache(const ADep: TBoss4DDependency; const ATargetDir: string);
    procedure UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
    function GetVersions(const ACacheDir: string): TArray<string>;
    function ResolveRevision(const ACacheDir: string; const AVersion: string): string;
    function VerifyCommit(const ACacheDir, ARevision: string;
      out ASigner: string): Boolean;
    function VerifyTag(const ACacheDir, ATag: string;
      out ASigner: string): Boolean;
    procedure Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
  end;

  { Contrato para chamadas HTTP REST }
  IBoss4DHttpClient = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60005}']
    function Get(const AURL: string; out AResponse: string): Integer;
    function PostJson(const AURL, ABody: string;
      out AResponse: string): Integer;
    function PostJsonAuthorized(const AURL, ABody, ABearerToken: string;
      out AResponse: string): Integer;
    function DownloadToFile(const AURL, ATargetPath: string): Integer;
  end;

  IBoss4DSelfUpdateApplier = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60012}']
    procedure LaunchVerifiedInstaller(const AInstallerPath: string);
  end;

  IBoss4DCredentialStore = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60013}']
    procedure SetSecret(const AName, AValue: string);
    function GetSecret(const AName: string): string;
    procedure DeleteSecret(const AName: string);
  end;

  IBoss4DPackageSigner = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60014}']
    function Sign(const AArtifactPath, AKeyId: string): string;
    function Verify(const AArtifactPath, ASignaturePath: string): Boolean;
  end;

  { Contrato para compilacao de dependencias Delphi e search paths }
  IBoss4DCompiler = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60006}']
    function Compile(const AProjectPath: string; const ADep: TBoss4DDependency;
      const ARootLock: TBoss4DLock; const APlatform: string = '';
      const ACompilerVersion: string = '';
      const AConfiguration: string = ''): Boolean;
    function BuildSearchPath(const ADep: TBoss4DDependency; const APlatform: string = ''): string;
  end;

  { Contrato para deteccao das IDEs Delphi no Windows Registry }
  IBoss4DRegistryService = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60007}']
    function GetInstalledDelphiVersions: TArray<string>;
    function GetDelphiPath(const AVersion: string): string;
  end;

implementation

end.
