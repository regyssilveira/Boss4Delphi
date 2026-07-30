unit Boss4D.Tests.SelfUpdate;

interface

uses
  DUnitX.TestFramework, Boss4D.Core.Ports;

type
  TUpdateLoggerMock = class(TInterfacedObject, IBoss4DLogger)
  private
    FLogCount: Integer;
    FDebugEnabled: Boolean;
  public
    procedure Log(const ALevel: TBoss4DLogLevel;
      const AMessage: string); overload;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string;
      const AArgs: array of const); overload;
    procedure SetDebugMode(const AEnabled: Boolean);
  end;

  TUpdateApplierMock = class(TInterfacedObject, IBoss4DSelfUpdateApplier)
  private
    FLaunchCount: Integer;
  public
    procedure LaunchVerifiedInstaller(const AInstallerPath: string);
    property LaunchCount: Integer read FLaunchCount;
  end;

  [TestFixture]
  TBoss4DSelfUpdateTests = class
  public
    [Test] procedure DoesNothingWhenCurrent;
    [Test] procedure DownloadsVerifiesAndLaunches;
    [Test] procedure RejectsInvalidChecksum;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Hash,
  Boss4D.Core.Services.SelfUpdate, Boss4D.Tests.Mocks;

const
  API_URL =
    'https://api.github.com/repos/regyssilveira/Boss4Delphi/releases/latest';
  BIN_URL = 'https://example.test/Boss4D_Setup.exe';
  SUM_URL = 'https://example.test/SHA256SUMS.txt';

procedure TUpdateLoggerMock.Log(const ALevel: TBoss4DLogLevel;
  const AMessage: string);
begin
  Inc(FLogCount);
end;

procedure TUpdateLoggerMock.Log(const ALevel: TBoss4DLogLevel;
  const AMessage: string; const AArgs: array of const);
begin
  Inc(FLogCount);
end;

procedure TUpdateLoggerMock.SetDebugMode(const AEnabled: Boolean);
begin
  FDebugEnabled := AEnabled;
end;

procedure TUpdateApplierMock.LaunchVerifiedInstaller(
  const AInstallerPath: string);
begin
  Inc(FLaunchCount);
end;

function ReleaseJson(const AVersion: string): string;
begin
  Result := Format('{"tag_name":"v%s","assets":[' +
    '{"name":"Boss4D_Setup.exe","browser_download_url":"%s"},' +
    '{"name":"SHA256SUMS.txt","browser_download_url":"%s"}]}',
    [AVersion, BIN_URL, SUM_URL]);
end;

procedure TBoss4DSelfUpdateTests.DoesNothingWhenCurrent;
var
  LHttp: THttpClientMock;
  LService: TBoss4DSelfUpdateService;
  LResult: TBoss4DSelfUpdateResult;
begin
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(API_URL, ReleaseJson('1.4.0'), 200);
  LService := TBoss4DSelfUpdateService.Create(LHttp,
    TUpdateLoggerMock.Create, nil);
  try
    LResult := LService.CheckAndDownload('1.4.0', TPath.GetTempPath);
    Assert.IsFalse(LResult.Updated);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DSelfUpdateTests.DownloadsVerifiesAndLaunches;
var
  LHttp: THttpClientMock;
  LService: TBoss4DSelfUpdateService;
  LApplier: TUpdateApplierMock;
  LDir, LPayload, LHash: string;
  LHasher: THashSHA2;
  LBytes: TBytes;
begin
  LDir := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LPayload := 'verified installer';
  LBytes := TEncoding.UTF8.GetBytes(LPayload);
  LHasher := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  LHasher.Update(LBytes, Length(LBytes));
  LHash := LHasher.HashAsString;
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(API_URL, ReleaseJson('1.5.0'), 200);
  LHttp.AddResponse(BIN_URL, LPayload, 200);
  LHttp.AddResponse(SUM_URL, LHash + '  Boss4D_Setup.exe', 200);
  LApplier := TUpdateApplierMock.Create;
  LService := TBoss4DSelfUpdateService.Create(LHttp,
    TUpdateLoggerMock.Create, LApplier);
  try
    Assert.IsTrue(LService.CheckAndDownload('1.4.0', LDir).Updated);
    Assert.AreEqual<Integer>(1, LApplier.LaunchCount);
  finally
    LService.Free;
    if TDirectory.Exists(LDir) then
      TDirectory.Delete(LDir, True);
  end;
end;

procedure TBoss4DSelfUpdateTests.RejectsInvalidChecksum;
var
  LHttp: THttpClientMock;
  LService: TBoss4DSelfUpdateService;
  LDir: string;
begin
  LDir := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(API_URL, ReleaseJson('1.5.0'), 200);
  LHttp.AddResponse(BIN_URL, 'tampered', 200);
  LHttp.AddResponse(SUM_URL, StringOfChar('0', 64) +
    '  Boss4D_Setup.exe', 200);
  LService := TBoss4DSelfUpdateService.Create(LHttp,
    TUpdateLoggerMock.Create, nil);
  try
    Assert.WillRaise(
      procedure
      begin
        LService.CheckAndDownload('1.4.0', LDir);
      end, Exception);
    Assert.IsFalse(TFile.Exists(TPath.Combine(LDir, 'Boss4D_Setup.exe')));
  finally
    LService.Free;
    if TDirectory.Exists(LDir) then
      TDirectory.Delete(LDir, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DSelfUpdateTests);

end.
