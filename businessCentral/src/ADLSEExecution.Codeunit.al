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
        EmitTelemetry: Boolean;
        ExportStartedTxt: Label 'Data export started for %1 out of %2 tables. Please refresh this page to see the latest export state for the tables. Only those tables that either have had changes since the last export or failed to export last time have been included. The tables for which the exports could not be started have been queued up for later.', Comment = '%1 = number of tables to start the export for. %2 = total number of tables enabled for export.';
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
        ADLSECurrentSession: Record "ADLSE Current Session";
        ADLSESetup: Codeunit "ADLSE Setup";
        ADLSECommunication: Codeunit "ADLSE Communication";
        ADLSESessionManager: Codeunit "ADLSE Session Manager";
        ADLSEExecution: Codeunit "ADLSE Execution";
        Counter: Integer;
        Started: Integer;
    begin
        ADLSESetup.CheckSetup(ADLSESetupRec);
        EmitTelemetry := ADLSESetupRec."Emit telemetry";
        ADLSECurrentSession.CleanupSessions();
        ADLSEExecution.ClearTrackedDeletedRecords();
        ADLSECommunication.SetupBlobStorage();
        ADLSESessionManager.Init();

        if EmitTelemetry then
            Log('ADLSE-022', 'Starting export for all tables', Verbosity::Normal);
        if ADLSETable.FindSet(false) then
            repeat
                Counter += 1;
                ADLSEField.SetRange("Table ID", ADLSETable."Table ID");
                ADLSEField.SetRange(Enabled, true);
                if not ADLSEField.IsEmpty() then
                    if ADLSESessionManager.StartExport(ADLSETable."Table ID", EmitTelemetry) then
                        Started += 1;
            until ADLSETable.Next() = 0;

        Message(ExportStartedTxt, Started, Counter);
        if EmitTelemetry then
            Log('ADLSE-001', StrSubstNo(ExportStartedTxt, Started, Counter), Verbosity::Normal);
    end;

    procedure StopExport()
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSERun: Record "ADLSE Run";
        ADLSECurrentSession: Record "ADLSE Current Session";
    begin
        ADLSESetup.GetSingleton();
        if ADLSESetup."Emit telemetry" then
            Log('ADLSE-003', 'Stopping export sessions', Verbosity::Verbose);

        ADLSECurrentSession.CancelAll();

        ADLSERun.CancelAllRuns();

        Message(SuccessfulStopMsg);
        if ADLSESetup."Emit telemetry" then
            Log('ADLSE-019', 'Stopped export sessions', Verbosity::Normal);
    end;

    procedure ScheduleExport()
    var
        JobQueueEntry: Record "Job Queue Entry";
        ScheduleAJob: Page "Schedule a Job";
    begin
        CreateJobQueueEntry(JobQueueEntry);
        ScheduleAJob.SetJob(JobQueueEntry);
        Commit(); // above changes go into the DB before RunModal
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

    internal procedure Log(EventId: Text; Message: Text; Verbosity: Verbosity)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        Log(EventId, Message, Verbosity, CustomDimensions);
    end;

    internal procedure Log(EventId: Text; Message: Text; Verbosity: Verbosity; CustomDimensions: Dictionary of [Text, Text])
    begin
        Session.LogMessage(EventId, Message, Verbosity, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"G/L Account Category Mgt.", 'OnAfterInitializeCompany', '', false, false)]
    local procedure OnAfterInitializeCompany()
    var
        ADLSEInstaller: Codeunit "ADLSE Installer";
    begin
        ADLSEInstaller.AddAllowedTables();
    end;

}