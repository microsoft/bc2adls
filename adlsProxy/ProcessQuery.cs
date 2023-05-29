// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
using System.Net;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace AdlsProxy
{
    internal static class ProcessQuery
    {
        public static HttpResponseData Process(Func<JObject, JToken, JToken, string> queryCreate, Func<ILogger, SqlDataReader, JToken> resultCreate, HttpRequestData req, ILogger logger)
        {
            try
            {
                var bodyText = new StreamReader(req.Body).ReadToEnd();
                var bodyJson = JObject.Parse(bodyText);
                if (bodyJson == null)
                {
                    throw new ArgumentException("Body in the request must be in the correct JSON format.");
                }
                var dbServer = bodyJson["server"];
                if (dbServer == null || dbServer.Type != JTokenType.String)
                {
                    throw new ArgumentException("Bad or missing SQL endpoint.");
                }
                var dbName = bodyJson["database"];
                if (dbName == null || dbServer.Type != JTokenType.String)
                {
                    throw new ArgumentException("Bad or missing SQL database name.");
                }

                var connParams = new SqlConnectionStringBuilder();
                connParams.DataSource = dbServer.ToString();
                connParams.InitialCatalog = dbName.ToString();
                connParams.Encrypt = true;
                
                // uncomment when testing locally- remember to add the attributes to the local.settings.json
                // connParams.Authentication = SqlAuthenticationMethod.ActiveDirectoryServicePrincipal;
                // connParams.UserID = Environment.GetEnvironmentVariable("SqlConnectionString_Auth_User"); // client ID
                // connParams.Password = Environment.GetEnvironmentVariable("SqlConnectionString_Auth_Password"); // client secret
                connParams.Authentication = SqlAuthenticationMethod.ActiveDirectoryManagedIdentity;

                logger.LogInformation($"Connection Parameters: {connParams.ConnectionString}");

                JObject output = new JObject();
                using (SqlConnection connection = new SqlConnection(connParams.ConnectionString))
                {
                    connection.Open();

                    var entity = bodyJson["entity"] as JToken;
                    if (entity == null || entity.Type != JTokenType.String)
                    {
                        throw new ArgumentException("Bad or missing entity to be queried.");
                    }

                    // form query
                    string sqlQuery = queryCreate(bodyJson, dbName, entity);
                    logger.LogInformation($"Query constructed: {sqlQuery}");
                    SqlCommand command = new SqlCommand(sqlQuery, connection);

                    // execute query
                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        output.Add("result", resultCreate(logger, reader));
                    }
                }

                logger.LogInformation("Request processed.");

                var response = req.CreateResponse(HttpStatusCode.OK);
                response.Headers.Add("Content-Type", "text/json; charset=utf-8");
                var outputAsText = output.ToString();
                response.WriteString(outputAsText);
                logger.LogInformation($"Length of the response: {outputAsText.Length}.");

                return response;
            }
            catch (ArgumentException argEx)
            {
                logger.LogWarning($"Invalid input presented. {argEx.Message} \r\n {argEx.StackTrace}");

                var response = req.CreateResponse(HttpStatusCode.BadRequest);
                response.Headers.Add("Content-Type", "text/plain; charset=utf-8");
                response.WriteString(argEx.Message);
                return response;
            }
            catch (Exception ex)
            {
                logger.LogError($"Exception! {ex.Message} \r\n {ex.StackTrace}");

                var response = req.CreateResponse(HttpStatusCode.InternalServerError);
                response.Headers.Add("Content-Type", "text/plain; charset=utf-8");
                response.WriteString("The server encountered an error processing your request. Please take a look at the server logs.");
                return response;
            }
        }
    }
}