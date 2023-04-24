// Create an API page for table and field

page 82567 "ADLSE Field API"
{
    PageType = API;
    APIPublisher = 'bc2adlsTeamMicrosoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlseField';
    EntitySetName = 'adlseField';
    SourceTable = "ADLSE Field";
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
                field(tableId; Rec."Table ID")
                {
                    trigger OnValidate()
                    var
                        ADLSETable: Record "ADLSE Table";
                        ErrorLbl: Label 'Table ID does not exist';
                    begin
                        if not ADLSETable.Get(Rec."Table ID") then
                            Error(ErrorLbl);
                    end;
                }
                field(fieldId; Rec."Field ID") { }
                field(enabled; Rec.Enabled) { }
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
        }
    }
}