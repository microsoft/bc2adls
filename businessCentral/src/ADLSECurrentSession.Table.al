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
    begin

        Rec.Init();
        Rec."Table ID" := ADLSETableID;
        Rec."Session ID" := SessionId();
        Rec."Session Unique ID" := GetActiveSessionIDForSession(SessionId());
        Rec."Company Name" := CopyStr(CompanyName(), 1, 30);
        Rec.Insert();
    end;

    procedure Stop(ADLSETableID: Integer)
    begin
        Rec.Get(ADLSETableID, CompanyName());
        Rec.Delete();
    end;

    procedure CheckForNoActiveSessions()
    begin
        if AreAnySessionsActive() then
            Error(ExportDataInProgressErr);
    end;

    procedure AreAnySessionsActive() AnyActive: Boolean
    begin
        if Rec.FindSet(false) then
            repeat
                if IsSessionActive() then begin
                    AnyActive := true;
                    exit;
                end;
            until Rec.Next() = 0;
    end;

    procedure CleanupInactiveSessions()
    begin
        Rec.SetRange("Company Name", CompanyName());
        if Rec.FindSet(true) then
            if not IsSessionActive() then
                Rec.Delete();
    end;

    procedure CancelAll()
    var
        ADLSEUtil: Codeunit "ADLSE Util";
    begin
        if Rec.FindSet(false) then
            repeat
                if IsSessionActive() then
                    Session.StopSession(Rec."Session ID", StrSubstNo(SessionTerminatedMsg, ADLSEUtil.GetTableCaption(Rec."Table ID")));
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

    procedure GetActiveSessionIDForSession(SessId: Integer): Guid
    var
        ActiveSession: Record "Active Session";
    begin
        ActiveSession.Get(ServiceInstanceId(), SessId);
        exit(ActiveSession."Session Unique ID");
    end;
}