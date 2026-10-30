param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

function Read-DotEnv {
    param([string]$Path)

    $values = @{}
    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match "^\s*#" -or $_ -notmatch "=") {
            return
        }

        $key, $value = $_ -split "=", 2
        $values[$key.Trim()] = $value.Trim()
    }

    return $values
}

function Resolve-Template {
    param(
        [string]$TemplatePath,
        [hashtable]$EnvValues,
        [hashtable]$ExtraValues = @{}
    )

    $body = Get-Content -Raw -Path $TemplatePath
    foreach ($key in $EnvValues.Keys) {
        $body = $body.Replace("`${$key}", $EnvValues[$key])
    }
    foreach ($key in $ExtraValues.Keys) {
        $body = $body.Replace("`${$key}", $ExtraValues[$key])
    }
    return $body
}

function Register-Connector {
    param(
        [string]$Name,
        [string]$TemplatePath,
        [hashtable]$EnvValues,
        [hashtable]$ExtraValues = @{}
    )

    $body = Resolve-Template -TemplatePath $TemplatePath -EnvValues $EnvValues -ExtraValues $ExtraValues
    $uri = "http://localhost:8083/connectors/$Name/config"

    Write-Host "Registering Iceberg sink connector $Name"
    $registered = Invoke-RestMethod -Method Put -Uri $uri -Body $body -ContentType "application/json"
    Write-Host "Registered $($registered.name); task assignments will appear after startup."
}

if (-not (Test-Path $EnvFile)) {
    throw "Expected $EnvFile to exist. Copy .env.example to .env first."
}

$plugins = Invoke-RestMethod -Uri "http://localhost:8083/connector-plugins" -TimeoutSec 20
$icebergPlugin = $plugins | Where-Object { $_.class -eq "org.apache.iceberg.connect.IcebergSinkConnector" }
if (-not $icebergPlugin) {
    throw "IcebergSinkConnector is not loaded. Run '.\scripts\setup.ps1 plugin:iceberg', restart Kafka Connect, and try again."
}

$envValues = Read-DotEnv -Path $EnvFile
if (-not $envValues.ContainsKey("ICEBERG_CONTROL_TOPIC")) {
    $envValues["ICEBERG_CONTROL_TOPIC"] = "mbs_iceberg_control"
}
$prefix = if ($envValues.ContainsKey("KAFKA_TOPIC_PREFIX")) { $envValues["KAFKA_TOPIC_PREFIX"] } else { "mbs_poc" }
$currentDb = "EKYC_ICICI"
$archivedDb = "EKYC_ICICI_Archived"
$templatePath = "infra/kafka-connect/connectors/iceberg-dsb-raw-sink.template.json"

$mappings = @(
    @{ Suffix = "customer-lead"; Topic = "$prefix.$currentDb.dbo.Customer_Lead"; Table = "raw.customer_lead_cdc_connect" },
    @{ Suffix = "customer-lead-icici"; Topic = "$prefix.$currentDb.dbo.Customer_Lead_ICICI"; Table = "raw.customer_lead_icici_cdc_connect" },
    @{ Suffix = "change-pincode-log"; Topic = "$prefix.$currentDb.dbo.ChangePincode_log"; Table = "raw.change_pincode_log_cdc_connect" },
    @{ Suffix = "service-request-assign-log"; Topic = "$prefix.$currentDb.dbo.ServiceRequestAssignLog"; Table = "raw.service_request_assign_log_cdc_connect" },
    @{ Suffix = "sr-status-update-log"; Topic = "$prefix.$currentDb.dbo.SRStatusUpdateLog"; Table = "raw.sr_status_update_log_cdc_connect" },
    @{ Suffix = "mas-pincode"; Topic = "$prefix.$currentDb.dbo.MasPincode"; Table = "raw.mas_pincode_cdc_connect" },
    @{ Suffix = "mas-pincode-mis-hdfc"; Topic = "$prefix.$currentDb.dbo.Mas_Pincode_For_MIS_HDFC"; Table = "raw.mas_pincode_for_mis_hdfc_cdc_connect" },
    @{ Suffix = "mst-campaign-leads"; Topic = "$prefix.$currentDb.dbo.MstCampaignLeads"; Table = "raw.mst_campaign_leads_cdc_connect" },
    @{ Suffix = "mbs-user"; Topic = "$prefix.$currentDb.dbo.MBSUser"; Table = "raw.mbs_user_cdc_connect" },
    @{ Suffix = "customer-lead-archived"; Topic = "$prefix.$archivedDb.dbo.Customer_Lead_Archived"; Table = "raw.customer_lead_archived_cdc_connect" },
    @{ Suffix = "customer-lead-purge-details"; Topic = "$prefix.$archivedDb.dbo.Customer_Lead_purge_details"; Table = "raw.customer_lead_purge_details_cdc_connect" },
    @{ Suffix = "service-request-assign-log-archieved"; Topic = "$prefix.$archivedDb.dbo.ServiceRequestAssignLog_archieved"; Table = "raw.service_request_assign_log_archieved_cdc_connect" },
    @{ Suffix = "service-request-assign-log-purge-details"; Topic = "$prefix.$archivedDb.dbo.ServiceRequestAssignLog_purge_details"; Table = "raw.service_request_assign_log_purge_details_cdc_connect" },
    @{ Suffix = "sr-status-update-log-archieved"; Topic = "$prefix.$archivedDb.dbo.SRStatusUpdateLog_archieved"; Table = "raw.sr_status_update_log_archieved_cdc_connect" },
    @{ Suffix = "sr-status-update-log-purge-details"; Topic = "$prefix.$archivedDb.dbo.SRStatusUpdateLog_purge_details"; Table = "raw.sr_status_update_log_purge_details_cdc_connect" }
)

foreach ($mapping in $mappings) {
    Register-Connector `
        -Name "mbs-iceberg-$($mapping.Suffix)-raw-sink" `
        -TemplatePath $templatePath `
        -EnvValues $envValues `
        -ExtraValues @{
            CONNECT_TOPIC = $mapping.Topic
            ICEBERG_TABLE = $mapping.Table
        }
}
