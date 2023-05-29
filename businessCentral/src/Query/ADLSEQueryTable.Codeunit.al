// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82578 "ADLSE Query Table"
{
    /// <summary>
    /// This is the facade to query data in the data lake for tables that have 
    /// already been configured in the main setup page. The data will be 
    /// filtered to the current company, if the table is per company. 
    /// <example>
    /// Here is an example of how to use this facade.
    /// <code>
    /// 
    /// procedure QueryCustomerLedgerEntryFromLake()
    /// var
    ///     CustLedgerEntry: Record "Cust. Ledger Entry";
    ///     GLRegister: Record "G/L Register";
    ///     ADLSEQueryTable: Codeunit "ADLSE Query Table";
    ///     EntryNo: Integer;
    ///     CustomerNo: Code[20];
    ///     DocumentType: Enum "Gen. Journal Document Type";
    ///     Timestamp: BigInteger;
    ///     PostingDate: Date;
    ///     ModifiedDateTime: DateTime;
    ///     GLRegisterNo: Integer;
    ///     CreationTime: Time;
    ///     RecordsFound: Integer;
    /// begin
    ///     // first set the table to be queried
    ///     ADLSEQueryTable.Open(Database::"Cust. Ledger Entry");
    /// 
    ///     // set the filters to be applied
    ///     ADLSEQueryTable.SetRange(CustLedgerEntry.FieldNo("Document Type"), "Gen. Journal Document Type"::Invoice);
    ///     ADLSEQueryTable.SetFilter(CustLedgerEntry.FieldNo("Customer No."), '>=%1', '40000');
    ///     ADLSEQueryTable.SetFilter(CustLedgerEntry.FieldNo("Posting Date"), '>%1', 20211023D);
    ///
    ///     // set the result to be sorted first by descending order of Posting Date and then ascending order of Entry No. 
    ///     ADLSEQueryTable.SetOrderBy(CustLedgerEntry.FieldNo("Posting Date"), false);
    ///     ADLSEQueryTable.SetOrderBy(CustLedgerEntry.FieldNo("Entry No."));
    /// 
    ///     // make the find set query
    ///     if ADLSEQueryTable.FindSet() then
    ///         // records found
    ///         repeat
    ///             EntryNo := ADLSEQueryTable.Field(CustLedgerEntry.FieldNo("Entry No.")); // get an integer value
    ///             CustomerNo := ADLSEQueryTable.Field(CustLedgerEntry.FieldNo("Customer No.")); // get a code value
    ///             DocumentType := Enum::"Gen. Journal Document Type".FromInteger(
    ///                 ADLSEQueryTable.Field(CustLedgerEntry.FieldNo("Document Type"))); // get an enum value
    ///             PostingDate := ADLSEQueryTable.Field(CustLedgerEntry.FieldNo("Posting Date")); // get a date value
    ///             ModifiedDateTime := ADLSEQueryTable.Field(CustLedgerEntry.FieldNo(SystemModifiedAt)); // get a datetime value
    ///             Timestamp := ADLSEQueryTable.Field(0); // get a big integer
    ///             RecordsFound += 1;
    ///         until not ADLSEQueryTable.Next(); // Next will return false when there are no more records in the result set
    ///     Message('Records found: %1.', RecordsFound);
    /// end;
    /// 
    /// </code>
    /// </example>
    /// </summary>
    /// <remarks>The <c>ADLSE Query</c> facade provides 
    /// a more general way to query data on the lake, especially when the 
    /// entity does not correspond to any table in Dynamics 365 Business 
    /// Central. All calls to the lake from this facade actually go through an 
    /// instance of the <c>ADLSE Query</c> facade.
    /// </remarks>

    Access = Public;

    var
        ADLSEQueryTableImpl: Codeunit "ADLSE Query Table Impl.";

    /// <summary>
    /// States the table that needs to be queried from the lake. This table 
    /// must be added to the list of tables in the setup page. 
    /// </summary>
    /// <remarks>This procedure initializes the underlying query object and 
    /// must be the first call to be made when using this facade.</remarks>
    /// <param name="TableID">The integer identifier for the table to be 
    /// queried.</param>
    procedure Open(TableID: Integer)
    begin
        ADLSEQueryTableImpl.Init(TableID);
    end;

    /// <summary>
    /// Sets a simple filter, as a single value, on a field. The field must be 
    /// present in the table and must also be enabled in the setup. 
    /// </summary>
    /// <param name="FieldID">The integer identifier for the field to be 
    /// filtered on.</param>
    /// <param name="ValueVariant">The value to which the field is to be 
    /// filtered.</param>
    procedure SetRange(FieldID: Integer; ValueVariant: Variant)
    begin
        ADLSEQueryTableImpl.SetRange(FieldID, ValueVariant);
    end;

    /// <summary>
    /// Sets a filter, based on a range of values, on a field. The field must 
    /// be present in the table and must also be enabled in the setup.
    /// </summary>
    /// <param name="FieldID">The integer identifier for the field to be 
    /// filtered on.</param>
    /// <param name="FromValueVariant">The lower range value to which the field
    /// is to be filtered.</param>
    /// <param name="ToValueVariant">The upper range value to which the field 
    /// is to be filtered.</param>
    procedure SetRange(FieldID: Integer; FromValueVariant: Variant; ToValueVariant: Variant)
    begin
        ADLSEQueryTableImpl.SetRange(FieldID, FromValueVariant, ToValueVariant);
    end;

    /// <summary>
    /// Sets a generic filter on a field. 
    /// </summary>
    /// <param name="FieldID">The integer identifier for the field to be 
    /// filtered on.</param>
    /// <param name="FilterExpression">A text expression stating the type of 
    /// filter to be applied. The expressions supported are limited to those 
    /// stated in the enum "ADLSE Query Filter Operator".</param>
    /// <param name="ValueVariant">The value to which the field is to be 
    /// filtered.</param>
    procedure SetFilter(FieldID: Integer; FilterExpression: Text; ValueVariant: Variant)
    begin
        ADLSEQueryTableImpl.SetFilter(FieldID, FilterExpression, ValueVariant);
    end;

    /// <summary>
    /// Orders the result against the field specified. The sorting is based on 
    /// the first field that is passed, followed by the next in a repeated call
    /// of this procedure, and so on. 
    /// </summary>
    /// <param name="FieldID">The integer identifier of the field that the 
    /// result should be sorted against.</param>
    procedure SetOrderBy(FieldID: Integer)
    begin
        ADLSEQueryTableImpl.SetOrderBy(FieldID);
    end;

    /// <summary>
    /// Orders the result against the field specified. The sorting is based on 
    /// the first field that is passed, followed by the next in a repeated call
    ///  to this procedure, and so on. 
    /// </summary>
    /// <param name="FieldID">The integer identifier of the field that the 
    /// result should be sorted against.</param>
    /// <param name="Ascending">An optional boolean to specify the sorting 
    /// order- true implies sorted ascending and false, otherwise.</param>
    procedure SetOrderBy(FieldID: Integer; Ascending: Boolean)
    begin
        ADLSEQueryTableImpl.SetOrderBy(FieldID, Ascending);
    end;

    /// <summary>
    /// Makes a call to fetch the records based on the filters and sorting
    /// specified. The result points to the first record, if found. The fields 
    /// values can be requested by calling <c>Field()</c>. 
    /// Subsequent records can be pointed to by calling 
    /// <c>Next()</c>.
    /// </summary>
    /// <returns>True, if there are any records found; false otherwise.</returns>
    procedure FindSet(): Boolean
    begin
        exit(ADLSEQueryTableImpl.FindSet());
    end;

    /// <summary>
    /// Moves the cursor to the next record in the result set that was 
    /// populated originally by calling <c>FindSet()</c>. 
    /// </summary>
    /// <returns>True, if the cursor could be moved to the next record; false 
    /// otherwise, say when the cursor is already on the last record.</returns>
    procedure Next(): Boolean
    begin
        exit(ADLSEQueryTableImpl.Next());
    end;

    /// <summary>
    /// The value of a field fetched from the record found as a result of the 
    /// <c>FindSet()</c> call.
    /// </summary>
    /// <param name="FieldID">The integer identifier of the field that the 
    /// result should be sorted against.</param>
    /// <returns>The value of the field. In case of Option/ Enum type fields, 
    /// this returns the ordinal integer value which may need to be converted 
    /// to the respective enum.</returns>
    procedure Field(FieldID: Integer): Variant
    begin
        exit(ADLSEQueryTableImpl.Field(FieldID));
    end;

    /// <summary>
    /// Queries for records being present in the lake on a table with filters.
    /// set previously.
    /// </summary>
    /// <returns>True if no records exist on the lake; false otherwise.</returns>
    procedure IsEmpty(): Boolean
    begin
        exit(ADLSEQueryTableImpl.IsEmpty());
    end;

    /// <summary>
    /// Queries for the number of records records being present in the lake on
    /// a table with filters set previously.
    /// </summary>
    /// <returns>The number of records found.</returns>
    procedure Count(): Integer
    begin
        exit(ADLSEQueryTableImpl.Count());
    end;

}