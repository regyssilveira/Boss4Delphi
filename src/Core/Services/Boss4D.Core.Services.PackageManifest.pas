unit Boss4D.Core.Services.PackageManifest;

interface

uses
  System.SysUtils, System.RegularExpressions, System.Generics.Collections;

type
  TBoss4DPackageManifest = class
  public
    class function AddRequires(const AContent: string;
      const ADependencies: TArray<string>): string; static;
  end;

implementation

class function TBoss4DPackageManifest.AddRequires(const AContent: string;
  const ADependencies: TArray<string>): string;
var
  LMatch: TMatch;
  LRequiresStart: Integer;
  LRequiresBlock, LUpdatedBlock: string;
  LRestOfFile: string;
  LSemicolonPositions: TList<Integer>;
  I, J: Integer;
  LInSingleComment: Boolean;
  LInBlockComment1: Boolean;
  LInBlockComment2: Boolean;
  LInString: Boolean;
  LChar, LNextChar: Char;
  LPos, LPrevPos: Integer;
  LChunk, LUpdatedChunk: string;
  LDependency: string;
  LLines: TArray<string>;
  LLastLineIdx: Integer;
  LLastLine: string;
  LCommentIdx: Integer;
  LBeforeComment, LCommentPart: string;
  LIndent: string;
begin
  // Localiza o bloco requires completo desde a palavra 'requires' ate 'contains' ou 'end'
  LMatch := TRegEx.Match(AContent, '(?is)\brequires\b(?<body>.*?)\b(contains|end)\b');
  if not LMatch.Success then
    raise EArgumentException.Create('Clausula requires nao encontrada no DPK.');

  LRequiresStart := LMatch.Groups['body'].Index;
  LRequiresBlock := LMatch.Groups['body'].Value;
  LRestOfFile := AContent.Substring(LRequiresStart - 1 + LRequiresBlock.Length);
  
  LSemicolonPositions := TList<Integer>.Create;
  try
    LInSingleComment := False;
    LInBlockComment1 := False;
    LInBlockComment2 := False;
    LInString := False;
    
    I := 1;
    while I <= Length(LRequiresBlock) do
    begin
      LChar := LRequiresBlock[I];
      if I < Length(LRequiresBlock) then
        LNextChar := LRequiresBlock[I + 1]
      else
        LNextChar := #0;
        
      if LInSingleComment then
      begin
        if (LChar = #10) or (LChar = #13) then
          LInSingleComment := False;
      end
      else if LInBlockComment1 then
      begin
        if LChar = '}' then
          LInBlockComment1 := False;
      end
      else if LInBlockComment2 then
      begin
        if (LChar = '*') and (LNextChar = ')') then
        begin
          LInBlockComment2 := False;
          Inc(I);
        end;
      end
      else if LInString then
      begin
        if LChar = '''' then
          LInString := False;
      end
      else
      begin
        if (LChar = '/') and (LNextChar = '/') then
        begin
          LInSingleComment := True;
          Inc(I);
        end
        else if LChar = '{' then
        begin
          LInBlockComment1 := True;
        end
        else if (LChar = '(') and (LNextChar = '*') then
        begin
          LInBlockComment2 := True;
          Inc(I);
        end
        else if LChar = '''' then
        begin
          LInString := True;
        end
        else if LChar = ';' then
        begin
          LSemicolonPositions.Add(I - 1);
        end;
      end;
      Inc(I);
    end;

    LUpdatedBlock := LRequiresBlock;
    
    for J := LSemicolonPositions.Count - 1 downto 0 do
    begin
      LPos := LSemicolonPositions[J];
      if J > 0 then
        LPrevPos := LSemicolonPositions[J - 1] + 1
      else
        LPrevPos := 0;
        
      LChunk := LUpdatedBlock.Substring(LPrevPos, LPos - LPrevPos);
      LUpdatedChunk := LChunk;
      
      for LDependency in ADependencies do
      begin
        if LDependency.Trim.IsEmpty then
          Continue;
          
        if TRegEx.IsMatch(LUpdatedChunk, '(?i)\b' + TRegEx.Escape(LDependency.Trim) + '\b') then
          Continue;
          
        LLines := LUpdatedChunk.Split([sLineBreak, #10, #13]);
        LLastLineIdx := -1;
        for var K := Length(LLines) - 1 downto 0 do
        begin
          if not LLines[K].Trim.IsEmpty then
          begin
            LLastLineIdx := K;
            Break;
          end;
        end;
        
        LCommentIdx := -1;
        if LLastLineIdx >= 0 then
        begin
          LLastLine := LLines[LLastLineIdx];
          LCommentIdx := LLastLine.IndexOf('//');
          
          if LCommentIdx >= 0 then
          begin
            LBeforeComment := LLastLine.Substring(0, LCommentIdx);
            LCommentPart := LLastLine.Substring(LCommentIdx);
            
            LIndent := '';
            var K := 0;
            while (K < LBeforeComment.Length) and CharInSet(LBeforeComment[K + 1], [' ', #9]) do
            begin
              LIndent := LIndent + LBeforeComment[K + 1];
              Inc(K);
            end;
            if LIndent.IsEmpty then
              LIndent := '  ';
              
            if not LBeforeComment.Trim.EndsWith(',') then
              LBeforeComment := LBeforeComment.TrimRight + ',';
              
            LLines[LLastLineIdx] := LBeforeComment.TrimRight + sLineBreak + LIndent + LDependency.Trim + ' ' + LCommentPart;
          end;
        end;
        
        if (LLastLineIdx < 0) or (LCommentIdx < 0) then
        begin
          if LUpdatedChunk.Trim.IsEmpty then
            LUpdatedChunk := sLineBreak + '  ' + LDependency.Trim
          else if LUpdatedChunk.TrimRight.EndsWith(',') then
            LUpdatedChunk := LUpdatedChunk.TrimRight + sLineBreak + '  ' + LDependency.Trim
          else
            LUpdatedChunk := LUpdatedChunk.TrimRight + ',' + sLineBreak + '  ' + LDependency.Trim;
        end
        else
        begin
          LUpdatedChunk := string.Join(sLineBreak, LLines);
        end;
      end;
      
      LUpdatedBlock := LUpdatedBlock.Substring(0, LPrevPos) + LUpdatedChunk + LUpdatedBlock.Substring(LPos);
    end;
  finally
    LSemicolonPositions.Free;
  end;

  Result := AContent.Substring(0, LRequiresStart - 1) + LUpdatedBlock + LRestOfFile;
end;

end.
