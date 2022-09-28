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
        field(10; "Company Name"; Text[30])
        {
            Editable = false;
            Caption = 'Company name';
        }
    }

    keys
    {
        key(Key1; "Table ID", "Company Name")
        {
            Clustered = true;
        }

        key(SessionID; "Session ID")
        {
        }
    }

    var
        SessionTerminatedMsg: Label 'Export to data lake session for table %1 terminated by user.', Comment = '%1 is the table name corresponding to the session';
        ExportDataInProgressErr: Label 'An export data process is already running. Please wait for it to finish.';

    procedure Start(ADLSETableID: Integer)
    var
        ActiveSession: Record "Active Session";
    begin
        ActiveSession.Get(ServiceInstanceId(), SessionId());

        Rec.Init();
        Rec."Table ID" := ADLSETableID;
        Rec."Session ID" := SessionId();
        Rec."Session Unique ID" := ActiveSession."Session Unique ID";
        Rec."Company Name" := CompanyName();
        Rec.Insert();
    end;

    procedure Stop(ADLSETableID: Integer)
    begin
        Rec.Get(ADLSETableID, CompanyName());
        Rec.Delete();
    end;

    [Obsolete('Use the function CheckForNoActiveSessions instead', '1.2.0.0')]
    procedure CheckSessionsActive() AnyActive: Boolean
    begin
        AnyActive := IsAnySessionActive();
    end;

    procedure CheckForNoActiveSessions()
    begin
        if IsAnySessionActive() then
            Error(ExportDataInProgressErr);
    end;

    local procedure IsAnySessionActive() AnyActive: Boolean
    var
        InactiveSessionIDs: List of [Integer];
    begin
        if Rec.FindSet(false) then
            repeat
                if IsSessionActive() then
                    AnyActive := true
                else
                    InactiveSessionIDs.Add(Rec."Session ID");
            until Rec.Next() = 0;

        CleanupInactiveSessions(InactiveSessionIDs);
    end;

    local procedure CleanupInactiveSessions(InactiveSessionIDs: List of [Integer])
    var
        TheSessionID: Integer;
    begin
        foreach TheSessionID in InactiveSessionIDs do begin
            Rec.SetRange("Session ID", TheSessionID);
            Rec.DeleteAll();
        end;
    end;

    procedure IsAnySessionActiveForOtherExports(ADLSETableID: Integer): Boolean
    begin
        Rec.SetFilter("Table ID", '<>%1', ADLSETableID);
        if (not Rec.IsEmpty()) then
            exit(true);

        Rec.SetFilter("Company Name", '<>%1', CompanyName());
        exit(not Rec.IsEmpty());
    end;

    [TryFunction]
    procedure CancelAll(ADLSETableErrorText: Text[2048])
    var
        ADLSETable: Record "ADLSE Table";
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if Rec.FindSet(false) then
            repeat
                if IsSessionActive() then begin
                    Session.StopSession(Rec."Session ID", StrSubstNo(SessionTerminatedMsg, ADLSEUtil.GetTableCaption(Rec."Table ID")));

                    ADLSETable.Get(Rec."Table ID");
                    ADLSETable.State := "ADLSE State"::Error;
                    ADLSETable.LastError := ADLSETableErrorText;
                    ADLSETable.Modify();
                end;
            until Rec.Next() = 0;

        Rec.DeleteAll();
    end;

    [Obsolete('Converted to local procedure IsSessionActive', '1.2.0.0')]
    procedure IsLinkedSessionActive(): Boolean
    begin
        exit(IsSessionActive());
    end;

    local procedure IsSessionActive(): Boolean
    var
        ActiveSession: Record "Active Session";
    begin
        if ActiveSession.Get(ServiceInstanceId(), Rec."Session ID") then
            exit(ActiveSession."Session Unique ID" = Rec."Session Unique ID");
    end;

}