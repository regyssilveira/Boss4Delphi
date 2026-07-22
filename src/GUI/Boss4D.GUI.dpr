program Boss4D.GUI;

uses
  Vcl.Forms,

  Boss4D.GUI.Main in 'Boss4D.GUI.Main.pas' {FormMain},
  Boss4D.Core.Domain.Consts in '..\Core\Domain\Boss4D.Core.Domain.Consts.pas',
  Boss4D.Core.Domain.Env in '..\Core\Domain\Boss4D.Core.Domain.Env.pas',
  Boss4D.Core.Domain.SemVer in '..\Core\Domain\Boss4D.Core.Domain.SemVer.pas',
  Boss4D.Core.Domain.Dependency in '..\Core\Domain\Boss4D.Core.Domain.Dependency.pas',
  Boss4D.Core.Domain.Package in '..\Core\Domain\Boss4D.Core.Domain.Package.pas',
  Boss4D.Core.Domain.Lock in '..\Core\Domain\Boss4D.Core.Domain.Lock.pas',
  Boss4D.Core.Domain.Sbom in '..\Core\Domain\Boss4D.Core.Domain.Sbom.pas',
  Boss4D.Core.Domain.License in '..\Core\Domain\Boss4D.Core.Domain.License.pas',
  Boss4D.Core.Ports in '..\Core\Ports\Boss4D.Core.Ports.pas',
  Boss4D.Adapters.Json in '..\Adapters\Json\Boss4D.Adapters.Json.pas',
  Boss4D.Adapters.Http in '..\Adapters\Http\Boss4D.Adapters.Http.pas',
  Boss4D.Adapters.Git in '..\Adapters\Git\Boss4D.Adapters.Git.pas',
  Boss4D.Adapters.Registry in '..\Adapters\Registry\Boss4D.Adapters.Registry.pas',
  Boss4D.Adapters.Compiler in '..\Adapters\Compiler\Boss4D.Adapters.Compiler.pas',
  Boss4D.Adapters.Logger in '..\Adapters\Logger\Boss4D.Adapters.Logger.pas',
  Boss4D.Core.Services.Init in '..\Core\Services\Boss4D.Core.Services.Init.pas',
  Boss4D.Core.Services.Config in '..\Core\Services\Boss4D.Core.Services.Config.pas',
  Boss4D.Core.Services.Install in '..\Core\Services\Boss4D.Core.Services.Install.pas',
  Boss4D.Core.Services.Cache in '..\Core\Services\Boss4D.Core.Services.Cache.pas',
  Boss4D.Core.Services.Run in '..\Core\Services\Boss4D.Core.Services.Run.pas',
  Boss4D.Core.Services.Doctor in '..\Core\Services\Boss4D.Core.Services.Doctor.pas',
  Boss4D.Core.Services.License in '..\Core\Services\Boss4D.Core.Services.License.pas',
  Boss4D.Core.Services.Tree in '..\Core\Services\Boss4D.Core.Services.Tree.pas',
  Boss4D.Core.Services.Outdated in '..\Core\Services\Boss4D.Core.Services.Outdated.pas',
  Boss4D.Core.Services.IDEIntegration in '..\Core\Services\Boss4D.Core.Services.IDEIntegration.pas',
  Boss4D.Core.Services.Tool in '..\Core\Services\Boss4D.Core.Services.Tool.pas',
  Boss4D.Core.Services.Workspace in '..\Core\Services\Boss4D.Core.Services.Workspace.pas',
  Boss4D.Core.Services.GetIt in '..\Core\Services\Boss4D.Core.Services.GetIt.pas',
  Boss4D.Core.Services.Scaffold in '..\Core\Services\Boss4D.Core.Services.Scaffold.pas',
  Boss4D.Core.Services.SourceNormalizer in '..\Core\Services\Boss4D.Core.Services.SourceNormalizer.pas',
  Boss4D.Core.Services.PackageManifest in '..\Core\Services\Boss4D.Core.Services.PackageManifest.pas';



begin
  Application.Initialize;
  Application.MainFormOnTaskBar := True;

  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
