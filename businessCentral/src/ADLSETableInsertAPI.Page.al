// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82568 "ADLSE Table Insert API"
{
    PageType = API;
    APIPublisher = 'bc2adlsTeamMicrosoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlseTableInsert';
    EntitySetName = 'adlseTablesInsert';
    SourceTable = "ADLSE Table";
    InsertAllowed = true;
    DeleteAllowed = false;
    ModifyAllowed = false;
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(tableId; Rec."Table ID") { }
                field(enabled; Rec.Enabled) { }
                field(systemId; Rec.SystemId)
                {
                    Editable = false;
                }
            }
            part(adlseFields; "ADLSE Field Insert API")
            {
                EntityName = 'adlseFieldInsert';
                EntitySetName = 'adlseFieldsInsert';
                SubPageLink = "Table ID" = field("Table ID");
            }
        }
    }

}