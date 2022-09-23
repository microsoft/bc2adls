// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82569 "ADLSE Execution"
{
    Access = Internal;

    trigger OnRun()
    begin
        StartExport();
    end;

    var
        ExportStartedTxt: Label 'Data export started for %1 tables that were in the state Ready. Please refresh this page to see the latest export State for the tables.', Comment = '%1 = number of tables to start the export for.';
        ExportStoppedDueToCancelledSessionTxt: Label 'Export stopped as session was cancelled. Please check state of the export on the data lake before enabling this.';
        ExportNotStoppedErr: Label 'Not all sessions that are exporting data may have been stopped. Please try cancelling sessions from the Admin Center and try again. Last Error: %1', Comment = '%1 = error text';
        SuccessfulStopMsg: Label 'The export process was stopped successfully.';
        TrackedDeletedRecordsRemovedMsg: Label 'Representations of deleted records that have been exported previously have been deleted.';
        JobCategoryCodeTxt: Label 'ADLSE';
        JobCategoryDescriptionTxt: Label 'Export to Azure Data Lake';
        JobScheduledTxt: Label 'The job has been scheduled. Please go to the Job Queue Entries page to locate it and make further changes.';

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
        Commit();

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
        if ADLSESetupRec."Emit telemetry" then
            Log('ADLSE-001', StrSubstNo(ExportStartedTxt, Counter), Verbosity::Normal, DataClassification::SystemMetadata);
    end;

    procedure StopExport()
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSETable: Record "ADLSE Table";
        ADLSECurrentSession: Record "ADLSE Current Session";
    begin
        ADLSESetup.GetSingleton();
        if ADLSESetup."Emit telemetry" then
            Log('ADLSE-003', 'Stopping export sessions', Verbosity::Normal, DataClassification::SystemMetadata);

        if not ADLSECurrentSession.CancelAll(ExportStoppedDueToCancelledSessionTxt) then
            Error(ExportNotStoppedErr, GetLastErrorText() + GetLastErrorCallStack());

        ADLSETable.SetRange(State, "ADLSE State"::Exporting);
        ADLSETable.ModifyAll(State, "ADLSE State"::Error);
        ADLSETable.ModifyAll(LastError, ExportStoppedDueToCancelledSessionTxt);

        ADLSESetup.Running := false;
        ADLSESetup.Modify();

        Message(SuccessfulStopMsg);
        if ADLSESetup."Emit telemetry" then
            Log('ADLSE-004', 'Stopped export sessions', Verbosity::Normal, DataClassification::SystemMetadata);
    end;

    procedure ScheduleExport()
    var
        JobQueueEntry: Record "Job Queue Entry";
        ScheduleAJob: Page "Schedule a Job";
    begin
        CreateJobQueueEntry(JobQueueEntry);
        ScheduleAJob.SetJob(JobQueueEntry);
        Commit();
        if ScheduleAJob.RunModal() = Action::OK then
            Message(JobScheduledTxt);
    end;

    local procedure CreateJobQueueEntry(var JobQueueEntry: Record "Job Queue Entry")
    var
        JobQueueCategory: Record "Job Queue Category";
    begin
        JobQueueCategory.InsertRec(JobCategoryCodeTxt, JobCategoryDescriptionTxt);
        if JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"ADLSE Execution") then
            exit;
        JobQueueEntry.Init();
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Description := JobQueueCategory.Description;
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := CODEUNIT::"ADLSE Execution";
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime(); // now
        JobQueueEntry."Expiration Date/Time" := CurrentDateTime() + (7 * 24 * 60 * 60 * 1000); // 7 days from now
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

    internal procedure Log(EventId: Text; Message: Text; Verbosity: Verbosity; DataClassification: DataClassification)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        Log(EventId, Message, Verbosity, DataClassification, CustomDimensions);
    end;

    internal procedure Log(EventId: Text; Message: Text; Verbosity: Verbosity; DataClassification: DataClassification; CustomDimensions: Dictionary of [Text, Text])
    begin
        Session.LogMessage(EventId, Message, Verbosity, DataClassification, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::GlobalTriggerManagement, 'OnAfterGetDatabaseTableTriggerSetup', '', false, false)]
    local procedure GetDatabaseTableTriggerSetup(TableId: Integer; var OnDatabaseInsert: Boolean; var OnDatabaseModify: Boolean; var OnDatabaseDelete: Boolean; var OnDatabaseRename: Boolean)
    var
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
    begin
        if CompanyName() = '' then
            exit;

        // track deletes only if at least one export has been made for that table
        if ADLSETableLastTimestamp.ExistsUpdatedLastTimestamp(TableId) then
            OnDatabaseDelete := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::GlobalTriggerManagement, 'OnAfterOnDatabaseDelete', '', false, false)]
    local procedure OnAfterOnDatabaseDelete(RecRef: RecordRef)
    var
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
    begin
        // exit function for tables that you do not wish to sync deletes for
        // you should also consider not registering for deletes for the table in the function GetDatabaseTableTriggerSetup above.
        // if RecRef.Number = Database::"G/L Entry" then
        //     exit;

        // check if table is to be tracked.
        if not ADLSETableLastTimestamp.ExistsUpdatedLastTimestamp(RecRef.Number) then
            exit;

        ADLSEDeletedRecord.TrackDeletedRecord(RecRef);
    end;
}