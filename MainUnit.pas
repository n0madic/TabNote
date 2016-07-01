unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ComCtrls, Registry,
  ExtCtrls, AppEvnts, IniFiles, Menus, ChromeTabs, ChromeTabsTypes,
  ChromeTabsUtils, ChromeTabsControls, ChromeTabsClasses, ChromeTabsLog;

type
  TFormMain = class(TForm)
    ChromeTabs1: TChromeTabs;
    StatusBar1: TStatusBar;
    Memo1: TMemo;
    Panel1: TPanel;
    Label1: TLabel;
    EditRename: TEdit;
    ButtonOK: TButton;
    TrayIcon1: TTrayIcon;
    ApplicationEvents1: TApplicationEvents;
    TrayPopupMenu: TPopupMenu;
    Show1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    ButtonCancel: TButton;
    TimerSave: TTimer;
    Bevel1: TBevel;
    procedure ChromeTabs1ButtonAddClick(Sender: TObject; var Handled: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure ChromeTabs1ActiveTabChanged(Sender: TObject; ATab: TChromeTab);
    procedure Memo1Change(Sender: TObject);
    procedure ChromeTabs1ButtonCloseTabClick(Sender: TObject; ATab: TChromeTab;
      var Close: Boolean);
    procedure ChromeTabs1TabDblClick(Sender: TObject; ATab: TChromeTab);
    procedure ButtonOKClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ApplicationEvents1Minimize(Sender: TObject);
    procedure Memo1Exit(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure TimerSaveTimer(Sender: TObject);
    procedure TrayIcon1Click(Sender: TObject);
    procedure ChromeTabs1TabDragEnd(Sender: TObject; MouseX,
      MouseY: Integer; Cancelled: Boolean);
    procedure FormShow(Sender: TObject);
    procedure Memo1KeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
    procedure SaveINI;
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;
  Notes: TStringList;
  Ini: TMemIniFile;
  IniName: String;
  IsSaved: boolean;
  TotalTabCount: integer;

implementation

{$R *.dfm}

procedure TFormMain.SaveINI;
var i: integer;
begin
  // Save INI file if there are changes
  If Not IsSaved Then
    begin
    TimerSave.Enabled := False;
    // Save notes
    if Ini.SectionExists('Notes') then Ini.EraseSection('Notes');
    if Notes.Count > 0 then
      for i:= 0 to Notes.Count-1 do
        Ini.WriteString('Notes', Notes.Names[i], Notes.ValueFromIndex[i]);
    IsSaved := True;
    // Text on statusbar
    StatusBar1.SimpleText := 'Saved';
    TimerSave.Enabled := True;
    // Save window position/size
    Ini.WriteInteger('Config', 'FormWidth', FormMain.Width);
    Ini.WriteInteger('Config', 'FormHeight', FormMain.Height);
    Ini.WriteInteger('Config', 'FormTop', FormMain.Top);
    Ini.WriteInteger('Config', 'FormLeft', FormMain.Left);
    // Write INI file
    Ini.UpdateFile;
  end;
end;

procedure TFormMain.TimerSaveTimer(Sender: TObject);
begin
  // Save update by timer (if changed)
  StatusBar1.SimpleText := '';
  SaveINI;
end;

procedure TFormMain.FormCreate(Sender: TObject);
var i: integer;
    RegIniFile : TRegIniFile;
begin
  Notes := TStringList.Create;
  IniName := ChangeFileExt(Application.ExeName, '.ini');
  // Backup INI file on startup
  CopyFile(PChar(IniName), PChar(IniName+'.bak'), False);
  // Create INI with Unicode, if it possible
  Ini := TMemIniFile.Create(IniName {$if CompilerVersion >= 20}, TEncoding.UTF8{$ifend});
  // Check autostart
  RegIniFile := TRegIniFile.Create('Software\Microsoft\Windows\CurrentVersion\Run');
  if (Not RegIniFile.ValueExists(Application.Title)) And (Not Ini.ReadBool('Config', 'NoAutostart', False)) then
    if MessageBox(0, 'Run program on startup?!', 'TabNote autostart', MB_YESNO Or MB_ICONQUESTION) = IDYES then
      begin
        RegIniFile.WriteString('', Application.Title, Application.ExeName);
        Ini.WriteBool('Config', 'NoAutostart', False);
      end
    else
      // Remember that the autostart is not needed
      Ini.WriteBool('Config', 'NoAutostart', True);
  RegIniFile.Free;
  // Read notes from INI file
  if Ini.SectionExists('Notes') then
  begin
    Ini.ReadSectionValues('Notes',Notes);
    for i := 0 to Notes.Count-1 do
      ChromeTabs1.Tabs.Add.Caption := Notes.Names[i];
  end
  else // if notes not found
    ChromeTabs1.Tabs.Add.Caption := 'Note 1';
  // Get total tabs counter
  TotalTabCount := Ini.ReadInteger('Config', 'TotalTabCount', 1);
  // Restore ActiveTab index
  ChromeTabs1.ActiveTabIndex := Ini.ReadInteger('Config', 'ActiveTabIndex', 0);
  // Update Memo
  Memo1.Lines.CommaText := Notes.Values[ChromeTabs1.ActiveTab.Caption];
  IsSaved := True;
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  // Restore window position and size
  FormMain.Width := Ini.ReadInteger('Config', 'FormWidth', FormMain.Width);
  FormMain.Height := Ini.ReadInteger('Config', 'FormHeight', FormMain.Height);
  FormMain.Top := Ini.ReadInteger('Config', 'FormTop', FormMain.Top);
  FormMain.Left := Ini.ReadInteger('Config', 'FormLeft', FormMain.Left);
end;

procedure TFormMain.ChromeTabs1ActiveTabChanged(Sender: TObject;
  ATab: TChromeTab);
begin
  // Switch tabs
  Memo1.Lines.Clear;
  Memo1.Lines.CommaText := Notes.Values[ATab.Caption];
  IsSaved := True;
  Memo1.Enabled := True;
  // Save current index
  Ini.WriteInteger('Config', 'ActiveTabIndex', ATab.Index);
  If Memo1.Showing Then Memo1.SetFocus;
end;

procedure TFormMain.ChromeTabs1TabDragEnd(Sender: TObject; MouseX,
  MouseY: Integer; Cancelled: Boolean);
begin
  // Save disposition of the tabs
  IsSaved := False;
end;

procedure TFormMain.ChromeTabs1ButtonAddClick(Sender: TObject;
  var Handled: Boolean);
  var NewName: String;
begin
  // Add no more than 30 tabs
  if ChromeTabs1.Tabs.Count < 30 then
  begin
    Handled := true;
    repeat
      TotalTabCount := TotalTabCount + 1;
      NewName := 'Note '+IntToStr(TotalTabCount);
      // Check whether there is such a name
    until Notes.IndexOfName(NewName) = -1;
    ChromeTabs1.Tabs.Add.Caption := NewName;
    Notes.Values[NewName] := ' ';
    Memo1.Lines.Clear;
    // Update total tabs counter
    Ini.WriteInteger('Config', 'TotalTabCount', TotalTabCount);
    IsSaved := False;
    Memo1.Enabled := True;
  end;
end;

procedure TFormMain.ChromeTabs1ButtonCloseTabClick(Sender: TObject;
  ATab: TChromeTab; var Close: Boolean);
var index: integer;
begin
  // Delete tab
  index := Notes.IndexOfName(ATab.Caption);
  If index <> -1 Then Notes.Delete(index);
  Memo1.Lines.Clear;
  Close := True;
  if ChromeTabs1.Tabs.Count = 1 then
    Memo1.Enabled := False;
  IsSaved := False;
  SaveINI;
end;

procedure TFormMain.ChromeTabs1TabDblClick(Sender: TObject; ATab: TChromeTab);
begin
  // Show rename tab dialog
  EditRename.Text := ATab.Caption;
  Panel1.Visible := True;
  // Prevent switching tabs
  ChromeTabs1.Enabled := False;
end;

procedure TFormMain.ButtonOKClick(Sender: TObject);
var index: integer;
begin
  // Rename tab
  index := Notes.IndexOfName(ChromeTabs1.ActiveTab.Caption);
  // If name changed
  if EditRename.Text <> ChromeTabs1.ActiveTab.Caption then
    // and no longer meets
    if Notes.IndexOfName(EditRename.Text) <> -1 then MessageBox(0, 'Already there is a name of the tab!', 'Error', MB_OK or MB_ICONERROR) else
    begin
      Notes[index] := EditRename.Text + Notes.NameValueSeparator+Notes.ValueFromIndex[index];
      ChromeTabs1.ActiveTab.Caption := EditRename.Text;
    end;
  ChromeTabs1.Enabled := True;
  Panel1.Visible := False;
  IsSaved := False;
  SaveINI;
end;

procedure TFormMain.ButtonCancelClick(Sender: TObject);
begin
  // Hide rename dialog without changes
  Panel1.Visible := False;
  ChromeTabs1.Enabled := True;
end;

procedure TFormMain.Memo1Change(Sender: TObject);
begin
  // Update notes if Memo change
  Notes.Values[ChromeTabs1.ActiveTab.Caption] := Memo1.Lines.CommaText;
  IsSaved := False;
  TimerSave.Enabled := False;
  TimerSave.Enabled := True;
end;

procedure TFormMain.Memo1KeyPress(Sender: TObject; var Key: Char);
begin
  // Clear status bar if key pressed in Memo
  if IsCharAlphaNumeric(Key) then StatusBar1.SimpleText := '';
end;

procedure TFormMain.Memo1Exit(Sender: TObject);
begin
  // Saving changes while leaving the memo
  SaveINI;
end;

procedure TFormMain.ApplicationEvents1Minimize(Sender: TObject);
begin
  // Minimize application to the system tray
  TrayIcon1.Visible := True;
  Application.Minimize;
  Application.MainForm.Visible := False;
end;

procedure TFormMain.TrayIcon1Click(Sender: TObject);
begin
  // Restore application from system tray
  Application.MainForm.Visible := True;
  Application.Restore;
  Application.BringToFront;
  TrayIcon1.Visible := False;
end;

procedure TFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveINI;
  Ini.Free;
end;

procedure TFormMain.Exit1Click(Sender: TObject);
begin
  SaveINI;
  Ini.Free;
  Application.Terminate;
end;

end.
