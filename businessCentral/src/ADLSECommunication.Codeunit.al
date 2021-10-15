// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82562 "ADLSE Communication"
{
    Access = Internal;

    var
        ADLSECredentials: Codeunit "ADLSE Credentials";
        TableID: Integer;
        FieldIdList: List of [Integer];
        DataBlobPath: Text;
        DataBlobBlockIDs: List of [Text];
        LastRecordOnPayloadTimeStamp: BigInteger;
        Payload: TextBuilder;
        LastFlushedTimeStamp: BigInteger;
        NumberOfFlushes: Integer;
        EntityName: Text;
        EntityJson: JsonObject;
        // EntityJsonNeedsUpdate: Boolean;
        // ManifestJsonsNeedsUpdate: Boolean;
        DefaultContainerName: Text;
        MaxSizeOfPayloadMiB: Integer;
        DeltaCdmManifestNameTxt: Label 'deltas.manifest.cdm.json', Locked = true;
        DataCdmManifestNameTxt: Label 'data.manifest.cdm.json', Locked = true;
        EntityManifestNameTemplateTxt: Label '%1.cdm.json', Locked = true, Comment = '%1 = Entity name';
        ContainerUrl: Label 'https://%1.blob.core.windows.net/%2', Comment = '%1: Account name, %2: Container Name';
        CorpusJsonPathTxt: Label '/%1', Comment = '%1 = name of the blob', Locked = true;
        CannotAddedMoreBlocksErr: Label 'The number of blocks that can be added to the blob has reached its maximum limit.';


    procedure SetupBlobStorage()
    var
        ADLSEGen2Util: Codeunit "ADLSE Gen 2 Util";
    begin
        ADLSECredentials.Init();

        if not ADLSEGen2Util.ContainerExists(GetBaseUrl(), ADLSECredentials) then
            ADLSEGen2Util.CreateContainer(GetBaseUrl(), ADLSECredentials);
    end;

    local procedure GetBaseUrl(): Text
    var
        ADLSESetup: Record "ADLSE Setup";
    begin
        if DefaultContainerName = '' then begin
            ADLSESetup.Get();
            DefaultContainerName := ADLSESetup.Container;
        end;
        exit(StrSubstNo(ContainerUrl, ADLSECredentials.GetStorageAccount(), DefaultContainerName));
    end;

    procedure Init(TableIDValue: Integer; FieldIdListValue: List of [Integer]; LastFlushedTimeStampValue: BigInteger)
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        TableID := TableIDValue;
        FieldIdList := FieldIdListValue;
        // DataBlobPath := '';
        // Clear(DataBlobBlockIDs);
        // LastRecordOnPayloadTimeStamp := 0;
        // Clear(Payload);
        // NumberOfFlushes := 0;

        ADLSECredentials.Init();
        EntityName := ADLSEUtil.GetDataLakeCompliantTableName(TableID);
        // Clear(EntityJson);

        LastFlushedTimeStamp := LastFlushedTimeStampValue;
        ADLSESetup.Get();
        MaxSizeOfPayloadMiB := ADLSESetup.MaxPayloadSizeMiB;
    end;

    procedure CheckEntity(var EntityJsonNeedsUpdate: Boolean; var ManifestJsonsNeedsUpdate: Boolean)
    var
        ADLSECdmUtil: Codeunit "ADLSE CDM Util";
        ADLSEGen2Util: Codeunit "ADLSE Gen 2 Util";
        OldJson: JsonObject;
        NewJson: JsonObject;
        BlobExists: Boolean;
        BlobEntityPath: Text;
    begin
        // check entity
        EntityJson := ADLSECdmUtil.CreateEntityContent(TableID, FieldIdList);
        BlobEntityPath := StrSubstNo(CorpusJsonPathTxt, StrSubstNo(EntityManifestNameTemplateTxt, EntityName));
        OldJson := ADLSEGen2Util.GetBlobContent(GetBaseUrl() + BlobEntityPath, ADLSECredentials, BlobExists);
        if BlobExists then
            ADLSECdmUtil.CheckChangeInEntities(OldJson, EntityJson, EntityName);
        EntityJsonNeedsUpdate := JsonsDifferent(OldJson, EntityJson);

        // check manifest. Assume that if the data manifest needs change, the delta manifest will also need be updated
        OldJson := ADLSEGen2Util.GetBlobContent(GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, DataCdmManifestNameTxt), ADLSECredentials, BlobExists);
        NewJson := ADLSECdmUtil.UpdateDefaultManifestContent(OldJson, TableID, 'data');
        ManifestJsonsNeedsUpdate := JsonsDifferent(OldJson, NewJson);
    end;

    local procedure JsonsDifferent(Json1: JsonObject; Json2: JsonObject): Boolean
    var
        Content1: Text;
        Content2: Text;
    begin
        Json1.WriteTo(Content1);
        Json2.WriteTo(Content2);
        exit(Content1 <> Content2);
    end;

    local procedure CreateDataBlob()
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        ADLSEGen2Util: Codeunit "ADLSE Gen 2 Util";
        FileIdentifer: Guid;
    begin
        if DataBlobPath <> '' then
            // already created blob
            exit;
        FileIdentifer := CreateGuid();
        // AppendBlobDataPath := StrSubstNo('/deltas/%1/%2/%3.csv', EntityName, ADLSEUtil.GetDataLakeCompliantName(CompanyName()), ADLSEUtil.ToText(FileIdentifer));
        DataBlobPath := StrSubstNo('/deltas/%1/%2.csv', EntityName, ADLSEUtil.ToText(FileIdentifer));
        ADLSEGen2Util.CreateDataBlob(GetBaseUrl() + DataBlobPath, ADLSECredentials);
        //.CreateAppendBlob(GetBaseUrl() + AppendBlobDataPath, ADLSECredentials);
    end;

    [TryFunction]
    procedure TryCollectAndSendRecord(Rec: RecordRef; RecordTimeStamp: BigInteger; var LastTimestampExported: BigInteger)
    begin
        CreateDataBlob();
        LastTimestampExported := CollectAndSendRecord(Rec, RecordTimeStamp);
    end;

    local procedure CollectAndSendRecord(Rec: RecordRef; RecordTimeStamp: BigInteger) LastTimestampExported: BigInteger
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        RecordPayLoad: Text;
    begin
        if NumberOfFlushes = 50000 then // https://docs.microsoft.com/en-us/rest/api/storageservices/put-block#remarks
            Error(CannotAddedMoreBlocksErr);

        RecordPayLoad := ADLSEUtil.CreateCsvPayload(Rec, FieldIdList, Payload.Length() = 0);
        // check if payload exceeds the limit
        if Payload.Length() + StrLen(RecordPayLoad) + 2 > MaxPayloadSize() then // the 2 is to account for new line characters
            FlushPayload();
        LastTimestampExported := LastFlushedTimeStamp;

        Payload.Append(RecordPayLoad);
        LastRecordOnPayloadTimeStamp := RecordTimestamp;
    end;

    [TryFunction]
    procedure TryFinish(var LastTimestampExported: BigInteger)
    begin
        LastTimestampExported := Finish();
    end;

    local procedure Finish() LastTimestampExported: BigInteger
    begin
        FlushPayload();

        LastTimestampExported := LastFlushedTimeStamp;

        // if NumberOfFlushes > 0 then
        //     UpdateCdmJsons();
    end;

    local procedure MaxPayloadSize(): Integer
    var
        MaxLimitForPutBlockCalls: Integer;
        MaxCapacityOfTextBuilder: Integer;
    begin
        MaxLimitForPutBlockCalls := MaxSizeOfPayloadMiB * 1024 * 1024;
        MaxCapacityOfTextBuilder := Payload.MaxCapacity();
        if MaxLimitForPutBlockCalls < MaxCapacityOfTextBuilder then
            exit(MaxLimitForPutBlockCalls);
        exit(MaxCapacityOfTextBuilder);
    end;

    local procedure FlushPayload()
    var
        ADLSEGen2Util: Codeunit "ADLSE Gen 2 Util";
        ADLSE: Codeunit ADLSE;
        BlockID: Text;
    begin
        if Payload.Length() = 0 then
            exit;

        BlockID := ADLSEGen2Util.AddBlockToDataBlob(GetBaseUrl() + DataBlobPath, Payload.ToText(), ADLSECredentials);
        DataBlobBlockIDs.Add(BlockID);
        ADLSEGen2Util.CommitAllBlocksOnDataBlob(GetBaseUrl() + DataBlobPath, ADLSECredentials, DataBlobBlockIDs);

        LastFlushedTimeStamp := LastRecordOnPayloadTimeStamp;
        Payload.Clear();
        LastRecordOnPayloadTimeStamp := 0;
        NumberOfFlushes += 1;

        ADLSE.OnTableExported(TableID, LastFlushedTimeStamp);
    end;

    [TryFunction]
    procedure TryUpdateCdmJsons(EntityJsonNeedsUpdate: Boolean; ManifestJsonsNeedsUpdate: Boolean)
    begin
        UpdateCdmJsons(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate);
    end;

    local procedure UpdateCdmJsons(EntityJsonNeedsUpdate: Boolean; ManifestJsonsNeedsUpdate: Boolean)
    var
        ADLSESetup: Record "ADLSE Setup";
        ADLSECdmUtil: Codeunit "ADLSE CDM Util";
        ADLSEGen2Util: Codeunit "ADLSE Gen 2 Util";
        ADLSEExecute: Codeunit "ADLSE Execute";
        LeaseID: Text;
        BlobPath: Text;
        BlobExists: Boolean;
    begin
        // update entity json
        if EntityJsonNeedsUpdate then begin
            BlobPath := GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, StrSubstNo(EntityManifestNameTemplateTxt, EntityName));
            LeaseID := ADLSEGen2Util.AcquireLease(BlobPath, ADLSECredentials, BlobExists);
            ADLSEGen2Util.CreateOrUpdateJsonBlob(BlobPath, ADLSECredentials, LeaseID, EntityJson);
            ADLSEGen2Util.ReleaseBlob(BlobPath, ADLSECredentials, LeaseID);
        end;

        // update manifest
        if ManifestJsonsNeedsUpdate then begin
            // Expected that multiple sessions that export data from different tables will be competing for writing to manifest. Semaphore applied.
            ADLSEExecute.AcquireLockonADLSESetup(ADLSESetup);

            UpdateManifest(GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, DataCdmManifestNameTxt), 'data');
            UpdateManifest(GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, DeltaCdmManifestNameTxt), 'deltas');
            Commit(); // to release the lock above
        end;
    end;

    local procedure UpdateManifest(BlobPath: Text; Folder: Text)
    var
        ADLSECdmUtil: Codeunit "ADLSE CDM Util";
        ADLSEGen2Util: Codeunit "ADLSE Gen 2 Util";
        ManifestJson: JsonObject;
        LeaseID: Text;
        BlobExists: Boolean;
    begin
        LeaseID := ADLSEGen2Util.AcquireLease(BlobPath, ADLSECredentials, BlobExists);
        if BlobExists then
            ManifestJson := ADLSEGen2Util.GetBlobContent(BlobPath, ADLSECredentials, BlobExists);
        ManifestJson := ADLSECdmUtil.UpdateDefaultManifestContent(ManifestJson, TableID, Folder);
        ADLSEGen2Util.CreateOrUpdateJsonBlob(BlobPath, ADLSECredentials, LeaseID, ManifestJson);
        ADLSEGen2Util.ReleaseBlob(BlobPath, ADLSECredentials, LeaseID);
    end;

}