unit Boss4D.Core.Services.Documentation;

interface

uses
  System.Generics.Collections;

type
  TBoss4DDocumentationSymbol = class
  private
    FName: string;
    FKind: string;
    FSummary: string;
    FSourcePath: string;
    FLine: Integer;
  public
    property Name: string read FName write FName;
    property Kind: string read FKind write FKind;
    property Summary: string read FSummary write FSummary;
    property SourcePath: string read FSourcePath write FSourcePath;
    property Line: Integer read FLine write FLine;
  end;

  TBoss4DDocumentationResult = record
    Files: Integer;
    Symbols: Integer;
    OutputDirectory: string;
  end;

  TBoss4DDocumentationService = class
  private
    function IsSourceIncluded(const ARoot, AOutput,
      ASourcePath: string; const AIncludeDependencies: Boolean): Boolean;
    function ExtractSymbols(const ARoot, ASourcePath: string):
      TObjectList<TBoss4DDocumentationSymbol>;
    function TryParseDeclaration(const ALine: string;
      out AKind, AName: string): Boolean;
    function NormalizeComment(const AComment: string): string;
    function RenderHtml(
      const ASymbols: TObjectList<TBoss4DDocumentationSymbol>): string;
    function RenderSearchIndex(
      const ASymbols: TObjectList<TBoss4DDocumentationSymbol>): string;
  public
    function Generate(const ARootDirectory, AOutputDirectory: string;
      const AIncludeDependencies: Boolean = True):
      TBoss4DDocumentationResult;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.JSON,
  System.RegularExpressions,
  System.NetEncoding,
  System.Generics.Defaults;

function TBoss4DDocumentationService.IsSourceIncluded(
  const ARoot, AOutput, ASourcePath: string;
  const AIncludeDependencies: Boolean): Boolean;
begin
  var LPath := TPath.GetFullPath(ASourcePath);
  var LRelative := LPath.Substring(
    IncludeTrailingPathDelimiter(ARoot).Length).Replace('\', '/');
  Result := not LPath.StartsWith(
      IncludeTrailingPathDelimiter(AOutput), True) and
    not LRelative.StartsWith('.git/', True) and
    not LRelative.StartsWith('.codex-build/', True) and
    not LRelative.StartsWith('.ci-build/', True) and
    not LRelative.Contains('/__history/') and
    not LRelative.Contains('/__recovery/');
  if Result and not AIncludeDependencies then
    Result := not LRelative.StartsWith('modules/', True);
end;

function TBoss4DDocumentationService.NormalizeComment(
  const AComment: string): string;
begin
  Result := TRegEx.Replace(AComment, '<[^>]+>', ' ');
  Result := Result.Replace('{**', '').Replace('}', '');
  Result := TRegEx.Replace(Result, '^\s*\* ?', '',
    [roMultiLine]);
  Result := TRegEx.Replace(Result, '\s+', ' ').Trim;
end;

function TBoss4DDocumentationService.TryParseDeclaration(
  const ALine: string; out AKind, AName: string): Boolean;
var
  LMatch: TMatch;
begin
  Result := False;
  AKind := '';
  AName := '';
  LMatch := TRegEx.Match(ALine,
    '^\s*(unit|program|library|package)\s+([A-Za-z_][A-Za-z0-9_.]*)',
    [roIgnoreCase]);
  if LMatch.Success then
  begin
    AKind := LMatch.Groups[1].Value.ToLower;
    AName := LMatch.Groups[2].Value;
    Exit(True);
  end;
  LMatch := TRegEx.Match(ALine,
    '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(class|record|interface|object)',
    [roIgnoreCase]);
  if LMatch.Success then
  begin
    AKind := LMatch.Groups[2].Value.ToLower;
    AName := LMatch.Groups[1].Value;
    Exit(True);
  end;
  LMatch := TRegEx.Match(ALine,
    '^\s*(?:class\s+)?(procedure|function|constructor|destructor|operator)\s+([A-Za-z_][A-Za-z0-9_.]*)',
    [roIgnoreCase]);
  if LMatch.Success then
  begin
    AKind := LMatch.Groups[1].Value.ToLower;
    AName := LMatch.Groups[2].Value;
    Exit(True);
  end;
  LMatch := TRegEx.Match(ALine,
    '^\s*property\s+([A-Za-z_][A-Za-z0-9_]*)',
    [roIgnoreCase]);
  if LMatch.Success then
  begin
    AKind := 'property';
    AName := LMatch.Groups[1].Value;
    Exit(True);
  end;
end;

function TBoss4DDocumentationService.ExtractSymbols(
  const ARoot, ASourcePath: string):
  TObjectList<TBoss4DDocumentationSymbol>;
var
  LLines: TStringList;
  LComment: TStringBuilder;
  LInPascalDoc: Boolean;
  LCommentLine: Integer;
begin
  Result := TObjectList<TBoss4DDocumentationSymbol>.Create(True);
  LLines := TStringList.Create;
  LComment := TStringBuilder.Create;
  try
    LLines.LoadFromFile(ASourcePath, TEncoding.UTF8);
    LInPascalDoc := False;
    LCommentLine := 0;
    for var I := 0 to LLines.Count - 1 do
    begin
      var LLine := LLines[I];
      var LTrimmed := LLine.Trim;
      if LInPascalDoc then
      begin
        LComment.AppendLine(LTrimmed);
        if LTrimmed.Contains('}') then
          LInPascalDoc := False;
        Continue;
      end;
      if LTrimmed.StartsWith('{**') then
      begin
        LComment.Clear;
        LComment.AppendLine(LTrimmed);
        LCommentLine := I + 1;
        LInPascalDoc := not LTrimmed.Contains('}');
        Continue;
      end;
      if LTrimmed.StartsWith('///') then
      begin
        if LComment.Length = 0 then
          LCommentLine := I + 1;
        LComment.AppendLine(LTrimmed.Substring(3).Trim);
        Continue;
      end;
      if LComment.Length = 0 then
        Continue;
      if LTrimmed.IsEmpty or SameText(LTrimmed, 'type') or
         SameText(LTrimmed, 'const') or LTrimmed.StartsWith('[') then
        Continue;
      var LKind, LName: string;
      if TryParseDeclaration(LLine, LKind, LName) then
      begin
        var LSymbol := TBoss4DDocumentationSymbol.Create;
        LSymbol.Name := LName;
        LSymbol.Kind := LKind;
        LSymbol.Summary := NormalizeComment(LComment.ToString);
        LSymbol.SourcePath := ExtractRelativePath(
          IncludeTrailingPathDelimiter(ARoot), ASourcePath).Replace('\', '/');
        LSymbol.Line := LCommentLine;
        Result.Add(LSymbol);
      end;
      LComment.Clear;
    end;
  finally
    LComment.Free;
    LLines.Free;
  end;
end;

function TBoss4DDocumentationService.RenderSearchIndex(
  const ASymbols: TObjectList<TBoss4DDocumentationSymbol>): string;
var
  LRoot: TJSONObject;
  LItems: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  LItems := TJSONArray.Create;
  try
    for var LSymbol in ASymbols do
      LItems.AddElement(TJSONObject.Create
        .AddPair('name', LSymbol.Name)
        .AddPair('kind', LSymbol.Kind)
        .AddPair('summary', LSymbol.Summary)
        .AddPair('source', LSymbol.SourcePath)
        .AddPair('line', TJSONNumber.Create(LSymbol.Line)));
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('symbolCount', TJSONNumber.Create(ASymbols.Count));
    LRoot.AddPair('symbols', LItems);
    LItems := nil;
    Result := LRoot.ToJSON;
  finally
    LItems.Free;
    LRoot.Free;
  end;
end;

function TBoss4DDocumentationService.RenderHtml(
  const ASymbols: TObjectList<TBoss4DDocumentationSymbol>): string;
begin
  Result := '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>Boss4D API Documentation</title><style>' +
    'body{font-family:system-ui;margin:auto;max-width:1100px;padding:2rem;background:#0b1020;color:#e5e7eb}' +
    'input{width:100%;box-sizing:border-box;padding:.8rem;margin:1rem 0;background:#111827;color:inherit;border:1px solid #475569}' +
    'article{padding:1rem;margin:.8rem 0;border:1px solid #334155;border-radius:.7rem;background:#111827}' +
    'code{color:#5eead4}small{color:#94a3b8}[hidden]{display:none}</style></head><body>' +
    '<h1>Boss4D API Documentation</h1><p><strong id="visible-count">' +
    ASymbols.Count.ToString + '</strong> documented symbols</p>' +
    '<label>Search API<input id="api-search" type="search" placeholder="symbol, kind, source or summary"></label>' +
    '<main id="symbols">';
  for var LSymbol in ASymbols do
    Result := Result + '<article data-search="' +
      TNetEncoding.HTML.Encode(LSymbol.Name + ' ' + LSymbol.Kind + ' ' +
        LSymbol.SourcePath + ' ' + LSymbol.Summary) + '"><h2>' +
      TNetEncoding.HTML.Encode(LSymbol.Name) + '</h2><code>' +
      TNetEncoding.HTML.Encode(LSymbol.Kind) + '</code><p>' +
      TNetEncoding.HTML.Encode(LSymbol.Summary) + '</p><small>' +
      TNetEncoding.HTML.Encode(LSymbol.SourcePath) + ':' +
      LSymbol.Line.ToString + '</small></article>';
  Result := Result + '</main><script>const q=document.getElementById("api-search"),' +
    'items=[...document.querySelectorAll("article")];function apply(){let n=0;' +
    'items.forEach(x=>{x.hidden=!x.dataset.search.toLowerCase().includes(q.value.toLowerCase());if(!x.hidden)n++;});' +
    'document.getElementById("visible-count").textContent=n;}q.addEventListener("input",apply);' +
    '</script></body></html>';
end;

function TBoss4DDocumentationService.Generate(
  const ARootDirectory, AOutputDirectory: string;
  const AIncludeDependencies: Boolean): TBoss4DDocumentationResult;
var
  LSymbols: TObjectList<TBoss4DDocumentationSymbol>;
  LFiles: TList<string>;
begin
  var LRoot := TPath.GetFullPath(ARootDirectory);
  var LOutput := TPath.GetFullPath(AOutputDirectory);
  if not TDirectory.Exists(LRoot) then
    raise EDirectoryNotFoundException.CreateFmt(
      'Diretorio raiz nao encontrado: %s.', [LRoot]);
  LSymbols := TObjectList<TBoss4DDocumentationSymbol>.Create(True);
  LFiles := TList<string>.Create;
  try
    for var LPattern in TArray<string>.Create('*.pas', '*.pp') do
      for var LSource in TDirectory.GetFiles(LRoot, LPattern,
        TSearchOption.soAllDirectories) do
        if IsSourceIncluded(LRoot, LOutput, LSource,
          AIncludeDependencies) then
          LFiles.Add(LSource);
    LFiles.Sort;
    for var LSource in LFiles do
    begin
      var LExtracted := ExtractSymbols(LRoot, LSource);
      try
        while LExtracted.Count > 0 do
          LSymbols.Add(LExtracted.Extract(LExtracted[0]));
      finally
        LExtracted.Free;
      end;
    end;
    LSymbols.Sort(TComparer<TBoss4DDocumentationSymbol>.Construct(
      function(const ALeft, ARight: TBoss4DDocumentationSymbol): Integer
      begin
        Result := CompareText(ALeft.Name, ARight.Name);
        if Result = 0 then
          Result := CompareText(ALeft.SourcePath, ARight.SourcePath);
      end));
    TDirectory.CreateDirectory(LOutput);
    TFile.WriteAllText(TPath.Combine(LOutput, 'index.html'),
      RenderHtml(LSymbols), TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LOutput, 'search-index.json'),
      RenderSearchIndex(LSymbols), TEncoding.UTF8);
    Result.Files := LFiles.Count;
    Result.Symbols := LSymbols.Count;
    Result.OutputDirectory := LOutput;
  finally
    LFiles.Free;
    LSymbols.Free;
  end;
end;

end.
