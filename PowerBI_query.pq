// Power Query M script for Power BI — MDSO Incident Review data source
// Paste into: Home > Transform Data > Advanced Editor
//
// Before using:
//   1. Replace "YOUR_SERVER_NAME" with the actual SQL Server hostname/instance.
//   2. The query targets the [Workforce] database (set in Sql.Database options).
//   3. Date parameters (@StartDate / @EndDate) are embedded in the native SQL so
//      the rolling 3-month window executes server-side. To change the lookback,
//      edit the DATEADD offset inside the query text below.

let
    // ─── Connection parameters ───────────────────────────────────────────────────
    ServerName = "YOUR_SERVER_NAME",
    DatabaseName = "Workforce",

    // ─── Native SQL query (GDW_query.sql body without USE/GO/SET preamble) ──────
    SqlQuery = "
DECLARE @StartDate DATE = DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));
DECLARE @EndDate   DATE = CAST(GETDATE() AS DATE);

WITH
BaseIncidents AS
(
    SELECT DISTINCT
         inc.[Id] AS [EventID]
        ,'https://gstt.radarhealthcare.net/incident/27/details/' + CAST(inc.[Id] AS NVARCHAR(MAX)) AS [EventURL]
        ,inc.[IncidentTypeId]
        ,inc.[IncidentSubTypeId]
        ,inc.[Reference]
        ,inc.[Description] AS [Title]
        ,inc.[IncidentDateTime] AS [EventDate]
        ,inc.[ClosedOn] AS [ClosedDate]
        ,inc.[Created] AS [CreatedDate]
        ,inc.[LocationID]
        ,loc.[Name] AS [Location]
        ,reg.[Name] AS [Region]
        ,tg.[Name] AS [ClinicalGroup_RegionTag]
    FROM rad.RiskManagement_Incident inc
    INNER JOIN rad.Templates_FormTemplateInstance inst
        ON inc.Id = inst.LinkedObjectId
       AND inst.LinkedObjectType = 3
    INNER JOIN rad.Templates_FormTemplateInstanceValue form_values
        ON inst.Id = form_values.[TemplateInstanceId]
        AND form_values.DeletedInstant IS NULL
    LEFT JOIN rad.Radar_Location loc
        ON inc.[LocationID] = loc.ID
    LEFT JOIN rad.Radar_Region reg
        ON reg.ID = loc.RegionID
    LEFT JOIN rad.Radar_TagLink tl
        ON tl.LinkedObjectID = reg.ID
    INNER JOIN rad.Radar_Tag tg
        ON tg.ID = tl.TagID
       AND tg.ID IN (1,2,3,4,5,6)
    WHERE inc.[RecordStatus] = '2'
      AND inc.[IncidentTypeId] = 187
      AND inc.[Created] >= @StartDate
      AND inc.[Created] < DATEADD(DAY, 1, @EndDate)
),

RequiredFormValues AS
(
    SELECT DISTINCT
         inc.ID AS EventID
        ,fv.[FieldName]
        ,fv.[Value]
    FROM rad.RiskManagement_Incident inc
    INNER JOIN rad.Templates_FormTemplateInstance inst
        ON inc.Id = inst.LinkedObjectId
       AND inst.LinkedObjectType = 3
    INNER JOIN rad.Templates_FormTemplateInstanceValue fv
        ON inst.Id = fv.[TemplateInstanceId]
        AND fv.DeletedInstant IS NULL
    WHERE inc.[RecordStatus] = '2'
      AND inc.[IncidentTypeId] = 187
      AND inc.[Created] >= @StartDate
      AND inc.[Created] <  DATEADD(DAY, 1, @EndDate)
      AND fv.[FieldName] IN
      (
          'Patient_Involved',
          'LFPSE_Patient_Involved',
          'staff_related',
          'environment_related',
          'visitors_related',
          'tier_1',
          'tier_2'
      )
),

RequiredFormAgg AS
(
    SELECT
         EventID
        ,MIN(CASE WHEN [FieldName] = 'Patient_Involved' THEN [Value] END) AS [Patient_Involved]
        ,MIN(CASE WHEN [FieldName] = 'LFPSE_Patient_Involved' THEN [Value] END) AS [LFPSE_Patient_Involved]
        ,MIN(CASE WHEN [FieldName] = 'staff_related' THEN [Value] END) AS [staff_related]
        ,MIN(CASE WHEN [FieldName] = 'environment_related' THEN [Value] END) AS [environment_related]
        ,MIN(CASE WHEN [FieldName] = 'visitors_related' THEN [Value] END) AS [visitors_related]
        ,MIN(CASE WHEN [FieldName] = 'tier_1' THEN [Value] END) AS [tier_1]
        ,MIN(CASE WHEN [FieldName] = 'tier_2' THEN [Value] END) AS [tier_2]
    FROM RequiredFormValues
    GROUP BY EventID
),

WorkflowFormValues AS
(
    SELECT DISTINCT
         inc.ID AS EventID
        ,fv.[FieldName]
        ,fv.[Value]
    FROM rad.RiskManagement_Incident inc
    INNER JOIN rad.Workflow_Instance inst
        ON inc.Id = inst.LinkedObjectId
       AND inst.LinkedObjectType = 3
    INNER JOIN rad.Workflow_UserTask tasks
        ON inst.Id = tasks.WorkflowInstanceId
    INNER JOIN rad.Templates_FormTemplateInstance f_inst
        ON tasks.Id = f_inst.LinkedObjectId
       AND f_inst.LinkedObjectType = 6
    INNER JOIN rad.Templates_FormTemplateInstanceValue fv
        ON f_inst.Id = fv.[TemplateInstanceId]
        AND fv.DeletedInstant IS NULL
    WHERE inc.[RecordStatus] = '2'
      AND inc.[IncidentTypeId] = 187
      AND inc.[Created] >= @StartDate
      AND inc.[Created] <  DATEADD(DAY, 1, @EndDate)
      AND fv.[FieldName] IN
      (
          'duty-of-candour',
          '-azp461PF-3UGjUP_please-select-the-reason-why-dut',
          'Hx74MY6bSrifRlA3_was-a-verbal-apology-given-by-wa',
          'fzbugArqbqxUBKax_date-verbal-apology-given',
          'i2FM2CtpqnSotID2_reason-verbal-apology-not-given',
          'BMQWV6AY3Qc2FUIn_was-a-duty-of-candour-letter-sen',
          'JhZENRmC3A6xI9bQ_date-duty-of-candour-letter-sent',
          'iZsv5-RmlL06bn-w_reason-duty-of-candour-letter-no',
          'VpaLHXhH2Gk0F7Bx_has-the-outcome-of-the-review-or',
          'YLsj5YIJcqEaZGyB_date-outcome-of-review-or-invest',
          'oao7ugaoexkkQ41S_reason-outcome-of-review-or-inve',
          'sXRWExCBXMwFClfp_start-of-mdso-investigation',
          'o2WJulzEqABvEMOG_end-of-mdso-investigation'
      )
),

WorkflowFormAgg AS
(
    SELECT
         EventID
        ,MIN(CASE WHEN [FieldName] = 'duty-of-candour' THEN [Value] END) AS [duty-of-candour]
        ,MIN(CASE WHEN [FieldName] = '-azp461PF-3UGjUP_please-select-the-reason-why-dut' THEN [Value] END) AS [-azp461PF-3UGjUP_please-select-the-reason-why-dut]
        ,MIN(CASE WHEN [FieldName] = 'Hx74MY6bSrifRlA3_was-a-verbal-apology-given-by-wa' THEN [Value] END) AS [Hx74MY6bSrifRlA3_was-a-verbal-apology-given-by-wa]
        ,MIN(CASE WHEN [FieldName] = 'fzbugArqbqxUBKax_date-verbal-apology-given' THEN [Value] END) AS [fzbugArqbqxUBKax_date-verbal-apology-given]
        ,MIN(CASE WHEN [FieldName] = 'i2FM2CtpqnSotID2_reason-verbal-apology-not-given' THEN [Value] END) AS [i2FM2CtpqnSotID2_reason-verbal-apology-not-given]
        ,MIN(CASE WHEN [FieldName] = 'BMQWV6AY3Qc2FUIn_was-a-duty-of-candour-letter-sen' THEN [Value] END) AS [BMQWV6AY3Qc2FUIn_was-a-duty-of-candour-letter-sen]
        ,MIN(CASE WHEN [FieldName] = 'JhZENRmC3A6xI9bQ_date-duty-of-candour-letter-sent' THEN [Value] END) AS [JhZENRmC3A6xI9bQ_date-duty-of-candour-letter-sent]
        ,MIN(CASE WHEN [FieldName] = 'iZsv5-RmlL06bn-w_reason-duty-of-candour-letter-no' THEN [Value] END) AS [iZsv5-RmlL06bn-w_reason-duty-of-candour-letter-no]
        ,MIN(CASE WHEN [FieldName] = 'VpaLHXhH2Gk0F7Bx_has-the-outcome-of-the-review-or' THEN [Value] END) AS [VpaLHXhH2Gk0F7Bx_has-the-outcome-of-the-review-or]
        ,MIN(CASE WHEN [FieldName] = 'YLsj5YIJcqEaZGyB_date-outcome-of-review-or-invest' THEN [Value] END) AS [YLsj5YIJcqEaZGyB_date-outcome-of-review-or-invest]
        ,MIN(CASE WHEN [FieldName] = 'oao7ugaoexkkQ41S_reason-outcome-of-review-or-inve' THEN [Value] END) AS [oao7ugaoexkkQ41S_reason-outcome-of-review-or-inve]
        ,MIN(CASE WHEN [FieldName] = 'sXRWExCBXMwFClfp_start-of-mdso-investigation' THEN [Value] END) AS [sXRWExCBXMwFClfp_start-of-mdso-investigation]
        ,MIN(CASE WHEN [FieldName] = 'o2WJulzEqABvEMOG_end-of-mdso-investigation' THEN [Value] END) AS [o2WJulzEqABvEMOG_end-of-mdso-investigation]
    FROM WorkflowFormValues
    GROUP BY EventID
),

WorkflowDateAgg AS
(
    SELECT
         inc.ID AS EventID
        ,MIN(CASE WHEN tasks.[Description] = 'Governance Triage' THEN tasks.[DueDate] END) AS [GovernanceTriage_DueDate]
        ,MIN(CASE WHEN tasks.[Description] = 'Governance Triage' THEN tasks.[CompletionDateTime] END) AS [GovernanceTriage_CompletedDate]
        ,MIN(CASE WHEN tasks.[Description] = 'Local Incident Review' THEN tasks.[DueDate] END) AS [LocalIncidentReview_DueDate]
        ,MIN(CASE WHEN tasks.[Description] = 'Local Incident Review' THEN tasks.[CompletionDateTime] END) AS [LocalIncidentReview_CompletedDate]
        ,MIN(CASE WHEN tasks.[Description] = 'MDSO Team Incident Review (LFPSE)' THEN tasks.[DueDate] END) AS [MDSOTeamIncidentReview_DueDate]
        ,MIN(CASE WHEN tasks.[Description] = 'MDSO Team Incident Review (LFPSE)' THEN tasks.[CompletionDateTime] END) AS [MDSOTeamIncidentReview_CompletedDate]
        ,MIN(CASE WHEN tasks.[Description] = 'MDSO Team Incident Review (LFPSE)' THEN tasks.[AssignedToUserId] END) AS [MDSOTeamIncidentReview_AssignedTo]
    FROM rad.RiskManagement_Incident inc
    INNER JOIN rad.Workflow_Instance inst
        ON inc.Id = inst.LinkedObjectId
       AND inst.LinkedObjectType = 3
    LEFT JOIN rad.Workflow_UserTask tasks
        ON inst.Id = tasks.WorkflowInstanceId
       AND tasks.[Description] IN ('Governance Triage', 'Local Incident Review', 'MDSO Team Incident Review (LFPSE)')
    WHERE inc.[RecordStatus] = '2'
      AND inc.[IncidentTypeId] = 187
      AND inc.[Created] >= @StartDate
      AND inc.[Created] <  DATEADD(DAY, 1, @EndDate)
    GROUP BY inc.ID
),

WorkflowUserAgg AS
(
    SELECT
         inc.ID AS EventID
        ,MIN(CASE WHEN tasks.[Description] = 'Governance Triage' THEN u.[DisplayName] END) AS [GovernanceTriage_User]
        ,MIN(CASE WHEN tasks.[Description] = 'Local Incident Review' THEN u.[DisplayName] END) AS [LocalIncidentReview_User]
        ,MIN(CASE WHEN tasks.[Description] = 'MDSO Team Incident Review (LFPSE)' THEN u.[DisplayName] END) AS [MDSO Team Incident Review (LFPSE)]
    FROM rad.RiskManagement_Incident inc
    INNER JOIN rad.Workflow_Instance inst
        ON inc.Id = inst.LinkedObjectId
       AND inst.LinkedObjectType = 3
    LEFT JOIN rad.Workflow_UserTask tasks
        ON inst.Id = tasks.WorkflowInstanceId
       AND tasks.[Description] IN ('Governance Triage', 'Local Incident Review', 'MDSO Team Incident Review (LFPSE)')
    LEFT JOIN rad.Radar_User u
        ON u.ID = tasks.[AssignedToUserId]
    WHERE inc.[RecordStatus] = '2'
      AND inc.[IncidentTypeId] = 187
      AND inc.[Created] >= @StartDate
      AND inc.[Created] <  DATEADD(DAY, 1, @EndDate)
    GROUP BY inc.ID
),

Tier2Lookup AS
(
    SELECT *
    FROM
    (
        SELECT
             [ValueCD]
            ,[ValueDSC]
            ,ROW_NUMBER() OVER
            (
                PARTITION BY [ValueCD]
                ORDER BY CASE
                            WHEN [DisplayName] = 'LFPSE Incident Form' THEN 1
                            WHEN [DisplayName] = 'LFPSE (NHS Event Version 5.6 and GSTT Option 3)' THEN 2
                            ELSE 99
                         END
            ) AS rn
        FROM [rad].[VwFormTemplate]
        WHERE [ValueCD] IS NOT NULL
          AND [FieldNM] = 'tier_2'
          AND [DisplayName] IN
          (
              'LFPSE Incident Form',
              'LFPSE (NHS Event Version 5.6 and GSTT Option 3)'
          )
    ) x
    WHERE rn = 1
)

SELECT
     X.[EventID]
    ,X.[EventURL]
    ,CASE WHEN X.[IncidentTypeId] = 187 THEN 'Incident' END AS [EventType]
    ,X.[IncidentSubTypeId] AS [EventSubType]
    ,X.[Reference]
    ,X.[Title]
    ,X.[EventDate]
    ,X.[ClosedDate]
    ,X.[CreatedDate]
    ,X.[LocationID] AS [LocationId]
    ,X.[Location]
    ,X.[Region]
    ,X.[ClinicalGroup_RegionTag]
    ,COALESCE(
        ic.[ValueDSC] COLLATE DATABASE_DEFAULT,
        a.[tier_1] COLLATE DATABASE_DEFAULT
    ) AS [IncidentClassification]
    ,COALESCE(
        isc.[ValueDSC] COLLATE DATABASE_DEFAULT,
        a.[tier_2] COLLATE DATABASE_DEFAULT
    ) AS [IncidentSub-Classification]
    ,a.[Patient_Involved] AS [DoesThisEventInvolveAPatient]
    ,a.[LFPSE_Patient_Involved] AS [DidIncidentOccurToPatientUnderTrustCare]
    ,a.[staff_related] AS [DoesThisIncidentInvolveActualOrPotentialHarmToStaff]
    ,a.[environment_related] AS [DoesThisIncidentInvolveActualOrPotentialHarmToEstatesFacilitiesOrTheEnvironment]
    ,a.[visitors_related] AS [DoesThisIncidentInvolveActualOrPotentialHarmToVisitorsMembersOfThePublicRelatives]
    ,d.[duty-of-candour] AS [IndicationOfWhetherTheAdverseEventMeetsTheRequirementsForDutyOfCandour]
    ,d.[-azp461PF-3UGjUP_please-select-the-reason-why-dut] AS [PleaseSelectReasonWhyDutyOfCandourIsNotRequired]
    ,d.[Hx74MY6bSrifRlA3_was-a-verbal-apology-given-by-wa] AS [WasAVerbalApologyGivenByWayOfDutyOfCandour]
    ,d.[fzbugArqbqxUBKax_date-verbal-apology-given] AS [DateVerbalApologyGiven]
    ,d.[i2FM2CtpqnSotID2_reason-verbal-apology-not-given] AS [ReasonVerbalApologyNotGiven]
    ,d.[BMQWV6AY3Qc2FUIn_was-a-duty-of-candour-letter-sen] AS [WasADutyOfCandourLetterSent]
    ,d.[JhZENRmC3A6xI9bQ_date-duty-of-candour-letter-sent] AS [DateDutyOfCandourLetterSent]
    ,d.[iZsv5-RmlL06bn-w_reason-duty-of-candour-letter-no] AS [ReasonDutyOfCandourLetterNotSent]
    ,d.[VpaLHXhH2Gk0F7Bx_has-the-outcome-of-the-review-or] AS [HasTheOutcomeOfTheReviewOrInvestigationBeenSharedWithTheRelevantPerson]
    ,d.[YLsj5YIJcqEaZGyB_date-outcome-of-review-or-invest] AS [DateOutcomeOfReviewOrInvestigationShared]
    ,d.[oao7ugaoexkkQ41S_reason-outcome-of-review-or-inve] AS [ReasonOutcomeOfReviewOrInvestigationNotSent]
    ,wd.[GovernanceTriage_DueDate]
    ,wd.[GovernanceTriage_CompletedDate]
    ,wd.[LocalIncidentReview_DueDate]
    ,wd.[LocalIncidentReview_CompletedDate]
    ,wu.[GovernanceTriage_User]
    ,wu.[LocalIncidentReview_User]
    ,wd.[MDSOTeamIncidentReview_DueDate]
    ,wd.[MDSOTeamIncidentReview_CompletedDate]
    ,wd.[MDSOTeamIncidentReview_AssignedTo]
    ,d.[sXRWExCBXMwFClfp_start-of-mdso-investigation] AS [StartDateOfMDSOReview]
    ,d.[o2WJulzEqABvEMOG_end-of-mdso-investigation]   AS [EndDateOfMDSOReview]
FROM BaseIncidents X
LEFT JOIN RequiredFormAgg a
    ON X.[EventID] = a.[EventID]
LEFT JOIN WorkflowFormAgg d
    ON X.[EventID] = d.[EventID]
LEFT JOIN WorkflowDateAgg wd
    ON X.[EventID] = wd.[EventID]
LEFT JOIN WorkflowUserAgg wu
    ON X.[EventID] = wu.[EventID]
LEFT JOIN [rad].[VwFormTemplate] ic
    ON a.[tier_1] = ic.[ValueCD] COLLATE database_default
   AND ic.[DisplayName] = 'LFPSE Incident Form'
   AND ic.[FieldNM] = 'tier_1'
LEFT JOIN Tier2Lookup isc
    ON REPLACE(a.[tier_2], ' ', '') COLLATE database_default
     = REPLACE(isc.[ValueCD], ' ', '') COLLATE database_default
WHERE wd.[MDSOTeamIncidentReview_AssignedTo] IS NOT NULL
",

    // ─── Execute the query ───────────────────────────────────────────────────────
    Source = Sql.Database(ServerName, DatabaseName, [Query = SqlQuery]),

    // ─── Type transformations ────────────────────────────────────────────────────
    TypedColumns = Table.TransformColumnTypes(Source, {
        {"EventID", Int64.Type},
        {"EventDate", type datetime},
        {"ClosedDate", type datetime},
        {"CreatedDate", type datetime},
        {"GovernanceTriage_DueDate", type datetime},
        {"GovernanceTriage_CompletedDate", type datetime},
        {"LocalIncidentReview_DueDate", type datetime},
        {"LocalIncidentReview_CompletedDate", type datetime},
        {"MDSOTeamIncidentReview_DueDate", type datetime},
        {"MDSOTeamIncidentReview_CompletedDate", type datetime},
        {"MDSOTeamIncidentReview_AssignedTo", Int64.Type},
        {"StartDateOfMDSOReview", type date},
        {"EndDateOfMDSOReview", type date}
    })
in
    TypedColumns
