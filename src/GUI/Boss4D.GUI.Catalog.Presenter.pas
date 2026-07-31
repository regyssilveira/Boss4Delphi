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
    Description: string;
    License: string;
    VersionSummary: string;
    Versions: string;
    InstallVersions: TArray<string>;
    VariantSummary: string;
    CompatibilitySummary: string;
    Dependencies: TArray<string>;
    DependencyGraph: string;
    ChangelogUrl: string;
    SbomUrl: string;
    SupplyChainSummary: string;
  end;

  TBoss4DGUICatalogPresenter = class
  public
    function BuildRows(
      const AEntries: TObjectList<TBoss4DPackageIndexEntry>):
      TArray<TBoss4DGUICatalogRow>;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.StrUtils;

function TBoss4DGUICatalogPresenter.BuildRows(
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>):
  TArray<TBoss4DGUICatalogRow>;
var
  LRows: TList<TBoss4DGUICatalogRow>;
  LRow: TBoss4DGUICatalogRow;
  LRevoked: Integer;
  LVersions: TStringList;
  LVariants: TStringList;
  LVersion: TBoss4DPackageVersion;
  LVariant: TBoss4DPackageArtifactVariant;
  LHasDigest: Boolean;
  LHasSignature: Boolean;
  LHasProvenance: Boolean;
begin
  LRows := TList<TBoss4DGUICatalogRow>.Create;
  LVersions := TStringList.Create;
  LVariants := TStringList.Create;
  try
    LVariants.Sorted := True;
    LVariants.Duplicates := dupIgnore;
    for var LEntry in AEntries do
    begin
      LRow := Default(TBoss4DGUICatalogRow);
      LRow.Name := LEntry.Name;
      LRow.Version := LEntry.LatestVersion;
      LRow.Repository := LEntry.Repository;
      LRow.Description := LEntry.Description;
      LRow.License := LEntry.License;
      LRow.Dependencies := LEntry.Dependencies.ToArray;
      if Length(LRow.Dependencies) = 0 then
        LRow.DependencyGraph := LEntry.Name + ' -> sem dependencias informadas'
      else
        LRow.DependencyGraph := LEntry.Name + ' -> ' +
          string.Join(', ', LRow.Dependencies);
      LRow.ChangelogUrl := LEntry.ChangelogUrl;
      LRow.SbomUrl := LEntry.SbomUrl;
      LRevoked := 0;
      LVersions.Clear;
      LVariants.Clear;
      LHasDigest := LEntry.ArtifactDigest <> '';
      LHasSignature := LEntry.SignatureUrl <> '';
      LHasProvenance := LEntry.ProvenanceUrl <> '';
      for LVersion in LEntry.Versions do
      begin
        if LVersion.Revoked then
        begin
          Inc(LRevoked);
          LVersions.Add(LVersion.Version + ' (revogada)');
        end
        else
          LVersions.Add(LVersion.Version);
        if SameText(LVersion.Version, LEntry.LatestVersion) then
        begin
          LHasDigest := LVersion.ArtifactDigest <> '';
          LHasSignature := LVersion.SignatureUrl <> '';
          LHasProvenance := LVersion.ProvenanceUrl <> '';
        end;
        for LVariant in LVersion.Variants do
          LVariants.Add(LVariant.Platform + ' / ' + LVariant.Compiler);
      end;
      for LVariant in LEntry.Variants do
        LVariants.Add(LVariant.Platform + ' / ' + LVariant.Compiler);
      LRow.VersionSummary := Format('%d versao(oes)',
        [Integer(LEntry.Versions.Count)]);
      if LRevoked > 0 then
        LRow.VersionSummary := LRow.VersionSummary +
          Format(', %d revogada(s)', [LRevoked]);
      LRow.Versions := StringReplace(Trim(LVersions.Text),
        sLineBreak, ', ', [rfReplaceAll]);
      LRow.InstallVersions := nil;
      for LVersion in LEntry.Versions do
        if not LVersion.Revoked then
        begin
          var LLength := Length(LRow.InstallVersions);
          SetLength(LRow.InstallVersions, LLength + 1);
          LRow.InstallVersions[LLength] := LVersion.Version;
        end;
      if LVariants.Count = 0 then
      begin
        LRow.VariantSummary := 'Pacote baseado em codigo-fonte';
        LRow.CompatibilitySummary :=
          'Compativel via codigo-fonte; requer toolchain local'
      end
      else
      begin
        LRow.VariantSummary := StringReplace(Trim(LVariants.Text),
          sLineBreak, ', ', [rfReplaceAll]);
        LRow.CompatibilitySummary :=
          'Artefatos verificados: ' + LRow.VariantSummary;
      end;
      LRow.SupplyChainSummary := Format(
        'Digest: %s | Assinatura: %s | Proveniencia: %s',
        [IfThen(LHasDigest, 'sim', 'nao'),
         IfThen(LHasSignature, 'sim', 'nao'),
         IfThen(LHasProvenance, 'sim', 'nao')]);
      LRows.Add(LRow);
    end;
    Result := LRows.ToArray;
  finally
    LVariants.Free;
    LVersions.Free;
    LRows.Free;
  end;
end;

end.
