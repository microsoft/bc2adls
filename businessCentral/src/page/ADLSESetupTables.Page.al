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

                field("TableCaption"; TableCaptionValue)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Table';
                    Tooltip = 'The caption of the table whose data is to exported.';
                }
                field(State; Rec.State)
                {
                    ApplicationArea = All;
                    Tooltip = 'Specifies the state of the export for this table.';
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
                field(LastError; Rec.LastError)
                {
                    ApplicationArea = All;
                    ToolTip = 'The message for the error that occured during the last export of this table.';
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

            action(Disable)
            {
                ApplicationArea = All;
                Caption = 'Disable';
                ToolTip = 'Set the status to On Hold, so that data is not exported from this table';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                PromotedCategory = Process;
                Image = ApprovalSetup;
                Visible = CanBeDisabledValue;

                trigger OnAction()
                begin
                    Rec.Disable();
                    CurrPage.Update();
                end;
            }

            action(Enable)
            {
                ApplicationArea = All;
                Caption = 'Enable';
                ToolTip = 'Set the status to Ready, so that data can be exported from this table';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                Image = Approval;
                Visible = CanBeEnabledValue;

                trigger OnAction()
                begin
                    Rec.Enable();
                    CurrPage.Update();
                end;
            }

            action("Reset")
            {
                ApplicationArea = All;
                Caption = 'Reset';
                ToolTip = 'Set the table to export all of its data again.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedOnly = true;
                Image = ResetStatus;
                Enabled = HasBeenExportedPreviously;

                trigger OnAction()
                var
                    ADLSESetup: Codeunit "ADLSE Setup";
                begin
                    ADLSESetup.Reset(Rec);
                    CurrPage.Update();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        TableMetadata: Record "Table Metadata";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if TableMetadata.Get(Rec."Table ID") then begin
            TableCaptionValue := ADLSEUtil.GetTableCaption(Rec."Table ID");
            NumberFieldsChosenValue := Rec.FieldsChosen();
            CanBeDisabledValue := Rec.CanBeDisabled();
            CanBeEnabledValue := Rec.CanBeEnabled();
            UpdatedLastTimestamp := ADLSETableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
            DeletedRecordLastEntryNo := ADLSETableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");
            ADLSEntityName := ADLSEUtil.GetDataLakeCompliantTableName(Rec."Table ID");
        end else begin
            TableCaptionValue := StrSubstNo(AbsentTableCaptionLbl, Rec."Table ID");
            NumberFieldsChosenValue := 0;
            CanBeDisabledValue := false;
            CanBeEnabledValue := false;
            UpdatedLastTimestamp := 0;
            DeletedRecordLastEntryNo := 0;
            ADLSEntityName := '';
            Rec.State := "ADLSE State"::OnHold;
            Rec.Modify();
        end;
        HasBeenExportedPreviously := (UpdatedLastTimestamp > 0) or (DeletedRecordLastEntryNo > 0);
    end;

    var
        TableCaptionValue: Text;
        NumberFieldsChosenValue: Integer;
        CanBeDisabledValue: Boolean;
        CanBeEnabledValue: Boolean;
        HasBeenExportedPreviously: Boolean;
        ADLSEntityName: Text;
        UpdatedLastTimestamp: BigInteger;
        DeletedRecordLastEntryNo: BigInteger;
        AbsentTableCaptionLbl: Label 'Table%1', Comment = '%1 = Table ID';

    local procedure DoChooseFields()
    var
        ADLSESetup: Codeunit "ADLSE Setup";
    begin
        ADLSESetup.ChooseFieldsToExport(Rec);
        CurrPage.Update();
    end;
}