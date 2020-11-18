$token = "1491600444:AAH12RVE2kqI-npA3jqSC5N9rgoCkWxmvk4"
$baseUrl = "https://api.telegram.org/bot$token/"

$updatesOffsetStorageFileName = "$PSScriptRoot\offset_storage";

function log($msg) {
    Write-Information -MessageData  $msg -InformationAction Continue;
}

function isExistOffsetStorage() {
    return Test-Path -path $updatesOffsetStorageFileName;
}

function createOffsetStorage() {
    $status = isExistOffsetStorage;
    if ($status -eq $False) {
        log("create offset storage");
        New-Item $updatesOffsetStorageFileName;
    }
}

function writeToOffsetStorage($text) {
    $text | Set-Content $updatesOffsetStorageFileName
}

function getOffsetFromStorage() {
    if (isExistOffsetStorage) {
        return Get-Content -Path $updatesOffsetStorageFileName -TotalCount 1
    }
    else {
        throw 'storage not found';
    }
}

function setSleepInterval($time = 5) {
    log("Start sleep; time: $time");
    Start-Sleep -s $time;
}

function request($path, $body) {
    log("request: $path");
    $response = Invoke-WebRequest -UseBasicParsing -Uri ($baseUrl + $path) -Method POST -Body $body;
    log("response: $response");

    return $response | ConvertFrom-Json;
}

function validateResponse($response) {
    if (!$response.ok) {
        throw 'bad respose';
    }
}

function getUpdates($timeout = 15) {
    $status = isExistOffsetStorage;
    if ($status -eq $true) {
        $offsetFromStorage = getOffsetFromStorage;
        $offset = [int]$offsetFromStorage + 1;
        log("Send getUpdates. Wait events. timeout=$timeout; offset=$offset");
        return request("getUpdates?timeout=$timeout&offset=$offset");
    }

    log("Send getUpdates. Wait events. timeout=$timeout");
    return request("getUpdates?timeout=$timeout");
}

function sendMessage($msg) {
    #need validation requeries params
    $postParams = @{
        chat_id = $msg.chat.id;
        text = $msg.text
    }

    Invoke-WebRequest -UseBasicParsing -Uri ($baseUrl + "sendMessage") -Method POST -Body $postParams;
}

function processMessages($resultArr) {
    if ($resultArr.count -lt 1) {
        return;
    }

    log("start process messages");

    foreach ($msg in $resultArr) {
        $msgObj = $msg.message;
        if ($msgObj) {
            sendMessage($msgObj);
        }
    }

    log("end process messages");
}

function saveLastUpdateId($result) {
    if (isExistOffsetStorage -eq $false) {
        createOffsetStorage;
    }

    writeToOffsetStorage($result[$result.count - 1].update_id);
}

while ($true) {
    #send long pool request
    $response = getUpdates;

    if (!$response.ok) {
        log("getUpdates failure. "); setSleepInterval; continue;
    }
    elseif  (!$response.result.count) {
        log("getUpdates success. response.result is empty"); setSleepInterval; continue;
    }

    #start messages processor
    processMessages($response.result);

    #save last update id
    saveLastUpdateId($response.result);
    setSleepInterval;
}