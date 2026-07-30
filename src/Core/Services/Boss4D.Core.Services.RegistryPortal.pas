unit Boss4D.Core.Services.RegistryPortal;

interface

type
  TBoss4DRegistryPortalService = class
  private
    function EscapeHtml(const AValue: string): string;
  public
    function Generate(const ARegistryContent: string): string;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.NetEncoding;

function TBoss4DRegistryPortalService.EscapeHtml(
  const AValue: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AValue);
end;

function TBoss4DRegistryPortalService.Generate(
  const ARegistryContent: string): string;
var
  LRoot: TJSONObject;
  LPackages: TJSONArray;
begin
  LRoot := TJSONObject.ParseJSONValue(ARegistryContent) as TJSONObject;
  if not Assigned(LRoot) or
     (LRoot.GetValue<Integer>('schemaVersion', 0) <> 1) then
  begin
    LRoot.Free;
    raise EArgumentException.Create('Registry v1 invalido.');
  end;
  try
    LPackages := LRoot.GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
      raise EArgumentException.Create('Registry sem packages.');
    Result := '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>Boss4D Public Registry</title></head><body>' +
      '<main><h1>Boss4D Public Registry</h1><p>Protocol v1</p><ul>';
    for var LValue in LPackages do
    begin
      var LPackage := TJSONObject(LValue);
      Result := Result + '<li><strong>' +
        EscapeHtml(LPackage.GetValue<string>('name', '')) +
        '</strong> <code>' +
        EscapeHtml(LPackage.GetValue<string>('version', '')) +
        '</code><p>' +
        EscapeHtml(LPackage.GetValue<string>('description', '')) +
        '</p><a href="https://' +
        EscapeHtml(LPackage.GetValue<string>('repository', '')) +
        '">repository</a></li>';
    end;
    Result := Result + '</ul></main></body></html>';
  finally
    LRoot.Free;
  end;
end;

end.
