# ADO Orchestrate Deployment Pipeline

This repository contains an Azure DevOps YAML pipeline (`Orchestrate_DP.yml`) and a revised deployment script (`scripts/DeploymentPipelines-DeployAll_Revised.ps1`) for Microsoft Fabric deployment pipelines.

## Attribution

This implementation is based on the `DeploymentPipelines-DeployAll.ps1` script developed by Microsoft.

Source:
- https://github.com/microsoft/fabric-samples/blob/main/features-samples/fabric-apis/DeploymentPipelines-DeployAll.ps1

Further details can be found in Microsoft’s article:
- [Automate your deployment pipeline with Fabric APIs](https://learn.microsoft.com/en-us/fabric/cicd/deployment-pipelines/pipeline-automation-fabric)

## How this pipeline works

The YAML defines two deployment stages:
- **Test**: deploys from `DevStageName` to `TestStageName`
- **Prod**: deploys from `TestStageName` to `ProdStageName` (depends on successful Test stage)

In each stage, the pipeline:
1. Acquires a Fabric API token from Microsoft Entra ID using service principal credentials.
2. Stores it as an output variable (`FABRIC_TOKEN`).
3. Runs `scripts/DeploymentPipelines-DeployAll_Revised.ps1` with pipeline/stage parameters.

## Azure DevOps setup (add YAML pipeline)

1. Push this repository to an Azure DevOps repo.
2. In Azure DevOps, go to **Pipelines** > **New pipeline**.
3. Choose your repository source and select this repo.
4. Select **Existing Azure Pipelines YAML file**.
5. Choose `Orchestrate_DP.yml`.
6. Save and run the pipeline.
7. If prompted, authorize variable groups and any protected resources.
8. Ensure Azure DevOps **Environments** named `Test` and `Production` exist (or update names in YAML).
9. (Optional) Configure approvals/checks on the `Production` environment.

## Quick Start (for less technical users)

Use this click path in Azure DevOps:

1. **Azure DevOps home** → **Projects** → open your project.
	- _Screenshot hint: capture the project landing page with left menu visible._
2. Left menu: **Pipelines** → **Pipelines**.
	- _Screenshot hint: show the “New pipeline” button in the top-right area._
3. Click **New pipeline**.
4. Select your code location (for example: **Azure Repos Git**).
5. Select this repository (`ADO_OrchestrateDP`).
6. Choose **Existing Azure Pipelines YAML file**.
	- _Screenshot hint: capture the YAML selection screen._
7. Pick `Orchestrate_DP.yml` and click **Continue**.
8. Click **Run** (or **Save** then **Run**) to start.
9. If prompted, click **Permit** for variable groups/resources.
10. To see progress: **Pipelines** → select run → open **Stage** (`Test` / `Prod`) → open job logs.

If you only remember one path, use: **Pipelines → New pipeline → Existing Azure Pipelines YAML file → Orchestrate_DP.yml → Run**.

## Variable groups and variables used

The YAML references these variable groups:
- `DPDemoS`
- `DPDemoNS`

The pipeline expects these variables (typically provided by variable groups):
- `tenantId` - Microsoft Entra tenant ID
- `servicePrincipalId` - App (client) ID
- `servicePrincipalKey` - Client secret (**secret variable**)
- `deploymentPipelineName` - Fabric deployment pipeline display name
- `DevStageName` - Source stage name for Test deployment
- `TestStageName` - Target stage name for Test deployment and source for Prod
- `ProdStageName` - Target stage name for Prod deployment
- `deploymentNote` - Optional deployment note

Runtime/output variable:
- `FABRIC_TOKEN` - Generated at runtime in each stage (`GetFabricToken` step) and passed as an environment variable to the deployment script.

## Notes

- Trigger is currently configured for pushes to the `dev` branch.
- Keep `servicePrincipalKey` in a secret variable (preferably in a locked variable group).
- The service principal must have required permissions in Fabric deployment pipelines and workspaces.
