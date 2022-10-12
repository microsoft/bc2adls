// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82561 "ADLSE Execute"
{
    Access = Internal;
    TableNo = "ADLSE Table";

    trigger OnRun()
    var
        ADLSESetup: Record "ADLSE Setup";
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
        ADLSESetup.Get(0);
        EmitTelemetry := ADLSESetup."Emit telemetry";
        CDMDataFormat := ADLSESetup.DataFormat;

        // Register session started
        ADLSECurrentSession.Start(Rec."Table ID");
        Commit(); // to release locks on the "ADLSE Current Session" record thus allowing other sessions to check for it being active when they are nearing the last step.
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-004', 'Registered session to export table', Verbosity::Normal, DataClassification::CustomerContent);

        // No changes allowed to this table & its associations while the export is running
        Rec.Get(Rec."Table ID");
        UpdatedLastTimestamp := ADLSETableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
        DeletedLastEntryNo := ADLSETableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");

        // Set to Exporting
        Rec.State := "ADLSE State"::Exporting;
        Rec.LastError := '';
        Rec.Modify();
        if EmitTelemetry then begin
            Clear(CustomDimensions);
            CustomDimensions.Add('Entity name', ADLSEUtil.GetDataLakeCompliantTableName(Rec."Table ID"));
            CustomDimensions.Add('Old Updated Last time stamp', Format(UpdatedLastTimestamp));
            CustomDimensions.Add('Old Deleted Last entry no.', Format(DeletedLastEntryNo));
            ADLSEExecution.Log('ADLSE-004', 'Exporting with parameters', Verbosity::Normal, DataClassification::CustomerContent, CustomDimensions);
        end;

        // Perform the export 
        OldUpdatedLastTimestamp := UpdatedLastTimestamp;
        OldDeletedLastEntryNo := DeletedLastEntryNo;
        if not TryExportTableData(Rec."Table ID", ADLSECommunication, UpdatedLastTimestamp, DeletedLastEntryNo, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
            SetErrorState(Rec);
            SetStateFinished(Rec);
            exit;
        end;
        if EmitTelemetry then begin
            Clear(CustomDimensions);
            CustomDimensions.Add('Updated Last time stamp', Format(UpdatedLastTimestamp));
            CustomDimensions.Add('Deleted Last entry no.', Format(DeletedLastEntryNo));
            CustomDimensions.Add('Entity Json needs update', Format(EntityJsonNeedsUpdate));
            CustomDimensions.Add('Manifest Json needs update', Format(ManifestJsonsNeedsUpdate));
            ADLSEExecution.Log('ADLSE-005', 'Exported to deltas CDM folder', Verbosity::Normal, DataClassification::CustomerContent, CustomDimensions);
        end;

        // check if anything exported at all
        if (UpdatedLastTimestamp > OldUpdatedLastTimestamp) or (DeletedLastEntryNo > OldDeletedLastEntryNo) then begin
            // update the last timestamps of the record
            if not ADLSETableLastTimestamp.TrySaveUpdatedLastTimestamp(Rec."Table ID", UpdatedLastTimestamp) then begin
                SetErrorState(Rec);
                SetStateFinished(Rec);
                exit;
            end;
            if not ADLSETableLastTimestamp.TrySaveDeletedLastEntryNo(Rec."Table ID", DeletedLastEntryNo) then begin
                SetErrorState(Rec);
                SetStateFinished(Rec);
                exit;
            end;
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-006', 'Saved the timestamps into the database', Verbosity::Normal, DataClassification::CustomerContent);
            Commit; // to save the last time stamps into the database.

            // update Jsons
            if not ADLSECommunication.TryUpdateCdmJsons(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
                SetErrorState(Rec);
                SetStateFinished(Rec);
                exit;
            end;
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-007', 'Jsons have been updated', Verbosity::Normal, DataClassification::CustomerContent);
        end;

        // Set to not exporting.            
        Rec.State := "ADLSE State"::Ready;
        Rec.Modify();
        SetStateFinished(Rec);
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-005', 'Export completed without error', Verbosity::Normal, DataClassification::CustomerContent);
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
        FieldIdList: List of [Integer];
    begin
        FieldIdList := CreateFieldListForTable(TableID);

        // first export the upserts
        ADLSECommunication.Init(TableID, FieldIdList, UpdatedLastTimeStamp, EmitTelemetry);
        ADLSECommunication.CheckEntity(CDMDataFormat, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate);
        ExportTableUpdates(TableID, FieldIdList, ADLSECommunication, UpdatedLastTimeStamp);

        // then export the deletes
        ADLSECommunicationDeletions.Init(TableID, FieldIdList, DeletedLastEntryNo, EmitTelemetry);
        // entity has been already checked above
        ExportTableDeletes(TableID, FieldIdList, ADLSECommunicationDeletions, DeletedLastEntryNo);
    end;

    local procedure ExportTableUpdates(TableID: Integer; FieldIdList: List of [Integer]; ADLSECommunication: Codeunit "ADLSE Communication"; var UpdatedLastTimeStamp: BigInteger)
    var
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSE: Codeunit ADLSE;
        ADLSEExecution: Codeunit "ADLSE Execution";
        Rec: RecordRef;
        TimeStampField: FieldRef;
        FlushedTimeStamp: BigInteger;
        FieldId: Integer;
    begin
        Rec.Open(TableID);
        Rec.SetView(TimestampAscendingSortViewTxt);
        TimeStampField := Rec.Field(0); // 0 is the TimeStamp field
        TimeStampField.SetFilter('>%1', UpdatedLastTimestamp);

        foreach FieldId in FieldIdList do
            Rec.AddLoadFields(FieldID);

        if not Rec.ReadPermission() then
            Error(InsufficientReadPermErr);

        if Rec.FindSet(false) then begin
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-008', 'Updated records found', Verbosity::Verbose, DataClassification::CustomerContent);
            repeat
                if ADLSECommunication.TryCollectAndSendRecord(Rec, TimeStampField.Value(), FlushedTimeStamp) then
                    UpdatedLastTimeStamp := FlushedTimeStamp
                else
                    Error(GetLastErrorText() + GetLastErrorCallStack());
            until Rec.Next = 0;

            if ADLSECommunication.TryFinish(FlushedTimeStamp) then
                UpdatedLastTimeStamp := FlushedTimeStamp
            else
                Error(GetLastErrorText() + GetLastErrorCallStack());
        end;
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-009', 'Updated records exported', Verbosity::Verbose, DataClassification::CustomerContent);
    end;

    local procedure ExportTableDeletes(TableID: Integer; FieldIdList: List of [Integer]; ADLSECommunication: Codeunit "ADLSE Communication"; var DeletedLastEntryNo: BigInteger)
    var
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
        ADLSEUtil: Codeunit "ADLSE Util";
        ADLSEExecution: Codeunit "ADLSE Execution";
        Rec: RecordRef;
        FlushedTimeStamp: BigInteger;
    begin
        ADLSEDeletedRecord.SetView(TimestampAscendingSortViewTxt);
        ADLSEDeletedRecord.SetRange("Table ID", TableID);
        ADLSEDeletedRecord.SetFilter("Entry No.", '>%1', DeletedLastEntryNo);

        if ADLSEDeletedRecord.FindSet(false) then begin
            if EmitTelemetry then
                ADLSEExecution.Log('ADLSE-010', 'Deleted records found', Verbosity::Verbose, DataClassification::CustomerContent);
            Rec.Open(ADLSEDeletedRecord."Table ID");
            repeat
                ADLSEUtil.CreateFakeRecordForDeletedAction(ADLSEDeletedRecord, Rec);
                if ADLSECommunication.TryCollectAndSendRecord(Rec, ADLSEDeletedRecord."Entry No.", FlushedTimeStamp) then
                    DeletedLastEntryNo := FlushedTimeStamp
                else
                    Error(GetLastErrorText() + GetLastErrorCallStack());
            until ADLSEDeletedRecord.Next() = 0;

            if ADLSECommunication.TryFinish(FlushedTimeStamp) then
                DeletedLastEntryNo := FlushedTimeStamp
            else
                Error(GetLastErrorText() + GetLastErrorCallStack());
        end;
        if EmitTelemetry then
            ADLSEExecution.Log('ADLSE-011', 'Deleted records exported', Verbosity::Verbose, DataClassification::CustomerContent);
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
            until ADLSEField.Next = 0;
        ADLSEUtil.AddSystemFields(FieldIdList);
    end;

    local procedure SetErrorState(var ADLSETable: Record "ADLSE Table")
    var
        ADLSEExecution: Codeunit "ADLSE Execution";
        CustomDimension: Dictionary of [Text, Text];
        LastErrorMessage: Text;
        LastErrorStack: Text;
    begin
        ADLSETable.State := "ADLSE State"::Error;
        LastErrorMessage := GetLastErrorText();
        LastErrorStack := GetLastErrorCallStack();
        if ADLSETable.LastError = '' then // do not overwrite an existing error
            ADLSETable.LastError := CopyStr(LastErrorMessage + LastErrorStack, 1, 2048); // 2048 is the max size of the field 
        ADLSETable.Modify();
        if EmitTelemetry then begin
            CustomDimension.Add('Error text', LastErrorMessage);
            CustomDimension.Add('Error stack', LastErrorStack);
            ADLSEExecution.Log('ADLSE-008', 'Error occured during execution', Verbosity::Warning, DataClassification::CustomerContent, CustomDimension);
        end;
    end;

    local procedure SetStateFinished(var ADLSETable: Record "ADLSE Table")
    begin
        if not TrySetStateFinished(ADLSETable."Table ID") then
            SetErrorState(ADLSETable);
    end;

    [TryFunction]
    local procedure TrySetStateFinished(ADLSETableIDRunning: Integer)
    var
        ADLSETable: Record "ADLSE Table";
        ADLSESetup: Record "ADLSE Setup";
        ADLSECurrentSession: Record "ADLSE Current Session";
    begin
        AcquireLockonADLSESetup(ADLSESetup);
        // if no other sessions currently running an export, set state to stopped
        if not ADLSECurrentSession.IsAnySessionActiveForOtherExports(ADLSETableIDRunning) then begin
            ADLSESetup.Running := false;
            ADLSESetup.Modify();
        end;

        ADLSECurrentSession.Stop(ADLSETableIDRunning);
        Commit();
    end;

    procedure AcquireLockonADLSESetup(var ADLSESetup: Record "ADLSE Setup")
    begin
        ADLSESetup.LockTable(true);
        ADLSESetup.Get(0);
    end;
}