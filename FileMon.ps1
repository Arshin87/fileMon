$global:data = [PSCustomObject]@{
    "FolderData" = @{

        'Desktop' = @{
            'items'     = @();
            'Recievers' = @('person1@email.com', 'person2@email.com', 'person3@email.com');
            'path'      = @('C:\Users\torbj\Desktop');
            'State'     = @(0)
        };

    }
    "Config"     = @{
        'Timer'     = 20000;
        'smtp'      = 'smtp.domain.com'
        'Sender'    = 'sender@email.com';
        'Subject'   = 'Newly created files';
        'Title'     = 'Newly created files';
        'Mailstate' = 0
    }
}


#Root path you want to monitor!
$monitorPath = 'C:\Users\Person\Desktop'
####################################################
#Watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.IncludeSubdirectories = $true
$watcher.Path = $monitorPath
$watcher.EnableRaisingEvents = $true
####################################################
#Timer
$timer = New-Object Timers.Timer
$timer.Enabled = $True
$timer.AutoReset = $True
$timer.Interval = $data.Config.Timer



function stop-events {
    try {
        Unregister-Event -SourceIdentifier "Filesystem changes"
        Unregister-Event -SourceIdentifier "Sending Mails"
    }
    catch {
        Write-Host "Nothing was running"
    }


}

#Clears datastructire of items after mail is sent(So you dont get same info twise)
function clear-FolderData {

    $data.Config.Mailstate = 0;


    foreach ($FolderDataNames in $data.FolderData.Keys) {
        $data.FolderData.$FolderDataNames.Items = @()
    }

    foreach ($FolderDataNames in $data.FolderData.Keys) {
        $data.FolderData.$FolderDataNames.State = 0;
    }
    

}

#
function send-mail {
    
    #Get recipients and formats it ready to be used by send-mailmessage cmdlet.
    function get-recievers {
        $rec = foreach ($rec in $folder.$item.Recievers) {
            $recievers += "$($rec) "
        };
        
        return $recievers
    }

    $subject = $data.Config.Subject
    $smtp = $data.Config.smtp
    $from = $data.Config.Sender
    $folder = $data.FolderData

    #For each monitored folder in datastrucutre check state "1 waiting to send, 0 nothing to send"
    foreach ($item in $folder.keys) {
        if ($folder.$item.State -eq 1) {

            switch ($item) {
                Desktop { 
                    $rec = get-recievers;
                    $htmlbody = new-html($data.FolderData.$item.Items);
                    foreach ($rec in $data.FolderData.$item.Recievers) {
                        Send-MailMessage -To "$($rec)" -from "$($from)" -Subject "$($Subject)" -SmtpServer "$($smtp)" -BodyAsHtml $htmlbody
                    }
                }
                
                Default {}
            }
        }
    
    }


}

function new-html([System.Object]$currentObject) {

    #Builds HTML that is used in the mail output

    $content = "<ul>"
    foreach ($obj in $currentObject) {
        $content += "<li> Name: "
        $content += $obj.FullPath
        $content += "</li>"
        $content += "<li> FilePath: "
        $content += $obj.FilePath
        $content += "</li>"
        $content += "<li> TimeStamp: "
        $content += $obj.TimeStamp
        $content += "</li>"
        $content += "<br>"
    }
    $content += "</ul>"
        
    $htmlbody = @" 
        <!DOCTYPE html>
        <html>
            <head>
                <title>$($data.Config.Subject)</title>
                <meta charset="utf-8">
            </head>
         <body>
            <p>
                <h1>$($data.Config.Title)</h1>
                <h3>
                <table>
                $content
                </table>
               </h3>
            </p>
        </body>
        </html> 
"@
    
    return $htmlbody
    
}



####################################################
#   Main Code runs here! To stop use cmdlet stop-filemon
####################################################

#Action triggered on Event (created).
$watcherAction = {

    $fullPath = $event.SourceEventArgs.FullPath
    $filePath = Split-Path -Path $fullPath
    $changeType = $event.SourceEventArgs.ChangeType
    $name = Split-Path $event.SourceEventArgs.Name
    $timestamp = $event.TimeGenerated
    $isPath = (Get-Item $fullPath) -is [System.IO.DirectoryInfo]

    switch ($filePath) {
        #Adds data from directory to datastructure
        $data.FolderData.Desktop.path {
            $global:data.FolderData.Desktop.items += [pscustomobject]@{Name = $name; FilePath = $filePath; isFolder = $isPath; Type = $changeType; FullPath = $fullPath; TimeStamp = $timestamp }; 
            $($data.Config.Mailstate = 1); $($data.FolderData.Desktop.State = 1); break 
        }
        Default {}
    }

}

#Action triggered on event (Elapsed)
$mailAction = {

    Write-Host -NoNewline '.'
    send-mail
    clear-FolderData

}

Register-ObjectEvent -SourceIdentifier "Filesystem changes" $watcher 'Created' -Action $watcherAction
Register-ObjectEvent -SourceIdentifier "Sending Mails" $timer 'Elapsed' -Action $mailAction
