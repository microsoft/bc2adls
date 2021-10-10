// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
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
        // field(3; UpdatedLastTimestamp; BigInteger)
        // {
        //     Editable = false;
        //     Caption = 'Last timestamp exported for an updated record';
        // }
        // field(4; DeletedRecordLastEntryNo; BigInteger)
        // {
        //     Editable = false;
        //     Caption = 'Last timestamp exported for a deleted record';
        // }
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
        ADLSETableField: Record "ADLSE Field";
    begin
        CheckTableOfTypeNormal(Rec."Table ID");
        ADLSETableField.InsertForTable(Rec);
    end;

    trigger OnDelete()
    var
        ADLSETableField: Record "ADLSE Field";
    begin
        // CheckNotExporting();

        ADLSETableField.SetRange("Table ID", Rec."Table ID");
        ADLSETableField.DeleteAll();
    end;

    trigger OnModify()
    begin
        CheckNotExporting();
    end;

    var
        TableNotNormalErr: Label 'Table %1 is not a normal table.';
        TableExportingDataErr: Label 'Data is being executed for table %1. Please wait for the export to finish before making changes.';

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
        Rec.Init();
        Rec."Table ID" := TableID;
        Rec.State := "ADLSE State"::Ready;
        Rec.Insert(true);
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