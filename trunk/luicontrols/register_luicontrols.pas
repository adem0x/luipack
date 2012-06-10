unit register_luicontrols;

{$Mode ObjFpc}
{$H+}

interface

uses 
  Classes, SysUtils, LResources, LazarusPackageIntf,
  ToggleLabel, MenuButton, SearchEdit, ValidateEdit, WizardControls,
  DropDownManager, DropDownButton, AdvancedLabel;
  
procedure Register;

implementation

const
  ComponentPage = 'Lui Controls';

procedure RegisterUnitToggleLabel;
begin
  RegisterComponents(ComponentPage, [TToggleLabel]);
end;  

procedure RegisterUnitMenuButton;
begin
  RegisterComponents(ComponentPage, [TMenuButton]);
end;

procedure RegisterUnitSearchEdit;
begin
  RegisterComponents(ComponentPage, [TSearchEdit]);
end;

procedure RegisterUnitValidateEdit;
begin
  RegisterComponents(ComponentPage, [TDBDateMaskEdit, TDBValidateEdit]);
end;

procedure RegisterUnitWizardControls;
begin
  RegisterComponents(ComponentPage, [TWizardController, TWizardButtonPanel]);
end;

procedure RegisterUnitDropDownManager;
begin
  RegisterComponents(ComponentPage, [TDropDownManager]);
end;

procedure RegisterUnitDropDownButton;
begin
  RegisterComponents(ComponentPage, [TDropDownButton]);
end;

procedure RegisterUnitAdvancedLabel;
begin
  RegisterComponents(ComponentPage, [TAdvancedLabel]);
end;


procedure Register;

begin
  RegisterUnit('ToggleLabel',@RegisterUnitToggleLabel);
  RegisterUnit('MenuButton',@RegisterUnitMenuButton);
  RegisterUnit('SearchEdit',@RegisterUnitSearchEdit);
  RegisterUnit('ValidateEdit',@RegisterUnitValidateEdit);
  RegisterUnit('WizardControls',@RegisterUnitWizardControls);
  RegisterUnit('DropDownManager',@RegisterUnitDropDownManager);
  RegisterUnit('DropDownButton',@RegisterUnitDropDownButton);
  RegisterUnit('AdvancedLabel',@RegisterUnitAdvancedLabel);
end; 

initialization
{.$i ideicons.lrs}
 
end.
