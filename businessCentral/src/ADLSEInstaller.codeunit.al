codeunit 82571 "ADLSE Installer"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
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
        if UpgradeTag.HasUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag()) then
            exit;

        RetenPolAllowedTables.AddAllowedTable(Database::"ADLSE Run", ADLSERun.FieldNo(SystemModifiedAt));

        ADLSEDeletedRecord.SetRange(Exported, false);
        RecRef.GetTable(ADLSEDeletedRecord);
        RetenPolAllowedTables.AddTableFilterToJsonArray(TableFilters, RetentionPeriodEnum::"Never Delete", ADLSEDeletedRecord.FieldNo(SystemCreatedAt), true, true, RecRef);
        ADLSEDeletedRecord.Reset();
        ADLSEDeletedRecord.SetRange(Exported, true);
        RecRef.GetTable(ADLSEDeletedRecord);
        RetenPolAllowedTables.AddTableFilterToJsonArray(TableFilters, RetentionPeriodEnum::"1 Week", ADLSEDeletedRecord.FieldNo(SystemCreatedAt), true, false, RecRef);

        RetenPolAllowedTables.AddAllowedTable(Database::"ADLSE Deleted Record", ADLSEDeletedRecord.FieldNo(SystemCreatedAt), TableFilters);

        UpgradeTag.SetUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag());
    end;

    local procedure GetRetenPolLogEntryAddedUpgradeTag(): Code[250]
    begin
        exit('MS-334067-ADLSERetenPolLogEntryAdded-20221028');
    end;
}