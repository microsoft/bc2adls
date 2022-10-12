page 82564 "ADLSE Setup API"
{
    PageType = API;
    APIPublisher = 'Microsoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlsSetup';
    EntitySetName = 'adlsSetup';
    SourceTable = "ADLSE Setup";
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
                field(container; rec.Container) { }
                field(emitTelemetry; rec."Emit telemetry") { }
                field(dataFormat; rec.DataFormat) { }
                field(maxPayloadSizeMiB; rec.MaxPayloadSizeMiB) { }
                field(multiCompanyExport; rec."Multi- Company Export") { }
                field(systemId; Rec.SystemId) { }
                field(systemCreatedAt; Rec.SystemCreatedAt) { }
                field(systemCreatedBy; Rec.SystemCreatedBy) { }
                field(systemModifiedAt; Rec.SystemModifiedAt) { }
                field(systemModifiedBy; Rec.SystemModifiedBy) { }
            }
        }
    }

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
        SetActionResponse(ActionContext, Page::"ADLSE Setup API", AdlsId);
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