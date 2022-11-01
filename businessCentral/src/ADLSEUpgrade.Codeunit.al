codeunit 82572 "ADLSE Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerCompany()
    var
        adlseInstaller: Codeunit "ADLSE Installer";
    begin
        adlseInstaller.AddAllowedTables(); // also sets the tag!
    end;
}