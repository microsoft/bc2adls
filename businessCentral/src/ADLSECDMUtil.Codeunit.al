// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82566 "ADLSE CDM Util" // Refer Common Data Model https://docs.microsoft.com/en-us/common-data-model/sdk/overview
{
    Access = Internal;

    var
        BlankArray: JsonArray;
        CompanyFieldNameLbl: Label '$Company';
        ExistingFieldCannotBeRemovedErr: Label 'The field %1 in the entity %2 is already present in the data lake and cannot be removed.', Comment = '%1: field name, %2: entity name';
        FieldDataTypeCannotBeChangedErr: Label 'The data type for the field %1 in the entity %2 cannot be changed.', Comment = '%1: field name, %2: entity name';
        RepresentsTableTxt: Label 'Represents the table %1', Comment = '%1: table caption';
        ManifestNameTxt: Label '%1-manifest', Comment = '%1: name of manifest';
        EntityPathTok: Label '%1.cdm.json/%1', Comment = '%1: Entity';
        UnequalAttributeCountErr: Label 'Unequal number of attributes';
        MismatchedValueInAttributeErr: Label 'The attribute value for %1 at index %2 is different. First: %3, Second: %4', Comment = '%1 = field, %2 = index, %3 = value of the first, %4 = value of the second';

    procedure CreateEntityContent(TableID: Integer; FieldIdList: List of [Integer]) Content: JsonObject
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        Definition: JsonObject;
        Definitions: JsonArray;
        Import: JsonObject;
        Imports: JsonArray;
        EntityName: Text;
    begin
        Content.Add('jsonSchemaSemanticVersion', '1.0.0');
        Import.Add('corpusPath', 'cdm:/foundations.cdm.json');
        Imports.Add(Import);
        Content.Add('imports', Imports);
        EntityName := ADLSEUtil.GetDataLakeCompliantTableName(TableID);
        Definition.Add('entityName', EntityName);
        Definition.Add('exhibitsTraits', BlankArray);
        Definition.Add('displayName', ADLSEUtil.GetTableName(TableID));
        Definition.Add('description', StrSubstNo(RepresentsTableTxt, ADLSEUtil.GetTableName(TableID)));
        Definition.Add('hasAttributes', CreateAttributes(TableID, FieldIdList));
        Definitions.Add(Definition);
        Content.Add('definitions', Definitions);
    end;

    procedure UpdateDefaultManifestContent(ExistingContent: JsonObject; TableID: Integer; Folder: Text; ADLSECdmFormat: Enum "ADLSE CDM Format") Content: JsonObject
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        Entities: JsonArray;
        EntityToken: JsonToken;
        Entity: JsonObject;
        DataPartitionPattern: JsonObject;
        ExhibitsTrait: JsonObject;
        DataPartitionPatterns: JsonArray;
        ExhibitsTraits: JsonArray;
        ExhibitsTraitArgs: JsonArray;
        EntityName: Text;
    begin
        Content.Add('jsonSchemaSemanticVersion', '1.0.0');
        Content.Add('imports', BlankArray);
        Content.Add('manifestName', StrSubstNo(ManifestNameTxt, Folder));
        Content.Add('explanation', 'Data exported from the Business Central to the Azure Data Lake Storage');

        EntityName := ADLSEUtil.GetDataLakeCompliantTableName(TableID);
        if ExistingContent.Contains('entities') then begin
            ExistingContent.Get('entities', EntityToken);
            Entities := EntityToken.Clone().AsArray();
        end;
        if not ADLSEUtil.JsonTokenExistsWithValueInArray(Entities, 'entityName', EntityName) then begin
            Entity.Add('type', 'LocalEntity');
            Entity.Add('entityName', EntityName);
            Entity.Add('entityPath', StrSubstNo(EntityPathTok, EntityName));

            DataPartitionPattern.Add('name', EntityName);
            DataPartitionPattern.Add('rootLocation', Folder + '/' + EntityName + '/');
            case ADLSECdmFormat of
                "ADLSE CDM Format"::Csv:
                    begin
                        DataPartitionPattern.Add('globPattern', '*.csv');
                        ExhibitsTrait.Add('traitReference', 'is.partition.format.CSV');
                        AddNameValue(ExhibitsTraitArgs, 'columnHeaders', 'true');
                        AddNameValue(ExhibitsTraitArgs, 'delimiter', ',');
                        AddNameValue(ExhibitsTraitArgs, 'escape', '\');
                        AddNameValue(ExhibitsTraitArgs, 'encoding', 'utf-8');
                        AddNameValue(ExhibitsTraitArgs, 'quote', '"');
                        ExhibitsTrait.Add('arguments', ExhibitsTraitArgs);
                        ExhibitsTraits.Add(ExhibitsTrait);
                        DataPartitionPattern.Add('exhibitsTraits', ExhibitsTraits);
                    end;
                ADLSECdmFormat::Parquet:
                    begin
                        DataPartitionPattern.Add('globPattern', '*.parquet');
                        ExhibitsTrait.Add('traitReference', 'is.partition.format.parquet');
                        ExhibitsTraits.Add(ExhibitsTrait);
                        DataPartitionPattern.Add('exhibitsTraits', ExhibitsTraits);
                    end;
            end;

            DataPartitionPatterns.Add(DataPartitionPattern);
            Entity.Add('dataPartitionPatterns', DataPartitionPatterns);

            Entities.Add(Entity);
        end;

        Content.Add('entities', Entities);
        Content.Add('relationships', BlankArray);
    end;

    local procedure AddNameValue(var Token: JsonArray; Name: Text; Value: Text)
    var
        NameValue: JsonObject;
    begin
        NameValue.Add('name', Name);
        NameValue.Add('value', Value);
        Token.Add(NameValue);
    end;

    local procedure CreateAttributes(TableID: Integer; FieldIdList: List of [Integer]) Result: JsonArray;
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        RecRef: RecordRef;
        FldRef: FieldRef;
        FieldId: Integer;
        DataFormat: Text;
        AppliedTraits: JsonArray;
    begin
        RecRef.Open(TableID);
        foreach FieldId in FieldIdList do begin
            FldRef := RecRef.Field(FieldId);
            ADLSEUtil.GetCDMAttributeDetails(FldRef.Type, DataFormat, AppliedTraits);
            Result.Add(
                CreateAttributeJson(
                    ADLSEUtil.GetDataLakeCompliantFieldName(FldRef.Name, FldRef.Number),
                    DataFormat,
                    FldRef.Name,
                    AppliedTraits));
        end;
        if ADLSEUtil.IsTablePerCompany(TableID) then begin
            ADLSEUtil.GetCDMAttributeDetails(FieldType::Text, DataFormat, AppliedTraits);
            Result.Add(
                CreateAttributeJson(GetCompanyFieldName(), DataFormat, GetCompanyFieldName(), AppliedTraits));
        end;
    end;

    procedure GetCompanyFieldName(): Text
    begin
        exit(CompanyFieldNameLbl);
    end;

    local procedure CreateAttributeJson(Name: Text; DataFormat: Text; DisplayName: Text; AppliedTraits: JsonArray) Attribute: JsonObject
    begin
        Attribute.Add('name', Name);
        Attribute.Add('dataFormat', DataFormat);
        Attribute.Add('appliedTraits', AppliedTraits);
        Attribute.Add('displayName', DisplayName);
    end;

    procedure CheckChangeInEntities(EntityContentOld: JsonObject; EntityContentNew: JsonObject; EntityName: Text)
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        OldAttributes: JsonArray;
        OldAttribute: JsonToken;
        NewAttributes: JsonArray;
        NewAttribute: JsonToken;
        TempToken: JsonToken;
        OldAttributeFound: Boolean;
        OldAttributeName: Text;
        OldDataType: Text;
        NewDataType: Text;
    begin
        // fields cannot be removed or their data type changed.
        if EntityContentOld.SelectToken('definitions[0].hasAttributes', TempToken) then
            OldAttributes := TempToken.AsArray();

        EntityContentNew.SelectToken('definitions[0].hasAttributes', TempToken);
        NewAttributes := TempToken.AsArray();

        foreach OldAttribute in OldAttributes do begin
            OldAttributeFound := false;
            OldAttributeName := ADLSEUtil.GetTextValueForKeyInJson(OldAttribute.AsObject(), 'name');

            foreach NewAttribute in NewAttributes do
                if ADLSEUtil.GetTextValueForKeyInJson(NewAttribute.AsObject(), 'name') = OldAttributeName then begin
                    OldAttributeFound := true;
                    OldDataType := ADLSEUtil.GetTextValueForKeyInJson(OldAttribute.AsObject(), 'dataFormat');
                    NewDataType := ADLSEUtil.GetTextValueForKeyInJson(NewAttribute.AsObject(), 'dataFormat');
                    if OldDataType <> NewDataType then
                        Error(FieldDataTypeCannotBeChangedErr, OldAttributeName, EntityName);
                    break;
                end;

            if not OldAttributeFound then
                Error(ExistingFieldCannotBeRemovedErr, OldAttributeName, EntityName);
        end;
    end;

    [TryFunction]
    procedure CompareEntityJsons(Json1: JsonObject; Json2: JsonObject)
    var
        Token: JsonToken;
        Attributes1: JsonArray;
        Attributes2: JsonArray;
        Attribute1: JsonToken;
        Attribute2: JsonToken;
        Counter: Integer;
    begin
        ClearLastError();

        Json1.SelectToken('definitions[0].hasAttributes', Token);
        Attributes1 := Token.AsArray();

        Json2.SelectToken('definitions[0].hasAttributes', Token);
        Attributes2 := Token.AsArray();

        if Attributes1.Count() <> Attributes2.Count() then
            Error(UnequalAttributeCountErr);

        for Counter := 0 to Attributes1.Count() - 1 do begin
            Attributes1.Get(Counter, Attribute1);
            Attributes2.Get(Counter, Attribute2);

            CompareAttributeField(Attribute1, Attribute2, 'name', Counter);
            CompareAttributeField(Attribute1, Attribute2, 'dataFormat', Counter);
            CompareAttributeField(Attribute1, Attribute2, 'displayName', Counter);
        end;
    end;

    local procedure CompareAttributeField(Attribute1: JsonToken; Attribute2: JsonToken; FieldName: Text; Index: Integer)
    var
        ADLSEUtil: Codeunit "ADLSE Util";
        Value1: Text;
        Value2: Text;
    begin
        Value1 := ADLSEUtil.GetTextValueForKeyInJson(Attribute1.AsObject(), FieldName);
        Value2 := ADLSEUtil.GetTextValueForKeyInJson(Attribute2.AsObject(), FieldName);
        if (Value1 <> Value2) then
            Error(MismatchedValueInAttributeErr, FieldName, Index, Value1, Value2);
    end;
}