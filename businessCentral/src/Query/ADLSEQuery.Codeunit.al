// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82577 "ADLSE Query"
{
    /// <summary>
    /// This is the facade to generically query data in the data lake.
    /// <example>
    /// Here is an example of how to use this facade.
    /// <code>
    /// 
    /// procedure QuerySharedMetadataTableFromLake()
    /// var
    ///     ADLSEQuery: Codeunit "ADLSE Query";
    ///     RecordsFound: Integer;
    ///     EntryNo: Integer;
    ///     CustomerNo: Code[20];
    ///     DocumentType: Text;
    ///     Timestamp: BigInteger;
    ///     PostingDate: Date;
    ///     ModifiedDateTime: DateTime;
    /// begin
    ///     // initialize with the table name
    ///     ADLSEQuery.Init('custledgerentry_21'); 
    /// 
    ///     // optionally set the connection string
    ///     ADLSEQuery.SetServer('serverless sql endpoint, XXXX.sql.azuresynapse.net');
    ///     ADLSEQuery.SetDatabase('database name');
    /// 
    ///     // set filtering
    ///     ADLSEQuery.SetRange('DocumentType-5', 'Invoice');
    ///     ADLSEQuery.SetFilter('CustomerNo-3', '>=%1', '40000');
    ///     ADLSEQuery.SetFilter('PostingDate-4', '>%1', 20211023D);
    ///     ADLSEQuery.SetRange('$Company', 'CRONUS USA, Inc.');
    /// 
    ///     // set sequence of results
    ///     ADLSEQuery.SetOrderBy('PostingDate-4', false);
    ///     ADLSEQuery.SetOrderBy('EntryNo-1');
    /// 
    ///     // set fields to be fetched
    ///     ADLSEQuery.AddLoadField('EntryNo-1');
    ///     ADLSEQuery.AddLoadField('CustomerNo-3');
    ///     ADLSEQuery.AddLoadField('DocumentType-5');
    ///     ADLSEQuery.AddLoadField('PostingDate-4');
    ///     ADLSEQuery.AddLoadField('SystemModifiedAt-2000000003');
    ///     ADLSEQuery.AddLoadField('timestamp-0');
    /// 
    ///     // make the find set query
    ///     if ADLSEQuery.FindSet() then
    ///         // records found
    ///         repeat
    ///             EntryNo := ADLSEQuery.Field('EntryNo-1').AsInteger(); // get an integer value
    ///             CustomerNo := ADLSEQuery.Field('CustomerNo-3').AsCode(); // get a code value
    ///             DocumentType := ADLSEQuery.Field('DocumentType-5').AsText(); // get a text value
    ///             PostingDate := DT2Date(ADLSEQuery.Field('PostingDate-4').AsDateTime()); // get a date value
    ///             ModifiedDateTime := ADLSEQuery.Field('SystemModifiedAt-2000000003').AsDateTime(); // get a datetime value
    ///             Timestamp := ADLSEQuery.Field('timestamp-0').AsBigInteger(); // get a big integer value
    ///             RecordsFound += 1;
    ///         until not ADLSEQuery.Next(); // Next will return false when there are no more records in the result set
    ///     Message('Records found: %1.', RecordsFound);
    /// end;
    /// 
    /// </code>
    /// </example>
    /// </summary>
    /// <remarks>The <c>ADLSE Query</c> facade provides a way to query data on 
    /// the lake, for any shared metadata table.</remarks>
    Access = Public;

    var
        ADLSEQueryImpl: Codeunit "ADLSE Query Impl.";

    /// <summary>
    /// States the table that needs to be queried from the lake. 
    /// </summary>
    /// <remarks>This procedure initializes the underlying query object and 
    /// must be the first call to be made when using this facade.</remarks>
    /// <param name="TableName">The name of the table to be queried.</param>
    procedure Init(TableName: Text)
    begin
        ADLSEQueryImpl.Init(TableName);
    end;

    /// <summary>
    /// Sets the SQL endpoint to be used in the connection string to make 
    /// queries on the lake. If the SQL endpoint is not set, the Synapse 
    /// Serverless SQL Endpoint configured on the setup page is used.
    /// </summary>
    /// <param name="NewServer">The new SQL endpoint.</param>
    procedure SetServer(NewServer: Text)
    begin
        ADLSEQueryImpl.SetServer(NewServer);
    end;

    /// <summary>
    /// Sets the SQL database name to be used in the connection string to make 
    /// queries on the lake. If the SQL Database is not set, the SQL Database 
    /// Name configured on the setup page is used.
    /// </summary>
    /// <param name="NewDatabase">The new database name.</param>
    procedure SetDatabase(NewDatabase: Text)
    begin
        ADLSEQueryImpl.SetDatabase(NewDatabase);
    end;

    /// <summary>
    /// Sets a simple filter, as a single value, on a field. 
    /// </summary>
    /// <param name="FieldName">The name of the field to be filtered on.</param>
    /// <param name="ValueVariant">The value to which the field is to be 
    /// filtered. Convert option / enum values to their corresponding names 
    /// before passing them.</param>
    procedure SetRange(FieldName: Text; ValueVariant: Variant)
    begin
        ADLSEQueryImpl.SetRange(FieldName, ValueVariant);
    end;

    /// <summary>
    /// Sets a filter, based on a range of values, on a field. 
    /// </summary>
    /// <param name="FieldName">The name of the field to be filtered on.</param>
    /// <param name="FromValueVariant">The lower range value to which the field
    /// is to be filtered. Convert option / enum values to their corresponding 
    /// names before passing them.</param>
    /// <param name="ToValueVariant">The upper range value to which the field 
    /// is to be filtered. Convert option / enum values to their corresponding 
    /// names before passing them.</param>
    procedure SetRange(FieldName: Text; FromValueVariant: Variant; ToValueVariant: Variant)
    begin
        ADLSEQueryImpl.SetRange(FieldName, FromValueVariant, ToValueVariant);
    end;

    /// <summary>
    /// Sets a generic filter on a field. 
    /// </summary>
    /// <param name="FieldName">The name of the field to be filtered on.</param>
    /// <param name="FilterExpression">A text expression stating the type of 
    /// filter to be applied. The expressions supported are limited to those 
    /// stated in the enum "ADLSE Query Filter Operator".</param>
    /// <param name="ValueVariant">The value to which the field is to be 
    /// filtered. Convert option / enum values to their corresponding names 
    /// before passing them.</param>
    procedure SetFilter(FieldName: Text; FilterExpression: Text; ValueVariant: Variant)
    begin
        ADLSEQueryImpl.SetFilter(FieldName, FilterExpression, ValueVariant);
    end;

    /// <summary>
    /// Orders the result against the field specified. The sorting is based on 
    /// the first field that is passed, followed by the next in a repeated call
    /// of this procedure, and so on. The sorting will be in ascending order.
    /// </summary>
    /// <param name="FieldName">The name of the field that the result should be
    /// sorted against.</param>
    procedure SetOrderBy(FieldName: Text)
    begin
        ADLSEQueryImpl.SetOrderBy(FieldName);
    end;

    /// <summary>
    /// Orders the result against the field specified. The sorting is based on 
    /// the first field that is passed, followed by the next in a repeated call
    /// of this procedure, and so on. 
    /// </summary>
    /// <param name="FieldName">The name of the field that the result should be
    /// sorted against.</param>
    /// <param name="Ascending">An optional boolean to specify the sorting 
    /// order- true implies sorted ascending and false, otherwise.</param>
    procedure SetOrderBy(FieldName: Text; Ascending: Boolean)
    begin
        ADLSEQueryImpl.SetOrderBy(FieldName, Ascending);
    end;

    /// <summary>
    /// States the field to be included in the result set when making a 
    /// <c>FindSet</c> call. If no fields are set, the result 
    /// contains all fields on the entity in the lake. 
    /// </summary>
    /// <param name="FieldName">The name of the field that should be included 
    /// in the result set.</param>
    procedure AddLoadField(FieldName: Text)
    begin
        ADLSEQueryImpl.AddLoadField(FieldName);
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
        exit(ADLSEQueryImpl.FindSet());
    end;

    /// <summary>
    /// Moves the cursor to the next record in the result set that was 
    /// populated originally by calling <c>FindSet()</c>. 
    /// </summary>
    /// <returns>True, if the cursor could be moved to the next record; false 
    /// otherwise, say when the cursor is already on the last record.</returns>
    procedure Next(): Boolean
    begin
        exit(ADLSEQueryImpl.Next());
    end;

    /// <summary>
    /// The value of a field fetched from the record found as a result of the 
    /// <c>FindSet()</c> call.
    /// </summary>
    /// <param name="FieldName">The name of the field that the result should be 
    /// sorted against.</param>
    /// <returns>The value of the field as a <c>JsonValue</c> variable.
    /// </returns>
    procedure Field(FieldName: Text): JsonValue
    begin
        exit(ADLSEQueryImpl.Field(FieldName));
    end;

    /// <summary>
    /// Queries for records being present in the lake on a table with filters.
    /// set previously.
    /// </summary>
    /// <returns>True if no records exist on the lake; false otherwise.</returns>
    procedure IsEmpty(): Boolean
    begin
        exit(ADLSEQueryImpl.IsEmpty());
    end;

    /// <summary>
    /// Queries for the number of records records being present in the lake on
    /// a table with filters set previously.
    /// </summary>
    /// <returns>The number of records found.</returns>
    procedure Count(): Integer
    begin
        exit(ADLSEQueryImpl.Count());
    end;

}