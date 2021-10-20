// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82562 "ADLSE Setup Fields"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "ADLSE Field";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    Caption = 'Select the fields to be exported';

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(FieldCaption; Rec.FieldCaption)
                {
                    ApplicationArea = All;
                    Tooltip = 'Specifies the name of the field to be exported';
                }

                field("Field ID"; Rec."Field ID")
                {
                    ApplicationArea = All;
                    Caption = 'Number';
                    Tooltip = 'Specifies the ID of the field to be exported';
                    Visible = false;
                }

                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    Tooltip = 'Specifies if the field will be exported';
                }

                field(ADLSFieldName; ADLSFieldName)
                {
                    ApplicationArea = All;
                    Caption = 'Attribute name';
                    Tooltip = 'Specifies the name of the field for this entity in the data lake.';
                    Editable = false;
                }

                field("Field Class"; FieldClassName)
                {
                    ApplicationArea = All;
                    Caption = 'Class';
                    Tooltip = 'Specifies the field class';
                    Editable = false;
                    Visible = false;
                }

                field("Field Type"; FieldTypeName)
                {
                    ApplicationArea = All;
                    Caption = 'Type';
                    Tooltip = 'Specifies the field type';
                    Editable = false;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
        }
    }

    trigger OnAfterGetRecord()
    var
        Fld: Record Field;
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        Fld.Get(Rec."Table ID", Rec."Field ID");
        ADLSFieldName := ADLSEUtil.GetDataLakeCompliantFieldName(Fld.FieldName, Fld."No.");
        FieldClassName := Fld.Class;
        FieldTypeName := Fld."Type Name";
    end;

    var
        ADLSFieldName: Text;
        FieldClassName: Option Normal,FlowField,FlowFilter;
        FieldTypeName: Text[30];

}