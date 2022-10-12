// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82568 "ADLSE Gen 2 Util"
{
    Access = Internal;
    SingleInstance = true;

    var
        AcquireLeaseSuffixTxt: Label '?comp=lease', Locked = true;
        LeaseDurationSecsTxt: Label '60', Locked = true, Comment = 'This is the maximum duration for a lock on the blobs';
        AcquireLeaseTimeoutSecondsTxt: Label '180', Locked = true, Comment = 'The number of seconds to continuously try to acquire a lock on the blob. This must be more than the value specified for AcquireLeaseSleepSecondsTxt.';
        AcquireLeaseSleepSecondsTxt: Label '10', Locked = true, Comment = 'The number of seconds to sleep for before re-trying to acquire a lock on the blob. This must be less than the value specified for AcquireLeaseTimeoutSecondsTxt.';
        TimedOutWaitingForLockOnBlobErr: Label 'Timed out waiting to acquire lease on blob %1 after %2 seconds. %3', Comment = '%1: blob name, %2: total waiting time in seconds, %3: Http Response';
        CouldNotReleaseLockOnBlobErr: Label 'Could not release lock on blob %1. %2', Comment = '%1: blob name, %2: Http response.';

        CreateContainerSuffixTxt: Label '?restype=container', Locked = true;
        CoundNotCreateContainerErr: Label 'Could not create container %1. %2', Comment = '%1: container name; %2: error text';
        GetContainerMetadataSuffixTxt: Label '?restype=container&comp=metadata', Locked = true;

        PutBlockSuffixTxt: Label '?comp=block&blockid=%1', Locked = true, Comment = '%1 = the block id being added';
        PutLockListSuffixTxt: Label '?comp=blocklist', Locked = true;
        CouldNotAppendDataToBlobErr: Label 'Could not append data to %1. %2', Comment = '%1: blob path, %2: Http response.';
        CouldNotCommitBlocksToDataBlobErr: Label 'Could not commit blocks to %1. %2', Comment = '%1: Blob path, %2: Http Response';
        CouldNotCreateBlobErr: Label 'Could not create blob %1. %2', Comment = '%1: blob path, %2: error text';
        CouldNotReadDataInBlobErr: Label 'Could not read data on %1. %2', Comment = '%1: blob path, %2: Http respomse';
        LatestBlockTagTok: Label '<Latest>%1</Latest>', Comment = '%1: block ID';

    procedure ContainerExists(ContainerPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"): Boolean
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Get);
        ADLSEHttp.SetUrl(ContainerPath + GetContainerMetadataSuffixTxt);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        exit(ADLSEHttp.InvokeRestApi(Response)); // no error
    end;

    procedure CreateContainer(ContainerPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials")
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Put);
        ADLSEHttp.SetUrl(ContainerPath + CreateContainerSuffixTxt);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        if not ADLSEHttp.InvokeRestApi(Response) then
            Error(CoundNotCreateContainerErr, ContainerPath, Response);
    end;

    procedure GetBlobContent(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"; var BlobExists: Boolean) Content: JsonObject
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        ContentToken: JsonToken;
        Response: Text;
        StatusCode: Integer;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Get);
        ADLSEHttp.SetUrl(BlobPath);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        BlobExists := true;
        if ADLSEHttp.InvokeRestApi(Response, StatusCode) then begin
            if Response.Trim() <> '' then begin
                ContentToken.ReadFrom(Response);
                Content := ContentToken.AsObject();
            end;
            exit;
        end;

        BlobExists := StatusCode <> 404;

        if BlobExists then // real error
            Error(CouldNotReadDataInBlobErr, BlobPath, Response);
    end;

    procedure CreateOrUpdateJsonBlob(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"; LeaseID: Text; Body: JsonObject)
    var
        BodyAsText: Text;
    begin
        Body.WriteTo(BodyAsText);
        CreateBlockBlob(BlobPath, ADLSECredentials, LeaseID, BodyAsText, true);
    end;

    local procedure CreateBlockBlob(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"; LeaseID: Text; Body: Text; IsJson: Boolean)
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Put);
        ADLSEHttp.SetUrl(BlobPath);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        ADLSEHttp.AddHeader('x-ms-blob-type', 'BlockBlob');
        if IsJson then begin
            ADLSEHttp.AddHeader('x-ms-blob-content-type', ADLSEHttp.GetContentTypeJson());
            ADLSEHttp.SetContentIsJson();
        end else
            ADLSEHttp.AddHeader('x-ms-blob-content-type', ADLSEHttp.GetContentTypeTextCsv());
        ADLSEHttp.SetBody(Body);
        if LeaseID <> '' then
            ADLSEHttp.AddHeader('x-ms-lease-id', LeaseID);
        if not ADLSEHttp.InvokeRestApi(Response) then
            Error(CouldNotCreateBlobErr, BlobPath, Response);
    end;

    procedure CreateDataBlob(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials")
    begin
        CreateBlockBlob(BlobPath, ADLSECredentials, '', '', false);
    end;

    procedure AddBlockToDataBlob(BlobPath: Text; Body: Text; ADLSECredentials: Codeunit "ADLSE Credentials") BlockID: Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Put);
        BlockID := Base64Convert.ToBase64(CreateGuid());
        ADLSEHttp.SetUrl(BlobPath + StrSubstNo(PutBlockSuffixTxt, BlockID));
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        ADLSEHttp.SetBody(Body);
        if not ADLSEHttp.InvokeRestApi(Response) then
            Error(CouldNotAppendDataToBlobErr, BlobPath, Response);
    end;

    procedure CommitAllBlocksOnDataBlob(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"; BlockIDList: List of [Text])
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
        Body: TextBuilder;
        BlockID: Text;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Put);
        ADLSEHttp.SetUrl(BlobPath + PutLockListSuffixTxt);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);

        Body.Append('<?xml version="1.0" encoding="utf-8"?><BlockList>');
        foreach BlockID in BlockIDList do
            Body.Append(StrSubstNo(LatestBlockTagTok, BlockID));
        Body.Append('</BlockList>');

        ADLSEHttp.SetBody(Body.ToText());
        if not ADLSEHttp.InvokeRestApi(Response) then
            Error(CouldNotCommitBlocksToDataBlobErr, BlobPath, Response);
    end;

    procedure AcquireLease(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"; var BlobExists: Boolean) LeaseID: Text
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
        LeaseIdHeaderValues: List of [Text];
        MaxMillisecondsToWaitFor: Integer;
        SleepForMilliseconds: Integer;
        FirstAcquireRequestAt: DateTime;
        StatusCode: Integer;
    begin
        ADLSEHttp.SetMethod("ADLSE Http Method"::Put);
        ADLSEHttp.SetUrl(BlobPath + AcquireLeaseSuffixTxt);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        ADLSEHttp.AddHeader('x-ms-lease-action', 'acquire');
        ADLSEHttp.AddHeader('x-ms-lease-duration', LeaseDurationSecsTxt);

        Evaluate(MaxMillisecondsToWaitFor, AcquireLeaseTimeoutSecondsTxt);
        MaxMillisecondsToWaitFor *= 1000;
        Evaluate(SleepForMilliseconds, AcquireLeaseSleepSecondsTxt);
        SleepForMilliseconds *= 1000;
        FirstAcquireRequestAt := CurrentDateTime();
        while CurrentDateTime() - FirstAcquireRequestAt < MaxMillisecondsToWaitFor do begin
            if ADLSEHttp.InvokeRestApi(Response, StatusCode) then begin
                LeaseIdHeaderValues := ADLSEHttp.GetResponseHeaderValue('x-ms-lease-id');
                LeaseIdHeaderValues.Get(1, LeaseID);
                BlobExists := true;
                exit;
            end else
                if StatusCode = 404 then
                    exit;
            Sleep(SleepForMilliseconds);
        end;
        Error(TimedOutWaitingForLockOnBlobErr, BlobPath, AcquireLeaseTimeoutSecondsTxt, Response);
    end;

    procedure ReleaseBlob(BlobPath: Text; ADLSECredentials: Codeunit "ADLSE Credentials"; LeaseID: Text)
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Response: Text;
    begin
        if LeaseID = '' then
            exit; // nothing has been leased
        ADLSEHttp.SetMethod("ADLSE Http Method"::Put);
        ADLSEHttp.SetUrl(BlobPath + AcquireLeaseSuffixTxt);
        ADLSEHttp.SetAuthorizationCredentials(ADLSECredentials);
        ADLSEHttp.AddHeader('x-ms-lease-action', 'release');
        ADLSEHttp.AddHeader('x-ms-lease-id', LeaseID);
        if not ADLSEHttp.InvokeRestApi(Response) then
            Error(CouldNotReleaseLockOnBlobErr, BlobPath, Response);
    end;

}