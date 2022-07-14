page 82563 ADLS
{
    PageType = API;
    Caption = 'ADLS';
    APIPublisher = 'Microsoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adls';
    EntitySetName = 'adls';
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
                field(state; rec.State) { }
                field(lastError; rec.LastError) { }
                field(systemId; Rec.SystemId) { }
                field(systemCreatedAt; Rec.SystemCreatedAt) { }
                field(systemCreatedBy; Rec.SystemCreatedBy) { }
                field(systemModifiedAt; Rec.SystemModifiedAt) { }
                field(systemModifiedBy; Rec.SystemModifiedBy) { }
            }
        }
    }
    [ServiceEnabled]
    procedure disable(var ActionContext: WebServiceActionContext)
    begin
        rec.Disable();
        SetActionResponse(ActionContext, rec."SystemId");
    end;

    [ServiceEnabled]
    procedure enable(var ActionContext: WebServiceActionContext)
    begin
        rec.enable();
        SetActionResponse(ActionContext, rec."SystemId");
    end;

    [ServiceEnabled]
    procedure reset(var ActionContext: WebServiceActionContext)
    begin
        rec.reset();
        SetActionResponse(ActionContext, rec."SystemId");
    end;

    [ServiceEnabled]
    procedure startExport(var ActionContext: WebServiceActionContext)
    var
        ADLSEExecution: Codeunit "ADLSE Execution";
    begin
        ADLSEExecution.StartExport();
        SetActionResponse(ActionContext, rec."SystemId");
    end;

    [ServiceEnabled]
    procedure stopExport(var ActionContext: WebServiceActionContext)
    var
        ADLSEExecution: Codeunit "ADLSE Execution";
    begin
        ADLSEExecution.StopExport();
        SetActionResponse(ActionContext, rec."SystemId");
    end;

    local procedure SetActionResponse(var ActionContext: WebServiceActionContext; AdlsId: Guid)
    var
    begin
        SetActionResponse(ActionContext, Page::"ADLS", AdlsId);
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