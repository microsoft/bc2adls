// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82576 "ADLSE Query Table Impl."
{
    Access = Internal;

    var
        ADLSEQuery: Codeunit "ADLSE Query";
        ADLSEUtil: Codeunit "ADLSE Util";
        SystemFieldsList: List of [Integer];
        TableNumber: Integer;
        TableNotConfiguredErr: Label 'The table %1 has not been configured on the setup page.', Comment = '%1 is the table caption';
        FieldNotConfiguredErr: Label 'The field with Id %1 on table %2 has not been configured on the setup page.', Comment = '%1 is the field ID and %2 is the table caption';
        FieldNotEnabledErr: Label 'The field %1 in table %2 is not enabled in the configuration', Comment = '%1 is the field caption, %2 is the table caption';

    procedure Init(TableID: Integer)
    var
        ADLSETable: Record "ADLSE Table";
        ADLSECDMUtil: Codeunit "ADLSE CDM Util";
    begin
        if not ADLSETable.Get(TableID) then
            Error(TableNotConfiguredErr, ADLSEUtil.GetTableCaption(TableID));
        ADLSEQuery.Init(ADLSEUtil.GetDataLakeCompliantTableName(TableID).ToLower().Replace('-', '_'));
        TableNumber := TableID;

        if ADLSEUtil.IsTablePerCompany(TableNumber) then
            ADLSEQuery.SetRange(ADLSECDMUtil.GetCompanyFieldName(), CompanyName());

        Clear(SystemFieldsList);
        ADLSEUtil.AddSystemFields(SystemFieldsList);
    end;

    procedure SetRange(FieldID: Integer; ValueVariant: Variant)
    begin
        CheckField(FieldID);
        ADLSEQuery.SetRange(ADLSEUtil.GetDataLakeCompliantFieldName(TableNumber, FieldID), CurateVariant(FieldId, ValueVariant));
    end;

    procedure SetRange(FieldID: Integer; FromValueVariant: Variant; ToValueVariant: Variant)
    begin
        CheckField(FieldID);
        ADLSEQuery.SetRange(ADLSEUtil.GetDataLakeCompliantFieldName(TableNumber, FieldID), CurateVariant(FieldId, FromValueVariant), CurateVariant(FieldId, ToValueVariant));
    end;

    procedure SetFilter(FieldID: Integer; FilterExpression: Text; ValueVariant: Variant)
    begin
        CheckField(FieldID);
        ADLSEQuery.SetFilter(ADLSEUtil.GetDataLakeCompliantFieldName(TableNumber, FieldID), FilterExpression, CurateVariant(FieldId, ValueVariant));
    end;

    local procedure CurateVariant(FieldID: Integer; ValueVariant: Variant): Variant
    var
        FieldRef: FieldRef;
    begin
        FieldRef := GetFieldRef(FieldID);
        if FieldRef.Type = FieldType::Option then
            exit(FieldRef.GetEnumValueNameFromOrdinalValue(ValueVariant));
        exit(ValueVariant);
    end;

    procedure SetOrderBy(FieldID: Integer)
    begin
        CheckField(FieldID);
        ADLSEQuery.SetOrderBy(ADLSEUtil.GetDataLakeCompliantFieldName(TableNumber, FieldID));
    end;

    procedure SetOrderBy(FieldID: Integer; Ascending: Boolean)
    begin
        CheckField(FieldID);
        ADLSEQuery.SetOrderBy(ADLSEUtil.GetDataLakeCompliantFieldName(TableNumber, FieldID), Ascending);
    end;

    local procedure CheckField(FieldID: Integer)
    var
        ADLSEField: Record "ADLSE Field";
    begin
        if SystemFieldsList.Contains(FieldID) then
            exit;
        if not ADLSEField.Get(TableNumber, FieldID) then
            Error(FieldNotConfiguredErr, FieldID, ADLSEUtil.GetTableCaption(TableNumber));
        if not ADLSEField.Enabled then
            Error(FieldNotEnabledErr, ADLSEField.FieldCaption, ADLSEUtil.GetTableCaption(TableNumber));
    end;

    procedure FindSet(): Boolean
    var
        ADLSEField: Record "ADLSE Field";
        SystemFieldID: Integer;
    begin
        ADLSEField.SetRange("Table ID", TableNumber);
        ADLSEField.SetRange(Enabled, true);
        if ADLSEField.FindSet() then
            repeat
                ADLSEQuery.AddLoadField(GetFieldNameOnTheLake(ADLSEField."Field ID"));
            until ADLSEField.Next() = 0;
        // also add System Audit fields
        foreach SystemFieldID in SystemFieldsList do
            ADLSEQuery.AddLoadField(GetFieldNameOnTheLake(SystemFieldID));

        exit(ADLSEQuery.FindSet());
    end;

    procedure IsEmpty(): Boolean
    begin
        exit(ADLSEQuery.IsEmpty());
    end;

    procedure Count(): Integer
    begin
        exit(ADLSEQuery.Count());
    end;

    procedure Next(): Boolean
    begin
        exit(ADLSEQuery.Next());
    end;

    procedure Field(FieldID: Integer) VariantValue: Variant
    var
        Value: JsonValue;
    begin
        CheckField(FieldID);
        Value := ADLSEQuery.Field(GetFieldNameOnTheLake(FieldID));

        VariantValue := ADLSEUtil.ConvertJsonToVariant(GetFieldRef(FieldID), Value);
    end;

    local procedure GetFieldRef(FieldID: Integer): FieldRef
    var
        RecordRef: RecordRef;
    begin
        RecordRef.Open(TableNumber);
        exit(RecordRef.Field(FieldID));
    end;

    local procedure GetFieldNameOnTheLake(FieldID: Integer): Text
    var
        FieldRef: FieldRef;
    begin
        FieldRef := GetFieldRef(FieldID);
        exit(ADLSEUtil.GetDataLakeCompliantFieldName(FieldRef.Name, FieldID));
    end;
}