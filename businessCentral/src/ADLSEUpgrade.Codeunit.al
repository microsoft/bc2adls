codeunit 82572 "ADLSE Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerCompany()
    var
        ADLSEInstaller: Codeunit "ADLSE Installer";
    begin
        ADLSEInstaller.AddAllowedTables(); // also sets the tag!
    end;
}