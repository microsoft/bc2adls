// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82563 "ADLSE Http"
{
    Access = Internal;

    var
        Credentials: Interface "ADLSE ICredentials";
        HttpMethod: Enum "ADLSE Http Method";
        Url: Text;
        Body: Text;
        ContentTypeJson: Boolean;
        AdditionalRequestHeaders: Dictionary of [Text, Text];
        ResponseHeaders: HttpHeaders;
        AzureStorageServiceVersionTok: Label '2020-10-02', Locked = true; // Latest version from https://docs.microsoft.com/en-us/rest/api/storageservices/versioning-for-the-azure-storage-services
        ContentTypeApplicationJsonTok: Label 'application/json', Locked = true;
        ContentTypePlainTextTok: Label 'text/plain; charset=utf-8', Locked = true;
        UnsupportedMethodErr: Label 'Unsupported method: %1', Comment = '%1: http method name';
        OAuthTok: Label 'https://login.microsoftonline.com/%1/oauth2/token', Comment = '%1: tenant id';
        BearerTok: Label 'Bearer %1', Comment = '%1: access token';
        AcquireTokenBodyTok: Label 'resource=%1&scope=%2&client_id=%3&client_secret=%4&client_info=1&grant_type=client_credentials', Comment = '%1: resource, %2: scope, %3: client ID, %4: client secret';

    procedure SetMethod(HttpMethodValue: Enum "ADLSE Http Method")
    begin
        HttpMethod := HttpMethodValue;
    end;

    procedure SetUrl(UrlValue: Text)
    begin
        Url := UrlValue;
    end;

    procedure AddHeader(HeaderKey: Text; HeaderValue: Text)
    begin
        AdditionalRequestHeaders.Add(HeaderKey, HeaderValue);
    end;

    procedure AddHeader(HeaderKey: Text; HeaderValue: Integer)
    var
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        AdditionalRequestHeaders.Add(HeaderKey, ADLSEUtil.ConvertVariantToText(HeaderValue));
    end;

    procedure SetBody(BodyValue: Text)
    begin
        Body := BodyValue;
    end;

    procedure SetContentIsJson()
    begin
        ContentTypeJson := true;
    end;

    procedure GetContentTypeJson(): Text
    begin
        exit(ContentTypeApplicationJsonTok);
    end;

    procedure GetContentTypeTextCsv(): Text
    begin
        exit(ContentTypePlainTextTok);
    end;

    procedure SetAuthorizationCredentials(ADLSEICredentials: Interface "ADLSE ICredentials")
    begin
        Credentials := ADLSEICredentials;
    end;

    procedure GetResponseHeaderValue(HeaderKey: Text) Result: List of [Text]
    var
        Values: array[10] of Text;  // max 10 values in each header
        Counter: Integer;
    begin
        if not ResponseHeaders.Contains(HeaderKey) then
            exit;
        ResponseHeaders.GetValues(HeaderKey, Values);
        for Counter := 1 to 10 do
            Result.Add(Values[Counter]);
    end;

    procedure InvokeRestApi(var Response: Text) Success: Boolean
    var
        StatusCode: Integer;
    begin
        Success := InvokeRestApi(Response, StatusCode);
    end;

    [NonDebuggable]
    procedure InvokeRestApi(var Response: Text; var StatusCode: Integer) Success: Boolean
    var
        Client: HttpClient;
        Headers: HttpHeaders;
        // RequestMsg: HttpRequestMessage;
        ResponseMsg: HttpResponseMessage;
        Content: HttpContent;
        HeaderKey: Text;
        HeaderValue: Text;
    begin
        Client.SetBaseAddress(Url);
        if not AddAuthorization(Client, Response) then
            exit(false);

        if AdditionalRequestHeaders.Count() > 0 then begin
            Headers := Client.DefaultRequestHeaders();
            foreach HeaderKey in AdditionalRequestHeaders.Keys do begin
                AdditionalRequestHeaders.Get(HeaderKey, HeaderValue);
                Headers.Add(HeaderKey, HeaderValue);
            end;
        end;
        case HttpMethod of
            "ADLSE Http Method"::Get:
                Client.Get(Url, ResponseMsg);
            "ADLSE Http Method"::Put:
                begin
                    // RequestMsg.Method('PUT');
                    // RequestMsg.SetRequestUri(Url);
                    AddContent(Content);
                    Client.Put(Url, Content, ResponseMsg);
                end;
            "ADLSE Http Method"::Post:
                begin
                    // RequestMsg.Method('POST');
                    // RequestMsg.SetRequestUri(Url);
                    AddContent(Content);
                    Client.Post(Url, Content, ResponseMsg);
                end;
            else
                Error(UnsupportedMethodErr, HttpMethod);
        end;

        Content := ResponseMsg.Content();
        Content.ReadAs(Response);
        ResponseHeaders := ResponseMsg.Headers();
        Success := ResponseMsg.IsSuccessStatusCode();
        StatusCode := ResponseMsg.HttpStatusCode();
    end;

    local procedure AddContent(var Content: HttpContent)
    var
        Headers: HttpHeaders;
    begin
        Content.WriteFrom(Body);
        Content.GetHeaders(Headers);
        if ContentTypeJson then begin
            Headers.Remove('Content-Type');
            Headers.Add('Content-Type', 'application/json');
        end;
    end;

    [NonDebuggable]
    local procedure AddAuthorization(Client: HttpClient; var Response: Text) Success: Boolean
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        Headers: HttpHeaders;
        AccessToken: Text;
        AuthError: Text;
    begin
        if not Credentials.IsInitialized() then begin // anonymous call
            Success := true;
            exit;
        end;

        AccessToken := AcquireTokenOAuth2(AuthError);
        if AccessToken = '' then begin
            Response := AuthError;
            Success := false;
            exit;
        end;
        Headers := Client.DefaultRequestHeaders();
        Headers.Add('Authorization', StrSubstNo(BearerTok, AccessToken));
        Headers.Add('x-ms-version', AzureStorageServiceVersionTok);
        Headers.Add('x-ms-date', ADLSEUtil.GetCurrentDateTimeInGMTFormat());
        Success := true;
    end;

    [NonDebuggable]
    local procedure AcquireTokenOAuth2(var AuthError: Text) AccessToken: Text
    var
        ADSEUtil: Codeunit "ADLSE Util";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        Content: HttpContent;
        Headers: HttpHeaders;
        ResponseMessage: HttpResponseMessage;
        Uri: Text;
        RequestBody: Text;
        ResponseBody: Text;
        Json: JsonObject;
    begin
        Uri := StrSubstNo(OAuthTok, Credentials.GetTenantID());
        RequestMessage.Method('POST');
        RequestMessage.SetRequestUri(Uri);
        RequestBody :=
            StrSubstNo(
                AcquireTokenBodyTok,
                Credentials.GetResource(),
                Credentials.GetScope(),
                Credentials.GetClientID(),
                Credentials.GetClientSecret());
        Content.WriteFrom(RequestBody);
        Content.GetHeaders(Headers);
        Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'application/x-www-form-urlencoded');

        Client.Post(Uri, Content, ResponseMessage);
        Content := ResponseMessage.Content();
        Content.ReadAs(ResponseBody);
        if not ResponseMessage.IsSuccessStatusCode() then begin
            AuthError := ResponseBody;
            exit;
        end;

        Json.ReadFrom(ResponseBody);
        AccessToken := ADSEUtil.GetTextValueForKeyInJson(Json, 'access_token');
        // TODO: Store access token in cache, and use it based on expiry date.
    end;
}