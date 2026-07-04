unit Boss4D.Adapters.Http;

interface

uses
  Boss4D.Core.Ports;

type
  { Adaptador HTTP nativo usando System.Net.HttpClient }
  TBoss4DHttpNativeAdapter = class(TInterfacedObject, IBoss4DHttpClient)
  public
    function Get(const AURL: string; out AResponse: string): Integer;
  end;

implementation

uses
  System.SysUtils, System.Net.HttpClient, System.Classes;

{ TBoss4DHttpNativeAdapter }

function TBoss4DHttpNativeAdapter.Get(const AURL: string; out AResponse: string): Integer;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LStringStream: TStringStream;
begin
  AResponse := '';
  LClient := THTTPClient.Create;
  try
    LClient.UserAgent := 'Boss4D/1.0 (Delphi 13 Nativo Dependency Manager)';
    
    // Configura alguns timeouts padrão razoáveis
    LClient.ConnectionTimeout := 10000; // 10 segundos
    LClient.ResponseTimeout := 15000;   // 15 segundos

    LStringStream := TStringStream.Create('', TEncoding.UTF8);
    try
      try
        LResponse := LClient.Get(AURL, LStringStream);
        Result := LResponse.StatusCode;
        AResponse := LStringStream.DataString;
      except
        on E: Exception do
        begin
          Result := 500;
          AResponse := E.Message;
        end;
      end;
    finally
      LStringStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

end.
