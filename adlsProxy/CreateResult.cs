// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
using Newtonsoft.Json.Linq;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace AdlsProxy
{
    internal static class CreateResult
    {
        public static JToken FindSet(ILogger logger, SqlDataReader reader)
        {
            IList<string> columnNames = new List<string>();
            for (int fldIndex = 0; fldIndex <= reader.FieldCount - 1; fldIndex++)
            {
                columnNames.Add(reader.GetName(fldIndex));
            }

            int recordCount = 0;
            JArray queryResult = new JArray();
            while (reader.Read())
            {
                IList<object?> fields = new List<object?>();
                for (int fldIndex = 0; fldIndex <= reader.FieldCount - 1; fldIndex++)
                {
                    fields.Add(reader[fldIndex]);
                }
                queryResult.Add(tokenizeResultRecord(columnNames, fields));
                recordCount++;
            }
            logger.LogInformation($"[FindSet] Number of records found: {recordCount}.");
            return queryResult;
        }

        public static JToken Count(ILogger logger, SqlDataReader reader)
        {
            reader.Read();
            var result = (int)reader[0];
            logger.LogInformation($"[Count] Number of records found: {result}.");
            return result;
        }

        public static JToken IsEmpty(ILogger logger, SqlDataReader reader)
        {
            reader.Read();
            var result = ((int)reader[0]) == 0 ? false : true;
            logger.LogInformation($"[IsEmpty] Records found: {!result}.");
            return result;
        }

        private static JObject tokenizeResultRecord(IList<string> columnNames, IList<object?> values)
        {
            var result = new JObject();
            for (int fldIndex = 0; fldIndex <= columnNames.Count - 1; fldIndex++)
            {
                var field = values[fldIndex];
                result.Add(columnNames[fldIndex], field == null ? null : new JValue(field));
            }
            return result;
        }
    }
}