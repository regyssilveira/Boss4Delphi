unit Boss4D.Adapters.Registry;

interface

uses
  Boss4D.Core.Ports;

type
  { Adaptador para leitura do Registro do Windows buscando instalacoes do Delphi }
  TBoss4DWindowsRegistryAdapter = class(TInterfacedObject, IBoss4DRegistryService)
  public
    function GetInstalledDelphiVersions: TArray<string>;
    function GetDelphiPath(const AVersion: string): string;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, Boss4D.Core.Domain.Consts
  {$IFDEF MSWINDOWS}, System.Win.Registry, System.Classes, Winapi.Windows{$ENDIF};

{ TBoss4DWindowsRegistryAdapter }

function TBoss4DWindowsRegistryAdapter.GetInstalledDelphiVersions: TArray<string>;
{$IFDEF MSWINDOWS}
var
  LReg: TRegistry;
  LSubKeys: TStringList;
  LResultList: TList<string>;
  I: Integer;
begin
  LResultList := TList<string>.Create;
  LSubKeys := TStringList.Create;
  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKeyReadOnly(REGISTRY_BASE_PATH) then
    begin
      LReg.GetKeyNames(LSubKeys);
      for I := 0 to LSubKeys.Count - 1 do
      begin
        var LKey := LSubKeys[I];
        var LVal: Double;
        var LCleanKey := LKey.Replace('.', FormatSettings.DecimalSeparator);
        if TryStrToFloat(LCleanKey, LVal) then
        begin
          LResultList.Add(LKey);
        end;
      end;
    end;
    Result := LResultList.ToArray;
  finally
    LReg.Free;
    LSubKeys.Free;
    LResultList.Free;
  end;
end;
{$ELSE}
begin
  Result := nil;
end;
{$ENDIF}

function TBoss4DWindowsRegistryAdapter.GetDelphiPath(const AVersion: string): string;
{$IFDEF MSWINDOWS}
var
  LReg: TRegistry;
begin
  Result := '';
  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKeyReadOnly(REGISTRY_BASE_PATH + AVersion) then
    begin
      Result := LReg.ReadString('RootDir');
    end;
  finally
    LReg.Free;
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

end.
