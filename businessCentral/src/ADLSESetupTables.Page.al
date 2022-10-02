// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82561 "ADLSE Setup Tables"
{
    Caption = 'Tables';
    LinksAllowed = false;
    PageType = ListPart;
    SourceTable = "ADLSE Table";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;

                field(TableCaption; TableCaptionValue)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Table';
                    Tooltip = 'Specifies the caption of the table whose data is to exported.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Enabled';
                    Tooltip = 'Specifies the state of the table. Set this checkmark to export this table, otherwise not.';
                }
                field(FieldsChosen; NumberFieldsChosenValue)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = '# Fields selected';
                    Tooltip = 'Shows if any field has been chosen to be exported. Click on Choose Fields action to add fields to export.';

                    trigger OnDrillDown()
                    begin
                        DoChooseFields();
                    end;
                }
                field(ADLSTableName; ADLSEntityName)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Entity name';
                    Tooltip = 'The name of the entity corresponding to this table on the data lake. The value at the end indicates the table number in Dynamics 365 Business Central.';
                }
                field(Status; LastRunState)
                {
                    ApplicationArea = All;
                    Caption = 'Last exported state';
                    Editable = false;
                    Tooltip = 'Specifies the status of the last export from this table in this company.';
                }
                field(LastRanAt; LastStarted)
                {
                    ApplicationArea = All;
                    Caption = 'Last started at';
                    Editable = false;
                    Tooltip = 'Specifies the time of the last export from this table in this company.';
                }
                field(LastError; LastRunError)
                {
                    ApplicationArea = All;
                    Caption = 'Last error';
                    Editable = false;
                    ToolTip = 'Specifies the error message from the last export of this table in this company.';
                }
                field(LastTimestamp; UpdatedLastTimestamp)
                {
                    ApplicationArea = All;
                    Tooltip = 'The timestamp of the record in this table that was exported last.';
                    Caption = 'Last timestamp';
                    Visible = false;
                }
                field(LastTimestampDeleted; DeletedRecordLastEntryNo)
                {
                    ApplicationArea = All;
                    Tooltip = 'The timestamp of the deleted records in this table that was exported last.';
                    Caption = 'Last timestamp deleted';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AddTable)
            {
                ApplicationArea = All;
                Caption = 'Add';
                Tooltip = 'Add a table to be exported';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                PromotedCategory = Process;
                Image = New;

                trigger OnAction()
                var
                    ADLSESetup: Codeunit "ADLSE Setup";
                begin
                    ADLSESetup.AddTableToExport();
                    CurrPage.Update();
                end;
            }

            action(DeleteTable)
            {
                ApplicationArea = All;
                Caption = 'Delete';
                Tooltip = 'Removes a table that had been added to the list meant for export';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                PromotedCategory = Process;
                Image = Delete;

                trigger OnAction()
                begin
                    Rec.Delete(true);
                    CurrPage.Update();
                end;
            }

            action(ChooseFields)
            {
                ApplicationArea = All;
                Caption = 'Choose fields';
                ToolTip = 'Select the fields of this table to be exported';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                PromotedCategory = Process;
                Image = SelectEntries;

                trigger OnAction()
                begin
                    DoChooseFields();
                end;
            }

            action(Reset)
            {
                ApplicationArea = All;
                Caption = 'Reset';
                ToolTip = 'Set the selected tables to export all of its data again.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                Image = ResetStatus;

                trigger OnAction()
                var
                    ADLSESetup: Codeunit "ADLSE Setup";
                    SelectedADLSETable: Record "ADLSE Table";
                begin
                    CurrPage.SetSelectionFilter(SelectedADLSETable);
                    SelectedADLSETable.ResetSelected();
                    CurrPage.Update();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        TableMetadata: Record "Table Metadata";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSERun: Record "ADLSE Run";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if TableMetadata.Get(Rec."Table ID") then begin
            TableCaptionValue := ADLSEUtil.GetTableCaption(Rec."Table ID");
            NumberFieldsChosenValue := Rec.FieldsChosen();
            UpdatedLastTimestamp := ADLSETableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
            DeletedRecordLastEntryNo := ADLSETableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");
            ADLSEntityName := ADLSEUtil.GetDataLakeCompliantTableName(Rec."Table ID");
        end else begin
            TableCaptionValue := StrSubstNo(AbsentTableCaptionLbl, Rec."Table ID");
            NumberFieldsChosenValue := 0;
            UpdatedLastTimestamp := 0;
            DeletedRecordLastEntryNo := 0;
            ADLSEntityName := '';
            Rec.Modify();
        end;
        ADLSERun.GetLastRunDetails(Rec."Table ID", LastRunState, LastStarted, LastRunError);
    end;

    var
        TableCaptionValue: Text;
        NumberFieldsChosenValue: Integer;
        ADLSEntityName: Text;
        UpdatedLastTimestamp: BigInteger;
        DeletedRecordLastEntryNo: BigInteger;
        AbsentTableCaptionLbl: Label 'Table%1', Comment = '%1 = Table ID';
        LastRunState: Enum "ADLSE Run State";
        LastStarted: DateTime;
        LastRunError: Text[2048];

    local procedure DoChooseFields()
    var
        ADLSESetup: Codeunit "ADLSE Setup";
    begin
        ADLSESetup.ChooseFieldsToExport(Rec);
        CurrPage.Update();
    end;
}