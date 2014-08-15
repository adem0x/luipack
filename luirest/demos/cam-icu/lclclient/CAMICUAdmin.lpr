program CAMICUAdmin;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Controls, zvdatetimectrls, MainView, CAMICUApp,
  CAMICUAppSetup, MainPresenter, PatientModel, PatientEvaluationModel,
PatientEvaluationsView, PatientEvaluationsPresenter, EvaluationView;

{$R *.res}

var
  App: TCAMICUApp;

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  //bootstrap app
  App := TCAMICUApp.Create(Application);
  ConfigureApp(App);
  App.Initialize;
  while not App.ConnectToService do
  begin
    if App.Presentations['appconfig'].ShowModal(['Config', App.Config]) <> mrOK then
    begin
      Application.ShowMainForm := False;
      Application.Terminate;
      break;
    end;
  end;
  if not Application.Terminated then
  begin
    Application.CreateForm(TMainForm, MainForm);
    //setup MainView manually
    MainForm.Presenter := TMainPresenter.Create(Application);
    MainForm.Presenter.Initialize;
  end;
  Application.CreateForm(TPatientEvaluationsForm, PatientEvaluationsForm);
  Application.CreateForm(TEvaluationForm, EvaluationForm);
  Application.Run;
end.

