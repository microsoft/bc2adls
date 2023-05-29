// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82567 "ADLSE Setup Query"
{
    Caption = 'Query data in the lake';
    PageType = CardPart;
    SourceTable = "ADLSE Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Connection)
            {
                Caption = 'Default connection details';

                field("Serverless SQL Endpoint"; Rec."Serverless SQL Endpoint")
                {
                    Caption = 'Synapse Serverless SQL Endpoint';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Synapse Serverless SQL Endpoint which hosts the SQL database holding the shared metadata tables.';
                }

                field("SQL Database"; Rec."SQL Database")
                {
                    Caption = 'SQL Database Name';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the SQL database name holding the shared metadata tables.';
                }
            }

            group(Authentication)
            {
                Caption = 'App registration';

                field("Lookup Client ID"; LookupClientID)
                {
                    Caption = 'Client ID';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    Tooltip = 'Specifies the application client ID for the Azure Function App that queries the Synapse serverless SQL endpoint.';

                    trigger OnValidate()
                    begin
                        ADLSEQueryCredentials.SetClientID(LookupClientID);
                    end;
                }

                field("Lookup Client secret"; LookupClientSecret)
                {
                    Caption = 'Client secret';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    Tooltip = 'Specifies the client secret for the Azure Function App that queries the Synapse serverless SQL endpoint.';

                    trigger OnValidate()
                    begin
                        ADLSEQueryCredentials.SetClientSecret(LookupClientSecret);
                    end;
                }
            }

            group(API)
            {
                Caption = 'Function Api';

                field("Function App URL"; Rec."Function App Url")
                {
                    Caption = 'Function app url';
                    ApplicationArea = All;
                    ExtendedDatatype = URL;
                    ToolTip = 'Specifies the URL of the function app that queries the Synapse serverless SQL database.';
                }

                field("Function Key FindSet"; FunctionKeyFindSet)
                {
                    Caption = 'Function key FindSet';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies a function key that authorizes the FindSet Api call on the function app.';

                    trigger OnValidate()
                    var
                        ADLSEQuery: Codeunit "ADLSE Query Impl.";
                    begin
                        ADLSEQueryCredentials.SetFunctionKey(ADLSEQuery.GetFunctionFindSetToken(), FunctionKeyFindSet);
                    end;
                }

                field("Function Key IsEmpty"; FunctionKeyIsEmpty)
                {
                    Caption = 'Function key IsEmpty';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies a function key that authorizes the IsEmpty Api call on the function app.';

                    trigger OnValidate()
                    var
                        ADLSEQuery: Codeunit "ADLSE Query Impl.";
                    begin
                        ADLSEQueryCredentials.SetFunctionKey(ADLSEQuery.GetFunctionIsEmptyToken(), FunctionKeyIsEmpty);
                    end;
                }

                field("Function Key Count"; FunctionKeyCount)
                {
                    Caption = 'Function key Count';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies a function key that authorizes the Count Api call on the function app.';

                    trigger OnValidate()
                    var
                        ADLSEQuery: Codeunit "ADLSE Query Impl.";
                    begin
                        ADLSEQueryCredentials.SetFunctionKey(ADLSEQuery.GetFunctionCountToken(), FunctionKeyCount);
                    end;
                }
            }

        }
    }

    var
        ADLSEQueryCredentials: Codeunit "ADLSE Query Credentials";
        [NonDebuggable]
        [NonDebuggable]
        LookupClientID: Text;
        [NonDebuggable]
        LookupClientSecret: Text;
        [NonDebuggable]
        FunctionKeyFindSet: Text;
        [NonDebuggable]
        FunctionKeyIsEmpty: Text;
        [NonDebuggable]
        FunctionKeyCount: Text;
}