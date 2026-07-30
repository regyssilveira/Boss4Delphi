unit Boss4D.Tests.LazarusProject;

interface

uses
  DUnitX.TestFramework, System.SysUtils, System.IOUtils,
  Boss4D.Core.Services.LazarusProject;

type
  [TestFixture]
  TTestsLazarusProject = class
  private
    FTempDir: string;
    function WriteFixture(const AFileName, AContent: string): string;
    function CountText(const AContent, AValue: string): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure UpdatesProjectAndEveryBuildMode;
    [Test]
    procedure UpdatesLazarusPackage;
    [Test]
    procedure IsDeterministicAndIdempotent;
    [Test]
    procedure RejectsMissingProject;
  end;

implementation

function TTestsLazarusProject.WriteFixture(const AFileName,
  AContent: string): string;
begin
  Result := TPath.Combine(FTempDir, AFileName);
  TFile.WriteAllText(Result, AContent, TEncoding.UTF8);
end;

function TTestsLazarusProject.CountText(const AContent,
  AValue: string): Integer;
var
  LOffset: Integer;
begin
  Result := 0;
  LOffset := 1;
  repeat
    LOffset := Pos(AValue, AContent, LOffset);
    if LOffset = 0 then
      Break;
    Inc(Result);
    Inc(LOffset, Length(AValue));
  until False;
end;

procedure TTestsLazarusProject.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath,
    'Boss4DLazarus_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TTestsLazarusProject.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestsLazarusProject.UpdatesProjectAndEveryBuildMode;
var
  LProjectPath: string;
  LContent: string;
begin
  LProjectPath := WriteFixture('sample.lpi',
    '<CONFIG><ProjectOptions><BuildModes>' +
    '<Item Name="Default"><CompilerOptions><SearchPaths>' +
    '<OtherUnitFiles Value="existing"/></SearchPaths></CompilerOptions></Item>' +
    '<Item Name="Release"><CompilerOptions/></Item>' +
    '</BuildModes></ProjectOptions><CompilerOptions/></CONFIG>');

  Assert.IsTrue(TBoss4DLazarusProjectService.UpdateUnitPaths(LProjectPath,
    ['modules\zeta', 'modules\alpha']));

  LContent := TFile.ReadAllText(LProjectPath, TEncoding.UTF8);
  Assert.AreEqual(3, CountText(LContent, 'modules\alpha;modules\zeta'));
  Assert.Contains(LContent,
    'Value="existing;modules\alpha;modules\zeta"');
end;

procedure TTestsLazarusProject.UpdatesLazarusPackage;
var
  LPackagePath: string;
  LContent: string;
begin
  LPackagePath := WriteFixture('sample.lpk',
    '<CONFIG><Package><CompilerOptions><SearchPaths>' +
    '<OtherUnitFiles Value="src"/></SearchPaths></CompilerOptions>' +
    '</Package></CONFIG>');

  Assert.IsTrue(TBoss4DLazarusProjectService.UpdateUnitPaths(LPackagePath,
    ['modules\dependency']));

  LContent := TFile.ReadAllText(LPackagePath, TEncoding.UTF8);
  Assert.Contains(LContent, 'Value="src;modules\dependency"');
end;

procedure TTestsLazarusProject.IsDeterministicAndIdempotent;
var
  LProjectPath: string;
  LFirstContent: string;
begin
  LProjectPath := WriteFixture('stable.lpi',
    '<CONFIG><CompilerOptions><SearchPaths>' +
    '<OtherUnitFiles Value="existing;MODULES\ALPHA"/></SearchPaths>' +
    '</CompilerOptions></CONFIG>');

  Assert.IsTrue(TBoss4DLazarusProjectService.UpdateUnitPaths(LProjectPath,
    ['modules\zeta\', 'modules\alpha', 'modules\zeta']));
  LFirstContent := TFile.ReadAllText(LProjectPath, TEncoding.UTF8);

  Assert.IsFalse(TBoss4DLazarusProjectService.UpdateUnitPaths(LProjectPath,
    ['modules\alpha', 'modules\zeta']));
  Assert.AreEqual(LFirstContent,
    TFile.ReadAllText(LProjectPath, TEncoding.UTF8));
  Assert.AreEqual(1, CountText(LFirstContent, 'modules\zeta'));
end;

procedure TTestsLazarusProject.RejectsMissingProject;
begin
  Assert.WillRaise(
    procedure
    begin
      TBoss4DLazarusProjectService.UpdateUnitPaths(
        TPath.Combine(FTempDir, 'missing.lpi'), ['modules\dependency']);
    end,
    EFileNotFoundException);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsLazarusProject);

end.
