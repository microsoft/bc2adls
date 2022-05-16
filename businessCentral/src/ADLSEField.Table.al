// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82562 "ADLSE Field"
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
        field(2; "Field ID"; Integer)
        {
            Editable = false;
            Caption = 'Field ID';
        }
        field(3; Enabled; Boolean)
        {
            Caption = 'Enabled';

            trigger OnValidate()
            begin
                Rec.CheckFieldToBeEnabled();
            end;
        }
        field(100; FieldCaption; Text[80])
        {
            Caption = 'Field';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Field."Field Caption" where("No." = field("Field ID"), TableNo = field("Table ID")));
        }
    }

    keys
    {
        key(Key1; "Table ID", "Field ID")
        {
            Clustered = true;
        }
    }

    trigger OnModify()
    var
        ADLSETable: Record "ADLSE Table";
    begin
        ADLSETable.Get(Rec."Table ID");
        ADLSETable.CheckNotExporting();
    end;

    procedure InsertForTable(ADLSETable: Record "ADLSE Table")
    var
        Fld: Record Field;
        ADLSEField: Record "ADLSE Field";
        ADLSESetup: Codeunit "ADLSE Setup";
    begin
        Fld.SetRange(TableNo, ADLSETable."Table ID");
        Fld.SetFilter("No.", '<%1', 2000000000); // no system fields

        if Fld.FindSet() then
            repeat
                if ADLSEField.Get(ADLSETable."Table ID", Fld."No.") then
                    Rec.TransferFields(ADLSEField)
                else begin
                    Rec."Table ID" := Fld.TableNo;
                    Rec."Field ID" := Fld."No.";
                    Rec.Enabled := false;
                end;
                Rec.Insert();
            until Fld.Next() = 0;
    end;

    procedure CheckFieldToBeEnabled()
    var
        Fld: Record Field;
        ADLSESetup: Codeunit "ADLSE Setup";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        Fld.Get(Rec."Table ID", Rec."Field ID");
        ADLSEUtil.CheckFieldTypeForExport(Fld);
        ADLSESetup.CheckFieldCanBeExported(Fld);
    end;

    [TryFunction]
    procedure CanFieldBeEnabled()
    begin
        CheckFieldToBeEnabled();
    end;
}