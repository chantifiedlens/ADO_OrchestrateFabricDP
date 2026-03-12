param(
[string]$deploymentPipelineName,
[string]$sourceStageName,
[string]$targetStageName,
[string]$deploymentNote
)

# =============================
# Configuration
# =============================

$global:baseUrl = "https://api.fabric.microsoft.com/v1"
$global:fabricHeaders = @{ }

# =============================
# Logging Helpers
# =============================

function LogInfo($message) {
    Write-Host "[INFO ] $message"
}

function LogWarn($message) {
    Write-Host "[WARN ] $message"
}

function LogError($message) {
    Write-Host "[ERROR] $message"
}

# =============================
# Authentication Setup
# =============================

function SetFabricHeaders($token) {

    if ([string]::IsNullOrEmpty($token)) {
        throw "Fabric token was not provided via pipeline environment variable"
    }

    LogInfo "Setting Fabric authentication headers"

    $global:fabricHeaders = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $token"
    }

    LogInfo "Fabric headers initialized successfully"
}

# =============================
# REST Wrapper
# =============================

function Invoke-FabricRest {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        $Body = $null
    )

    LogInfo "$Method $Uri"

    try {

        if ($Body) {
            return Invoke-RestMethod `
                -Uri $Uri `
                -Method $Method `
                -Headers $global:fabricHeaders `
                -Body ($Body | ConvertTo-Json -Depth 10) `
                -ContentType "application/json"
        }
        else {
            return Invoke-RestMethod `
                -Uri $Uri `
                -Method $Method `
                -Headers $global:fabricHeaders
        }

    }
    catch {

        if ($_.Exception.Response) {

            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()

                LogError $reader.ReadToEnd()
            }
            catch {
                LogError $_.Exception.Message
            }
        }

        throw $_
    }
}

# =============================
# Main Execution
# =============================

try {

    LogInfo "Starting Fabric deployment script"

    # ⭐ Pipeline token injection (enterprise pattern)
    $fabricToken = $env:FABRIC_TOKEN

    SetFabricHeaders $fabricToken

    LogInfo "Validating pipeline and stages..."

    $pipelines = Invoke-RestMethod `
        -Headers $global:fabricHeaders `
        -Uri "$global:baseUrl/deploymentPipelines" `
        -Method GET

    $deploymentPipeline = $pipelines.value |
        Where-Object { $_.DisplayName -eq $deploymentPipelineName }

    if (!$deploymentPipeline) {
        throw "Pipeline not found"
    }

    $stages = Invoke-RestMethod `
        -Headers $global:fabricHeaders `
        -Uri "$global:baseUrl/deploymentPipelines/$($deploymentPipeline.id)/stages" `
        -Method GET

    $sourceStage = $stages.value |
        Where-Object { $_.DisplayName -eq $sourceStageName }

    $targetStage = $stages.value |
        Where-Object { $_.DisplayName -eq $targetStageName }

    if (!$sourceStage -or !$targetStage) {
        throw "Stage validation failed"
    }

    LogInfo "Starting deployment operation..."

    $deployUrl = "$global:baseUrl/deploymentPipelines/$($deploymentPipeline.id)/deploy"

    $deployBody = @{
        sourceStageId = $sourceStage.id
        targetStageId = $targetStage.id
        note = $deploymentNote
    }

    $deployResponse = Invoke-WebRequest `
        -Headers $global:fabricHeaders `
        -Uri $deployUrl `
        -Method POST `
        -Body ($deployBody | ConvertTo-Json -Depth 10)

    $operationId = $deployResponse.Headers["x-ms-operation-id"]

    if (-not $operationId) {
        throw "Operation ID not returned"
    }

    $retryAfter = $deployResponse.Headers["Retry-After"]

    # Headers come back as string arrays → take first value and convert to int
    if ($retryAfter) {
        $retryAfter = [int]$retryAfter[0]
    }
    else {
        $retryAfter = 5
    }

    LogInfo "Operation ID = $operationId"

    $operationUrl = "$global:baseUrl/operations/$operationId"

    do {

        $operationState = Invoke-RestMethod `
            -Headers $global:fabricHeaders `
            -Uri $operationUrl `
            -Method GET

        LogInfo "Deployment status = $($operationState.Status)"

        if ($operationState.Status -in @("NotStarted","Running")) {
            Start-Sleep -Seconds $retryAfter
        }

    } while ($operationState.Status -in @("NotStarted","Running"))

    if ($operationState.Status -eq "Failed") {
        throw "Deployment failed: $($operationState.Error | ConvertTo-Json -Depth 10)"
    }

    LogInfo "Deployment completed successfully"
}
catch {
    LogError $_.Exception.Message
    exit 1
}