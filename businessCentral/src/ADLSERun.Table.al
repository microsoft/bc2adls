// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82566 "ADLSE Run"
{
    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; ID; Integer)
        {
            Editable = false;
            Caption = 'ID';
            AutoIncrement = true;
        }
        field(2; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(3; "Company Name"; Text[30])
        {
            Editable = false;
            Caption = 'Company name';
        }
        field(4; State; Enum "ADLSE Run State")
        {
            Editable = false;
            Caption = 'State';
        }
        field(5; Error; Text[2048])
        {
            Editable = false;
            Caption = 'Error';
        }
        field(6; Started; DateTime)
        {
            Editable = false;
            Caption = 'Started';
        }
        field(7; Ended; DateTime)
        {
            Editable = false;
            Caption = 'Ended';
        }
    }

    keys
    {
        key(Key1; ID)
        {
            Clustered = true;
        }
        key(Key2; "Table ID", "Company Name")
        {
        }
    }

    var
        ExportRunNotFoundErr: Label 'No export process running for table %1.', Comment = '&1 = caption of the table';
        ExportStoppedDueToCancelledSessionTxt: Label 'Export stopped as session was cancelled. Please check state of the export on the data lake before enabling this.';

    procedure GetLastRunDetails(TableID: Integer; var Status: enum "ADLSE Run State"; var Started: DateTime; var ErrorIfAny: Text[2048])
    begin
        if FindLastRun(TableID) then begin
            Status := Rec.State;
            Started := Rec.Started;
            ErrorIfAny := Rec.Error;
            exit;
        end;
        Status := "ADLSE Run State"::None;
        Started := 0DT;
        ErrorIfAny := '';
    end;

    procedure RegisterStarted(TableID: Integer)
    begin
        Rec.Init();
        Rec."Table ID" := TableID;
        Rec."Company Name" := CompanyName();
        Rec.State := "ADLSE Run State"::InProcess;
        Rec.Started := CurrentDateTime();
        Rec.Insert();
    end;

    procedure RegisterEnded(TableID: Integer; EmitTelemetry: Boolean)
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        ADLSEExecution: Codeunit "ADLSE Execution";
        CustomDimension: Dictionary of [Text, Text];
        LastErrorMessage: Text;
        LastErrorStack: Text;
    begin
        if not FindLastRun(TableID) then
            Error(ExportRunNotFoundErr, ADLSEUtil.GetTableCaption(TableID));
        if Rec.State <> "ADLSE Run State"::InProcess then
            exit;
        LastErrorMessage := GetLastErrorText();
        if LastErrorMessage <> '' then begin
            LastErrorStack := GetLastErrorCallStack();
            Rec.Error := CopyStr(LastErrorMessage + LastErrorStack, 1, 2048); // 2048 is the max size of the field 
            Rec.State := "ADLSE Run State"::Failed;

            if EmitTelemetry then begin
                CustomDimension.Add('Error text', LastErrorMessage);
                CustomDimension.Add('Error stack', LastErrorStack);
                ADLSEExecution.Log('ADLSE-008', 'Error occured during execution', Verbosity::Error, CustomDimension);
            end;
            ClearLastError();
        end else
            Rec.State := "ADLSE Run State"::Success;
        Rec.Ended := CurrentDateTime();
        Rec.Modify();
    end;

    procedure CancelAllRuns()
    begin
        Rec.SetRange(State, "ADLSE Run State"::InProcess);
        Rec.ModifyAll(Ended, CurrentDateTime);
        Rec.ModifyAll(State, "ADLSE Run State"::Failed);
        Rec.ModifyAll(Error, ExportStoppedDueToCancelledSessionTxt);
    end;

    procedure OldRunsExist(): Boolean;
    begin
        FilterOnOldRuns();
        exit(not Rec.IsEmpty());
    end;

    procedure DeleteOldRuns()
    begin
        FilterOnOldRuns();
        Rec.DeleteAll();
    end;

    local procedure FindLastRun(TableID: Integer) Found: Boolean
    begin
        Rec.SetCurrentKey(ID);
        Rec.Ascending(false); // order results in a way that the last one shows up first
        Rec.SetRange("Table ID", TableID);
        Rec.SetRange("Company Name", CompanyName());
        Found := Rec.FindFirst();
    end;

    local procedure FilterOnOldRuns()
    begin
        Rec.SetFilter(State, '<>%1', "ADLSE Run State"::InProcess);
        Rec.SetRange("Company Name", CompanyName());
    end;
}