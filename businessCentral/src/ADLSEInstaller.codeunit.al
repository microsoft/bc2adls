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
        ADLSEUpgrade: Codeunit "ADLSE Upgrade";
        ADLSERun: Record "ADLSE Run";
        ADLSEDeletedRecord: record "ADLSE Deleted Record";
        RetentionPeriodEnum: Enum "Retention Period Enum";
        UpgradeTag: Codeunit "Upgrade Tag";
        RecRef: RecordRef;
        TableFilters: JsonArray;
    begin
        RetenPolAllowedTables.AddAllowedTable(Database::"ADLSE Run", ADLSERun.FieldNo(SystemModifiedAt));
    end;
}