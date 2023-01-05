// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82560 "ADLSE Setup"
{
    Access = Internal;

    var
        FieldClassNotSupportedErr: Label 'The field %1 of class %2 is not supported.', Comment = '%1 = field name, %2 = field class';
        SelectTableLbl: Label 'Select the tables to be exported';
        FieldObsoleteNotSupportedErr: Label 'The field %1 is obsolete', Comment = '%1 = field name';
        FieldDisabledNotSupportedErr: Label 'The field %1 is disabled', Comment = '%1 = field name';

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
        ADLSEField.InsertForTable(ADLSETable);
        Commit(); // changes made to the field table go into the database before RunModal is called
        Page.RunModal(Page::"ADLSE Setup Fields", ADLSEField, ADLSEField.Enabled);
    end;

    procedure CanFieldBeExported(TableID: Integer; FieldID: Integer): Boolean
    var
        Field: Record Field;
    begin
        if not Field.Get(TableID, FieldID) then
            exit(false);
        exit(CheckFieldCanBeExported(Field, false));
    end;

    procedure CheckFieldCanBeExported(Field: Record Field)
    begin
        CheckFieldCanBeExported(Field, true);
    end;

    local procedure CheckFieldCanBeExported(Field: Record Field; RaiseError: Boolean): Boolean
    begin
        if Field.Class <> Field.Class::Normal then begin
            if RaiseError then
                Error(FieldClassNotSupportedErr, Field."Field Caption", Field.Class);
            exit(false);
        end;
        if Field.ObsoleteState = Field.ObsoleteState::Removed then begin
            if RaiseError then
                Error(FieldObsoleteNotSupportedErr, Field."Field Caption");
            exit(false);
        end;
        if not Field.Enabled then begin
            if RaiseError then
                Error(FieldDisabledNotSupportedErr, Field."Field Caption");
            exit(false);
        end;
        exit(true);
    end;

    procedure CheckSetup(var ADLSESetup: Record "ADLSE Setup")
    var
        ADLSECurrentSession: Record "ADLSE Current Session";
        ADLSECredentials: Codeunit "ADLSE Credentials";
    begin
        ADLSESetup.GetSingleton();
        ADLSESetup.TestField(Container);
        if not ADLSESetup."Multi- Company Export" then
            if ADLSECurrentSession.AreAnySessionsActive() then
                ADLSECurrentSession.CheckForNoActiveSessions();

        ADLSECredentials.Check();
    end;
}