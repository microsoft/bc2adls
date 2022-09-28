// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82561 "ADLSE Table"
{
    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(2; State; Enum "ADLSE State")
        {
            Editable = false;
            Caption = 'State';
        }
        field(5; LastError; Text[2048])
        {
            Editable = false;
            Caption = 'Last error';
        }
    }

    keys
    {
        key(Key1; "Table ID")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSETableField: Record "ADLSE Field";
    begin
        ADLSESetup.CheckNoSimultaneousExportsAllowed();

        CheckTableOfTypeNormal(Rec."Table ID");
    end;

    trigger OnDelete()
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSETableField: Record "ADLSE Field";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
    begin
        ADLSESetup.CheckNoSimultaneousExportsAllowed();

        ADLSETableField.SetRange("Table ID", Rec."Table ID");
        ADLSETableField.DeleteAll();

        ADLSEDeletedRecord.SetRange("Table ID", Rec."Table ID");
        ADLSEDeletedRecord.DeleteAll();

        ADLSETableLastTimestamp.SetRange("Table ID", Rec."Table ID");
        ADLSETableLastTimestamp.DeleteAll();
    end;

    trigger OnModify()
    var
        ADLSESetup: Record "ADLSE Setup";
    begin
        ADLSESetup.CheckNoSimultaneousExportsAllowed();

        CheckNotExporting();
    end;

    var
        TableNotNormalErr: Label 'Table %1 is not a normal table.', Comment = '%1: caption of table';
        TableExportingDataErr: Label 'Data is being executed for table %1. Please wait for the export to finish before making changes.', Comment = '%1: table caption';
        TableCannotBeExportedErr: Label 'The table %1 cannot be exported because of the following error. \%2', Comment = '%1: Table ID, %2: error text';

    procedure FieldsChosen(): Integer
    var
        ADLSEField: Record "ADLSE Field";
    begin
        ADLSEField.SetRange("Table ID", Rec."Table ID");
        ADLSEField.SetRange(Enabled, true);
        exit(ADLSEField.Count());
    end;

    procedure Add(TableID: Integer)
    begin
        if not CheckTableCanBeExportedFrom(TableID) then
            Error(TableCannotBeExportedErr, TableID, GetLastErrorText());
        Rec.Init();
        Rec."Table ID" := TableID;
        Rec.State := "ADLSE State"::Ready;
        Rec.Insert(true);
    end;

    [TryFunction]
    local procedure CheckTableCanBeExportedFrom(TableID: Integer)
    var
        RecordRef: RecordRef;
    begin
        ClearLastError();
        RecordRef.Open(TableID);
    end;

    local procedure CheckTableOfTypeNormal(TableID: Integer)
    var
        AllObj: Record AllObjWithCaption;
        TableMetadata: Record "Table Metadata";
        TableCaption: Text;
    begin
        AllObj.Get(AllObj."Object Type"::Table, TableID);
        TableCaption := AllObj."Object Caption";

        TableMetadata.SetRange(ID, TableID);
        TableMetadata.FindFirst();

        if TableMetadata.TableType <> TableMetadata.TableType::Normal then
            Error(TableNotNormalErr, TableCaption);
    end;

    procedure CheckNotExporting()
    var
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if Rec.State = "ADLSE State"::Exporting then
            Error(TableExportingDataErr, ADLSEUtil.GetTableCaption(Rec."Table ID"));
    end;

    procedure CanBeDisabled(): Boolean
    begin
        exit(Rec.State = "ADLSE State"::Ready);
    end;

    procedure Disable()
    begin
        if CanBeDisabled() then begin
            Rec.State := Rec.State::OnHold;
            Rec.Modify();
        end;
    end;

    procedure CanBeEnabled(): Boolean
    begin
        exit(Rec.State in ["ADLSE State"::OnHold, "ADLSE State"::Error]);
    end;

    procedure Enable()
    begin
        if CanBeEnabled() then begin
            Rec.State := Rec.State::Ready;
            Rec.LastError := '';
            Rec.Modify();
        end;
    end;
}