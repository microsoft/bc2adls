// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
codeunit 82561 "ADLSE Execute"
{
    Access = Internal;
    TableNo = "ADLSE Table";

    trigger OnRun()
    var
        ADLSECurrentSession: Record "ADLSE Current Session";
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSECommunication: Codeunit "ADLSE Communication";
        UpdatedLastTimestamp: BigInteger;
        DeletedLastEntryNo: BigInteger;
        OldUpdatedLastTimestamp: BigInteger;
        OldDeletedLastEntryNo: BigInteger;
        EntityJsonNeedsUpdate: Boolean;
        ManifestJsonsNeedsUpdate: Boolean;
    begin
        // Database.SelectLatestVersion();

        // Register session started
        ADLSECurrentSession.Start(Rec."Table ID");

        // No changes allowed to this table & its associations while the export is running
        // Rec.LockTable();
        Rec.Get(Rec."Table ID");
        // ADLSETableLastTimestamp.LockTable();
        UpdatedLastTimestamp := ADLSETableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
        DeletedLastEntryNo := ADLSETableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");

        // Set to Exporting
        Rec.State := "ADLSE State"::Exporting;
        Rec.LastError := '';
        Rec.Modify();

        // Perform the export 
        OldUpdatedLastTimestamp := UpdatedLastTimestamp;
        OldDeletedLastEntryNo := DeletedLastEntryNo;
        if not TryExportTableData(Rec."Table ID", ADLSECommunication, UpdatedLastTimestamp, DeletedLastEntryNo, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
            SetErrorState(Rec);
            SetStateFinished(Rec);
            exit;
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
            Commit; // to save the last time stamps into the database.

            // update Jsons
            if not ADLSECommunication.TryUpdateCdmJsons(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
                SetErrorState(Rec);
                SetStateFinished(Rec);
                exit;
            end;
        end;

        // Set to not exporting.            
        Rec.State := "ADLSE State"::Ready;
        Rec.Modify();
        SetStateFinished(Rec);
    end;

    var
        TimestampAscendingSortViewTxt: Label 'Sorting(Timestamp) Order(Ascending)', Locked = true;

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
        ADLSECommunication.Init(TableID, FieldIdList, UpdatedLastTimeStamp);
        ADLSECommunication.CheckEntity(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate);
        ExportTableUpdates(TableID, FieldIdList, ADLSECommunication, UpdatedLastTimeStamp);

        // then export the deletes
        ADLSECommunicationDeletions.Init(TableID, FieldIdList, DeletedLastEntryNo);
        // entity has been already checked above
        ExportTableDeletes(TableID, FieldIdList, ADLSECommunicationDeletions, DeletedLastEntryNo);
    end;

    local procedure ExportTableUpdates(TableID: Integer; FieldIdList: List of [Integer]; ADLSECommunication: Codeunit "ADLSE Communication"; var UpdatedLastTimeStamp: BigInteger)
    var
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        Rec: RecordRef;
        TimeStampField: FieldRef;
        FlushedTimeStamp: BigInteger;
        FieldId: Integer;
    begin
        Rec.Open(TableID);
        foreach FieldId in FieldIdList do
            Rec.AddLoadFields(FieldID);

        Rec.SetView(TimestampAscendingSortViewTxt);
        TimeStampField := Rec.Field(0); // 0 is the TimeStamp field
        TimeStampField.SetFilter('>%1', UpdatedLastTimestamp);

        if Rec.FindSet(false) then begin
            repeat
                // UpdatedLastTimeStamp := ExportRecordUpdate(ADLSECommunication, Rec, TimeStampField.Value(), ADLSETable, true);
                if ADLSECommunication.TryCollectAndSendRecord(Rec, TimeStampField.Value(), FlushedTimeStamp) then
                    UpdatedLastTimeStamp := FlushedTimeStamp
                else
                    Error(GetLastErrorText() + GetLastErrorCallStack());
            until Rec.Next = 0;

            // UpdatedLastTimeStamp := Finish(ADLSECommunication, ADLSETable, true);
            if ADLSECommunication.TryFinish(FlushedTimeStamp) then
                UpdatedLastTimeStamp := FlushedTimeStamp
            else
                Error(GetLastErrorText() + GetLastErrorCallStack());
        end;
    end;

    local procedure ExportTableDeletes(TableID: Integer; FieldIdList: List of [Integer]; ADLSECommunication: Codeunit "ADLSE Communication"; var DeletedLastEntryNo: BigInteger)
    var
        ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
        ADLSEUtil: Codeunit "ADLSE Util";
        Rec: RecordRef;
        FlushedTimeStamp: BigInteger;
    begin
        ADLSEDeletedRecord.SetView(TimestampAscendingSortViewTxt);
        ADLSEDeletedRecord.SetRange("Table ID", TableID);
        ADLSEDeletedRecord.SetFilter("Entry No.", '>%1', DeletedLastEntryNo);

        if ADLSEDeletedRecord.FindSet(false) then begin
            Rec.Open(ADLSEDeletedRecord."Table ID");
            repeat
                ADLSEUtil.CreateFakeRecordForDeletedAction(ADLSEDeletedRecord, Rec);
                // DeletedLastEntryNo := ExportRecordUpdate(ADLSECommunication, Rec, ADLSEDeletedRecord."Entry No.", ADLSETable, false);
                if ADLSECommunication.TryCollectAndSendRecord(Rec, ADLSEDeletedRecord."Entry No.", FlushedTimeStamp) then
                    DeletedLastEntryNo := FlushedTimeStamp
                else
                    Error(GetLastErrorText() + GetLastErrorCallStack());
            until ADLSEDeletedRecord.Next() = 0;

            // DeletedLastEntryNo := Finish(ADLSECommunication, ADLSETable, false);
            if ADLSECommunication.TryFinish(FlushedTimeStamp) then
                DeletedLastEntryNo := FlushedTimeStamp
            else
                Error(GetLastErrorText() + GetLastErrorCallStack());
        end;
    end;

    // local procedure ExportRecordUpdate(
    //     ADLSECommunication: Codeunit "ADLSE Communication";
    //     Rec: RecordRef;
    //     RecordTimestamp: BigInteger;
    //     var ADLSETable: Record "ADLSE Table";
    //     ExportingExistingRecord: Boolean) LastFlushedTimestamp: BigInteger
    // begin
    //     LastFlushedTimestamp := ADLSECommunication.CollectAndSendRecord(Rec, RecordTimestamp);
    //     UpdateLastTimeStamps(ExportingExistingRecord, LastFlushedTimestamp, ADLSETable);
    // end;

    // local procedure Finish(
    //     ADLSECommunication: Codeunit "ADLSE Communication";
    //     var ADLSETable: Record "ADLSE Table";
    //     ExportingExistingRecord: Boolean) LastFlushedTimestamp: BigInteger;
    // begin
    //     LastFlushedTimestamp := ADLSECommunication.Finish();
    //     UpdateLastTimeStamps(ExportingExistingRecord, LastFlushedTimestamp, ADLSETable);
    // end;

    // local procedure UpdateLastTimeStamps(ExportingExistingRecord: Boolean; LastFlushedTimestamp: BigInteger; var ADLSETable: Record "ADLSE Table")
    // var
    //     ADLSETableLastTimestamp: Record "ADLSE Table Last Timestamp";
    //     NeedToUpdateTimestamp: Boolean;
    // begin
    //     if ExportingExistingRecord then
    //         NeedToUpdateTimestamp := LastFlushedTimestamp > ADLSETableLastTimestamp.GetUpdatedLastTimestamp(ADLSETable."Table ID")
    //     else
    //         NeedToUpdateTimestamp := LastFlushedTimestamp > ADLSETableLastTimestamp.GetDeletedLastEntryNo(ADLSETable."Table ID");

    //     if NeedToUpdateTimestamp then begin
    //         if ExportingExistingRecord then
    //             ADLSETableLastTimestamp.SaveUpdatedLastTimestamp(ADLSETable."Table ID", LastFlushedTimestamp)
    //         else
    //             ADLSETableLastTimestamp.SaveDeletedLastEntryNo(ADLSETable."Table ID", LastFlushedTimestamp);
    //         ADLSETable.Modify();

    //         Commit(); // to persist the timestamp value in case of a subsequent error
    //         AcquireLock(ADLSETable);
    //     end;
    // end;

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

    // local procedure AcquireLock(var ADLSETable: Record "ADLSE Table")
    // begin
    //     ADLSETable.LockTable(true);
    //     ADLSETable.Get(ADLSETable."Table ID");
    // end;

    local procedure SetErrorState(var ADLSETable: Record "ADLSE Table")
    begin
        ADLSETable.State := "ADLSE State"::Error;
        if ADLSETable.LastError = '' then
            ADLSETable.LastError := CopyStr(GetLastErrorText() + GetLastErrorCallStack(), 1, 2048); // 2048 is the max size of the field 
        ADLSETable.Modify();
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

    procedure AcquireLockonADLSESetup(var ADLSEState: Record "ADLSE Setup")
    begin
        ADLSEState.LockTable(true);
        ADLSEState.Get(0);
    end;
}