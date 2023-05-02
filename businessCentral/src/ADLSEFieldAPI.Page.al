// Create an API page for table and field

page 82567 "ADLSE Field API"
{
    PageType = API;
    APIPublisher = 'bc2adlsTeamMicrosoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlseField';
    EntitySetName = 'adlseFields';
    SourceTable = "ADLSE Field";
    InsertAllowed = true;
    ModifyAllowed = false;
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