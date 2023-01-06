// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82571 "ADLSE Installer"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        AddAllowedTables();
    end;

    procedure AddAllowedTables()
    var
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
        ADLSERun: Record "ADLSE Run";
    begin
        RetenPolAllowedTables.AddAllowedTable(Database::"ADLSE Run", ADLSERun.FieldNo(SystemModifiedAt));
    end;
}