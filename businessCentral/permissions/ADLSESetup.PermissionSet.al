// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
permissionset 82560 "ADLSE - Setup"
{
    /// <summary>
    /// The permission set to be used when administering the Azure Data Lake Storage export tool.
    /// </summary>
    Access = Public;
    Assignable = true;
    Caption = 'Azure Data Lake Storage - Setup';

    Permissions = tabledata "ADLSE Setup" = rimd,
                  tabledata "ADLSE Table" = rimd,
                  tabledata "ADLSE Field" = rimd,
                  tabledata "ADLSE Deleted Record" = rd,
                  tabledata "ADLSE Current Session" = r,
                  tabledata "ADLSE Table Last Timestamp" = rid;
}