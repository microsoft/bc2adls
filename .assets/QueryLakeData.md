# Querying data residing in the lake with bc2adls 

It is often desirable to query the data residing in the lake and use it inside Dynamics 365 Business Central (BC). Such data may either have been exported previously out of BC through the `bc2adls` tool, or general tabular data that has been sourced from external systems. The following steps help you establish a mechanism to query such data directly inside BC through the AL constructs.

Let's go through a few use cases that are enabled by this feature.
1. Data from BC that has been previously exported and archived into the lake may need to be looked up by the system or a user to see historical entities.
1. Data created on the lake by external systems (such as IoT devices or [Azure Synapse Link for Dataverse](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/export-to-data-lake)) need to be looked up in BC to make relevant calculations.
1. Data lake can now be used as a cheaper single- storage solution for miscellaneous tabular data that can be queried by BC on- demand.

## How it works
**Note the arrows that point from the lake database into BC in the diagram below.** Using the new façades [`ADLSE Query`](/businessCentral/src/Query/ADLSEQuery.Codeunit.al) and [`ADLSE Query Table`](/businessCentral/src/Query/ADLSEQueryTable.Codeunit.al), the AL developer issues a REST API call to the `AdlsProxy` Azure function app while passing information like the table and specific fields to be queried, filters to be applied, etc. The function app then formulates the request as an SQL query to the lake database, which in turn gets the relevant data from the `data` CDM folder in the storage account. The result is then returned as a Json response to BC so that records and corresponding fields in those records can be individually read via the AL language. Please see the documentation of the above façades for more details.

![Architecture](/.assets/architecture.png "Flow of data") 

Currently the funcionality only supports, 
- fetching a specific set (or all) fields in a filtered set of records that is sorted in a certain way, similar to the [Findset](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/recordref/recordref-findset-method) call.
- counting the number of records in the lake, similar to the [Count](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/recordref/recordref-count-method) call.
- checking if there are any records in the lake, similar to the [IsEmpty](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/recordref/recordref-isempty-method) call.

> **<em>Note</em>** 
> 1. The approach suggested will **only work for tabular data** that have been structured into shared metadata tables as described in [Creating shared metadata tables](/.assets/SharedMetadataTables.md). For data that was not created through the `bc2adls` export, you may need to create such tables manually as explained.
> 1. Since querying from BC requires a number of Azure components to work in tandem, please use this approach only for **non- business critical** processes that allow for network or process latency. 
> 1. The architecture allows for a limited amount of data to be queried from the serverless SQL endpoint. You may get errors if the response is too large for BC to process. Therefore, it is highly recommended that you apply filtering to narrow the results and only fetch the fields that you require.

## Setting it all up

### Pre-requisites
- You have [installed and configured](/.assets/Setup.md) `bc2adls`, and the tables and fields in BC to be queried from the lake have been added. This is, of course, only relevant if you wish to read BC data from the lake via the [`ADLSE Query Table`](/businessCentral/src/Query/ADLSEQueryTable.Codeunit.al) façade.
- You have configured [shared metadata tables](/.assets/SharedMetadataTables.md) for your data on the lake. This may include tables that are unknown to BC.
- You have sufficient access to create Azure Function Apps on your subscription.

### Create and deploy function app to Azure
Start Visual Studio Code and open the folder [`adlsProxy`](/adlsProxy/). Follow the instructions given in [the documentation](https://learn.microsoft.com/en-us/azure/azure-functions/create-first-function-vs-code-csharp?tabs=in-process). I used the runtime stack as .NET 7 Isolated. Let's say you chose to name the Function App as `AdlsProxyX`.

### Take note of the function app URL
Open the newly created function app `AdlsProxyX` in the Azure portal, under **Overview**, take a note of the value in the **URL** field. This should be the format `https://adlsproxyx.azurewebsites.net`.

### Add a system managed identity for the Azure function
In the Azure function app, and follow [the instructions](https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity?tabs=portal%2Chttp#add-a-system-assigned-identity) to add a system managed identity. This would create an identity named (usually) the same as the Function App.

### Protect your function app using new AAD credentials
In the Azure function app, follow the instructions at [Create a new app registration automatically](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad#--option-1-create-a-new-app-registration-automatically). This should create a brand new App registration that can be used to make requests on the function app. Take a note of the following values as they will be required later on,
- the `App (Client) ID` field, as well as,
- the newly created client secret stored as the [application setting](https://learn.microsoft.com/en-us/azure/azure-functions/functions-how-to-use-azure-function-app-settings?tabs=portal) named `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET`. Of course, you may just as well create a new secret on the new app registration and use it instead!

### Take a note of the function keys
In the Azure function app, under **Functions**, you will notice a few functions that have been created. Go inside each of the functions and under `Function Keys`, make a note of the full text of the respective function key. 
> It is recommended to go through the documentation at [Securing Azure functions](https://learn.microsoft.com/en-us/azure/azure-functions/security-concepts) in order to fully understand the different ways to authenticate and authorize functions. This may be handy if, say, you want only some credentials to access entity A, while everyone can access entity B etc. 

### Authorize the created system managed identity to query the data on the serverless SQL endpoint
Open the SQL query editor from the lake database in the Synapse studio opened from your Synapse workspace and execute the following query,

    CREATE LOGIN [AdlsProxyX] FROM EXTERNAL PROVIDER;
    CREATE USER AdlsProxyX FROM LOGIN [AdlsProxyX];
    ALTER ROLE db_datareader ADD member AdlsProxyX;

This will ensure that the function app has the necessary privileges to run SQL queries in the database. Please make sure that the above query has run in the context of the right database, and that you have replaced the word `AdlsProxyX` with the correct name of the system managed identity of the function app. 

### Authorize the created system managed identity to read the data on the lake
As queries from the Azure function will be executed in the context of the system managed identity of the function app, it needs to be assigned the **Storage Blob Data Reader** role on the storage account with the data files.

### Enable BC to send queries to the function app 
On the main setup page of the `bc2adls` extension, you will note a new fast tab called **Query data in the lake**. Fill out the fields in the following way,
- **Synapse Serverless SQL endpoint** Locate the Synapse workspace resource on the Azure portal and fill this with the value of the field **Serverless SQL endpoint** under **Overview**.
- **SQL Database Name** The name of the lake database that was created at the [Creating shared metadata tables](/.assets/SharedMetadataTables.md).
- **Client ID** The value of the app (client) id from the step [Protect your function app using new AAD credentials](#protect-your-function-app-using-new-aad-credentials) above.
- **Client secret** The value of the client secret from the step [Protect your function app using new AAD credentials](#protect-your-function-app-using-new-aad-credentials) above.
- **Function app url** The value of the url from the step [Take note of the function app URL](#take-note-of-the-function-app-url) above.
- **Function key FindSet** The value of the function key for the Findset function gathered at the step [Take a note of the function keys](#take-a-note-of-the-function-keys) above.
- **Function key IsEmpty** The value of the function key for the IsEmpty function gathered at the step [Take a note of the function keys](#take-a-note-of-the-function-keys) above.
- **Function key Count** The value of the function key for the Count function gathered at the step [Take a note of the function keys](#take-a-note-of-the-function-keys) above.

![Screenshot](/.assets/QueryDataInTheLake.png "bc2adls setup page") 

## Making queries in AL
Phew, that was a lengthy configuration but it is finally time to query the lake! Open Visual Studio Code and go the place in your AL code where you want to query the lake and follow the examples given in the documentation for the two façades,
1. [`ADLSE Query`](/businessCentral/src/Query/ADLSEQuery.Codeunit.al) used for any tabular data, and
1. [`ADLSE Query Table`](/businessCentral/src/Query/ADLSEQueryTable.Codeunit.al) used for BC tables.

Any errors that happen during the course of the Rest Api call to the function app are thrown up on the AL side. To troubleshoot further on the function app, it is recommended that you follow instructions at [Monitor executions in Azure functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-monitoring).