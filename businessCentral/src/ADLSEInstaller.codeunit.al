codeunit 82571 "ADLSE Installer"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerDatabase()
    begin
        DisableTablesExportingInvalidFields();
        AddAllowedTables();
    end;

    procedure AddAllowedTables()
    var
        ADLSERun: Record "ADLSE Run";
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
    begin
        RetenPolAllowedTables.AddAllowedTable(Database::"ADLSE Run", ADLSERun.FieldNo(SystemModifiedAt));
    end;

    procedure ListInvalidFieldsBeingExported() InvalidFieldsMap: Dictionary of [Integer, List of [Text]]
    var
        ADLSETable: Record "ADLSE Table";
        InvalidFields: List of [Text];
    begin
        // find the tables which export fields that have now been obsoleted or are invalid
        ADLSETable.SetRange(Enabled, true);
        if ADLSETable.FindSet() then
            repeat
                InvalidFields := ADLSETable.ListInvalidFieldsBeingExported();
                if InvalidFields.Count() > 0 then
                    InvalidFieldsMap.Add(ADLSETable."Table ID", InvalidFields);
            until ADLSETable.Next() = 0;
    end;

    local procedure DisableTablesExportingInvalidFields()
    var
        ADLSETable: Record "ADLSE Table";
        TableID: Integer;
    begin
        foreach TableID in ListInvalidFieldsBeingExported().Keys() do begin
            ADLSETable.Get(TableID);
            ADLSETable.Enabled := false;
            ADLSETable.Modify();
        end;
    end;
}