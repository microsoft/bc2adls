// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
codeunit 82569 "ADLSE Execution"
{
    Access = Internal;

    trigger OnRun()
    begin

    end;

    var
        ExportStartedTxt: Label 'Data export started for %1 tables that were in the state Ready. Please refresh this page to see the latest export State for the tables.', Comment = '%1 = number of tables to start the export for.';
        ExportStoppedDueToCancelledSessionTxt: Label 'Export stopped as session was cancelled. Please check state of the export on the data lake before enabling this.';
        ExportNotStoppedErr: Label 'Not all sessions that are exporting data may have been stopped. Please try cancelling sessions from the Admin Center and try again. Last Error: %1', Comment = '%1 = error text';
        SuccessfulStopMsg: Label 'The export process was stopped successfully.';
        TrackedDeletedRecordsRemovedMsg: Label 'Representations of deleted records that have been exported previously have been deleted.';

    procedure StartExport()
    var
        ADLSESetupRec: Record "ADLSE Setup";
        ADLSETable: Record "ADLSE Table";
        ADLSEField: Record "ADLSE Field";
        ADLSESetup: Codeunit "ADLSE Setup";
        ADSLEConnection: Codeunit "ADLSE Communication";
        NewSessionID: Integer;
        Counter: Integer;
    begin
        ADLSESetup.CheckSetup(ADLSESetupRec);

        ADSLEConnection.SetupBlobStorage();

        ADLSESetupRec.Running := true;
        ADLSESetupRec.Modify();
        Commit;

        ADLSETable.SetRange(State, "ADLSE State"::Ready);
        if ADLSETable.FindSet(true) then
            repeat
                ADLSEField.SetRange("Table ID", ADLSETable."Table ID");
                ADLSEField.SetRange(Enabled, true);
                if not ADLSEField.IsEmpty() then
                    // Codeunit.Run(Codeunit::"ADLSE Execute", ADLSETable);
                    if Session.StartSession(NewSessionID, Codeunit::"ADLSE Execute", CompanyName(), ADLSETable) then
                        Counter += 1;
            until ADLSETable.Next() = 0;

        Message(ExportStartedTxt, Counter);
    end;

    procedure StopExport()
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSETable: Record "ADLSE Table";
        ADLSECurrentSession: Record "ADLSE Current Session";
    begin
        if not ADLSECurrentSession.CancelAll(ExportStoppedDueToCancelledSessionTxt) then
            Error(ExportNotStoppedErr, GetLastErrorText() + GetLastErrorCallStack());

        ADLSETable.SetRange(State, "ADLSE State"::Exporting);
        ADLSETable.ModifyAll(State, "ADLSE State"::Error);
        ADLSETable.ModifyAll(LastError, ExportStoppedDueToCancelledSessionTxt);

        ADLSESetup.Get(0);
        ADLSESetup.Running := false;
        ADLSESetup.Modify();

        Message(SuccessfulStopMsg);
    end;

    procedure ClearTrackedDeletedRecords()
    var
        ADLSETable: Record "ADLSE Table";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
    begin
        ADLSETable.SetLoadFields("Table ID");
        if ADLSETable.FindSet() then
            repeat
                ADLSEDeletedRecord.SetRange("Table ID", ADLSETable."Table ID");
                ADLSEDeletedRecord.SetFilter("Entry No.", '<=%1', ADLSETableLastTimestamp.GetDeletedLastEntryNo(ADLSETable."Table ID"));
                ADLSEDeletedRecord.DeleteAll();

                ADLSETableLastTimestamp.SaveDeletedLastEntryNo(ADLSETable."Table ID", 0);
            until ADLSETable.Next() = 0;
        Message(TrackedDeletedRecordsRemovedMsg);
    end;

}