unit Boss4D.Posix.Documentation;

{$mode objfpc}{$H+}

interface

type
  TBoss4DDocumentationResult = record
    Files: Integer;
    Symbols: Integer;
    OutputDirectory: string;
  end;

function GenerateDocumentation(const ARootDirectory, AOutputDirectory: string;
  AIncludeDependencies: Boolean): TBoss4DDocumentationResult;

implementation

uses
  Classes, SysUtils, fpjson;

type
  TBoss4DDocumentationSymbol = record
    Name: string;
    Kind: string;
    Summary: string;
    SourcePath: string;
    Line: Integer;
  end;

  TBoss4DDocumentationSymbols = array of TBoss4DDocumentationSymbol;

function NormalizePath(const APath: string): string;
begin
  Result := StringReplace(APath, DirectorySeparator, '/', [rfReplaceAll]);
end;

function IsExcludedDirectory(const ARoot, AOutput, ADirectory: string;
  AIncludeDependencies: Boolean): Boolean;
var
  LName, LPath, LRelative: string;
begin
  LName := LowerCase(ExtractFileName(ExcludeTrailingPathDelimiter(ADirectory)));
  LPath := ExpandFileName(ADirectory);
  LRelative := LowerCase(NormalizePath(ExtractRelativePath(
    IncludeTrailingPathDelimiter(ARoot), LPath)));
  Result := (LPath = AOutput) or (LName = '.git') or
    (LName = '.codex-build') or (LName = '.ci-build') or
    (LName = '__history') or (LName = '__recovery') or
    ((not AIncludeDependencies) and
      ((LRelative = 'modules') or (Pos('modules/', LRelative) = 1)));
end;

procedure CollectSources(const ARoot, AOutput, ADirectory: string;
  AIncludeDependencies: Boolean; AFiles: TStrings);
var
  LSearch: TSearchRec;
  LPath, LExtension: string;
begin
  if IsExcludedDirectory(ARoot, AOutput, ADirectory,
    AIncludeDependencies) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        CollectSources(ARoot, AOutput, LPath, AIncludeDependencies, AFiles)
      else
      begin
        LExtension := LowerCase(ExtractFileExt(LSearch.Name));
        if (LExtension = '.pas') or (LExtension = '.pp') then
          AFiles.Add(ExpandFileName(LPath));
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function CompactWhitespace(const AValue: string): string;
var
  I: Integer;
  LSpace: Boolean;
begin
  Result := '';
  LSpace := False;
  for I := 1 to Length(AValue) do
    if AValue[I] in [#9, #10, #13, ' '] then
      LSpace := Result <> ''
    else
    begin
      if LSpace then Result := Result + ' ';
      Result := Result + AValue[I];
      LSpace := False;
    end;
end;

function StripXmlTags(const AValue: string): string;
var
  I: Integer;
  LInTag: Boolean;
begin
  Result := '';
  LInTag := False;
  for I := 1 to Length(AValue) do
    if AValue[I] = '<' then LInTag := True
    else if AValue[I] = '>' then LInTag := False
    else if not LInTag then Result := Result + AValue[I];
end;

function NormalizeComment(const AComment: string): string;
begin
  Result := StringReplace(AComment, '{**', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, LineEnding + '* ', LineEnding,
    [rfReplaceAll]);
  Result := CompactWhitespace(StripXmlTags(Result));
end;

function DeclarationToken(const ALine: string; out AKind, AName: string):
  Boolean;
var
  LLine, LLower, LRest: string;
  LPos, I: Integer;

  function ReadIdentifier(const AText: string): string;
  var
    J: Integer;
  begin
    Result := '';
    for J := 1 to Length(AText) do
      if AText[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.'] then
        Result := Result + AText[J]
      else
        Break;
  end;

  function MatchKeyword(const AKeyword: string): Boolean;
  begin
    Result := Pos(AKeyword + ' ', LLower) = 1;
    if Result then
    begin
      AKind := AKeyword;
      LRest := Trim(Copy(LLine, Length(AKeyword) + 1, MaxInt));
      AName := ReadIdentifier(LRest);
    end;
  end;

begin
  Result := False;
  AKind := '';
  AName := '';
  LLine := Trim(ALine);
  LLower := LowerCase(LLine);
  if Pos('class ', LLower) = 1 then
  begin
    Delete(LLine, 1, Length('class '));
    LLine := Trim(LLine);
    LLower := LowerCase(LLine);
  end;
  if MatchKeyword('unit') or MatchKeyword('program') or
     MatchKeyword('library') or MatchKeyword('package') or
     MatchKeyword('procedure') or MatchKeyword('function') or
     MatchKeyword('constructor') or MatchKeyword('destructor') or
     MatchKeyword('operator') or MatchKeyword('property') then
    Exit(AName <> '');
  LPos := Pos('=', LLine);
  if LPos = 0 then Exit;
  AName := Trim(Copy(LLine, 1, LPos - 1));
  for I := 1 to Length(AName) do
    if not (AName[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;
  LRest := LowerCase(Trim(Copy(LLine, LPos + 1, MaxInt)));
  AKind := 'class';
  if (LRest = AKind) or (Pos(AKind + ' ', LRest) = 1) or
     (Pos(AKind + '(', LRest) = 1) then Exit(True);
  AKind := 'record';
  if (LRest = AKind) or (Pos(AKind + ' ', LRest) = 1) or
     (Pos(AKind + '(', LRest) = 1) then Exit(True);
  AKind := 'interface';
  if (LRest = AKind) or (Pos(AKind + ' ', LRest) = 1) or
     (Pos(AKind + '(', LRest) = 1) then Exit(True);
  AKind := 'object';
  if (LRest = AKind) or (Pos(AKind + ' ', LRest) = 1) or
     (Pos(AKind + '(', LRest) = 1) then Exit(True);
  AKind := '';
end;

procedure AddSymbol(var ASymbols: TBoss4DDocumentationSymbols;
  const AName, AKind, ASummary, ASource: string; ALine: Integer);
var
  LIndex: Integer;
begin
  LIndex := Length(ASymbols);
  SetLength(ASymbols, LIndex + 1);
  ASymbols[LIndex].Name := AName;
  ASymbols[LIndex].Kind := AKind;
  ASymbols[LIndex].Summary := ASummary;
  ASymbols[LIndex].SourcePath := ASource;
  ASymbols[LIndex].Line := ALine;
end;

procedure ExtractSymbols(const ARoot, ASourcePath: string;
  var ASymbols: TBoss4DDocumentationSymbols);
var
  LLines: TStringList;
  LComment, LLine, LTrimmed, LKind, LName: string;
  LCommentLine, I: Integer;
  LInPascalDoc: Boolean;
begin
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(ASourcePath);
    LComment := '';
    LCommentLine := 0;
    LInPascalDoc := False;
    for I := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[I];
      LTrimmed := Trim(LLine);
      if LInPascalDoc then
      begin
        LComment := LComment + LineEnding + LTrimmed;
        if Pos('}', LTrimmed) > 0 then LInPascalDoc := False;
        Continue;
      end;
      if Pos('{**', LTrimmed) = 1 then
      begin
        LComment := LTrimmed;
        LCommentLine := I + 1;
        LInPascalDoc := Pos('}', LTrimmed) = 0;
        Continue;
      end;
      if Pos('///', LTrimmed) = 1 then
      begin
        if LComment = '' then LCommentLine := I + 1;
        LComment := LComment + LineEnding + Trim(Copy(LTrimmed, 4, MaxInt));
        Continue;
      end;
      if LComment = '' then Continue;
      if (LTrimmed = '') or SameText(LTrimmed, 'type') or
         SameText(LTrimmed, 'const') or (Pos('[', LTrimmed) = 1) then
        Continue;
      if DeclarationToken(LLine, LKind, LName) then
        AddSymbol(ASymbols, LName, LKind, NormalizeComment(LComment),
          NormalizePath(ExtractRelativePath(
            IncludeTrailingPathDelimiter(ARoot), ASourcePath)), LCommentLine);
      LComment := '';
    end;
  finally
    LLines.Free;
  end;
end;

function CompareSymbols(const ALeft, ARight: TBoss4DDocumentationSymbol):
  Integer;
begin
  Result := CompareText(ALeft.Name, ARight.Name);
  if Result = 0 then
    Result := CompareText(ALeft.SourcePath, ARight.SourcePath);
end;

procedure SortSymbols(var ASymbols: TBoss4DDocumentationSymbols);
var
  I, J: Integer;
  LValue: TBoss4DDocumentationSymbol;
begin
  for I := 1 to High(ASymbols) do
  begin
    LValue := ASymbols[I];
    J := I - 1;
    while (J >= 0) and (CompareSymbols(ASymbols[J], LValue) > 0) do
    begin
      ASymbols[J + 1] := ASymbols[J];
      Dec(J);
    end;
    ASymbols[J + 1] := LValue;
  end;
end;

function HtmlEncode(const AValue: string): string;
begin
  Result := StringReplace(AValue, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

function RenderHtml(const ASymbols: TBoss4DDocumentationSymbols): string;
var
  I: Integer;
begin
  Result := '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>Boss4D API Documentation</title><style>' +
    'body{font-family:system-ui;margin:auto;max-width:1100px;padding:2rem;background:#0b1020;color:#e5e7eb}' +
    'input{width:100%;box-sizing:border-box;padding:.8rem;margin:1rem 0;background:#111827;color:inherit;border:1px solid #475569}' +
    'article{padding:1rem;margin:.8rem 0;border:1px solid #334155;border-radius:.7rem;background:#111827}' +
    'code{color:#5eead4}small{color:#94a3b8}[hidden]{display:none}</style></head><body>' +
    '<h1>Boss4D API Documentation</h1><p><strong id="visible-count">' +
    IntToStr(Length(ASymbols)) + '</strong> documented symbols</p>' +
    '<label>Search API<input id="api-search" type="search" placeholder="symbol, kind, source or summary"></label>' +
    '<main id="symbols">';
  for I := 0 to High(ASymbols) do
    Result := Result + '<article data-search="' +
      HtmlEncode(ASymbols[I].Name + ' ' + ASymbols[I].Kind + ' ' +
        ASymbols[I].SourcePath + ' ' + ASymbols[I].Summary) + '"><h2>' +
      HtmlEncode(ASymbols[I].Name) + '</h2><code>' +
      HtmlEncode(ASymbols[I].Kind) + '</code><p>' +
      HtmlEncode(ASymbols[I].Summary) + '</p><small>' +
      HtmlEncode(ASymbols[I].SourcePath) + ':' +
      IntToStr(ASymbols[I].Line) + '</small></article>';
  Result := Result + '</main><script>const q=document.getElementById("api-search"),' +
    'items=[...document.querySelectorAll("article")];function apply(){let n=0;' +
    'items.forEach(x=>{x.hidden=!x.dataset.search.toLowerCase().includes(q.value.toLowerCase());if(!x.hidden)n++;});' +
    'document.getElementById("visible-count").textContent=n;}q.addEventListener("input",apply);' +
    '</script></body></html>';
end;

function RenderSearchIndex(const ASymbols: TBoss4DDocumentationSymbols): string;
var
  LRoot, LItem: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  LRoot := TJSONObject.Create;
  try
    LItems := TJSONArray.Create;
    LRoot.Add('schemaVersion', 1);
    LRoot.Add('symbolCount', Length(ASymbols));
    LRoot.Add('symbols', LItems);
    for I := 0 to High(ASymbols) do
    begin
      LItem := TJSONObject.Create;
      LItem.Add('name', ASymbols[I].Name);
      LItem.Add('kind', ASymbols[I].Kind);
      LItem.Add('summary', ASymbols[I].Summary);
      LItem.Add('source', ASymbols[I].SourcePath);
      LItem.Add('line', ASymbols[I].Line);
      LItems.Add(LItem);
    end;
    Result := LRoot.AsJSON;
  finally
    LRoot.Free;
  end;
end;

procedure SaveText(const APath, AContent: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AContent <> '' then
      LStream.WriteBuffer(AContent[1], Length(AContent));
  finally
    LStream.Free;
  end;
end;

function GenerateDocumentation(const ARootDirectory, AOutputDirectory: string;
  AIncludeDependencies: Boolean): TBoss4DDocumentationResult;
var
  LRoot, LOutput: string;
  LFiles: TStringList;
  LSymbols: TBoss4DDocumentationSymbols;
  I: Integer;
begin
  LRoot := ExpandFileName(ARootDirectory);
  LOutput := ExpandFileName(AOutputDirectory);
  if not DirectoryExists(LRoot) then
    raise Exception.Create('root directory not found: ' + LRoot);
  LFiles := TStringList.Create;
  try
    LFiles.Sorted := True;
    CollectSources(LRoot, LOutput, LRoot, AIncludeDependencies, LFiles);
    SetLength(LSymbols, 0);
    for I := 0 to LFiles.Count - 1 do
      ExtractSymbols(LRoot, LFiles[I], LSymbols);
    SortSymbols(LSymbols);
    if not ForceDirectories(LOutput) then
      raise Exception.Create('unable to create documentation directory: ' +
        LOutput);
    SaveText(IncludeTrailingPathDelimiter(LOutput) + 'index.html',
      RenderHtml(LSymbols));
    SaveText(IncludeTrailingPathDelimiter(LOutput) + 'search-index.json',
      RenderSearchIndex(LSymbols));
    Result.Files := LFiles.Count;
    Result.Symbols := Length(LSymbols);
    Result.OutputDirectory := LOutput;
  finally
    LFiles.Free;
  end;
end;

end.
