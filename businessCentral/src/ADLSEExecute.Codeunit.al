// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82561 "ADLSE Execute"
{
    Access = Internal;
    TableNo = "ADLSE Table";

    trigger OnRun()
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSERun: Record "ADLSE Run";
        ADLSECurrentSession: Record "ADLSE Current Session";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSECommunication: Codeunit "ADLSE Communication";
        ADLSEExecution: Codeunit "ADLSE Execution";
        ADLSEUtil: Codeunit "ADLSE Util";
        CustomDimensions: Dictionary of [Text, Text];
        UpdatedLastTimestamp: BigInteger;
        DeletedLastEntryNo: BigInteger;
        OldUpdatedLastTimestamp: BigInteger;
        OldDeletedLastEntryNo: BigInteger;
        EntityJsonNeedsUpdate: Boolean;
        ManifestJsonsNeedsUpdate: Boolean;
    begin
        ADLSESetup.GetSingleton();
        EmitTelemetry := ADLSESetup."Emit telemetry";
        CDMDataFormat := ADLSESetup.DataFormat;
        if EmitTelemetry then begin
            CustomDimensions.Add('Entity', ADLSEUtil.GetTableCaption(Rec."Table ID"));
            ADLSEExecution.Log('ADLSE-017', 'Starting the export for table', Verbosity::Normal, CustomDimensions);
        end;

        // Register session started
        ADLSECurrentSession.Start(Rec."Table ID");
        ADLSERun.RegisterStarted(Rec."Table ID");
        Commit(); // to release locks on the "ADLSE Current Session" record thus allowing other sessions to check for it being active when they are nearing the last step.
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-018', 'Registered session to export table', Verbosity::Verbose, CustomDimensions);

        UpdatedLastTimestamp := ADLSETableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
        DeletedLastEntryNo := ADLSETableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");

        if EmitTelemetry then begin
            Clear(CustomDimensions);
            CustomDimensions.Add('Old Updated Last time stamp', Format(UpdatedLastTimestamp));
            CustomDimensions.Add('Old Deleted Last entry no.', Format(DeletedLastEntryNo));
            ADLSEExecution.Log('ADLSE-004', 'Exporting with parameters', Verbosity::Verbose, CustomDimensions);
        end;

        // Perform the export 
        OldUpdatedLastTimestamp := UpdatedLastTimestamp;
        OldDeletedLastEntryNo := DeletedLastEntryNo;
        if not TryExportTableData(Rec."Table ID", ADLSECommunication, UpdatedLastTimestamp, DeletedLastEntryNo, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
            SetStateFinished(Rec);
            exit;
        end;
        if EmitTelemetry then begin
            Clear(CustomDimensions);
            CustomDimensions.Add('Updated Last time stamp', Format(UpdatedLastTimestamp));
            CustomDimensions.Add('Deleted Last entry no.', Format(DeletedLastEntryNo));
            CustomDimensions.Add('Entity Json needs update', Format(EntityJsonNeedsUpdate));
            CustomDimensions.Add('Manifest Json needs update', Format(ManifestJsonsNeedsUpdate));
            ADLSEExecution.Log('ADLSE-020', 'Exported to deltas CDM folder', Verbosity::Verbose, CustomDimensions);
        end;

        // check if anything exported at all
        if (UpdatedLastTimestamp > OldUpdatedLastTimestamp) or (DeletedLastEntryNo > OldDeletedLastEntryNo) then begin
            // update the last timestamps of the record
            if not ADLSETableLastTimestamp.TrySaveUpdatedLastTimestamp(Rec."Table ID", UpdatedLastTimestamp) then begin
                SetStateFinished(Rec);
                exit;
            end;
            if not ADLSETableLastTimestamp.TrySaveDeletedLastEntryNo(Rec."Table ID", DeletedLastEntryNo) then begin
                SetStateFinished(Rec);
                exit;
            end;
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-006', 'Saved the timestamps into the database', Verbosity::Normal);
            Commit(); // to save the last time stamps into the database.
        end;

        // update Jsons
        if not ADLSECommunication.TryUpdateCdmJsons(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
            SetStateFinished(Rec);
            exit;
        end;
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-007', 'Jsons have been updated', Verbosity::Normal);

        // Finalize
        SetStateFinished(Rec);
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-005', 'Export completed without error', Verbosity::Normal);
    end;

    var
        TimestampAscendingSortViewTxt: Label 'Sorting(Timestamp) Order(Ascending)', Locked = true;
        InsufficientReadPermErr: Label 'You do not have sufficient permissions to read from the table.';
        EmitTelemetry: Boolean;
        CDMDataFormat: Enum "ADLSE CDM Format";

    [TryFunction]
    local procedure TryExportTableData(TableID: Integer; var ADLSECommunication: Codeunit "ADLSE Communication";
        var UpdatedLastTimeStamp: BigInteger; var DeletedLastEntryNo: BigInteger;
        var EntityJsonNeedsUpdate: Boolean; var ManifestJsonsNeedsUpdate: Boolean)
    var
        ADLSECommunicationDeletions: Codeunit "ADLSE Communication";
        ADLSEExecution: Codeunit "ADLSE Execution";
        FieldIdList: List of [Integer];
    begin
        FieldIdList := CreateFieldListForTable(TableID);

        // first export the upserts
        ADLSECommunication.Init(TableID, FieldIdList, UpdatedLastTimeStamp, EmitTelemetry);
        ADLSECommunication.CheckEntity(CDMDataFormat, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate, EmitTelemetry);
        ExportTableUpdates(TableID, FieldIdList, ADLSECommunication, UpdatedLastTimeStamp);

        // then export the deletes
        ADLSECommunicationDeletions.Init(TableID, FieldIdList, DeletedLastEntryNo, EmitTelemetry);
        // entity has been already checked above
        ExportTableDeletes(TableID, ADLSECommunicationDeletions, DeletedLastEntryNo);
    end;

    procedure UpdatedRecordsExist(TableID: Integer; UpdatedLastTimeStamp: BigInteger): Boolean
    var
        Rec: RecordRef;
        TimeStampField: FieldRef;
    begin
        SetFilterForUpdates(TableID, UpdatedLastTimeStamp, Rec, TimeStampField);
        exit(not Rec.IsEmpty());
    end;

    local procedure SetFilterForUpdates(TableID: Integer; UpdatedLastTimeStamp: BigInteger; var Rec: RecordRef; var TimeStampField: FieldRef)
    begin
        Rec.Open(TableID);
        Rec.SetView(TimestampAscendingSortViewTxt);
        TimeStampField := Rec.Field(0); // 0 is the TimeStamp field
        TimeStampField.SetFilter('>%1', UpdatedLastTimestamp);
    end;

    local procedure ExportTableUpdates(TableID: Integer; FieldIdList: List of [Integer]; ADLSECommunication: Codeunit "ADLSE Communication"; var UpdatedLastTimeStamp: BigInteger)
    var
        ADLSEExecution: Codeunit "ADLSE Execution";
        Rec: RecordRef;
        TimeStampField: FieldRef;
        FlushedTimeStamp: BigInteger;
        FieldId: Integer;
    begin
        SetFilterForUpdates(TableID, UpdatedLastTimeStamp, Rec, TimeStampField);

        foreach FieldId in FieldIdList do
            Rec.AddLoadFields(FieldID);

        if not Rec.ReadPermission() then
            Error(InsufficientReadPermErr);

        if Rec.FindSet(false) then begin
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-021', 'Updated records found', Verbosity::Verbose);
            repeat
                if ADLSECommunication.TryCollectAndSendRecord(Rec, TimeStampField.Value(), FlushedTimeStamp) then
                    UpdatedLastTimeStamp := FlushedTimeStamp
                else
                    Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
            until Rec.Next() = 0;

            if ADLSECommunication.TryFinish(FlushedTimeStamp) then
                UpdatedLastTimeStamp := FlushedTimeStamp
            else
                Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
        end;
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-009', 'Updated records exported', Verbosity::Verbose);
    end;

    procedure DeletedRecordsExist(TableID: Integer; DeletedLastEntryNo: BigInteger): Boolean
    var
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
    begin
        SetFilterForDeletes(TableID, DeletedLastEntryNo, ADLSEDeletedRecord);
        exit(not ADLSEDeletedRecord.IsEmpty());
    end;

    local procedure SetFilterForDeletes(TableID: Integer; DeletedLastEntryNo: BigInteger; var ADLSEDeletedRecord: Record "ADLSE Deleted Record")
    begin
        ADLSEDeletedRecord.SetView(TimestampAscendingSortViewTxt);
        ADLSEDeletedRecord.SetRange("Table ID", TableID);
        ADLSEDeletedRecord.SetFilter("Entry No.", '>%1', DeletedLastEntryNo);
    end;

    local procedure ExportTableDeletes(TableID: Integer; ADLSECommunication: Codeunit "ADLSE Communication"; var DeletedLastEntryNo: BigInteger)
    var
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
        ADLSEUtil: Codeunit "ADLSE Util";
        ADLSEExecution: Codeunit "ADLSE Execution";
        Rec: RecordRef;
        FlushedTimeStamp: BigInteger;
    begin
        SetFilterForDeletes(TableID, DeletedLastEntryNo, ADLSEDeletedRecord);

        if ADLSEDeletedRecord.FindSet(false) then begin
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-010', 'Deleted records found', Verbosity::Verbose);
            Rec.Open(ADLSEDeletedRecord."Table ID");
            repeat
                ADLSEUtil.CreateFakeRecordForDeletedAction(ADLSEDeletedRecord, Rec);
                if ADLSECommunication.TryCollectAndSendRecord(Rec, ADLSEDeletedRecord."Entry No.", FlushedTimeStamp) then
                    DeletedLastEntryNo := FlushedTimeStamp
                else
                    Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
            until ADLSEDeletedRecord.Next() = 0;

            if ADLSECommunication.TryFinish(FlushedTimeStamp) then
                DeletedLastEntryNo := FlushedTimeStamp
            else
                Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
        end;
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-011', 'Deleted records exported', Verbosity::Verbose);
    end;

    local procedure CreateFieldListForTable(TableID: Integer) FieldIdList: List of [Integer]
    var
        ADLSEField: Record "ADLSE Field";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        ADLSEField.SetRange("Table ID", TableID);
        ADLSEField.SetRange(Enabled, true);
        if ADLSEField.FindSet() then
            repeat
                FieldIdList.Add(ADLSEField."Field ID");
            until ADLSEField.Next() = 0;
        ADLSEUtil.AddSystemFields(FieldIdList);
    end;


    local procedure SetStateFinished(var ADLSETable: Record "ADLSE Table")
    var
        ADLSERun: Record "ADLSE Run";
    begin
        if not TrySetStateFinished(ADLSETable."Table ID") then
            ADLSERun.RegisterEnded(ADLSETable."Table ID", EmitTelemetry);
        Commit();
    end;

    [TryFunction]
    local procedure TrySetStateFinished(ADLSETableIDRunning: Integer)
    var
        ADLSERun: Record "ADLSE Run";
        ADLSECurrentSession: Record "ADLSE Current Session";
    begin
        ADLSERun.RegisterEnded(ADLSETableIDRunning, EmitTelemetry);
        ADLSECurrentSession.Stop(ADLSETableIDRunning);
    end;
}