unit Boss4D.Core.Services.Scaffold;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DScaffoldService = class
  private
    FPackageRepository: IBoss4DPackageRepository;
    FLogger: IBoss4DLogger;
    procedure EnsureTargetIsAvailable(const ATargetDirectory: string);
    procedure WriteApplicationTemplate(const AName, ATargetDirectory: string);
    procedure WritePackageTemplate(const AName, ATargetDirectory: string);
  public
    constructor Create(const APackageRepository: IBoss4DPackageRepository;
      const ALogger: IBoss4DLogger);
    procedure Execute(const ATemplate, AName, ATargetDirectory: string);
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Consts;

constructor TBoss4DScaffoldService.Create(
  const APackageRepository: IBoss4DPackageRepository;
  const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepository := APackageRepository;
  FLogger := ALogger;
end;

procedure TBoss4DScaffoldService.EnsureTargetIsAvailable(
  const ATargetDirectory: string);
begin
  if TDirectory.Exists(ATargetDirectory) and
     (Length(TDirectory.GetFileSystemEntries(ATargetDirectory)) > 0) then
    raise EInvalidOpException.Create('O diretorio de destino nao esta vazio: ' +
      ATargetDirectory);
  TDirectory.CreateDirectory(ATargetDirectory);
  TDirectory.CreateDirectory(TPath.Combine(ATargetDirectory, 'src'));
  TDirectory.CreateDirectory(TPath.Combine(ATargetDirectory, 'tests'));
end;

procedure TBoss4DScaffoldService.WriteApplicationTemplate(
  const AName, ATargetDirectory: string);
var
  LProject: TStringList;
  LEncoding: TEncoding;
begin
  LProject := TStringList.Create;
  LEncoding := TUTF8Encoding.Create(False);
  try
    LProject.Add('program ' + AName + ';');
    LProject.Add('');
    LProject.Add('{$APPTYPE CONSOLE}');
    LProject.Add('');
    LProject.Add('uses');
    LProject.Add('  System.SysUtils;');
    LProject.Add('');
    LProject.Add('begin');
    LProject.Add('  Writeln(''Hello from ' + AName + ''');');
    LProject.Add('end.');
    LProject.SaveToFile(TPath.Combine(ATargetDirectory, AName + '.dpr'),
      LEncoding);
  finally
    LEncoding.Free;
    LProject.Free;
  end;
end;

procedure TBoss4DScaffoldService.WritePackageTemplate(
  const AName, ATargetDirectory: string);
var
  LUnit: TStringList;
  LEncoding: TEncoding;
begin
  LUnit := TStringList.Create;
  LEncoding := TUTF8Encoding.Create(False);
  try
    LUnit.Add('unit ' + AName + ';');
    LUnit.Add('');
    LUnit.Add('interface');
    LUnit.Add('');
    LUnit.Add('implementation');
    LUnit.Add('');
    LUnit.Add('end.');
    LUnit.SaveToFile(TPath.Combine(TPath.Combine(ATargetDirectory, 'src'),
      AName + '.pas'), LEncoding);
  finally
    LEncoding.Free;
    LUnit.Free;
  end;
end;

procedure TBoss4DScaffoldService.Execute(const ATemplate, AName,
  ATargetDirectory: string);
var
  LTargetDirectory: string;
  LPackage: TBoss4DPackage;
begin
  if AName.Trim.IsEmpty then
    raise EArgumentException.Create('Informe o nome do projeto.');
  if not SameText(ATemplate, 'app') and not SameText(ATemplate, 'package') then
    raise EArgumentException.Create('Template desconhecido: ' + ATemplate);

  LTargetDirectory := TPath.GetFullPath(ATargetDirectory);
  EnsureTargetIsAvailable(LTargetDirectory);
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := AName;
    LPackage.Version := '1.0.0';
    LPackage.Description := 'Projeto criado pelo Boss4D';
    LPackage.MainSrc := 'src';
    if SameText(ATemplate, 'app') then
    begin
      LPackage.AddProject(AName + '.dpr');
      WriteApplicationTemplate(AName, LTargetDirectory);
    end
    else
      WritePackageTemplate(AName, LTargetDirectory);
    FPackageRepository.Save(LPackage,
      TPath.Combine(LTargetDirectory, FILE_PACKAGE));
  finally
    LPackage.Free;
  end;
  FLogger.Log(TBoss4DLogLevel.Info, 'Projeto criado em: ' + LTargetDirectory);
end;

end.
