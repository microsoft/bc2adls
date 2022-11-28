codeunit 82572 "ADLSE Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerCompany()
    var
        ADLSEInstaller: Codeunit "ADLSE Installer";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag()) then
            exit;
        ADLSEInstaller.AddAllowedTables();
        UpgradeTag.SetUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag());
    end;

    local procedure GetRetenPolLogEntryAddedUpgradeTag(): Code[250]
    begin
        exit('MS-334067-ADLSERetenPolLogEntryAdded-20221028');
    end;
}