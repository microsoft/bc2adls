// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82560 "ADLSE Setup"
{
    Access = Internal;

    var
        FieldClassNotSupportedErr: Label 'The field %1 of class %2 is not supported.', Comment = '%1 = field name, %2 = field class';
        ExportDataInProgressErr: Label 'An export data process is already running. Please wait for it to finish.';
        SelectTableLbl: Label 'Select the tables to be exported';
        FieldObsoleteNotSupportedErr: Label 'The field %1 is obsolete', Comment = '%1 = field name';

    procedure AddTableToExport()
    var
        AllObjWithCaption: Record AllObjWithCaption;
        ADLSETable: Record "ADLSE Table";
        AllObjectsWithCaption: Page "All Objects with Caption";
    begin
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);

        AllObjectsWithCaption.Caption(SelectTableLbl);
        AllObjectsWithCaption.SetTableView(AllObjWithCaption);
        AllObjectsWithCaption.LookupMode(true);
        if AllObjectsWithCaption.RunModal() = Action::LookupOK then begin
            AllObjectsWithCaption.SetSelectionFilter(AllObjWithCaption);
            if AllObjWithCaption.FindSet() then
                repeat
                    ADLSETable.Add(AllObjWithCaption."Object ID");
                until AllObjWithCaption.Next() = 0;
        end;
    end;

    procedure ChooseFieldsToExport(ADLSETable: Record "ADLSE Table")
    var
        ADLSEField: Record "ADLSE Field";
    begin
        ADLSEField.SetRange("Table ID", ADLSETable."Table ID");
        Page.RunModal(Page::"ADLSE Setup Fields", ADLSEField, ADLSEField.Enabled);
    end;

    procedure CheckFieldCanBeExported(Fld: Record Field)
    begin
        if Fld.Class <> Fld.Class::Normal then
            Error(FieldClassNotSupportedErr, Fld.FieldName, Fld.Class);
        if Fld.ObsoleteState = Fld.ObsoleteState::Removed then
            Error(FieldObsoleteNotSupportedErr, Fld.FieldName);
    end;

    procedure CheckSetup(var ADLSESetup: Record "ADLSE Setup")
    var
        ADLSECurrentSession: Record "ADLSE Current Session";
        ADLSECredentials: Codeunit "ADLSE Credentials";
    begin
        ADLSESetup.Get(0);
        ADLSESetup.TestField(Container);
        if ADLSESetup.Running then
            // are any of the sessions really active?
            if ADLSECurrentSession.CheckSessionsActive() then
                Error(ExportDataInProgressErr);

        ADLSECredentials.Check();
    end;

    procedure Reset(var ADLSETable: Record "ADLSE Table")
    var
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
    begin
        ADLSETable.Enable();
        ADLSETableLastTimestamp.SaveUpdatedLastTimestamp(ADLSETable."Table ID", 0);
        ADLSETableLastTimestamp.SaveDeletedLastEntryNo(ADLSETable."Table ID", 0);
        ADLSETable.Modify();

        ADLSEDeletedRecord.SetRange("Table ID", ADLSETable."Table ID");
        ADLSEDeletedRecord.DeleteAll();
    end;
}