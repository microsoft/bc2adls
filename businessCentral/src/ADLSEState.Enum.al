// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
enum 82560 "ADLSE State"
{
    Access = Internal;
    Extensible = false;
    ObsoleteState = Pending;
    ObsoleteReason = 'Use "ADLSE Run State" instead';
    ObsoleteTag = '1.2.0.0';

    value(0; Ready)
    {
        Caption = 'Ready';
    }

    value(1; Exporting)
    {
        Caption = 'Exporting';
    }

    value(2; Error)
    {
        Caption = 'Error';
    }

    value(3; OnHold)
    {
        Caption = 'On hold';
    }
}