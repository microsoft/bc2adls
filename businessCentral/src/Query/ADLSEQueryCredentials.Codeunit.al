// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82575 "ADLSE Query Credentials" implements "ADLSE ICredentials"
{
    Access = Internal;

    var
        ADLSECredentials: Codeunit "ADLSE Credentials";
        FunctionAppBaseUrl: Text;
        [NonDebuggable]
        ClientID: Text;

        [NonDebuggable]
        ClientSecret: Text;

        [NonDebuggable]
        FunctionKeys: Dictionary of [Text, Text];

        Initialized: Boolean;
        ValueNotFoundErr: Label 'No value found for %1.', Comment = '%1 = name of the key';
        ClientIdKeyNameTok: Label 'adlse-lookup-client-id', Locked = true;
        ClientSecretKeyNameTok: Label 'adlse-lookup-client-secret', Locked = true;
        FunctionKeysTok: Label 'adlse-function-keys', Locked = true;
        ApiScopeTok: Label 'api://%1/user_impersonation', Locked = true;

    [NonDebuggable]
    procedure Init(NewADLSECredentials: Codeunit "ADLSE Credentials"; NewFunctionAppUrl: Text)
    begin
        if IsInitialized() then
            exit;

        ADLSECredentials := NewADLSECredentials;

        FunctionAppBaseUrl := NewFunctionAppUrl;
        ClientID := GetSecret(ClientIdKeyNameTok);
        ClientSecret := GetSecret(ClientSecretKeyNameTok);
        InitFunctionKeys();

        Initialized := true;
    end;

    [NonDebuggable]
    local procedure InitFunctionKeys()
    var
        FunctionKeysText: Text;
        FunctionKeysJson: JsonObject;
        Ky: Text;
        ValJson: JsonToken;
        ValText: Text;
    begin
        FunctionKeysText := GetSecret(FunctionKeysTok);
        FunctionKeysJson.ReadFrom(FunctionKeysText);
        foreach Ky in FunctionKeysJson.Keys() do begin
            FunctionKeysJson.Get(Ky, ValJson);
            ValText := ValJson.AsValue().AsText();
            FunctionKeys.Set(Ky, ValText);
        end;
    end;

    procedure IsInitialized(): Boolean
    begin
        exit(Initialized);
    end;

    procedure Check()
    var
        ADLSESetup: Record "ADLSE Setup";
        NewADLSECredentials: Codeunit "ADLSE Credentials";
    begin
        NewADLSECredentials.Check(); // pre-requisite
        ADLSESetup.GetSingleton();
        ADLSESetup.TestField("Function App Url"); // must not be empty

        Init(NewADLSECredentials, ADLSESetup."Function App Url");
        CheckValueExists(ClientIdKeyNameTok, ClientID);
        CheckValueExists(ClientSecretKeyNameTok, ClientSecret);
    end;

    procedure GetFuntionAppBaseUrl(): Text
    begin
        exit(FunctionAppBaseUrl);
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
        SetSecret(ClientIdKeyNameTok, NewClientIDValue);
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
        SetSecret(ClientSecretKeyNameTok, NewClientSecretValue);
    end;

    procedure GetTenantID(): Text
    begin
        exit(ADLSECredentials.GetTenantID());
    end;

    [NonDebuggable]
    procedure GetResource(): Text
    begin
        exit(GetClientID());
    end;

    [NonDebuggable]
    procedure GetScope(): Text
    begin
        exit(StrSubstNo(ApiScopeTok, GetClientID()));
    end;

    [NonDebuggable]
    procedure GetFunctionKey(FunctionName: Text): Text
    begin
        exit(FunctionKeys.Get(FunctionName));
    end;

    [NonDebuggable]
    procedure SetFunctionKey(FunctionName: Text; KeyVal: Text): Text
    var
        JsonO: JsonObject;
        AsText: Text;
        Ky: Text;
    begin
        if not IsInitialized() then
            InitFunctionKeys();

        FunctionKeys.Set(FunctionName, KeyVal);

        foreach Ky in FunctionKeys.Keys do
            JsonO.Add(Ky, FunctionKeys.Get(Ky));
        JsonO.WriteTo(AsText);
        SetSecret(FunctionKeysTok, AsText);
    end;

    [NonDebuggable]
    local procedure GetSecret(KeyName: Text) Secret: Text
    begin
        if not IsolatedStorage.Contains(KeyName, IsolatedStorageDataScope()) then
            exit('');
        IsolatedStorage.Get(KeyName, IsolatedStorageDataScope(), Secret);
    end;

    [NonDebuggable]
    local procedure SetSecret(KeyName: Text; Secret: Text)
    begin
        if EncryptionEnabled() then begin
            IsolatedStorage.SetEncrypted(KeyName, Secret, IsolatedStorageDataScope());
            exit;
        end;
        IsolatedStorage.Set(KeyName, Secret, IsolatedStorageDataScope());
    end;

    [NonDebuggable]
    local procedure CheckValueExists(KeyName: Text; Val: Text)
    begin
        if Val.Trim() = '' then
            Error(ValueNotFoundErr, KeyName);
    end;

    local procedure IsolatedStorageDataScope(): DataScope
    begin
        exit(DataScope::Module); // so that all companies share the same settings
    end;
}