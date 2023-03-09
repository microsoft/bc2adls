// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace AdlsProxy
{
    public class Functions
    {
        private readonly ILogger _logger;

        public Functions(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<Functions>();
        }

        /// <summary>
        /// Finds the records on a given entity based on optional filters and returns a JSON result.  
        /// </summary>
        [Function("FindSet")]
        public HttpResponseData FindSet([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            return ProcessQuery.Process(CreateQuery.FindSet, CreateResult.FindSet, req, this._logger);
        }

        /// <summary>
        /// Counts the records on a given entity based on optional filters and returns a JSON result.  
        /// </summary>
        [Function("Count")]
        public HttpResponseData Count([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            return ProcessQuery.Process(CreateQuery.Count, CreateResult.Count, req, this._logger);
        }

        /// <summary>
        /// Checks if a given entity is empty based on optional filters and returns a JSON result.  
        /// </summary>
        [Function("IsEmpty")]
        public HttpResponseData IsEmpty([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            return ProcessQuery.Process(CreateQuery.IsEmpty, CreateResult.IsEmpty, req, this._logger);
        }

    }
}
