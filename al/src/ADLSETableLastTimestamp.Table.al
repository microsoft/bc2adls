// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
table 82564 "ADLSE Table Last Timestamp"
{
    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; "Company Name"; Text[30])
        {
            Editable = false;
            Caption = 'Company name';
            TableRelation = Company.Name;
        }
        field(2; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
            TableRelation = "ADLSE Table"."Table ID";
        }
        field(3; "Updated Last Timestamp"; BigInteger)
        {
            Editable = false;
            Caption = 'Last timestamp exported for an updated record';
        }
        field(4; "Deleted Last Entry No."; BigInteger)
        {
            Editable = false;
            Caption = 'Entry no. of the last deleted record';
        }
    }

    keys
    {
        key(Key1; "Company Name", "Table ID")
        {
            Clustered = true;
        }
    }

    procedure GetUpdatedLastTimestamp(TableID: Integer): BigInteger
    begin
        if Rec.Get(GetCompanyNameToLookFor(TableID), TableID) then
            exit(Rec."Updated Last Timestamp");
    end;

    procedure GetDeletedLastEntryNo(TableID: Integer): BigInteger
    begin
        if Rec.Get(GetCompanyNameToLookFor(TableID), TableID) then
            exit(Rec."Deleted Last Entry No.");
    end;

    [TryFunction]
    procedure TrySaveUpdatedLastTimestamp(TableID: Integer; Timestamp: BigInteger)
    begin
        SaveUpdatedLastTimestamp(TableID, Timestamp);
    end;

    procedure SaveUpdatedLastTimestamp(TableID: Integer; Timestamp: BigInteger)
    begin
        RecordLastTimestamp(TableID, Timestamp, true);
    end;

    [TryFunction]
    procedure TrySaveDeletedLastEntryNo(TableID: Integer; Timestamp: BigInteger)
    begin
        SaveDeletedLastEntryNo(TableID, Timestamp);
    end;

    procedure SaveDeletedLastEntryNo(TableID: Integer; Timestamp: BigInteger)
    begin
        RecordLastTimestamp(TableID, Timestamp, false);
    end;

    local procedure RecordLastTimestamp(TableID: Integer; Timestamp: BigInteger; Update: Boolean)
    var
        Company: Text;
    begin
        Company := GetCompanyNameToLookFor(TableID);
        if Rec.Get(Company, TableID) then begin
            ChangeLastTimestamp(Timestamp, Update);
            Rec.Modify();
        end else begin
            Rec.Init();
            Rec."Company Name" := Company;
            Rec."Table ID" := TableID;
            ChangeLastTimestamp(Timestamp, Update);
            Rec.Insert();
        end
    end;

    local procedure ChangeLastTimestamp(Timestamp: BigInteger; Update: Boolean)
    begin
        if Update then
            Rec."Updated Last Timestamp" := Timestamp
        else
            Rec."Deleted Last Entry No." := Timestamp;
    end;

    local procedure GetCompanyNameToLookFor(TableID: Integer): Text
    var
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if ADLSEUtil.IsTablePerCompany(TableID) then
            exit(CurrentCompany());
        // else it remains blank
    end;
}