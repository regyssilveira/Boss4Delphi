unit Boss4D.IDE.Legacy.Metadata;

interface

const
  BOSS4D_LEGACY_WIZARD_ID = 'Boss4D.Legacy.IDEWizard';
  BOSS4D_LEGACY_WIZARD_NAME = 'Boss4D Dependency Manager (Legacy)';

function Boss4DLegacyCommand(const AExecutable,
  AProjectDirectory: string): string;

implementation

uses
  System.SysUtils;

function Boss4DLegacyCommand(const AExecutable,
  AProjectDirectory: string): string;
begin
  Result := Format('"%s" install', [IncludeTrailingPathDelimiter(
    AProjectDirectory) + AExecutable]);
end;

end.
