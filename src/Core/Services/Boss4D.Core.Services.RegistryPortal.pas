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
  LSchemaVersion: Integer;
begin
  LRoot := TJSONObject.ParseJSONValue(ARegistryContent) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.Create('Registry invalido.');
  LSchemaVersion := LRoot.GetValue<Integer>('schemaVersion', 0);
  if not (LSchemaVersion in [1, 2]) then
  begin
    LRoot.Free;
    raise EArgumentException.Create('Schema de registry nao suportado.');
  end;
  try
    LPackages := LRoot.GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
      raise EArgumentException.Create('Registry sem packages.');
    Result := '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>Boss4D Public Registry</title></head><body>' +
      '<main><h1>Boss4D Public Registry</h1><p>Protocol v' +
      LSchemaVersion.ToString + '</p>' +
      '<label for="package-search">Search packages</label>' +
      '<input id="package-search" type="search" placeholder="name or repository">' +
      '<ul id="packages">';
    for var LValue in LPackages do
    begin
      var LPackage := TJSONObject(LValue);
      Result := Result + '<li data-package="' +
        EscapeHtml(LPackage.GetValue<string>('name', '') + ' ' +
          LPackage.GetValue<string>('repository', '')) + '"><strong>' +
        EscapeHtml(LPackage.GetValue<string>('name', '')) +
        '</strong>';
      if LSchemaVersion = 1 then
        Result := Result + ' <code>' +
          EscapeHtml(LPackage.GetValue<string>('version', '')) + '</code>'
      else
      begin
        var LVersions := LPackage.GetValue<TJSONArray>('versions');
        if Assigned(LVersions) then
          for var LVersionValue in LVersions do
            if LVersionValue is TJSONObject then
            begin
              var LVersion := TJSONObject(LVersionValue);
              Result := Result + '<div><code>' +
                EscapeHtml(LVersion.GetValue<string>('version', ''));
              if LVersion.GetValue<Boolean>('revoked', False) then
                Result := Result + ' (revoked)';
              Result := Result + '</code>';
              if not LVersion.GetValue<string>('sha256', '').IsEmpty then
                Result := Result + ' <span>SHA-256</span>';
              if not LVersion.GetValue<string>('signature', '').IsEmpty then
                Result := Result + ' <span>signature</span>';
              if not LVersion.GetValue<string>('provenance', '').IsEmpty then
                Result := Result + ' <span>provenance</span>';
              Result := Result + '</div>';
            end;
      end;
      Result := Result + '<p>' +
        EscapeHtml(LPackage.GetValue<string>('description', '')) +
        '</p><a href="https://' +
        EscapeHtml(LPackage.GetValue<string>('repository', '')) +
        '">repository</a></li>';
    end;
    Result := Result + '</ul></main><script>' +
      'document.getElementById("package-search").addEventListener("input",function(){' +
      'var q=this.value.toLowerCase();document.querySelectorAll("#packages li").forEach(' +
      'function(x){x.hidden=x.dataset.package.toLowerCase().indexOf(q)<0;});});' +
      '</script></body></html>';
  finally
    LRoot.Free;
  end;
end;

end.
