page 82565 "ADLSE Table API"
{
    PageType = API;
    APIPublisher = 'Microsoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlsTable';
    EntitySetName = 'adlsTable';
    SourceTable = "ADLSE Table";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(tableId; rec."Table ID") { }
                field(enabled; rec.Enabled) { }
                field(systemId; Rec.SystemId) { }
                field(systemCreatedAt; Rec.SystemCreatedAt) { }
                field(systemCreatedBy; Rec.SystemCreatedBy) { }
                field(systemModifiedAt; Rec.SystemModifiedAt) { }
                field(systemModifiedBy; Rec.SystemModifiedBy) { }
            }
        }
    }

    [ServiceEnabled]
    procedure reset(var ActionContext: WebServiceActionContext)
    begin
        rec.reset();
        SetActionResponse(ActionContext, rec."SystemId");
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
        ActionContext.AddEntityKey(rec.FieldNo(SystemId), DocumentId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;
}