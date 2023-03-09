// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82564 "ADLSE Util"
{
    Access = Internal;

    var
        AlphabetsLowerTxt: Label 'abcdefghijklmnopqrstuvwxyz';
        AlphabetsUpperTxt: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        NumeralsTxt: Label '1234567890';
        FieldTypeNotSupportedErr: Label 'The field %1 of type %2 is not supported.', Comment = '%1 = field name, %2 = field type';
        TypeOfFieldNotSupportedErr: Label 'The type of field %1 is not supported.', Comment = '%1 = field name';
        ConcatNameIdTok: Label '%1-%2', Comment = '%1: Name, %2: ID';
        DateTimeExpandedFormatTok: Label '%1, %2 %3 %4 %5:%6:%7 GMT', Comment = '%1: weekday, %2: day, %3: month, %4: year, %5: hour, %6: minute, %7: second';
        QuotedTextTok: Label '"%1"', Comment = '%1: text to be double- quoted';
        CommaPrefixedTok: Label ',%1', Comment = '%1: text to be prefixed';
        CommaSuffixedTok: Label '%1, ', Comment = '%1: text to be suffixed';
        WholeSecondsTok: Label ':%1Z', Comment = '%1: seconds';
        FractionSecondsTok: Label ':%1.%2Z', Comment = '%1: seconds, %2: milliseconds';
        UnmatchedEnumNameErr: Label 'No enum or option match in the field %1 found for the text %2.', Comment = '%1 is the field name, %2 is the text value for enum that failed parsing.';

    procedure ToText(GuidValue: Guid): Text
    begin
        exit(Format(GuidValue).TrimStart('{').TrimEnd('}'));
    end;

    procedure Concatenate(List: List of [Text]) Result: Text
    var
        Item: Text;
    begin
        foreach Item in List do
            Result += StrSubstNo(CommaSuffixedTok, Item);
    end;

    procedure GetCurrentDateTimeInGMTFormat(): Text
    var
        LocalTimeInUtc: Text;
        Parts: List of [Text];
        YearPart: Text;
        MonthPart: Text;
        DayPart: Text;
        HourPart: Text;
        MinutePart: Text;
        SecondPart: Text;
    begin
        // get the UTC notation of current time
        LocalTimeInUtc := Format(CurrentDateTime(), 0, 9);
        Parts := LocalTimeInUtc.Split('-', 'T', ':', '.', 'Z');
        YearPart := Parts.Get(1);
        MonthPart := Parts.Get(2);
        DayPart := Parts.Get(3);
        HourPart := Parts.Get(4);
        MinutePart := Parts.Get(5);
        SecondPart := Parts.Get(6);
        exit(StrSubstNo(DateTimeExpandedFormatTok,
            GetDayOfWeek(YearPart, MonthPart, DayPart),
            DayPart,
            Get3LetterMonth(MonthPart),
            YearPart,
            HourPart,
            MinutePart,
            SecondPart));
    end;

    local procedure GetDayOfWeek(YearPart: Text; MonthPart: Text; DayPart: Text): Text
    var
        TempDate: Date;
        Day: Integer;
        Month: Integer;
        Year: Integer;
    begin
        Evaluate(Year, YearPart);
        Evaluate(Month, MonthPart);
        Evaluate(Day, DayPart);
        TempDate := System.DMY2Date(Day, Month, Year);
        case Date2DWY(TempDate, 1) of // the week number
            1:
                exit('Mon');
            2:
                exit('Tue');
            3:
                exit('Wed');
            4:
                exit('Thu');
            5:
                exit('Fri');
            6:
                exit('Sat');
            7:
                exit('Sun');
        end;
    end;

    local procedure Get3LetterMonth(MonthPart: Text): Text
    var
        Month: Integer;
    begin
        Evaluate(Month, MonthPart);
        case Month of
            1:
                exit('Jan');
            2:
                exit('Feb');
            3:
                exit('Mar');
            4:
                exit('Apr');
            5:
                exit('May');
            6:
                exit('Jun');
            7:
                exit('Jul');
            8:
                exit('Aug');
            9:
                exit('Sep');
            10:
                exit('Oct');
            11:
                exit('Nov');
            12:
                exit('Dec');
        end;
    end;

    procedure GetTableCaption(TableID: Integer): Text
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(TableID);
        exit(RecRef.Caption());
    end;

    procedure GetTableName(TableID: Integer) TableName: Text
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(TableID);
        TableName := RecRef.Name;
    end;

    procedure GetDataLakeCompliantTableName(TableID: Integer) TableName: Text
    var
        OrigTableName: Text;
    begin
        OrigTableName := GetTableName(TableID);
        TableName := GetDataLakeCompliantName(OrigTableName);
        exit(StrSubstNo(ConcatNameIdTok, TableName, TableID));
    end;

    procedure GetDataLakeCompliantFieldName(FieldName: Text; FieldID: Integer): Text
    begin
        exit(StrSubstNo(ConcatNameIdTok, GetDataLakeCompliantName(FieldName), FieldID));
    end;

    procedure GetDataLakeCompliantFieldName(TableID: Integer; FieldID: Integer): Text
    var
        Field: Record Field;
    begin
        Field.Get(TableID, FieldID);
        exit(GetDataLakeCompliantFieldName(Field.FieldName, FieldID));
    end;

    procedure GetDataLakeCompliantName(Name: Text) Result: Text
    var
        ResultBuilder: TextBuilder;
        Index: Integer;
        Letter: Text;
        AddToResult: Boolean;
    begin
        for Index := 1 to StrLen(Name) do begin
            Letter := CopyStr(Name, Index, 1);
            AddToResult := true;
            if StrPos(AlphabetsLowerTxt, Letter) = 0 then
                if StrPos(AlphabetsUpperTxt, Letter) = 0 then
                    if StrPos(NumeralsTxt, Letter) = 0 then
                        AddToResult := false;
            if AddToResult then
                ResultBuilder.Append(Letter);
        end;
        Result := ResultBuilder.ToText();
    end;

    procedure CheckFieldTypeForExport(FieldType: Option): Boolean
    var
        Field: Record Field;
    begin
        case FieldType of
            Field.Type::BigInteger,
            Field.Type::Boolean,
            Field.Type::Code,
            Field.Type::Date,
            Field.Type::DateFormula,
            Field.Type::DateTime,
            Field.Type::Decimal,
            Field.Type::Duration,
            Field.Type::Guid,
            Field.Type::Integer,
            Field.Type::Option,
            Field.Type::Text,
            Field.Type::Time:
                exit(true);
        end;
        exit(false);
    end;

    local procedure ConvertFieldToText(FieldRef: FieldRef): Text
    var
        DateTimeValue: DateTime;
    begin
        case FieldRef.Type of
            FieldRef.Type::BigInteger,
            FieldRef.Type::Date,
            FieldRef.Type::DateFormula,
            FieldRef.Type::Decimal,
            FieldRef.Type::Duration,
            FieldRef.Type::Integer,
            FieldRef.Type::Time,
            FieldRef.Type::Boolean:
                exit(ConvertVariantToText(FieldRef.Value()));
            FieldRef.Type::DateTime:
                begin
                    DateTimeValue := FieldRef.Value();
                    if DateTimeValue = 0DT then
                        exit('');
                    exit(ConvertDateTimeToText(DateTimeValue));
                end;
            FieldRef.Type::Option:
                exit(FieldRef.GetEnumValueNameFromOrdinalValue(FieldRef.Value()));
            FieldRef.Type::Code,
            FieldRef.Type::Guid,
            FieldRef.Type::Text:
                exit(ConvertStringToText(FieldRef.Value()));
        end;
        RaiseFieldTypeNotSupportedError(FieldRef.Name, FieldRef.Type);
    end;

    local procedure RaiseFieldTypeNotSupportedError(FieldName: Text; FieldType: FieldType)
    begin
        Error(FieldTypeNotSupportedErr, FieldName, FieldType);
    end;

    procedure RaiseFieldTypeNotSupportedError(FieldName: Text; FieldTypeOption: Option)
    begin
        Error(FieldTypeNotSupportedErr, FieldName, FieldTypeOption);
    end;

    procedure RaiseFieldTypeNotSupportedError(FieldName: Text)
    begin
        Error(TypeOfFieldNotSupportedErr, FieldName);
    end;

    procedure ConvertVariantToJson(ValueVariant: Variant; var Result: JsonValue): Boolean
    var
        DateFormulaValue: DateFormula;
        BigIntegerValue: BigInteger;
        BooleanValue: Boolean;
        DateValue: Date;
        DateTimeValue: DateTime;
        DecimalValue: Decimal;
        DurationValue: Duration;
        IntegerValue: Integer;
        TextValue: Text;
        TimeValue: Time;
    begin
        case true of
            ValueVariant.IsBigInteger():
                begin
                    BigIntegerValue := ValueVariant;
                    Result.SetValue(BigIntegerValue);
                    exit(true);
                end;
            ValueVariant.IsDate():
                begin
                    DateValue := ValueVariant;
                    Result.SetValue(DateValue);
                    exit(true);
                end;
            ValueVariant.IsDateFormula():
                begin
                    DateFormulaValue := ValueVariant;
                    TextValue := ConvertVariantToText(DateFormulaValue);
                    Result.SetValue(TextValue);
                    exit(true);
                end;
            ValueVariant.IsDecimal():
                begin
                    DecimalValue := ValueVariant;
                    Result.SetValue(DecimalValue);
                    exit(true);
                end;
            ValueVariant.IsDuration():
                begin
                    DurationValue := ValueVariant;
                    Result.SetValue(DurationValue);
                    exit(true);
                end;
            ValueVariant.IsInteger():
                begin
                    IntegerValue := ValueVariant;
                    Result.SetValue(IntegerValue);
                    exit(true);
                end;
            ValueVariant.IsTime():
                begin
                    TimeValue := ValueVariant;
                    Result.SetValue(TimeValue);
                    exit(true);
                end;
            ValueVariant.IsDateTime():
                begin
                    DateTimeValue := ValueVariant;
                    Result.SetValue(DateTimeValue);
                    exit(true);
                end;
            ValueVariant.IsBoolean():
                begin
                    BooleanValue := ValueVariant;
                    Result.SetValue(BooleanValue);
                    exit(true);
                end;
            ValueVariant.IsByte(),
            ValueVariant.IsChar(),
            ValueVariant.IsCode(),
            ValueVariant.IsGuid(),
            ValueVariant.IsText():
                begin
                    TextValue := ValueVariant;
                    Result.SetValue(TextValue);
                    exit(true);
                end;
            ValueVariant.IsOption():
                ;// Option should be passed as Text
        end;
        exit(false);
    end;

    procedure ConvertJsonToVariant(FieldRef: FieldRef; Value: JsonValue): Variant
    var
        DataFormulaVal: DateFormula;
        DateTimeVal: DateTime;
        TxtVal: Text;
        GuidVal: Guid;
        EnumIndex: Integer;
    begin
        case FieldRef.Type of
            FieldType::BigInteger:
                exit(Value.AsBigInteger());
            FieldType::Boolean:
                exit(Value.AsBoolean());
            FieldType::Code:
                exit(Value.AsCode());
            FieldType::Date:
                begin
                    DateTimeVal := Value.AsDateTime();
                    exit(DT2Date(DateTimeVal));
                end;
            FieldType::DateFormula:
                begin
                    TxtVal := Value.AsText();
                    Evaluate(DataFormulaVal, TxtVal, 9);
                    exit(DataFormulaVal);
                end;
            FieldType::DateTime:
                exit(Value.AsDateTime());
            FieldType::Decimal:
                exit(Value.AsDecimal());
            FieldType::Duration:
                exit(Value.AsDuration());
            FieldType::Guid:
                begin
                    TxtVal := Value.AsText();
                    Evaluate(GuidVal, TxtVal, 9);
                    exit(GuidVal);
                end;
            FieldType::Integer:
                exit(Value.AsInteger());
            FieldType::Option:
                begin
                    TxtVal := Value.AsText();
                    for EnumIndex := 1 to FieldRef.EnumValueCount() do
                        if TxtVal = FieldRef.GetEnumValueName(EnumIndex) then
                            exit(FieldRef.GetEnumValueOrdinal(EnumIndex));
                    Error(UnmatchedEnumNameErr, FieldRef.Name, TxtVal);
                end;
            FieldType::Text:
                exit(Value.AsText());
            FieldType::Time:
                exit(Value.AsTime());
        end;
        RaiseFieldTypeNotSupportedError(FieldRef.Name, FieldRef.Type);
    end;

    procedure ConvertStringToText(Val: Text): Text
    begin
        Val := Val.Replace('\', '\\'); // escape the escape character
        Val := Val.Replace('"', '\"'); // escape the quote character
        exit(StrSubstNo(QuotedTextTok, Val));
    end;

    procedure ConvertVariantToText(VariantVal: Variant): Text
    begin
        exit(Format(VariantVal, 0, 9));
    end;

    local procedure ConvertDateTimeToText(Val: DateTime) Result: Text
    var
        SecondsText: Text;
        WholeSecondsText: Text;
        MillisecondsText: Text;
        StartIdx: Integer;
        PeriodIdx: Integer;
    begin
        // get default formatted as UTC
        Result := Format(Val, 0, 9); // The default formatting excludes the zeroes for the millseconds to the right.

        // get full seconds part
        StartIdx := Result.LastIndexOf(':') + 1;
        SecondsText := Result.Substring(StartIdx, StrLen(Result) - StartIdx);
        PeriodIdx := SecondsText.LastIndexOf('.');
        if PeriodIdx > 0 then begin
            MillisecondsText := PadStr(SecondsText.Substring(PeriodIdx + 1), 3, '0');
            WholeSecondsText := SecondsText.Substring(1, PeriodIdx - 1);
        end else begin
            MillisecondsText := PadStr(MillisecondsText, 3, '0');
            WholeSecondsText := SecondsText;
        end;
        Result := Result.Replace(StrSubstNo(WholeSecondsTok, SecondsText), StrSubstNo(FractionSecondsTok, WholeSecondsText, MillisecondsText));
    end;

    procedure AddSystemFields(var FieldIdList: List of [Integer])
    var
        RecRef: RecordRef;
    begin
        FieldIdList.Add(0); // Timestamp field
        FieldIdList.Add(RecRef.SystemIdNo());
        FieldIdList.Add(RecRef.SystemCreatedAtNo());
        FieldIdList.Add(RecRef.SystemCreatedByNo());
        FieldIdList.Add(RecRef.SystemModifiedAtNo());
        FieldIdList.Add(RecRef.SystemModifiedByNo());
    end;

    procedure CreateCsvPayload(Rec: RecordRef; FieldIdList: List of [Integer]; AddHeaders: Boolean) RecordPayload: Text
    var
        ADLSECDMUtil: Codeunit "ADLSE CDM Util";
        Field: FieldRef;
        FieldID: Integer;
        FieldsAdded: Integer;
        FieldTextValue: Text;
        Payload: TextBuilder;
    begin
        FieldsAdded := 0;
        if AddHeaders then begin
            foreach FieldID in FieldIdList do begin
                Field := Rec.Field(FieldID);

                FieldTextValue := GetDataLakeCompliantFieldName(Field.Name, Field.Number);
                if FieldsAdded = 0 then
                    Payload.Append(FieldTextValue)
                else
                    Payload.Append(StrSubstNo(CommaPrefixedTok, FieldTextValue));
                FieldsAdded += 1;
            end;
            if IsTablePerCompany(Rec.Number) then
                Payload.Append(StrSubstNo(CommaPrefixedTok, ADLSECDMUtil.GetCompanyFieldName()));
            Payload.AppendLine();
        end;

        FieldsAdded := 0;
        foreach FieldID in FieldIdList do begin
            Field := Rec.Field(FieldID);

            FieldTextValue := ConvertFieldToText(Field);
            if FieldsAdded = 0 then
                Payload.Append(FieldTextValue)
            else
                Payload.Append(StrSubstNo(CommaPrefixedTok, FieldTextValue));
            FieldsAdded += 1;
        end;
        if IsTablePerCompany(Rec.Number) then
            Payload.Append(StrSubstNo(CommaPrefixedTok, ConvertStringToText(CompanyName())));
        Payload.AppendLine();

        RecordPayload := Payload.ToText();
    end;

    procedure IsTablePerCompany(TableID: Integer): Boolean
    var
        TableMetadata: Record "Table Metadata";
    begin
        TableMetadata.SetRange(ID, TableID);
        TableMetadata.FindFirst();
        exit(TableMetadata.DataPerCompany);
    end;

    procedure CreateFakeRecordForDeletedAction(ADLSEDeletedRecord: Record "ADLSE Deleted Record"; var Rec: RecordRef)
    var
        TimestampField: FieldRef;
        SystemIdField: FieldRef;
        SystemDateField: FieldRef;
    begin
        TimestampField := Rec.Field(0);
        TimestampField.Value(ADLSEDeletedRecord."Deletion Timestamp");
        SystemIdField := Rec.Field(Rec.SystemIdNo());
        SystemIdField.Value(ADLSEDeletedRecord."System ID");

        SystemDateField := Rec.Field(Rec.SystemCreatedAtNo());
        SystemDateField.Value(0DT);
        SystemDateField := Rec.Field(Rec.SystemModifiedAtNo());
        SystemDateField.Value(0DT);
    end;

    procedure GetTextValueForKeyInJson(Object: JsonObject; "Key": Text): Text
    var
        ValueToken: JsonToken;
        JValue: JsonValue;
    begin
        Object.Get("Key", ValueToken);
        JValue := ValueToken.AsValue();
        exit(JValue.AsText());
    end;

    procedure JsonTokenExistsWithValueInArray(Arr: JsonArray; PropertyName: Text; PropertyValue: Text): Boolean
    var
        Token: JsonToken;
        Obj: JsonObject;
        PropertyToken: JsonToken;
    begin
        foreach Token in Arr do begin
            Obj := Token.AsObject();
            if Obj.Get(PropertyName, PropertyToken) then
                if PropertyToken.AsValue().AsText() = PropertyValue then
                    exit(true);
        end;
    end;
}