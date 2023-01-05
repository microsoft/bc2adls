codeunit 82572 "ADLSE Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnCheckPreconditionsPerDatabase()
    var
        ADLSEInstaller: Codeunit "ADLSE Installer";
        ADLSEExecution: Codeunit "ADLSE Execution";
        InvalidFieldsMap: Dictionary of [Integer, List of [Text]];
    begin
        InvalidFieldsMap := ADLSEInstaller.ListInvalidFieldsBeingExported();
        if InvalidFieldsMap.Count() > 0 then begin
            ADLSEExecution.Log('ADLSE-30',
                'Upgrade preconditions not met as there are invalid fields enabled for export. Please see previous telemetry.', Verbosity::Error);
            // raise error on encountering invalid fields so user can react to these errors and fix the export configuration
            Error(InvalidFieldsBeingExportedErr, ConcatenateTableFieldPairs(InvalidFieldsMap));
        end;
    end;

    trigger OnUpgradePerDatabase()
    var
        ADLSEInstaller: Codeunit "ADLSE Installer";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag()) then
            exit;
        ADLSEInstaller.AddAllowedTables();
        UpgradeTag.SetUpgradeTag(GetRetenPolLogEntryAddedUpgradeTag());
    end;

    var
        TableFieldsTok: Label '[%1]: %2\\', Comment = '%1: table caption, %2: list of field captions', Locked = true;

    local procedure ConcatenateTableFieldPairs(TableIDFieldNameList: Dictionary of [Integer, List of [Text]]) Result: Text
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        TableID: Integer;
    begin
        foreach TableID in TableIDFieldNameList.Keys() do
            Result += StrSubstNo(TableFieldsTok, ADLSEUtil.GetTableCaption(TableID), ADLSEUtil.Concatenate(TableIDFieldNameList.Get(TableID)));
    end;

    var
        InvalidFieldsBeingExportedErr: Label 'The following table fields cannot be exported. Please disable them. %1', Comment = '%1 = List of table - field pairs';

    local procedure GetRetenPolLogEntryAddedUpgradeTag(): Code[250]
    begin
        exit('MS-334067-ADLSERetenPolLogEntryAdded-20221028');
    end;
}