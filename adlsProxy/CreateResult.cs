// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
using Newtonsoft.Json.Linq;
using Microsoft.Data.SqlClient;

namespace AdlsProxy
{
    internal static class CreateResult
    {
        public static JToken FindSet(SqlDataReader reader)
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
            return queryResult;
        }

        public static JToken Count(SqlDataReader reader)
        {
            reader.Read();
            return (int)reader[0];
        }

        public static JToken IsEmpty(SqlDataReader reader)
        {
            reader.Read();
            return (int)reader[0] == 0 ? false : true;
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