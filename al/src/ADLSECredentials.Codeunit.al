// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
codeunit 82565 "ADLSE Credentials"
{
    Access = Internal;
    // The max sizes of the fields are determined based on the recommendations listed at 
    // https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage

    var
        [NonDebuggable]
        StorageAccount: Text;

        [NonDebuggable]
        ClientID: Text;

        [NonDebuggable]
        ClientSecret: Text;

        [NonDebuggable]
        StorageTenantID: Text;

        Initialized: Boolean;
        ValueNotFoundErr: Label 'No value found for %1.', Comment = '%1 = name of the key';
        TenantIdKeyName: Label 'adlse-tenant-id', Locked = true;
        StorageAccountKeyName: Label 'adlse-storage-account', Locked = true;
        ClientIdKeyName: Label 'adlse-client-id', Locked = true;
        ClientSecretKeyName: Label 'adlse-client-secret', Locked = true;

    [NonDebuggable]
    procedure Init()
    var
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        StorageTenantID := GetSecret(TenantIdKeyName);
        StorageAccount := GetSecret(StorageAccountKeyName);
        ClientID := GetSecret(ClientIdKeyName);
        ClientSecret := GetSecret(ClientSecretKeyName);

        Initialized := true;
    end;

    procedure IsInitialized(): Boolean
    begin
        exit(Initialized);
    end;

    procedure Check()
    begin
        Init();
        CheckValueExists(TenantIdKeyName, StorageTenantID);
        CheckValueExists(StorageAccountKeyName, StorageAccount);
        CheckValueExists(ClientIdKeyName, ClientID);
        CheckValueExists(ClientSecretKeyName, ClientSecret);
    end;

    [NonDebuggable]
    procedure GetTenantID(): Text
    begin
        exit(StorageTenantID);
    end;

    [NonDebuggable]
    procedure SetTenantID(NewTenantIdValue: Text): Text
    begin
        StorageTenantID := NewTenantIdValue;
        SetSecret(TenantIdKeyName, NewTenantIdValue);
    end;

    [NonDebuggable]
    procedure GetStorageAccount(): Text
    begin
        exit(StorageAccount);
    end;

    [NonDebuggable]
    procedure SetStorageAccount(NewStorageAccountValue: Text): Text
    begin
        StorageAccount := NewStorageAccountValue;
        SetSecret(StorageAccountKeyName, NewStorageAccountValue);
    end;

    [NonDebuggable]
    procedure GetClientID(): Text
    begin
        exit(ClientID);
    end;

    [NonDebuggable]
    procedure SetClientID(NewClientIDValue: Text): Text
    begin
        ClientID := NewClientIDValue;
        SetSecret(ClientIdKeyName, NewClientIDValue);
    end;

    [NonDebuggable]
    procedure GetClientSecret(): Text
    begin
        exit(ClientSecret);
    end;

    [NonDebuggable]
    procedure SetClientSecret(NewClientSecretValue: Text): Text
    begin
        ClientSecret := NewClientSecretValue;
        SetSecret(ClientSecretKeyName, NewClientSecretValue);
    end;

    [NonDebuggable]
    local procedure GetSecret(KeyName: Text) Secret: Text
    begin
        if not IsolatedStorage.Contains(KeyName, DataScope::Company) then
            exit('');
        IsolatedStorage.Get(KeyName, DataScope::Company, Secret);
    end;

    [NonDebuggable]
    local procedure SetSecret(KeyName: Text; Secret: Text)
    begin
        if EncryptionEnabled() then begin
            IsolatedStorage.SetEncrypted(KeyName, Secret, DataScope::Company);
            exit;
        end;
        IsolatedStorage.Set(KeyName, Secret, DataScope::Company);
    end;

    [NonDebuggable]
    local procedure CheckValueExists(KeyName: Text; Val: Text)
    begin
        if Val.Trim() = '' then
            Error(ValueNotFoundErr, KeyName);
    end;
}