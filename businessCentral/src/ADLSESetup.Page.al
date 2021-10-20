// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82560 "ADLSE Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "ADLSE Setup";
    InsertAllowed = false;
    DeleteAllowed = false;
    Caption = 'Export to Azure Data Lake Storage';

    layout
    {
        area(Content)
        {
            group(Setup)
            {
                Caption = 'Setup';
                group(Account)
                {
                    Caption = 'Account';
                    field(Container; Rec.Container)
                    {
                        ApplicationArea = All;
                        Tooltip = 'Specifies the name of the container where the data is going to be uploaded. Please refer to constraints on container names at https://docs.microsoft.com/en-us/rest/api/storageservices/naming-and-referencing-containers--blobs--and-metadata.';
                    }
                    field("Tenant ID"; StorageTenantID)
                    {
                        ApplicationArea = All;
                        Caption = 'Tenant ID';
                        Tooltip = 'Specifies the tenant ID which holds the app registration as well as the storage account. Note that they have to be on the same tenant.';

                        trigger OnValidate()
                        begin
                            ADLSECredentials.SetTenantID(StorageTenantID);
                        end;
                    }
                    field(AccountName; StorageAccount)
                    {
                        ApplicationArea = All;
                        Caption = 'Account name';
                        Tooltip = 'Specifies the name of the storage account.';

                        trigger OnValidate()
                        begin
                            ADLSECredentials.SetStorageAccount(StorageAccount);
                        end;
                    }
                }
                group(Access)
                {
                    Caption = 'App registration';
                    field("Client ID"; ClientID)
                    {
                        ApplicationArea = All;
                        ExtendedDatatype = Masked;
                        Tooltip = 'Specifies the application client ID for the Azure App Registration that accesses the storage account.';

                        trigger OnValidate()
                        begin
                            ADLSECredentials.SetClientID(ClientID);
                        end;
                    }
                    field("Client Secret"; ClientSecret)
                    {
                        ApplicationArea = All;
                        ExtendedDatatype = Masked;
                        Tooltip = 'Specifies the client secret for the Azure App Registration that accesses the storage account.';

                        trigger OnValidate()
                        begin
                            ADLSECredentials.SetClientSecret(ClientSecret);
                        end;
                    }
                }
                group(Execution)
                {
                    Caption = 'Execution';
                    field(MaxPayloadSize; Rec.MaxPayloadSizeMiB)
                    {
                        ApplicationArea = All;
                        Tooltip = 'Specifies the maximum size of the upload for each block of data in MiBs. A large value will reduce the number of iterations to upload the data but may interfear with the performance of other processes running on this environment.';
                    }

                    field("Emit telemetry"; Rec."Emit telemetry")
                    {
                        ApplicationArea = All;
                        Tooltip = 'Specifies if operational telemetry will be emitted to this extension publisher''s telemetry pipeline. You will have to configure a telemetry account for this extension first.';
                    }
                }
            }
            part(Tables; "ADLSE Setup Tables")
            {
                ApplicationArea = All;
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExportNow)
            {
                ApplicationArea = All;
                Caption = 'Export';
                Tooltip = 'Starts the export process by spawning different sessions for each table.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = Start;
                Enabled = not ExportInProgress;

                trigger OnAction()
                var
                    ADLSEExecution: Codeunit "ADLSE Execution";
                begin
                    ADLSEExecution.StartExport();
                    CurrPage.Update();
                end;
            }

            action(StopExport)
            {
                ApplicationArea = All;
                Caption = 'Stop export';
                Tooltip = 'Tries to stop all threads that are exporting data.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = Stop;
                // Enabled = ExportInProgress;

                trigger OnAction()
                var
                    ADLSEExecution: Codeunit "ADLSE Execution";
                begin
                    ADLSEExecution.StopExport();
                    CurrPage.Update();
                end;
            }

            action(Schedule)
            {
                ApplicationArea = All;
                Caption = 'Schedule export';
                Tooltip = 'Schedules the export process as a job queue entry.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = Timesheet;

                trigger OnAction()
                begin
                    Error('Not implemented');
                end;
            }

            action(ClearDeletedRecordsList)
            {
                ApplicationArea = All;
                Caption = 'Clear tracked deleted records';
                Tooltip = 'Removes the entries in the deleted record list that have already been exported. This may have to be done periodically to free up storage space.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = ClearLog;
                Enabled = TrackedDeletedRecordsExist;

                trigger OnAction()
                var
                    ADLSEExecution: Codeunit "ADLSE Execution";
                begin
                    ADLSEExecution.ClearTrackedDeletedRecords();
                    CurrPage.Update();
                end;
            }
        }
    }

    trigger OnInit()
    var
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
        ADLSESetup: Record "ADLSE Setup";
        ADLSEExecute: Codeunit "ADLSE Execute";
    begin
        if not ADLSESetup.Get(0) then
            ADLSESetup.Insert();
        ExportInProgress := ADLSESetup.Running;

        ADLSECredentials.Init();
        StorageTenantID := ADLSECredentials.GetTenantID();
        StorageAccount := ADLSECredentials.GetStorageAccount();
        ClientID := ADLSECredentials.GetClientID();
        ClientSecret := ADLSECredentials.GetClientSecret();

        TrackedDeletedRecordsExist := not ADLSEDeletedRecord.IsEmpty();
    end;

    var
        TrackedDeletedRecordsExist: Boolean;
        ExportInProgress: Boolean;
        [NonDebuggable]
        StorageTenantID: Text;
        [NonDebuggable]
        StorageAccount: Text;
        [NonDebuggable]
        ClientID: Text;
        [NonDebuggable]
        ClientSecret: Text;
        ADLSECredentials: Codeunit "ADLSE Credentials";
}