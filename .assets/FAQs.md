Here you will find answers to the most frequently asked questions. Please also refer to the [issues](/issues) site to know more or to ask your own questions in the community. 

### How do I run the export to the lake in a recurring schedule?
The [Job Queue](https://learn.microsoft.com/en-us/dynamics365/business-central/admin-job-queues-schedule-tasks) feature in Business Central is used to schedule background tasks in a periodic way. You may invoke the [Codeunit `ADLSE Execution`](https://github.com/microsoft/bc2adls/blob/main/businessCentral/src/ADLSEExecution.Codeunit.al) through the feature to export the data increments to the lake as a scheduled job. You may click `Schedule export` on the main setup page to create this job queue.

### How should I distribute the BC data to my lake?
We recommend that a data lake container holds data only for **only one** Business Central environment. After copying environments, ensure that the export destination on the setup page on the new environment points to a new data lake container.

### Can I export calculated fields into the lake?
No, only persistent fields on the BC tables can be exported. But, the [issue #88](/issues/88) describes a way to show up those fields when consuming the lake data.

### How can I export BLOB data to the lake?
Data from blob fields in tables are not exported today to the lake. It should be possible however to convert the (possibly, binary) data to text using the [Codeunit `Base64 Convert`](https://learn.microsoft.com/en-us/dynamics365/business-central/application/reference/system%20application/codeunit/system_application_codeunit_base64_convert) and then store it as a separate field in a new table and exporting it to the lake using the bc2adls solution.

### How do I export some tables at a different frequency than the rest?
Normally, all the tables that are setup for export will export at the same time. However you may invoke exports of selected tables by using the API pages available. The [issue #87](/issues/87) describes this possibility in more detail.

### How do I track the files in the `deltas` folder in my data lake container?
Incremental exports create files in the `deltas` folder in the lake container. Each such file has a `Modified` field that indicates the time when it was last updated, in other words, when the export process finished with that file. Each export process for an entity and in a company logs its execution on the  [`ADLSE Run`](https://github.com/microsoft/bc2adls/blob/main/businessCentral/src/ADLSERun.Table.al) table using the `Started` and `Ended` fields. Thus you may tally the value in the `Modified` field of the file to these fields and determine which run resulted in creation of that file.