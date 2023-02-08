# Using shared metadata tables with bc2adls

This guide will explain how to utilize shared metdata tables in Azure Synapse Analytics to provide additional opportunities to interact with your Business Central data.


## What is a shared metadata table?

Azure Synapse Analytics allows the different workspace computational engines to share databases and tables between its Apache Spark pools and serverless SQL pool.

Once a database has been created by a Spark job, you can create tables in it with Spark that use Parquet, Delta, or CSV as the storage format. These tables will immediately become available for querying by any of the Azure Synapse workspace Spark pools. The Spark created, managed, and external tables are also made available as external tables with the same name in the corresponding synchronized database in serverless SQL pool.

You can read more about shared metadata tables [here](https://learn.microsoft.com/en-us/azure/synapse-analytics/metadata/table).


## What are the advantages of using shared metadata tables?

Shared metadata tables combine the advantages of multiple different approaches to data storage. Like a traditional database table, they can be queried using SQL. At the same time, they store their data on the data lake, reducing storage costs and eliminating the need for database compute. This also means [Power BI can connect to them in DirectQuery mode](https://learn.microsoft.com/en-us/azure/synapse-analytics/sql/tutorial-connect-power-bi-desktop#4---create-power-bi-report), using the Serverless SQL endpoint of Azure Synapse Analytics workspace. You can find this endpoint in the Azure Portal on the **Overview** blade of your Synapse workspace resource.

Connecting with DirectQuery allows you to create composite multi-table based views in Power BI, similar to [API entities](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/webservices/api-overview) that have been exposed as read-only API pages or queries. 

In addition, the tables can easily be read and modified using [Spark notebooks written in Python, C#, Scala or SQL](https://learn.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-development-using-notebooks) to support big data analytics or machine learning scenarios.

## How to use shared metadata tables with bc2adls?

bc2adls can be configured to automatically create shared metadata tables when it is exporting data from Business Central. Perform the following steps:
1. [Create a serverless Apache Spark pool in Azure Synapse Analytics](https://learn.microsoft.com/en-us/azure/synapse-analytics/quickstart-create-apache-spark-pool-studio). The small compute size is sufficient. 
1. Ensure that the [CreateParquetTable](/synapse/notebook/CreateParquetTable.ipynb) notebook has been imported into your Synapse environment. If not, [import the notebook](https://learn.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-development-using-notebooks#create-a-notebook). 
1. The notebook is run with the default credentials of the [system- assigned managed identity(https://learn.microsoft.com/en-us/azure/synapse-analytics/synapse-service-identity#system-assigned-managed-identity)] of your Azure Synapse workspace that often has the same name as the Synapse workspace itself, and it needs access to read the BC data in the lake. So you should perform the [Step 3 of the Setup guide](https://github.com/microsoft/bc2adls/blob/main/.assets/Setup.md#step-3-connect-credential-to-the-blob-storage) giving the managed identity the role of **Storage Blob Data Reader**.
1. On the **Export to Azure Data Lake Storage** page in Business Central, ensure that **CDM data format** is set to **Parquet**. 
1. When executing the [Consolidation_AllEntities](/synapse/pipeline/Consolidation_AllEntities.json) pipeline, provide the name of the previously created Spark pool as the **sparkpoolName** parameter. The pipeline will still run if the parameter is missing, but no shared metadata tables will be created in that case.

After the pipeline run has successfully completed, a new lake database will be visible in the **Data** section of the Azure Synapse Analytics workspace. The database will be named after the data lake container with a table for each entity. To test whether the table has been created successfully, you can generate an automatic SQL query to display its contents:
![](/.assets/shared_metadata_table_sql_query.png "Select TOP 100 FROM shared metadata table")

### How does it work?

The [Consolidation_OneEntity](/synapse/pipeline/Consolidation_OneEntity.json) pipeline checks whether the entity it is currently processing already exists in the **data** folder of the Data Lake. If that is not the case - indicating that a new table has been exported - the pipeline will execute a pySpark notebook that creates the Spark table. Since the data is in Parquet format, Spark can read the schema from the Parquet files, when creating the table. This means that columns will retain their defined data types (or Spark equivalents).

> **<em>Note</em>** 
> Table and database names are always in lower case and non-alphanumeric characters, e.g., hyphens (-), are replaced with underscores (_).

### When is manual intervention required?

To minimize the number of Spark jobs that are triggered, the [CreateParquetTable](/synapse/notebook/CreateParquetTable.ipynb) notebook is only executed when a new table is exported.
This also means that in existing bc2adls deployments, no shared metadata table will be created for entities already present in the **data** folder. This can be solved by modifying the **SparkTableConditions** activity in the [Consolidation_OneEntity](/synapse/pipeline/Consolidation_OneEntity.json) pipeline or by triggering the notebook manually for the desired entities. In that case, the **container_name** and **entity_name** parameters need to be supplied.

Similarly, when the schema of a table changes, it is advised to [drop](https://spark.apache.org/docs/3.0.0/sql-ref-syntax-ddl-drop-table.html) and recreate the table. This is currently not done automatically.