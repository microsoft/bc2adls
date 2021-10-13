The following steps take you through configuring your Dynamics 365 Business Central (BC) as well as Azure resources to enable the feature.

## Configuring the storage account
You need to have a storage account to store the exported data from BC. This is the storage which exposes that data as CDM folders.

### Step 1. Create an Azure service principal
You will need an Azure credential to be able to connect BC to the Azure Data Lake Storage account, something we will configure later on. The general process is described at [Quickstart: Register an app in the Microsoft identity platform | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#register-an-application). The one I created for the demo looks like,
![Sample App Registration](/.assets/appRegistration.png)

Take particular note of the **a)** and **b)** fields on it. Also note that you will need to generate a secret **c)** by following the steps detailed in the [Option 2: Create a new application secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#authentication-two-options). Add a redirected URI **d)** , `https://businesscentral.dynamics.com/OAuthLanding.htm`, so that BC can connect to Azure resources, say the Blob storage, using this credential. 

### Step 2. Configure an Azure Data Lake Gen 2
The tool exports the BC data to an Azure Data Lake Gen 2. You may refer to the following to create the resource, [Create a storage account for Azure Data Lake Storage Gen2 | Microsoft Docs](https://docs.microsoft.com/en-us/azure/storage/blobs/create-data-lake-storage-account).

### Step 3. Connect credential to the blob storage
Now you must configure the above storage account to allow changes by the credential created above. Make sure you add a role assignment so that the above credential is granted the **Storage Blob Data Contributor** role on the storage account. Learn more to do this at [Assign an Azure role for access to blob data - Azure Storage | Microsoft Docs](https://docs.microsoft.com/en-us/azure/storage/blobs/assign-azure-role-data-access?tabs=portal#assign-an-azure-role). In the following screenshot, a sample storage account called **bc2adlssa** has been assigned a credential called **bc2adls**.
![Sample storage account](/.assets/storageAccount.png)

## Configuring the Dynamics 365 Business Central
In order to export the data from inside BC to the data lake, you will need to add a configuration to make BC aware of the location in the data lake.

### Step 4. Enter the BC settings
Let us take a look at the settings show in the sample screenshot of the main `Page 82560 - Export to Azure data lake Storage` below,
- **a)** The container name (defaulted to `business-central`) inside the storage account where the data shall be exported as block blobs. The export process creates this location if it does not already exist. Please ensure that the name corresponds to the requirements as outlined at [Naming and Referencing Containers, Blobs, and Metadata - Azure Storage | Microsoft Docs](https://docs.microsoft.com/en-us/rest/api/storageservices/Naming-and-Referencing-Containers--Blobs--and-Metadata).
- **b)** The tenant id at which the app registration created above resides (refer to **b)** in the picture at [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal))
- **c)** The name of the storage account that you created in [Step 2]().
- **d)** The Application (client) ID from the App registration (refer to **a)** in the picture at [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal))
- **e)** The client credential key you had defined (refer to **c)** in the in the picture at [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal))
- **f)** The size of the individual data payload that constitutes a single REST Api upload operation to the data lake. A bigger size will surely mean less number of uploads but might consume too much memory on the BC side. Note that each upload creates a new block within the blob in the data lake. So the size of such blocks are constrained as described at [Put Block (REST API) - Azure Storage | Microsoft Docs](https://docs.microsoft.com/en-us/rest/api/storageservices/put-block#remarks).

![The Export to Azure Data Lake Storage page](/.assets/bcAdlsePage.png)

## Configuring the Azure Synapse workspace
This section deals with consolidation of the data that was uploaded to the data lake from BC. It is assumed that you would run the exports from BC periodically and that would generate incremental changes loaded in the `deltas` CDM folder. These incremental changes will then be consolidated into the final `data` CDM folder using Azure Synapse.

### Step 5. Create an Azure Synapse Analytics workspace
Follow the steps as given in [Quickstart: create a Synapse workspace - Azure Synapse Analytics | Microsoft Docs](https://docs.microsoft.com/en-us/azure/synapse-analytics/quickstart-create-workspace) to create a workspace. Here you must provide the following and click on **Create** to create the workspace
- A unique workspace name
- A storage account and a container in it- that is exclusively for the use of this workspace, say, to store logs of activities. It is recommended that this is a different storage account than the one you use to store data from BC.
![Create Azure Synapse workspace](/.assets/synapseWorkspace.png)

### Step 6. Create data integration pipelines
This is the step that would create the analytics pipelines in the above workspace and consists of the following sub- steps,
1. Open the Synapse workspace just created and on the **Overview** blade, under **Getting Started** tab, click on the link to open the Synapse Studio. 

    ![Open Synapse Studio](/.assets/openSynapseStudio.png)

2. We need a linked service that establishes the connection to the storage account you created in Step 2. Click on **New** button on the Linked Services under the **Manage** pane.

    ![Synapse Linked Services](/.assets/synapseLinkedService.png)

3. In the **New linked service** pop-up, choose **Azure Data Lake Storage Gen2** before clicking on **Continue**.
4. Please enter the following information to configure the data lake linked service
    - Set **Name** to `AzureDataLakeStorage`. It is important that you set it exactly to this name as this is a dependency for the next steps when you import the pipeline elements.
    - You created a Service credential (via an **App Registration**) in [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal) and gave it permissions to read from and write to the data lake. We will use those details to configure the linked service. Set the **Authentication method** to be **Service Principal**.
    - Choose **Enter manually** for **Account selection method**.
    - Set the **URL** to point to the data lake store. The URL should be in the following format: `https://<storage-account-name>.dfs.core.windows.net`.
    - Set the **Tenant** to be the tenant guid for the App Registration (see **b)** in the picture at [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal)).
    - Set the **Service principal ID** to be equal to the **Application ID** in the App Registration (see **a)** in the picture at [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal)).
    - Set the **Service principal credential type** to be **Service principal key**.
    - Set the value of the **Service principal key** to be one of the secrets that you must have configured in the **Certificates & secrets** link of the App Registration (see **c)** in the picture at [Step 1](/.assets/Setup.md#step-1-create-an-azure-service-principal)).
    - It is always a good idea to click and verify that the **Test connection** button goes green when clicked. Once verified, click on **Create**.
    ![New linked service](/.assets/synapseNewLinkedService.png)
5. Let us deploy the pipelines and resources now. Note that for each resource, you will have to create a dummy entry in the Synapse Studio first with the name matching the value in the Name column in the table below. Then the content of the resource should be replaced with the content of the file linked in the table below, after clicking on the curly braces `{}` on the top right corner of the page. The following shows how to create a new dataset, for example. Note that the name of the tab is `Data` and the name of the menu to invoke under the `+` sign is `Integration dataset`.

    ![New Dataset](/.assets/synapseNewIntegrationDataset.png)

    It is important that the resources are created in the following sequence, 

| Sequence # | Name & Url | Tab | Menu to invoke under the `+` sign | 
| ---------- | ---- | --- | ----------------------------------| 
|1|[`data_dataset`](/synapse/dataset/data_dataset.json)|`Data`|`Integration dataset`|
|2|[`deltasManifest_dataset`](/synapse/dataset/deltasManifest_dataset.json)|`Data`|`Integration dataset`|
|3|[`deltas_dataset`](/synapse/dataset/deltas_dataset.json)|`Data`|`Integration dataset`|
|4|[`stagingManifest_dataset`](/synapse/dataset/stagingManifest_dataset.json)|`Data`|`Integration dataset`|
|5|[`staging_dataset`](/synapse/dataset/staging_dataset.json)|`Data`|`Integration dataset`|
|6|[`Consolidation_flow`](/synapse/dataflow/Consolidation_flow.json)|`Develop`|`Data flow`|
|7|[`Consolidation_OneEntity`](/synapse/pipeline/Consolidation_OneEntity.json)|`Integrate`|`Pipeline`|
|8|[`Consolidation_CheckForDeltas`](/synapse/pipeline/Consolidation_CheckForDeltas.json)|`Integrate`|`Pipeline`|
|9|[`Consolidation_AllEntities`](/synapse/pipeline/Consolidation_AllEntities.json)|`Integrate`|`Pipeline`|

6. At the toolbar of the **Synapse Studio** at the top, you may now click on **Validate all** and if there are no errors, click on **Publish all**.


## Congratulations!
You have completed configuring the resources. Please proceed to running the tool and exporting BC data to data lake [here](/.assets/RunningAnalytics.md).














