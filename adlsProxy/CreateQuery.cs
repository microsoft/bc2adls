// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
using Newtonsoft.Json.Linq;

namespace AdlsProxy
{
    internal enum FilterType
    {
        Equals,
        NotEquals,
        GreaterThan,
        GreaterThanOrEquals,
        LessThan,
        LessThanOrEquals
    }

    /// <summary>
    /// Creates an SQL query based on the JSON input passed. It is expected that the JSON is formatted in the following way, 
    /// {
    ///     "server": "Serverless SQL endpoint",
    ///     "database": "database name",
    ///     "entity": "custledgerentry_21",
    ///     "fields": [ "EntryNo-1", "CustomerNo-3", "PostingDate-4" ], // optional; if blank, return all fields. Only used by FindSet.
    ///     "filters": [
    ///         { "op": "GreaterThanOrEquals", "field": "CustomerNo-3", "value": "40000" },
    ///         { "op": "LessThan", "field": "EntryNo-1", "value": 1559 },
    ///         { "op": "NotEquals", "field": "PostingDate-4", "value": "2021-03-23T00:00:00" }
    ///     ], // optional; if blank, return unfiltered set of all records
    ///     "orderBy": [
    ///         {
    ///             "field": "PostingDate-4",
    ///             "ascending": false
    ///         },
    ///         {
    ///             "field": "EntryNo-1"
    ///         }
    ///     ] // optional. Only used by FindSet.
    /// }
    /// </summary>
    /// <returns>The SQL query formed as text.</returns>

    internal static class CreateQuery
    {
        public static string FindSet(JObject body, JToken database, JToken entity)
        {
            var selectFields = body["fields"] as JArray;
            var filters = body["filters"] as JArray;
            var orderBy = body["orderBy"] as JArray;

            var fieldListExpression = selectFields == null ? "*" : concatenateItems(selectFields, ",", t => $"[{t.ToString()}]");
            var filterExpression = filters == null ? "" : $" WHERE {concatenateItems(filters, " AND", filterTransformToken)}";
            var orderByExpression = orderBy == null ? "" : $" ORDER BY {concatenateItems(orderBy, ",", orderByTransformToken)}";
            return $"SELECT {fieldListExpression} FROM [{database}].[dbo].[{entity}]{filterExpression}{orderByExpression};";
        }

        public static string Count(JObject body, JToken database, JToken entity)
        {
            var filters = body["filters"] as JArray;

            var filterExpression = filters == null ? "" : $" WHERE {concatenateItems(filters, " AND", filterTransformToken)}";
            return $"SELECT COUNT(*) FROM [{database}].[dbo].[{entity}]{filterExpression};";
        }

        public static string IsEmpty(JObject body, JToken database, JToken entity)
        {
            var filters = body["filters"] as JArray;

            var filterExpression = filters == null ? "" : $" WHERE {concatenateItems(filters, " AND", filterTransformToken)}";
            return $"IF EXISTS (SELECT TOP 1 1 FROM [{database}].[dbo].[{entity}]{filterExpression}) SELECT 0 ELSE SELECT 1;";
        }

        private static string concatenateItems<T>(IEnumerable<T> list, string delimiter, Func<T, string> transform)
        {
            string result = "";
            var counter = 0;
            if (list != null)
            {
                foreach (var item in list)
                {
                    result += $"{transform(item)}{delimiter} ";
                    counter++;
                }
                if (counter > 0)
                {
                    // remove the last delimiter added
                    result = result.Remove(result.Length - $"{delimiter} ".Length);
                }
            }
            return result;
        }

        private static string filterTransformToken(JToken token)
        {
            var filter = token as JObject;
            if (filter == null)
            {
                throw new ArgumentException($"Bad item {token} in the filters expression.");
            }
            var op = filter["op"];
            if (op == null || op.Type != JTokenType.String)
            {
                throw new ArgumentException($"Bad or missing operator in the filter {token}.");
            }
            if (!Enum.TryParse((filter["op"] ?? "").ToString(), true, out FilterType filterType))
            {
                throw new ArgumentException($"Bad operator passed in the filter {token}.");
            }
            var field = filter["field"] as JToken;
            if (field == null || field.Type != JTokenType.String)
            {
                throw new ArgumentException($"Bad or missing field in the expression {token}.");
            }
            var value = filter["value"];
            if (value == null)
            {
                throw new ArgumentException($"Missing value in the filter {token}.");
            }
            var valueTokenType = (filter["value"] ?? 0).Type;
            var useQuotes = new[] { JTokenType.String, JTokenType.Date }.Contains(valueTokenType);
            return $"[{filter["field"]}] {filterOperator(filterType)} {(useQuotes ? "'" : "")}{filter["value"]}{(useQuotes ? "'" : "")}";
        }

        private static string filterOperator(FilterType op)
        {
            switch (op)
            {
                case FilterType.Equals:
                    return "=";
                case FilterType.NotEquals:
                    return "!=";
                case FilterType.GreaterThan:
                    return ">";
                case FilterType.GreaterThanOrEquals:
                    return ">=";
                case FilterType.LessThan:
                    return "<";
                case FilterType.LessThanOrEquals:
                    return "<=";
                default:
                    throw new ArgumentException($"The filter operator {op} is not supported.");
            }
        }

        private static bool isQuotedValue(JToken value)
        {
            return (value.Type == JTokenType.String || value.Type == JTokenType.Date);
        }

        private static string orderByTransformToken(JToken token)
        {
            var orderByItem = token as JObject;
            if (orderByItem == null)
            {
                throw new ArgumentException($"Bad item {token} in the order by expression.");
            }
            var field = orderByItem["field"] as JToken;
            if (field == null || field.Type != JTokenType.String)
            {
                throw new ArgumentException($"Bad or missing field in the expression {token} in the order by expression.");
            }
            bool orderByAscending = ((bool?)(orderByItem["ascending"] as JToken)) ?? true;
            return $"[{field}]{(orderByAscending ? " ASC" : " DESC")}";
        }
    }
}