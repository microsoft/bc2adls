Now that the steps to setup the tool are complete, let's look at how to run it and derive the insights from it. The execution consists of 2 steps- exporting the incremental updates from Dynamics 365 Business Central (BC) to the data lake and then to consolidate them into a final data store.

# Exporting data from BC
Open the `Page 82560 - Export to Azure Data Lake Storage` and add some tables that should be exported at the bottom grid of the page. Do not forget to explicitly (and judiciously) select the fields in the table that should be exported. Ensure that the `State` columns for the table rows are set to Ready. Click now on the `Export` action at the top of the page. This spawns multiple sessions that export each table in parallel. 

When none of the table rows have a `Status` of `Exporting`, it indicates that the export process has completed. You should be able to see the data through the CDM endpoint: `deltas.cdm.manifest.json`.

# Running the integration pipeline
The two Azure Synapse pipelines you have set up serve the following purposes,
- **Consolidation_OneEntity**\. Invoke this if you have just exported data from a few tables and would like to run the consolidation only for one entity at a time.
- **Consolidation_AllEntities**\. Invoke this if you want to run consolidation for all entities exported. It simply calls the above pipeline for each delta entity discovered.

These pipelines should be invoked after an export date process from BC has completed and require you to specify
- the container to which the data has been exported, and,
- a flag to delete the deltas, if successful. In the general case, you might want to set this to true, as the deltas will not be deleted if the pipeline results in an error. Set it to false, in case you want to debug/ troubleshoot.

The typical way to invoke a pipeline is to click on **Trigger now** under the Add trigger menu as shown below. This opens up the dialog where you could put in the inputs as mentioned above. 
![Trigger pipeline run](/.assets/synapseTriggerNow.png)

# Consuming the CDM folders
Once the consolidation run is completed, the CDM folder is ready to be consumed using the `data.manifest.cdm.json` file. In the given sample screenshot from Power BI, that translates to a folder called `data-manifest` (see **a)** below). On the other hand, you can always see the unconsolidated data from the `deltas.manifest.cdm.json` file using the `deltas-manifest` (see **b)** below). Both manifests have the same entities.
![Sample Power BI](/.assets/powerBI.png)