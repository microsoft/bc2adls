// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
codeunit 82567 ADLSE
{
    /// <summary>
    /// This is the main facade of Azure Data Lake Storage Export (ADLSE).
    /// </summary>

    Access = Public;

    /// <summary>
    /// Registers the deletion of a persisted record, so that its data can be 
    /// removed from the data lake on the next export run.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The recommended way to call this function is to include the following 
    /// event subscriber into a custom extension,
    /// <code>
    /// [EventSubscriber(ObjectType::Table, Database::&lt;table-name&gt;, 'OnAfterDeleteEvent', '', false, false)]
    /// local procedure EnsureRecordIsDeletedFromDataLake(Rec: Record &lt;table-name&gt;; RunTrigger: Boolean)
    /// var
    ///     AzureDataLakeStorageExport: Codeunit "Azure Data Lake Storage Export";
    ///     EntryNo : Integer;
    /// begin
    ///     EntryNo := NextEntryNo;
    ///     NextEntryNo := AzureDataLakeStorageExport.DeletingRecord(Rec, EntryNo);
    /// end;
    /// </code>
    /// where <c>&lt;table-name&gt;</c> should be replaced by the actual table 
    /// being deleted. The <c>NextEntryNo</c> is suggested to be a global 
    /// variable to be re-used as the entry number for subsequent calls to 
    /// avoid making a SQL call to find the record with the last entry number.
    /// </para>
    /// Tables whose records are never deleted through the normal business 
    /// process (such as ledger entries or log tables) but may be deleted by 
    /// custom functionality to free up storage (such as retention mechanisms 
    /// or custom archival routines) must avoid calling this function, as it 
    /// would force removal of such data from the data lake as well.
    /// </remarks>
    /// <param name="RecordVariant">
    /// The record or the record ref variable that is being deleted.
    /// </param>
    /// <param name="EntryNo">
    /// The entry number that will be used to track the deletion of this 
    /// record. A value of 0 may be passed in the first call to this 
    /// procedure.
    /// </param>
    /// <returns>
    /// The entry number that should be used the next time when 
    /// calling this procedure.
    /// </returns>
    procedure DeletedRecord(RecordVariant: Variant; EntryNo: Integer) NextEntryNo: Integer
    var
        ADLSEDeletedRecord: Record "ADLSE Deleted Record";
    begin
        NextEntryNo := ADLSEDeletedRecord.DeletedRecord(RecordVariant, EntryNo);
    end;

    /// <summary>
    /// This is the event which represents a successful export of a batch of 
    /// records for a single table to the data lake.
    /// </summary>
    /// <param name="TableID">
    /// The table number whose data was exported.
    /// </param>
    /// <param name="LastTimeStampExported">
    /// The value for the TimeStamp field for the last record that was synced.
    /// </param>
    [IntegrationEvent(false, false)]
    internal procedure OnTableExported(TableID: Integer; LastTimeStampExported: BigInteger)
    begin
    end;
}