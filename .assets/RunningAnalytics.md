Now that the steps to setup the tool are complete, let's look at how to run it and derive the insights from it. The execution consists of 2 steps- exporting the incremental updates from Dynamics 365 Business Central (BC) to the data lake and then to consolidate them into a final data store.

# Exporting data from BC
The export process makes incremental updates to the data lake, based on the amount of changes (adds/ modifies/ deletes) made in BC since the last run. Open the `Page 82560 - Export to Azure Data Lake Storage` and add some tables that should be exported at the bottom grid of [the page](/.assets/bcAdlsePage.png). Do not forget to explicitly (and judiciously) select the fields in the table that should be exported.

> **<em>Note</em>** BLOB fields, FlowFields and FilterFields are not supported currently.

Ensure that the `State` columns for the table rows are set to Ready. Click now on the `Export` action at the top of the page. This spawns multiple sessions that export each table in parallel and uploads only the incremental updates to the data since the last export. 

When none of the table rows have a `Status` of `Exporting`, it indicates that the export process has completed. You should be able to see the data through the CDM endpoint: `deltas.cdm.manifest.json`.

## Telemetry
You may switch off the telemetry traces created inside this extension by turning the "Emit telemetry" flag to off on the main setup page. When switched on, operational telemetry is pushed to any Application Insights account specified on the extension by the publisher. [Read more](https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/telemetry-overview).

# Running the integration pipeline
The **Consolidation_AllEntities** pipeline consolidates all the incremental updates into one view. It should be invoked after one or more export processes from BC has completed and it requires you to specify the following parameters,
- the container to which the data has been exported, and,
- a flag to delete the deltas, if successful. In the general case, you might want to set this to true, as the deltas will not be deleted if the pipeline results in an error. Set it to false, in case you want to debug/ troubleshoot.

Follow the instructions at [Pipeline execution and triggers in Azure Data Factory or Azure Synapse Analytics | Microsoft Docs](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers) to trigger the pipeline. You will be required then to provide values for the parameters mentioned above.
![Trigger pipeline run](/.assets/synapseTriggerNow.png)

> **<em>Note</em>** Ensure that the pipeline is not triggered for an Azure data lake container in which data is either being exported from BC or another pipeline is consolidating data.

# Consuming the CDM folders
Once the consolidation run is completed, the CDM folder is ready to be consumed using the `data.manifest.cdm.json` file. In the given sample screenshot from Power BI, that translates to a data source called `data-manifest` (see **a)** below). 
![Sample Power BI](/.assets/powerBI.png)