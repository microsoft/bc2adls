codeunit 82571 "ADLSE Installer"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag()) then
            AddAllowedTables();
    end;

    procedure AddAllowedTables()
    var
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
        ADLSERun: Record "ADLSE Run";
        ADLSEDeletedRecord: record "ADLSE Deleted Record";
        RetentionPeriodEnum: Enum "Retention Period Enum";
        UpgradeTag: Codeunit "Upgrade Tag";
        RecRef: RecordRef;
        TableFilters: JsonArray;
    begin
        RetenPolAllowedTables.AddAllowedTable(Database::"ADLSE Run", ADLSERun.FieldNo(SystemModifiedAt));

        UpgradeTag.SetUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag());
    end;

    local procedure GetRetenPolLogEntryAddedUpgradeTag(): Code[250]
    begin
        exit('MS-334067-ADLSERetenPolLogEntryAdded-20221028');
    end;
}