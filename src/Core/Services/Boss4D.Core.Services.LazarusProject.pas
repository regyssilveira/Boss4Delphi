unit Boss4D.Core.Services.LazarusProject;

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  System.Generics.Defaults,
  Xml.XMLIntf, Xml.XMLDoc;

type
  TBoss4DLazarusProjectService = class
  private
    class procedure CollectCompilerOptions(const ANode: IXMLNode;
      const ANodes: TList<IXMLNode>); static;
    class function EnsureUnitPaths(const ACompilerOptions: IXMLNode;
      const AUnitPaths: TArray<string>): Boolean; static;
    class function NormalizePaths(const AUnitPaths: TArray<string>): TArray<string>; static;
  public
    class function UpdateUnitPaths(const AProjectPath: string;
      const AUnitPaths: TArray<string>): Boolean; static;
  end;

implementation

class procedure TBoss4DLazarusProjectService.CollectCompilerOptions(
  const ANode: IXMLNode; const ANodes: TList<IXMLNode>);
begin
  if not Assigned(ANode) then
    Exit;

  if SameText(ANode.NodeName, 'CompilerOptions') then
    ANodes.Add(ANode);

  for var I := 0 to ANode.ChildNodes.Count - 1 do
    CollectCompilerOptions(ANode.ChildNodes[I], ANodes);
end;

class function TBoss4DLazarusProjectService.NormalizePaths(
  const AUnitPaths: TArray<string>): TArray<string>;
var
  LPaths: TList<string>;
begin
  LPaths := TList<string>.Create;
  try
    for var LPath in AUnitPaths do
    begin
      var LNormalized := ExcludeTrailingPathDelimiter(LPath.Trim);
      if LNormalized.IsEmpty then
        Continue;

      var LExists := False;
      for var LExisting in LPaths do
        if SameText(LExisting, LNormalized) then
        begin
          LExists := True;
          Break;
        end;

      if not LExists then
        LPaths.Add(LNormalized);
    end;

    LPaths.Sort(TComparer<string>.Construct(
      function(const ALeft, ARight: string): Integer
      begin
        Result := CompareText(ALeft, ARight);
      end));
    Result := LPaths.ToArray;
  finally
    LPaths.Free;
  end;
end;

class function TBoss4DLazarusProjectService.EnsureUnitPaths(
  const ACompilerOptions: IXMLNode;
  const AUnitPaths: TArray<string>): Boolean;
var
  LSearchPaths: IXMLNode;
  LOtherUnitFiles: IXMLNode;
  LExistingPaths: TStringList;
begin
  Result := False;
  LSearchPaths := ACompilerOptions.ChildNodes.FindNode('SearchPaths');
  if not Assigned(LSearchPaths) then
    LSearchPaths := ACompilerOptions.AddChild('SearchPaths');

  LOtherUnitFiles := LSearchPaths.ChildNodes.FindNode('OtherUnitFiles');
  if not Assigned(LOtherUnitFiles) then
    LOtherUnitFiles := LSearchPaths.AddChild('OtherUnitFiles');

  LExistingPaths := TStringList.Create;
  try
    LExistingPaths.StrictDelimiter := True;
    LExistingPaths.Delimiter := ';';
    if LOtherUnitFiles.HasAttribute('Value') then
      LExistingPaths.DelimitedText := VarToStr(LOtherUnitFiles.Attributes['Value']);

    for var LPath in AUnitPaths do
    begin
      var LExists := False;
      for var I := 0 to LExistingPaths.Count - 1 do
        if SameText(ExcludeTrailingPathDelimiter(LExistingPaths[I].Trim), LPath) then
        begin
          LExists := True;
          Break;
        end;

      if not LExists then
      begin
        LExistingPaths.Add(LPath);
        Result := True;
      end;
    end;

    if Result then
      LOtherUnitFiles.Attributes['Value'] := string.Join(';',
        LExistingPaths.ToStringArray);
  finally
    LExistingPaths.Free;
  end;
end;

class function TBoss4DLazarusProjectService.UpdateUnitPaths(
  const AProjectPath: string; const AUnitPaths: TArray<string>): Boolean;
var
  LDocument: IXMLDocument;
  LCompilerOptions: TList<IXMLNode>;
  LNormalizedPaths: TArray<string>;
begin
  if not FileExists(AProjectPath) then
    raise EFileNotFoundException.CreateFmt(
      'Projeto Lazarus nao encontrado: %s', [AProjectPath]);

  LNormalizedPaths := NormalizePaths(AUnitPaths);
  if Length(LNormalizedPaths) = 0 then
    Exit(False);

  LDocument := LoadXMLDocument(AProjectPath);
  LDocument.Options := LDocument.Options + [doNodeAutoIndent];
  LCompilerOptions := TList<IXMLNode>.Create;
  try
    CollectCompilerOptions(LDocument.DocumentElement, LCompilerOptions);
    Result := False;
    for var LNode in LCompilerOptions do
      Result := EnsureUnitPaths(LNode, LNormalizedPaths) or Result;

    if Result then
      LDocument.SaveToFile(AProjectPath);
  finally
    LCompilerOptions.Free;
  end;
end;

end.
