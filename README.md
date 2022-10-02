# Project

> **This tool is an <u>experiment</u> on Dynamics 365 Business Central with the sole purpose of discovering the possibilities of having data exported to an Azure Data Lake. To see the details of how this tool is supported, please visit [the Support page](./SUPPORT.md). In case you wish to use this tool for your next project and engage with us, you are welcome to write to bc2adls@microsoft.com. As we are a small team, please expect delays in getting back to you.**

## Introduction

The **bc2adls** tool is used to export data from [Dynamics 365 Business Central](https://dynamics.microsoft.com/en-us/business-central/overview/) (BC) to [Azure Data Lake Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction) and expose it in the [CDM folder](https://docs.microsoft.com/en-us/common-data-model/data-lake) format. The components involved are the following,
- the **[businessCentral](/tree/main/businessCentral/)** folder holds a [BC extension](https://docs.microsoft.com/en-gb/dynamics365/business-central/ui-extensions) called `Azure Data Lake Storage Export` (ADLSE) which enables export of incremental data updates to a container on the data lake. The increments are stored in the CDM folder format described by the `deltas.cdm.manifest.json manifest`.
- the **[synapse](/tree/main/synapse/)** folder holds the templates needed to create an [Azure Synapse](https://azure.microsoft.com/en-gb/services/synapse-analytics/) pipeline that consolidates the increments into a final `data` CDM folder.

The following diagram illustrates the flow of data through a usage scenario- the main points being,
- Incremental update data from BC is moved to Azure Data Lake Storage through the ADLSE extension into the `deltas` folder.
- Triggering the Synapse pipeline(s) consolidates the increments into the data folder.
- The data is now ready for consumption by analytics apps like Power BI,
	- via the `data.cdm.manifest.json manifest` file, or
	- via the raw CSV files for each individual entity inside the `data` folder
	
![Architecture](/.assets/architecture.jpg "Flow of data")

More details:
- [Installation and configuration](/.assets/Setup.md)
- [Executing the export and pipeline](/.assets/Execution.md)

## Latest notable changes

Pull request | Changes
--------------- | ---
[47](https://github.com/microsoft/bc2adls/pull/47) | The ability to simultaneously export data from multiple companies has been introduced. This is expected to save time and effort in cases which required users to sequence the runs for different companies one after the other.  
[43](https://github.com/microsoft/bc2adls/pull/43) | Intermediate staging data is no longer saved in CDM format. This eliminates potential conflicts during concurrent updates to the manifest. This does not affect the final data output, which continues to be in CDM format.
[33](https://github.com/microsoft/bc2adls/pull/33) | Fixing issue related to localizations of booleans and options/ enums. 
[31](https://github.com/microsoft/bc2adls/pull/31) | Permissions corrected to direct permissions.
[28](https://github.com/microsoft/bc2adls/pull/28) | The AL app is upgraded to Dynamics 365 Business Central version 20. An archive has been created to keep the older versions at [the archived folder](/archived/).
[23](https://github.com/microsoft/bc2adls/pull/23) | The setting in [Consolidation_OneEntity](/synapse/pipeline/Consolidation_OneEntity.json) that limited concurrent execution of the pipeline to one instance has been removed. Now, an infinite number of pipeline instances is allowed to run concurrently. 
[20](https://github.com/microsoft/bc2adls/pull/20) | Data on the lake can be chosen to be stored on the [Parquet](https://docs.microsoft.com/en-us/azure/data-factory/format-parquet) format, thus improving its fidelity to its original in Business Central.
[16](https://github.com/microsoft/bc2adls/pull/16) | The [Consolidation_CheckForDeltas](/synapse/pipeline/Consolidation_CheckForDeltas.json) pipeline now contains a fail activity that is triggered when no directory is found in `/deltas/` for an entity listed in the `deltas.manifest.cdm.json`. This may occur when no new deltas have been exported since the last execution of the consolidation pipeline. Other parallel pipeline runs are not affected.
[14](https://github.com/microsoft/bc2adls/pull/14) | It is possible now to select all fields in a table for export. Those fields that are not allowed to be exported, say flow fields, are not selected.
[13](https://github.com/microsoft/bc2adls/pull/13) | A template is inserted in the `OnAfterOnDatabaseDelete` procedure, so that deletions of archive table records, are not synchronized to the data lake. This helps in selected tables in the data lake continuing to hold on to records that may be removed from the BC database, for house-keeping purposes. This is especialy relevant for ledger entry tables.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
