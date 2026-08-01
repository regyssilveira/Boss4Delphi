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
    procedure WriteText(const AFileName, AContent: string);
    procedure WriteGuiTemplate(const AName, ATargetDirectory: string;
      const AFmx: Boolean);
    procedure WriteApiTemplate(const AName, ATargetDirectory: string);
    procedure WriteDUnitXTemplate(const AName, ATargetDirectory: string);
    procedure WriteLazarusTemplate(const AName, ATargetDirectory: string;
      const APackage: Boolean);
    procedure WriteWorkspaceTemplate(const AName, ATargetDirectory: string);
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

procedure TBoss4DScaffoldService.WriteText(const AFileName,
  AContent: string);
var
  LEncoding: TEncoding;
begin
  TDirectory.CreateDirectory(TPath.GetDirectoryName(AFileName));
  LEncoding := TUTF8Encoding.Create(False);
  try
    TFile.WriteAllText(AFileName, AContent, LEncoding);
  finally
    LEncoding.Free;
  end;
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

procedure TBoss4DScaffoldService.WriteGuiTemplate(const AName,
  ATargetDirectory: string; const AFmx: Boolean);
var
  LFramework, LFormUnit: string;
begin
  if AFmx then
  begin
    LFramework := 'FMX.Forms';
    LFormUnit := 'FMX.Forms';
  end
  else
  begin
    LFramework := 'Vcl.Forms';
    LFormUnit := 'Vcl.Forms';
  end;
  WriteText(TPath.Combine(ATargetDirectory, AName + '.dpr'),
    'program ' + AName + ';' + sLineBreak + sLineBreak +
    'uses' + sLineBreak + '  ' + LFramework + ',' + sLineBreak +
    '  MainView in ''src\MainView.pas'';' + sLineBreak + sLineBreak +
    'begin' + sLineBreak + '  Application.Initialize;' + sLineBreak +
    '  Application.CreateForm(TMainForm, MainForm);' + sLineBreak +
    '  Application.Run;' + sLineBreak + 'end.');
  WriteText(TPath.Combine(ATargetDirectory, 'src\MainView.pas'),
    'unit MainView;' + sLineBreak + 'interface' + sLineBreak +
    'uses ' + LFormUnit + ';' + sLineBreak +
    'type TMainForm = class(TForm);' + sLineBreak +
    'var MainForm: TMainForm;' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
end;

procedure TBoss4DScaffoldService.WriteApiTemplate(const AName,
  ATargetDirectory: string);
begin
  WriteText(TPath.Combine(ATargetDirectory, AName + '.dpr'),
    'program ' + AName + ';' + sLineBreak + sLineBreak +
    '{$APPTYPE CONSOLE}' + sLineBreak + 'uses Horse, Dext;' + sLineBreak +
    'begin' + sLineBreak +
    '  THorse.Get(''/'', procedure(Req: THorseRequest; Res: THorseResponse)' +
    ' begin Res.Send(''Boss4D API''); end);' + sLineBreak +
    '  THorse.Listen(9000);' + sLineBreak + 'end.');
end;

procedure TBoss4DScaffoldService.WriteDUnitXTemplate(const AName,
  ATargetDirectory: string);
begin
  WriteText(TPath.Combine(ATargetDirectory, AName + '.dpr'),
    'program ' + AName + ';' + sLineBreak +
    '{$APPTYPE CONSOLE}' + sLineBreak +
    'uses DUnitX.TestFramework, DUnitX.Loggers.Console;' + sLineBreak +
    'begin DUnitX.TestFramework.TDUnitX.CreateRunner.Execute; end.');
  WriteText(TPath.Combine(ATargetDirectory, 'tests\Sample.Tests.pas'),
    'unit Sample.Tests;' + sLineBreak + 'interface' + sLineBreak +
    'uses DUnitX.TestFramework;' + sLineBreak +
    'type [TestFixture] TSampleTests = class' + sLineBreak +
    '  [Test] procedure Passes;' + sLineBreak + 'end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TSampleTests.Passes; begin Assert.IsTrue(True); end;' +
    sLineBreak + 'end.');
end;

procedure TBoss4DScaffoldService.WriteLazarusTemplate(const AName,
  ATargetDirectory: string; const APackage: Boolean);
begin
  if APackage then
  begin
    WritePackageTemplate(AName, ATargetDirectory);
    WriteText(TPath.Combine(ATargetDirectory, AName + '.lpk'),
      '<?xml version="1.0"?><CONFIG><Package><Name Value="' + AName +
      '"/><Files Count="1"><Item1><Filename Value="src/' + AName +
      '.pas"/></Item1></Files></Package></CONFIG>');
  end
  else
  begin
    WriteText(TPath.Combine(ATargetDirectory, AName + '.lpr'),
      'program ' + AName + '; uses SysUtils; begin Writeln(''' +
      AName + '''); end.');
    WriteText(TPath.Combine(ATargetDirectory, AName + '.lpi'),
      '<?xml version="1.0"?><CONFIG><ProjectOptions><General>' +
      '<MainUnit Value="0"/></General><Units Count="1"><Unit0>' +
      '<Filename Value="' + AName + '.lpr"/></Unit0></Units>' +
      '</ProjectOptions></CONFIG>');
  end;
end;

procedure TBoss4DScaffoldService.WriteWorkspaceTemplate(const AName,
  ATargetDirectory: string);
begin
  for var LChild in TArray<string>.Create('apps\app', 'packages\shared') do
  begin
    var LChildDir := TPath.Combine(ATargetDirectory, LChild);
    TDirectory.CreateDirectory(LChildDir);
    var LChildPackage := TBoss4DPackage.Create;
    try
      LChildPackage.Name := TPath.GetFileName(LChildDir);
      LChildPackage.Version := '1.0.0';
      FPackageRepository.Save(LChildPackage,
        TPath.Combine(LChildDir, FILE_PACKAGE));
    finally
      LChildPackage.Free;
    end;
  end;
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
  if not SameText(ATemplate, 'app') and not SameText(ATemplate, 'package') and
     not SameText(ATemplate, 'vcl') and not SameText(ATemplate, 'fmx') and
     not SameText(ATemplate, 'api') and not SameText(ATemplate, 'horse-api') and
     not SameText(ATemplate, 'dext-api') and not SameText(ATemplate, 'dunitx') and
     not SameText(ATemplate, 'lazarus-app') and
     not SameText(ATemplate, 'lazarus-package') and
     not SameText(ATemplate, 'workspace') then
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
    else if SameText(ATemplate, 'package') then
      WritePackageTemplate(AName, LTargetDirectory);
    if SameText(ATemplate, 'vcl') or SameText(ATemplate, 'fmx') then
    begin
      LPackage.AddProject(AName + '.dpr');
      WriteGuiTemplate(AName, LTargetDirectory, SameText(ATemplate, 'fmx'));
    end;
    if SameText(ATemplate, 'api') or SameText(ATemplate, 'horse-api') or
       SameText(ATemplate, 'dext-api') then
    begin
      LPackage.AddProject(AName + '.dpr');
      LPackage.AddDependency('github.com/hashload/horse', '^3.0.0');
      LPackage.AddDependency('github.com/cesarliws/dext', '*');
      WriteApiTemplate(AName, LTargetDirectory);
    end;
    if SameText(ATemplate, 'dunitx') then
    begin
      LPackage.AddProject(AName + '.dpr');
      LPackage.AddDevDependency('github.com/VSoftTechnologies/DUnitX', '*');
      WriteDUnitXTemplate(AName, LTargetDirectory);
    end;
    if SameText(ATemplate, 'lazarus-app') then
    begin
      LPackage.AddProject(AName + '.lpi');
      WriteLazarusTemplate(AName, LTargetDirectory, False);
    end;
    if SameText(ATemplate, 'lazarus-package') then
    begin
      LPackage.AddProject(AName + '.lpk');
      WriteLazarusTemplate(AName, LTargetDirectory, True);
    end;
    if SameText(ATemplate, 'workspace') then
    begin
      LPackage.Workspaces.Add('apps/*');
      LPackage.Workspaces.Add('packages/*');
      WriteWorkspaceTemplate(AName, LTargetDirectory);
    end;
    FPackageRepository.Save(LPackage,
      TPath.Combine(LTargetDirectory, FILE_PACKAGE));
  finally
    LPackage.Free;
  end;
  FLogger.Log(TBoss4DLogLevel.Info, 'Projeto criado em: ' + LTargetDirectory);
end;

end.
