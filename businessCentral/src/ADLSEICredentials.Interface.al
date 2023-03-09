// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
interface "ADLSE ICredentials"
{
    Access = Internal;

    procedure IsInitialized(): Boolean;
    procedure GetClientID(): Text;
    procedure GetClientSecret(): Text;
    procedure GetTenantID(): Text;
    procedure GetResource(): Text;
    procedure GetScope(): Text;
}