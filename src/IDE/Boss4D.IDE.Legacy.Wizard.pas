unit Boss4D.IDE.Legacy.Wizard;

interface

uses
  ToolsAPI;

type
  TBoss4DLegacyWizard = class(TNotifierObject, IOTAWizard)
  public
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

procedure Register;

implementation

uses
  Vcl.Dialogs, Boss4D.IDE.Legacy.Metadata;

function TBoss4DLegacyWizard.GetIDString: string;
begin
  Result := BOSS4D_LEGACY_WIZARD_ID;
end;

function TBoss4DLegacyWizard.GetName: string;
begin
  Result := BOSS4D_LEGACY_WIZARD_NAME;
end;

function TBoss4DLegacyWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TBoss4DLegacyWizard.Execute;
begin
  MessageDlg('Use boss4d.exe no terminal do projeto. Este plugin garante ' +
    'descoberta e integracao basica no RAD Studio legado.',
    mtInformation, [mbOK], 0);
end;

procedure Register;
begin
  RegisterPackageWizard(TBoss4DLegacyWizard.Create);
end;

end.
