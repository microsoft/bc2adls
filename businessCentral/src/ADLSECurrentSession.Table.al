// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82565 "ADLSE Current Session"
{
    Access = Internal;
    DataClassification = SystemMetadata;
    DataPerCompany = false;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(2; "Session ID"; Integer)
        {
            Editable = false;
            Caption = 'Session ID';
        }
        field(3; "Session Unique ID"; Guid)
        {
            Editable = false;
            Caption = 'Session unique ID';
        }
    }

    keys
    {
        key(Key1; "Table ID")
        {
            Clustered = true;
        }
    }

    var
        SessionTerminatedMsg: Label 'Export to data lake session for table %1 terminated by user.', Comment = '%1 is the table name corresponding to the session';

    procedure Start(ADLSETableID: Integer)
    var
        ActiveSession: Record "Active Session";
    begin
        ActiveSession.Get(ServiceInstanceId(), SessionId());

        Rec.Init();
        Rec."Table ID" := ADLSETableID;
        Rec."Session ID" := SessionId;
        Rec."Session Unique ID" := ActiveSession."Session Unique ID";
        Rec.Insert();
    end;

    procedure Stop(ADLSETableID: Integer)
    begin
        Rec.Get(ADLSETableID);
        Rec.Delete();
    end;

    procedure CheckSessionsActive() AnyActive: Boolean
    var
        InactiveSessionIDs: List of [Integer];
        TheSessionID: Integer;
    begin
        if Rec.FindSet(false) then
            repeat
                if Rec.IsLinkedSessionActive() then
                    AnyActive := true
                else
                    InactiveSessionIDs.Add(Rec."Session ID");
            until Rec.Next() = 0;

        foreach TheSessionID in InactiveSessionIDs do begin
            Rec.SetRange("Session ID", TheSessionID);
            Rec.DeleteAll();
        end;
    end;

    procedure IsAnySessionActiveForOtherExports(ADLSETableID: Integer): Boolean
    begin
        Rec.SetFilter("Table ID", '<>%1', ADLSETableID);
        exit(not Rec.IsEmpty());
    end;

    [TryFunction]
    procedure CancelAll(ADLSETableErrorText: Text)
    var
        ADLSETable: Record "ADLSE Table";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if Rec.FindSet(false) then
            repeat
                if Rec.IsLinkedSessionActive() then begin
                    Session.StopSession(Rec."Session ID", StrSubstNo(SessionTerminatedMsg, ADLSEUtil.GetTableCaption(Rec."Table ID")));

                    ADLSETable.Get(Rec."Table ID");
                    ADLSETable.State := "ADLSE State"::Error;
                    ADLSETable.LastError := ADLSETableErrorText;
                    ADLSETable.Modify();
                end;
            until Rec.Next() = 0;

        Rec.DeleteAll();
    end;

    procedure IsLinkedSessionActive(): Boolean
    var
        ActiveSession: Record "Active Session";
    begin
        if ActiveSession.Get(ServiceInstanceId(), Rec."Session ID") then
            exit(ActiveSession."Session Unique ID" = Rec."Session Unique ID");
    end;

}