unit NotificationControls;

{$mode objfpc}{$H+}

interface

uses
  Forms, Classes, SysUtils, Controls, Graphics, LCLType, StdCtrls, ExtCtrls, Buttons, LMessages;

type

  { TDefaultNotificationControl }

  TDefaultNotificationControl = class(TCustomControl)
  private
    FLabel: TLabel;
    FTimer: TTimer;
    FCloseButton: TSpeedButton;
    procedure HideMessage(Sender: TObject);
    procedure DelayedDestroy(Data: PtrInt);
    procedure SetMessage(const Value: String);
    procedure SetTimeout(const Value: Integer);
  protected
    procedure CreateWnd; override;
    procedure Paint; override;
    procedure VisibleChanged; override;
    procedure WMEraseBkgnd(var Message: TLMEraseBkgnd); message LM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    property Message: String write SetMessage;
    property Timeout: Integer write SetTimeout;
  end;

implementation

uses
  LCLIntf, Themes;

{ TDefaultNotificationControl }

procedure TDefaultNotificationControl.HideMessage(Sender: TObject);
begin
  Visible := False;
end;

procedure TDefaultNotificationControl.DelayedDestroy(Data: PtrInt);
begin
  Destroy;
end;

procedure TDefaultNotificationControl.SetMessage(const Value: String);
begin
  FLabel.Caption := Value;
end;

procedure TDefaultNotificationControl.SetTimeout(const Value: Integer);
begin
  if FTimer  = nil then
  begin
    FTimer := TTimer.Create(Self);
    FTimer.OnTimer := @HideMessage;
  end;
  FTimer.Interval := Value;
end;

procedure TDefaultNotificationControl.CreateWnd;
begin
  inherited CreateWnd;
  Canvas.Brush.Color := clYellow;
end;

procedure TDefaultNotificationControl.Paint;
begin
  Canvas.Rectangle(0, 0, Width, Height);
end;

procedure TDefaultNotificationControl.VisibleChanged;
begin
  inherited VisibleChanged;
  if Visible then
  begin
    if (FTimer <> nil) and (FTimer.Interval > 0) then
      FTimer.Enabled := True;
  end
  else
  begin
    //auto destroy on hide
    Application.QueueAsyncCall(@DelayedDestroy, 0);
  end;
end;

procedure TDefaultNotificationControl.WMEraseBkgnd(var Message: TLMEraseBkgnd);
begin
  // Do nothing. Just to avoid flicker.
end;

constructor TDefaultNotificationControl.Create(AOwner: TComponent);
var
  CloseBitmap, CloseMask: HBITMAP;
begin
  inherited Create(AOwner);
  FCloseButton := TSpeedButton.Create(Self);
  FCloseButton.Parent := Self;
  FCloseButton.OnClick := @HideMessage;
  FCloseButton.Flat := True;
  ThemeServices.GetStockImage(idButtonClose, CloseBitmap, CloseMask);
  FCloseButton.Glyph.Handle := CloseBitmap;
  FCloseButton.Glyph.MaskHandle := CloseMask;
  FCloseButton.Width := FCloseButton.Glyph.Width + 2;
  FCloseButton.Height := FCloseButton.Glyph.Height + 2;
  FCloseButton.Top := 2;
  FCloseButton.Anchors := [akRight, akTop];
  FCloseButton.AnchorParallel(akRight, 2, Self);
  FCloseButton.Visible := True;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.WordWrap := True;
  FLabel.Layout := tlCenter;
  FLabel.Left := 4;
  FLabel.AnchorVerticalCenterTo(Self);
  FLabel.Visible := True;

  Height := FCloseButton.Height + 4;
end;

end.
