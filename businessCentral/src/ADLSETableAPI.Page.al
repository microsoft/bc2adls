// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82565 "ADLSE Table API"
{
    PageType = API;
    APIPublisher = 'bc2adlsTeamMicrosoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlseTable';
    EntitySetName = 'adlseTable';
    SourceTable = "ADLSE Table";
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(tableId; Rec."Table ID") { }
                field(enabled; Rec.Enabled)
                {
                    Editable = false;
                }
                field(systemId; Rec.SystemId)
                {
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Editable = false;
                }
                field(systemRowVersion; Rec.SystemRowVersion)
                {
                    Editable = false;
                }
            }
            part(adlseField; "ADLSE Field API")
            {
                EntityName = 'adlseField';
                EntitySetName = 'adlseField';
                SubPageLink = "Table ID" = Field("Table ID");
            }
        }
    }

    [ServiceEnabled]
    procedure Reset(var ActionContext: WebServiceActionContext)
    begin
        Rec.reset();
        SetActionResponse(ActionContext, Rec."SystemId");
    end;

    local procedure SetActionResponse(var ActionContext: WebServiceActionContext; AdlsId: Guid)
    var
    begin
        SetActionResponse(ActionContext, Page::"ADLSE Table API", AdlsId);
    end;

    local procedure SetActionResponse(var ActionContext: WebServiceActionContext; PageId: Integer; DocumentId: Guid)
    var
    begin
        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(PageId);
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), DocumentId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;
}