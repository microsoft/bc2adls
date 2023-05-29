// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82574 "ADLSE Query Impl."
{
    Access = Internal;

    var
        ADLSEQueryCredentials: Codeunit "ADLSE Query Credentials";
        Server: Text;
        Database: Text;
        TableName: Text;
        SelectFields: JsonArray;
        Filters: JsonArray;
        OrderBys: JsonArray;
        FindSetResult: JsonArray;
        FindSetResultCurrentRowIndex: Integer;
        IsInitialized: Boolean;
        ServerCannotBeEmptyErr: Label 'Server cannot be empty. Have you called SetServer()?';
        DatabaseCannotBeEmptyErr: Label 'Database cannot be empty. Have you called SetDatabase()?';
        TableCannotBeEmptyErr: Label 'Table cannot be empty. Have you called Init()?';
        FieldMissingInResultSetErr: Label 'The field %1 is not present in the result. Make sure that the casing of the field name is correct and that this field has been loaded in the query.', Comment = '%1 is the field name';
        FilterExpressionNotSupportedErr: Label 'The filter expression %1 is not supported.', Comment = '%1 is the passed filter expression';
        FunctionApiUrlTok: Label '%1/api/%2', Comment = '%1 is the function app url, %2 is the function Api', Locked = true;
        NotInitializedErr: Label 'The query api object needs to be initialized. Please call Init() first.';
        ApiCallFailedErr: Label 'The call to the URL %1 failed with status code %2: %3', Comment = '%1 is the url called for the api and %2 is the status code, %3 is the response body if any';
        ResultTokenMissingErr: Label 'Expected token ''result'' in response: %1', Comment = '%1 is the response from the function api call.';
        InvalidResponseErr: Label 'Invalid result in response: %1', Comment = '%1 is the response from the function api call.';
        NoRecordsFoundErr: Label 'No records found';
        UnexpectedJsonTokenForFieldErr: Label 'Expected a json value for the field %1. Got %2', Comment = '%1 is the field name queried, %2 is the text of the Json Token returned.';
        FieldAddedToOrderByErr: Label 'Field %1 has been added to the OrderBy clause already. You cannot add it twice.', Comment = '%1 is the field name';

    procedure Init(NewTableName: Text)
    var
        ADLSESetup: Record "ADLSE Setup";
    begin
        ADLSEQueryCredentials.Check();

        ADLSESetup.GetSingleton();
        if Server = '' then
            Server := ADLSESetup."Serverless SQL Endpoint";
        if Database = '' then
            Database := ADLSESetup."SQL Database";

        TableName := NewTableName;
        Clear(SelectFields);
        Clear(Filters);
        Clear(OrderBys);
        Clear(FindSetResult);
        FindSetResultCurrentRowIndex := 0;

        IsInitialized := true;
    end;

    procedure SetServer(NewServer: Text)
    begin
        Server := NewServer;
    end;

    procedure SetDatabase(NewDatabase: Text)
    begin
        Database := NewDatabase;
    end;

    procedure AddLoadField(NewFieldName: Text)
    var
        FieldToken: JsonToken;
        FieldName: Text;
    begin
        CheckInitialized();
        foreach FieldToken in SelectFields do begin
            FieldToken.WriteTo(FieldName);
            if FieldName = NewFieldName then
                exit;
        end;
        SelectFields.Add(NewFieldName);
    end;

    procedure SetRange(FieldName: Text; ValueVariant: Variant)
    begin
        SetFilter(FieldName, "ADLSE Query Filter Operator"::Equals, ValueVariant);
    end;

    procedure SetRange(FieldName: Text; FromValueVariant: Variant; ToValueVariant: Variant)
    begin
        SetFilter(FieldName, "ADLSE Query Filter Operator"::GreaterThanOrEquals, FromValueVariant);
        SetFilter(FieldName, "ADLSE Query Filter Operator"::LessThanOrEquals, ToValueVariant);
    end;

    procedure SetFilter(FieldName: Text; FilterExpression: Text; ValueVariant: Variant)
    var
        TrimmedExpression: Text;
    begin
        TrimmedExpression := FilterExpression.Replace(' ', ''); // remove all spaces
        case TrimmedExpression of
            '=%1':
                SetFilter(FieldName, "ADLSE Query Filter Operator"::Equals, ValueVariant);
            '<%1':
                SetFilter(FieldName, "ADLSE Query Filter Operator"::LessThan, ValueVariant);
            '<=%1':
                SetFilter(FieldName, "ADLSE Query Filter Operator"::LessThanOrEquals, ValueVariant);
            '>%1':
                SetFilter(FieldName, "ADLSE Query Filter Operator"::GreaterThan, ValueVariant);
            '>=%1':
                SetFilter(FieldName, "ADLSE Query Filter Operator"::GreaterThanOrEquals, ValueVariant);
            '<>%1':
                SetFilter(FieldName, "ADLSE Query Filter Operator"::NotEquals, ValueVariant);
            else
                Error(FilterExpressionNotSupportedErr, FilterExpression);
        end;
    end;

    procedure SetFilter(FieldName: Text; FilterOp: enum "ADLSE Query Filter Operator"; ValueVariant: Variant)
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        FilterObj: JsonObject;
        ValueJson: JsonValue;
    begin
        CheckInitialized();
        FilterObj.Add('op', FilterOp.Names().Get(FilterOp.Ordinals().IndexOf(FilterOp.AsInteger())));
        FilterObj.Add('field', FieldName);
        if not ADLSEUtil.ConvertVariantToJson(ValueVariant, ValueJson) then
            ADLSEUtil.RaiseFieldTypeNotSupportedError(FieldName);
        FilterObj.Add('value', ValueJson);
        Filters.Add(FilterObj);
    end;

    procedure SetOrderBy(FieldName: Text)
    begin
        SetOrderBy(FieldName, true);
    end;

    procedure SetOrderBy(FieldName: Text; Ascending: Boolean)
    var
        OrderBy: JsonObject;
        Token: JsonToken;
    begin
        CheckInitialized();
        if OrderBys.SelectToken('$[?(@.field==''' + FieldName + ''')]', Token) then
            // field has been set to be ordered by already
            Error(FieldAddedToOrderByErr, FieldName);
        OrderBy.Add('field', FieldName);
        OrderBy.Add('ascending', Ascending);
        OrderBys.Add(OrderBy);
    end;

    procedure FindSet(): Boolean
    var
        Payload: JsonObject;
        Response: JsonToken;
    begin
        Payload := CreatePayload();

        if SelectFields.Count() > 0 then
            Payload.Add('fields', SelectFields);
        if OrderBys.Count() > 0 then
            Payload.Add('orderBy', OrderBys);

        Response := CallFunctionApi(GetFunctionFindSetToken(), Payload);
        if not Response.IsArray() then
            Error(InvalidResponseErr, Response);

        FindSetResultCurrentRowIndex := -1;
        FindSetResult := Response.AsArray();
        if FindSetResult.Count() = 0 then
            exit(false);
        FindSetResultCurrentRowIndex := 0; // records found. Point at the first one.
        exit(true);
    end;

    procedure IsEmpty(): Boolean
    var
        Response: JsonToken;
    begin
        Response := CallFunctionApi(GetFunctionIsEmptyToken(), CreatePayload());
        if not Response.IsValue() then
            Error(InvalidResponseErr, Response);
        exit(Response.AsValue().AsBoolean());
    end;

    procedure Count(): Integer
    var
        Response: JsonToken;
    begin
        Response := CallFunctionApi(GetFunctionCountToken(), CreatePayload());
        if not Response.IsValue() then
            Error(InvalidResponseErr, Response);
        exit(Response.AsValue().AsInteger());
    end;

    local procedure CreatePayload() Payload: JsonObject
    begin
        if Server = '' then
            Error(ServerCannotBeEmptyErr);
        if Database = '' then
            Error(DatabaseCannotBeEmptyErr);
        if TableName = '' then
            Error(TableCannotBeEmptyErr);

        Payload.Add('server', Server);
        Payload.Add('database', Database);
        Payload.Add('entity', TableName);
        if Filters.Count() > 0 then
            Payload.Add('filters', Filters);
    end;

    [NonDebuggable]
    local procedure CallFunctionApi(FunctionName: Text; Payload: JsonObject) ResultToken: JsonToken;
    var
        ADLSEHttp: Codeunit "ADLSE Http";
        Url: Text;
        Request: Text;
        Response: Text;
        StatusCode: Integer;
        Result: JsonObject;
    begin
        CheckInitialized();

        ADLSEHttp.SetMethod("ADLSE Http Method"::Post);
        Url := StrSubstNo(FunctionApiUrlTok, ADLSEQueryCredentials.GetFuntionAppBaseUrl(), FunctionName);
        ADLSEHttp.SetUrl(Url);
        ADLSEHttp.SetAuthorizationCredentials(ADLSEQueryCredentials);
        ADLSEHttp.AddHeader('x-functions-key', ADLSEQueryCredentials.GetFunctionKey(FunctionName));
        ADLSEHttp.SetContentIsJson();

        Payload.WriteTo(Request);
        ADLSEHttp.SetBody(Request);

        if not ADLSEHttp.InvokeRestApi(Response, StatusCode) then
            Error(ApiCallFailedErr, Url, StatusCode, Response);

        Result.ReadFrom(Response);
        if not Result.Get('result', ResultToken) then
            Error(ResultTokenMissingErr, Response);
    end;

    procedure Next(): Boolean
    begin
        if FindSetResultCurrentRowIndex = FindSetResult.Count() - 1 then // at the last record
            exit(false);
        FindSetResultCurrentRowIndex += 1;
        exit(true);
    end;

    procedure Field(FieldName: Text): JsonValue
    var
        Result: JsonToken;
        Value: JsonToken;
        ValueAsText: Text;
    begin
        if FindSetResultCurrentRowIndex = -1 then
            Error(NoRecordsFoundErr);
        FindSetResult.Get(FindSetResultCurrentRowIndex, Result);
        if not Result.AsObject().Get(FieldName, Value) then
            Error(FieldMissingInResultSetErr, FieldName);
        if not Value.IsValue() then begin
            Value.WriteTo(ValueAsText);
            Error(UnexpectedJsonTokenForFieldErr, FieldName, ValueAsText);
        end;
        exit(Value.AsValue());
    end;

    procedure GetFunctionFindSetToken(): Text
    begin
        exit('FindSet');
    end;

    procedure GetFunctionIsEmptyToken(): Text
    begin
        exit('IsEmpty');
    end;

    procedure GetFunctionCountToken(): Text
    begin
        exit('Count');
    end;

    local procedure CheckInitialized()
    begin
        if not IsInitialized then
            Error(NotInitializedErr);
    end;
}