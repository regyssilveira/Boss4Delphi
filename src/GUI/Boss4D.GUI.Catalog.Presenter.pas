unit Boss4D.GUI.Catalog.Presenter;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Services.PackageIndex;

type
  TBoss4DGUICatalogRow = record
    Name: string;
    Version: string;
    Repository: string;
    VersionSummary: string;
  end;

  TBoss4DGUICatalogPresenter = class
  public
    function BuildRows(
      const AEntries: TObjectList<TBoss4DPackageIndexEntry>):
      TArray<TBoss4DGUICatalogRow>;
  end;

implementation

uses
  System.SysUtils;

function TBoss4DGUICatalogPresenter.BuildRows(
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>):
  TArray<TBoss4DGUICatalogRow>;
var
  LRows: TList<TBoss4DGUICatalogRow>;
  LRow: TBoss4DGUICatalogRow;
  LRevoked: Integer;
begin
  LRows := TList<TBoss4DGUICatalogRow>.Create;
  try
    for var LEntry in AEntries do
    begin
      LRow := Default(TBoss4DGUICatalogRow);
      LRow.Name := LEntry.Name;
      LRow.Version := LEntry.LatestVersion;
      LRow.Repository := LEntry.Repository;
      LRevoked := 0;
      for var LVersion in LEntry.Versions do
        if LVersion.Revoked then Inc(LRevoked);
      LRow.VersionSummary := Format('%d versao(oes)',
        [Integer(LEntry.Versions.Count)]);
      if LRevoked > 0 then
        LRow.VersionSummary := LRow.VersionSummary +
          Format(', %d revogada(s)', [LRevoked]);
      LRows.Add(LRow);
    end;
    Result := LRows.ToArray;
  finally
    LRows.Free;
  end;
end;

end.
