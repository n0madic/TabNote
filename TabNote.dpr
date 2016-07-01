program TabNote;

uses
  Forms,
  Dialogs,
  Windows,
  MainUnit in 'MainUnit.pas' {FormMain};

{$R *.res}

var
  Mutex : THandle;

begin
  // Checking for a Previous Instance of an Application
  Mutex := CreateMutex(nil, True, 'TabNote_Mutex');
  if (Mutex = 0) OR (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    ShowMessage('TabNote already running!');
    Halt;
  end
  else
  begin
    Application.Initialize;
    {$if CompilerVersion >= 20}Application.MainFormOnTaskbar := True;{$ifend}
    Application.Title := 'TabNote';
    Application.CreateForm(TFormMain, FormMain);
  Application.Run;
    if Mutex <> 0 then
      CloseHandle(Mutex);
  end;
end.
