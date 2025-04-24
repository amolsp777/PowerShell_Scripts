#@=============================================
#@ FileName:Get-DCDiag_ReportAMOL.ps1
#@=============================================
#@ Script Name: Get-DCDiag_ReportAMOL
#@ Created [DATE_DMY]:  04.12.2015
#@ Updated [DATE_DMY]:  06.Sept.2018
#@ Author: Amol Patil
#@ Email: amolsp777@live.com
#@ Web: 
#@ Requirements: 
#@ OS: Widndows 2008 and latest DC
#@ Version History: 0.1
#@=============================================
#@ Purpose:
#@ Get DCdiag output & DC replication information from DCs in the Domain.
#@ Added DC service Check / PORT check(New Format)
#@ FAST Process with Parallel command - 06/Sept/2018
#@=============================================

#@================Code Start===================


$ErrorActionPreference = "SilentlyContinue"
# Get Start Time | to get the total elepsed time to complete this script.
$startMain = (Get-Date) 

Write-Host "$(Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]")" -ForegroundColor Yellow -NoNewline
Write-Host " START"


#region Script Directory 
function Get-ScriptDirectory 
{  
    if($hostinvocation -ne $null) 
    { 
        Split-Path $hostinvocation.MyCommand.path 
    } 
    else 
    { 
        Split-Path $script:MyInvocation.MyCommand.Path 
    } 
} 
 
 
$SCRIPT_PARENT  = Get-ScriptDirectory  
#endregion 

#region Invoke-Parallel
function Invoke-Parallel {
    <#
    .SYNOPSIS
        Function to control parallel processing using runspaces
    .DESCRIPTION
        Function to control parallel processing using runspaces
            Note that each runspace will not have access to variables and commands loaded in your session or in other runspaces by default.  
            This behaviour can be changed with parameters.
    .PARAMETER ScriptFile
        File to run against all input objects.  Must include parameter to take in the input object, or use $args.  Optionally, include parameter to take in parameter.  Example: C:\script.ps1
    .PARAMETER ScriptBlock
        Scriptblock to run against all computers.
        You may use $Using:<Variable> language in PowerShell 3 and later.
        
            The parameter block is added for you, allowing behaviour similar to foreach-object:
                Refer to the input object as $_.
                Refer to the parameter parameter as $parameter
    .PARAMETER InputObject
        Run script against these specified objects.
    .PARAMETER Parameter
        This object is passed to every script block.  You can use it to pass information to the script block; for example, the path to a logging folder
        
            Reference this object as $parameter if using the scriptblock parameterset.
    .PARAMETER ImportVariables
        If specified, get user session variables and add them to the initial session state
    .PARAMETER ImportModules
        If specified, get loaded modules and pssnapins, add them to the initial session state
    .PARAMETER Throttle
        Maximum number of threads to run at a single time.
    .PARAMETER SleepTimer
        Milliseconds to sleep after checking for completed runspaces and in a few other spots.  I would not recommend dropping below 200 or increasing above 500
    .PARAMETER RunspaceTimeout
        Maximum time in seconds a single thread can run.  If execution of your code takes longer than this, it is disposed.  Default: 0 (seconds)
        WARNING:  Using this parameter requires that maxQueue be set to throttle (it will be by default) for accurate timing.  Details here:
        http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430
    .PARAMETER NoCloseOnTimeout
              Do not dispose of timed out tasks or attempt to close the runspace if threads have timed out. This will prevent the script from hanging in certain situations where threads become non-responsive, at the expense of leaking memory within the PowerShell host.
    .PARAMETER MaxQueue
        Maximum number of powershell instances to add to runspace pool.  If this is higher than $throttle, $timeout will be inaccurate
        
        If this is equal or less than throttle, there will be a performance impact
        The default value is $throttle times 3, if $runspaceTimeout is not specified
        The default value is $throttle, if $runspaceTimeout is specified
    .PARAMETER LogFile
        Path to a file where we can log results, including run time for each thread, whether it completes, completes with errors, or times out.
       .PARAMETER Quiet
              Disable progress bar.
    .EXAMPLE
        Each example uses Test-ForPacs.ps1 which includes the following code:
            param($computer)
            if(test-connection $computer -count 1 -quiet -BufferSize 16){
                $object = [pscustomobject] @{
                    Computer=$computer;
                    Available=1;
                    Kodak=$(
                        if((test-path "\\$computer\c$\users\public\desktop\Kodak Direct View Pacs.url") -or (test-path "\\$computer\c$\documents and settings\all users
        \desktop\Kodak Direct View Pacs.url") ){"1"}else{"0"}
                    )
                }
            }
            else{
                $object = [pscustomobject] @{
                    Computer=$computer;
                    Available=0;
                    Kodak="NA"
                }
            }
            $object
    .EXAMPLE
        Invoke-Parallel -scriptfile C:\public\Test-ForPacs.ps1 -inputobject $(get-content C:\pcs.txt) -runspaceTimeout 10 -throttle 10
            Pulls list of PCs from C:\pcs.txt,
            Runs Test-ForPacs against each
            If any query takes longer than 10 seconds, it is disposed
            Only run 10 threads at a time
    .EXAMPLE
        Invoke-Parallel -scriptfile C:\public\Test-ForPacs.ps1 -inputobject c-is-ts-91, c-is-ts-95
            Runs against c-is-ts-91, c-is-ts-95 (-computername)
            Runs Test-ForPacs against each
    .EXAMPLE
        $stuff = [pscustomobject] @{
            ContentFile = "windows\system32\drivers\etc\hosts"
            Logfile = "C:\temp\log.txt"
        }
    
        $computers | Invoke-Parallel -parameter $stuff {
            $contentFile = join-path "\\$_\c$" $parameter.contentfile
            Get-Content $contentFile |
                set-content $parameter.logfile
        }
        This example uses the parameter argument.  This parameter is a single object.  To pass multiple items into the script block, we create a custom object (using a PowerShell v3 language) with properties we want to pass in.
        Inside the script block, $parameter is used to reference this parameter object.  This example sets a content file, gets content from that file, and sets it to a predefined log file.
    .EXAMPLE
        $test = 5
        1..2 | Invoke-Parallel -ImportVariables {$_ * $test}
        Add variables from the current session to the session state.  Without -ImportVariables $Test would not be accessible
    .EXAMPLE
        $test = 5
        1..2 | Invoke-Parallel -ImportVariables {$_ * $Using:test}
        Reference a variable from the current session with the $Using:<Variable> syntax.  Requires PowerShell 3 or later.
    .FUNCTIONALITY
        PowerShell Language
    .NOTES
        Credit to Boe Prox for the base runspace code and $Using implementation
            http://learn-powershell.net/2012/05/10/speedy-network-information-query-using-powershell/
            http://gallery.technet.microsoft.com/scriptcenter/Speedy-Network-Information-5b1406fb#content
            https://github.com/proxb/PoshRSJob/
        Credit to T Bryce Yehl for the Quiet and NoCloseOnTimeout implementations
        Credit to Sergei Vorobev for the many ideas and contributions that have improved functionality, reliability, and ease of use
    .LINK
        https://github.com/RamblingCookieMonster/Invoke-Parallel
    #>
    [cmdletbinding(DefaultParameterSetName='ScriptBlock')]
    Param (   
        [Parameter(Mandatory=$false,position=0,ParameterSetName='ScriptBlock')]
            [System.Management.Automation.ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory=$false,ParameterSetName='ScriptFile')]
        [ValidateScript({test-path $_ -pathtype leaf})]
            $ScriptFile,

        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Alias('CN','__Server','IPAddress','Server','ComputerName')]    
            [PSObject]$InputObject,

            [PSObject]$Parameter,

            [switch]$ImportVariables,

            [switch]$ImportModules,

            [int]$Throttle = 20,

            [int]$SleepTimer = 200,

            [int]$RunspaceTimeout = 0,

                     [switch]$NoCloseOnTimeout = $false,

            [int]$MaxQueue,

        [validatescript({Test-Path (Split-Path $_ -parent)})]
            [string]$LogFile = "C:\temp\log.log",

                     [switch] $Quiet = $false
    )
    
    Begin {
                
        #No max queue specified?  Estimate one.
        #We use the script scope to resolve an odd PowerShell 2 issue where MaxQueue isn't seen later in the function
        if( -not $PSBoundParameters.ContainsKey('MaxQueue') )
        {
            if($RunspaceTimeout -ne 0){ $script:MaxQueue = $Throttle }
            else{ $script:MaxQueue = $Throttle * 3 }
        }
        else
        {
            $script:MaxQueue = $MaxQueue
        }

        Write-Verbose "Throttle: '$throttle' SleepTimer '$sleepTimer' runSpaceTimeout '$runspaceTimeout' maxQueue '$maxQueue' logFile '$logFile'"

        #If they want to import variables or modules, create a clean runspace, get loaded items, use those to exclude items
        if ($ImportVariables -or $ImportModules)
        {
            $StandardUserEnv = [powershell]::Create().addscript({

                #Get modules and snapins in this clean runspace
                $Modules = Get-Module | Select -ExpandProperty Name
                $Snapins = Get-PSSnapin | Select -ExpandProperty Name

                #Get variables in this clean runspace
                #Called last to get vars like $? into session
                $Variables = Get-Variable | Select -ExpandProperty Name
                
                #Return a hashtable where we can access each.
                @{
                    Variables = $Variables
                    Modules = $Modules
                    Snapins = $Snapins
                }
            }).invoke()[0]
            
            if ($ImportVariables) {
                #Exclude common parameters, bound parameters, and automatic variables
                Function _temp {[cmdletbinding()] param() }
                $VariablesToExclude = @( (Get-Command _temp | Select -ExpandProperty parameters).Keys + $PSBoundParameters.Keys + $StandardUserEnv.Variables )
                Write-Verbose "Excluding variables $( ($VariablesToExclude | sort ) -join ", ")"

                # we don't use 'Get-Variable -Exclude', because it uses regexps. 
                # One of the veriables that we pass is '$?'. 
                # There could be other variables with such problems.
                # Scope 2 required if we move to a real module
                $UserVariables = @( Get-Variable | Where { -not ($VariablesToExclude -contains $_.Name) } ) 
                Write-Verbose "Found variables to import: $( ($UserVariables | Select -expandproperty Name | Sort ) -join ", " | Out-String).`n"

            }

            if ($ImportModules) 
            {
                $UserModules = @( Get-Module | Where {$StandardUserEnv.Modules -notcontains $_.Name -and (Test-Path $_.Path -ErrorAction SilentlyContinue)} | Select -ExpandProperty Path )
                $UserSnapins = @( Get-PSSnapin | Select -ExpandProperty Name | Where {$StandardUserEnv.Snapins -notcontains $_ } ) 
            }
        }

        #region functions
            
            Function Get-RunspaceData {
                [cmdletbinding()]
                param( [switch]$Wait )

                #loop through runspaces
                #if $wait is specified, keep looping until all complete
                Do {

                    #set more to false for tracking completion
                    $more = $false

                    #Progress bar if we have inputobject count (bound parameter)
                    if (-not $Quiet) {
                                         Write-Progress  -Activity "Running Query" -Status "Starting threads"`
                                                -CurrentOperation "$startedCount threads defined - $totalCount input objects - $script:completedCount input objects processed"`
                                                -PercentComplete $( Try { $script:completedCount / $totalCount * 100 } Catch {0} )
                                  }

                    #run through each runspace.           
                    Foreach($runspace in $runspaces) {
                    
                        #get the duration - inaccurate
                        $currentdate = Get-Date
                        $runtime = $currentdate - $runspace.startTime
                        $runMin = [math]::Round( $runtime.totalminutes ,2 )

                        #set up log object
                        $log = "" | select Date, Action, Runtime, Status, Details
                        $log.Action = "Removing:'$($runspace.object)'"
                        $log.Date = $currentdate
                        $log.Runtime = "$runMin minutes"

                        #If runspace completed, end invoke, dispose, recycle, counter++
                        If ($runspace.Runspace.isCompleted) {
                            
                            $script:completedCount++
                        
                            #check if there were errors
                            if($runspace.powershell.Streams.Error.Count -gt 0) {
                                
                                #set the logging info and move the file to completed
                                $log.status = "CompletedWithErrors"
                                Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                                foreach($ErrorRecord in $runspace.powershell.Streams.Error) {
                                    Write-Error -ErrorRecord $ErrorRecord
                                }
                            }
                            else {
                                
                                #add logging details and cleanup
                                $log.status = "Completed"
                                Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                            }

                            #everything is logged, clean up the runspace
                            $runspace.powershell.EndInvoke($runspace.Runspace)
                            $runspace.powershell.dispose()
                            $runspace.Runspace = $null
                            $runspace.powershell = $null

                        }

                        #If runtime exceeds max, dispose the runspace
                        ElseIf ( $runspaceTimeout -ne 0 -and $runtime.totalseconds -gt $runspaceTimeout) {
                            
                            $script:completedCount++
                            $timedOutTasks = $true
                            
                                                #add logging details and cleanup
                            $log.status = "TimedOut"
                            Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                            Write-Error "Runspace timed out at $($runtime.totalseconds) seconds for the object:`n$($runspace.object | out-string)"

                            #Depending on how it hangs, we could still get stuck here as dispose calls a synchronous method on the powershell instance
                            if (!$noCloseOnTimeout) { $runspace.powershell.dispose() }
                            $runspace.Runspace = $null
                            $runspace.powershell = $null
                            $completedCount++

                        }
                   
                        #If runspace isn't null set more to true  
                        ElseIf ($runspace.Runspace -ne $null ) {
                            $log = $null
                            $more = $true
                        }

                        #log the results if a log file was indicated
                        if($logFile -and $log){
                            ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1] | out-file $LogFile -append
                        }
                    }

                    #Clean out unused runspace jobs
                    $temphash = $runspaces.clone()
                    $temphash | Where { $_.runspace -eq $Null } | ForEach {
                        $Runspaces.remove($_)
                    }

                    #sleep for a bit if we will loop again
                    if($PSBoundParameters['Wait']){ Start-Sleep -milliseconds $SleepTimer }

                #Loop again only if -wait parameter and there are more runspaces to process
                } while ($more -and $PSBoundParameters['Wait'])
                
            #End of runspace function
            }

        #endregion functions
        
        #region Init

            if($PSCmdlet.ParameterSetName -eq 'ScriptFile')
            {
                $ScriptBlock = [scriptblock]::Create( $(Get-Content $ScriptFile | out-string) )
            }
            elseif($PSCmdlet.ParameterSetName -eq 'ScriptBlock')
            {
                #Start building parameter names for the param block
                [string[]]$ParamsToAdd = '$_'
                if( $PSBoundParameters.ContainsKey('Parameter') )
                {
                    $ParamsToAdd += '$Parameter'
                }

                $UsingVariableData = $Null
                

                # This code enables $Using support through the AST.
                # This is entirely from  Boe Prox, and his https://github.com/proxb/PoshRSJob module; all credit to Boe!
                
                if($PSVersionTable.PSVersion.Major -gt 2)
                {
                    #Extract using references
                    $UsingVariables = $ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]},$True)    

                    If ($UsingVariables)
                    {
                        $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
                        ForEach ($Ast in $UsingVariables)
                        {
                            [void]$list.Add($Ast.SubExpression)
                        }

                        $UsingVar = $UsingVariables | Group Parent | ForEach {$_.Group | Select -First 1}
        
                        #Extract the name, value, and create replacements for each
                        $UsingVariableData = ForEach ($Var in $UsingVar) {
                            Try
                            {
                                $Value = Get-Variable -Name $Var.SubExpression.VariablePath.UserPath -ErrorAction Stop
                                $NewName = ('$__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                                [pscustomobject]@{
                                    Name = $Var.SubExpression.Extent.Text
                                    Value = $Value.Value
                                    NewName = $NewName
                                    NewVarName = ('__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                                }
                                $ParamsToAdd += $NewName
                            }
                            Catch
                            {
                                Write-Error "$($Var.SubExpression.Extent.Text) is not a valid Using: variable!"
                            }
                        }
    
                        $NewParams = $UsingVariableData.NewName -join ', '
                        $Tuple = [Tuple]::Create($list, $NewParams)
                        $bindingFlags = [Reflection.BindingFlags]"Default,NonPublic,Instance"
                        $GetWithInputHandlingForInvokeCommandImpl = ($ScriptBlock.ast.gettype().GetMethod('GetWithInputHandlingForInvokeCommandImpl',$bindingFlags))
        
                        $StringScriptBlock = $GetWithInputHandlingForInvokeCommandImpl.Invoke($ScriptBlock.ast,@($Tuple))

                        $ScriptBlock = [scriptblock]::Create($StringScriptBlock)

                        Write-Verbose $StringScriptBlock
                    }
                }
                
                $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($ParamsToAdd -Join ", "))`r`n" + $Scriptblock.ToString())
            }
            else
            {
                Throw "Must provide ScriptBlock or ScriptFile"; Break
            }

            Write-Debug "`$ScriptBlock: $($ScriptBlock | Out-String)"
            Write-Verbose "Creating runspace pool and session states"

            #If specified, add variables and modules/snapins to session state
            $sessionstate = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
            if ($ImportVariables)
            {
                if($UserVariables.count -gt 0)
                {
                    foreach($Variable in $UserVariables)
                    {
                        $sessionstate.Variables.Add( (New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null) )
                    }
                }
            }
            if ($ImportModules)
            {
                if($UserModules.count -gt 0)
                {
                    foreach($ModulePath in $UserModules)
                    {
                        $sessionstate.ImportPSModule($ModulePath)
                    }
                }
                if($UserSnapins.count -gt 0)
                {
                    foreach($PSSnapin in $UserSnapins)
                    {
                        [void]$sessionstate.ImportPSSnapIn($PSSnapin, [ref]$null)
                    }
                }
            }

            #Create runspace pool
            $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
            $runspacepool.Open() 

            Write-Verbose "Creating empty collection to hold runspace jobs"
            $Script:runspaces = New-Object System.Collections.ArrayList        
        
            #If inputObject is bound get a total count and set bound to true
            $global:__bound = $false
            $allObjects = @()
            if( $PSBoundParameters.ContainsKey("inputObject") ){
                $global:__bound = $true
            }

            #Set up log file if specified
            if( $LogFile ){
                New-Item -ItemType file -path $logFile -force | Out-Null
                ("" | Select Date, Action, Runtime, Status, Details | ConvertTo-Csv -NoTypeInformation -Delimiter ";")[0] | Out-File $LogFile
            }

            #write initial log entry
            $log = "" | Select Date, Action, Runtime, Status, Details
                $log.Date = Get-Date
                $log.Action = "Batch processing started"
                $log.Runtime = $null
                $log.Status = "Started"
                $log.Details = $null
                if($logFile) {
                    ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1] | Out-File $LogFile -Append
                }

                     $timedOutTasks = $false

        #endregion INIT
    }

    Process {

        #add piped objects to all objects or set all objects to bound input object parameter
        if( -not $global:__bound ){
            $allObjects += $inputObject
        }
        else{
            $allObjects = $InputObject
        }
    }

    End {
        
        #Use Try/Finally to catch Ctrl+C and clean up.
        Try
        {
            #counts for progress
            $totalCount = $allObjects.count
            $script:completedCount = 0
            $startedCount = 0

            foreach($object in $allObjects){
        
                #region add scripts to runspace pool
                    
                    #Create the powershell instance, set verbose if needed, supply the scriptblock and parameters
                    $powershell = [powershell]::Create()
                    
                    if ($VerbosePreference -eq 'Continue')
                    {
                        [void]$PowerShell.AddScript({$VerbosePreference = 'Continue'})
                    }

                    [void]$PowerShell.AddScript($ScriptBlock).AddArgument($object)

                    if ($parameter)
                    {
                        [void]$PowerShell.AddArgument($parameter)
                    }

                    # $Using support from Boe Prox
                    if ($UsingVariableData)
                    {
                        Foreach($UsingVariable in $UsingVariableData) {
                            Write-Verbose "Adding $($UsingVariable.Name) with value: $($UsingVariable.Value)"
                            [void]$PowerShell.AddArgument($UsingVariable.Value)
                        }
                    }

                    #Add the runspace into the powershell instance
                    $powershell.RunspacePool = $runspacepool
    
                    #Create a temporary collection for each runspace
                    $temp = "" | Select-Object PowerShell, StartTime, object, Runspace
                    $temp.PowerShell = $powershell
                    $temp.StartTime = Get-Date
                    $temp.object = $object
    
                    #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
                    $temp.Runspace = $powershell.BeginInvoke()
                    $startedCount++

                    #Add the temp tracking info to $runspaces collection
                    Write-Verbose ( "Adding {0} to collection at {1}" -f $temp.object, $temp.starttime.tostring() )
                    $runspaces.Add($temp) | Out-Null
            
                    #loop through existing runspaces one time
                    Get-RunspaceData

                    #If we have more running than max queue (used to control timeout accuracy)
                    #Script scope resolves odd PowerShell 2 issue
                    $firstRun = $true
                    while ($runspaces.count -ge $Script:MaxQueue) {

                        #give verbose output
                        if($firstRun){
                            Write-Verbose "$($runspaces.count) items running - exceeded $Script:MaxQueue limit."
                        }
                        $firstRun = $false
                    
                        #run get-runspace data and sleep for a short while
                        Get-RunspaceData
                        Start-Sleep -Milliseconds $sleepTimer
                    
                    }

                #endregion add scripts to runspace pool
            }
                     
            Write-Verbose ( "Finish processing the remaining runspace jobs: {0}" -f ( @($runspaces | Where {$_.Runspace -ne $Null}).Count) )
            Get-RunspaceData -wait

            if (-not $quiet) {
                         Write-Progress -Activity "Running Query" -Status "Starting threads" -Completed
                  }

        }
        Finally
        {
            #Close the runspace pool, unless we specified no close on timeout and something timed out
            if ( ($timedOutTasks -eq $false) -or ( ($timedOutTasks -eq $true) -and ($noCloseOnTimeout -eq $false) ) ) {
                   Write-Verbose "Closing the runspace pool"
                         $runspacepool.close()
            }

            #collect garbage
            [gc]::Collect()
        }       
    }
}
#endregion

    
Move-Item -Path ($SCRIPT_PARENT + "\DC_Health_Check_Report*.html") -Destination ($SCRIPT_PARENT + "\Reports\") -Force
Write-Host " Old Report moved to Reports folder ..... " -foregroundcolor green

Write-Host " Loading ActiveDirectory Module..... " -foregroundcolor Yellow
Import-Module ActiveDirectory


#region Domain Information collaction
$Domain = (Get-ADDomain).Forest  ## Enter Domain name like $domain = "AMOL.COM" if this variable not working 
$Date = Get-Date -Format "MMM-dd-yyyy"
$HTMLFileName = ($SCRIPT_PARENT + "\DC_Health_Check_Report_$($date).html")  # HTML Path to save Output

$ADForestInfo = Get-ADforest -server $Domain 
$ADDomainInfo = Get-ADdomain -server $Domain 
$DCs = Get-ADDomainController -filter * -server "$Domain" 
$allDCs = $DCs | foreach {$_.hostname}
$ADForestInfo.sites | foreach {$Sites += "$($_) "}
#endregion


$CompS = $allDCs #| select -First 1


#region Domain Information
Write-Host "Domain Information"
$DomainResults = New-Object Object
$DomainResults | Add-Member -Type NoteProperty -Name "Mode" -Value (($ADDomainInfo.DomainMode) -replace "Windows", "")
$DomainResults | Add-Member -Type NoteProperty -Name "InfraMaster" -Value $ADDomainInfo.infrastructuremaster
$DomainResults | Add-Member -Type NoteProperty -Name "Domain" -Value $ADDomainInfo.name
$DomainResults | Add-Member -Type NoteProperty -Name "PDC" -Value $ADDomainInfo.pdcemulator
$DomainResults | Add-Member -Type NoteProperty -Name "RID" -Value $ADDomainInfo.ridmaster
#endregion

#region DC / Sites  Information
$DCCount = $allDCs.Count
$SitesCount = ($ADForestInfo.sites).Count

Write-Host "Object Counts"
$ObjCounts = New-Object Object
$ObjCounts | Add-Member -Type NoteProperty -Name "DC" -Value $DCCount
$ObjCounts | Add-Member -Type NoteProperty -Name "Sites" -Value $SitesCount
#endregion

#region DC Repadmin ReplSum
#########################################
#             DC Repadmin ReplSum                      #
#########################################
Write-Host " ..... Repadmin /Replsum ..... " -foregroundcolor green
$myRepInfo = @(repadmin /replsum * /bysrc /bydest /sort:delta /homeserver:$Domain)
# Initialize our array.
$cleanRepInfo = @() 
   # Start @ #10 because all the previous lines are junk formatting
   # and strip off the last 4 lines because they are not needed.
    for ($i=10; $i -lt ($myRepInfo.Count-4); $i++) {
            if($myRepInfo[$i] -ne ""){
            # Remove empty lines from our array.
            $myRepInfo[$i] -replace '\s+', " "  | Out-Null          
            $cleanRepInfo += $myRepInfo[$i]             
            }
            }            
$finalRepInfo = @()   
            foreach ($line in $cleanRepInfo) {
            $splitRepInfo = $line -split '\s+',8
            if ($splitRepInfo[0] -eq "Source") { $repType = "Source" }
            if ($splitRepInfo[0] -eq "Destination") { $repType = "Destination" }
            if ($splitRepInfo[1] -notcontains "DSA") {       
            # Create an Object and populate it with our values.
           $objRepValues = New-Object System.Object 
               $objRepValues | Add-Member -type NoteProperty -name DSAType -value $repType # Source or Destination DSA
               $objRepValues | Add-Member -type NoteProperty -name Hostname  -value $splitRepInfo[1] # Hostname
               $objRepValues | Add-Member -type NoteProperty -name Delta  -value $splitRepInfo[2] # Largest Delta
               $objRepValues | Add-Member -type NoteProperty -name Fails -value $splitRepInfo[3] # Failures
               #$objRepValues | Add-Member -type NoteProperty -name Slash  -value $splitRepInfo[4] # Slash char
               $objRepValues | Add-Member -type NoteProperty -name Total -value $splitRepInfo[5] # Totals
               $objRepValues | Add-Member -type NoteProperty -name PctError  -value $splitRepInfo[6] # % errors   
               $objRepValues | Add-Member -type NoteProperty -name ErrorMsg  -value $splitRepInfo[7] # Error code
           
            # Add the Object as a row to our array    
            $finalRepInfo += $objRepValues
            
            }
            }

#endregion



$DCDiagBlock ={
[CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$false)]  
    [string[]]$ComputerName #= $CompName  
     ) 

$ErrorActionPreference = "SilentlyContinue"

$AllDCDiags = @()

$FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
$text = " Checking for - $ComputerName"

Write-Host $FormattedDate -ForegroundColor Yellow -NoNewline 
Write-Host $text


$sysname = "$($computername)"


     $text1 = " DCdiag Checking for - $ComputerName"

Write-Host $FormattedDate -ForegroundColor Yellow -NoNewline 
Write-Host $text1

      $Dcdiag = (Dcdiag.exe /s:$sysname) -split ('[\r\n]')

       $DCDResults = New-Object Object
       $DCDResults | Add-Member -Type NoteProperty -Name "ServerName" -Value $sysname
              $Dcdiag | %{
              Switch -RegEx ($_)
              {
              "Starting"      { $TestName   = ($_ -Replace ".*Starting test: ").Trim() }
              "passed test|failed test" { If ($_ -Match "passed test") { 
               $TestStatus = "Passed" 
               # $TestName
              # $_
              } 
               Else 
               { 
               $TestStatus = "Failed" 
                # $TestName
              # $_
              } }
              }
              If ($TestName -ne $Null -And $TestStatus -ne $Null)
              {
              $DCDResults | Add-Member -Name $("$TestName".Trim()) -Value $TestStatus -Type NoteProperty -force
              $TestName = $Null; $TestStatus = $Null
              }
              }
#$AllDCDiags += $DCDResults
#$AllDCDiags

$AllDCDiags += $DCDResults

$AllDCDiags

     $text2 = " DCdiag Done - $ComputerName"

Write-Host $FormattedDate -ForegroundColor Yellow -NoNewline 
Write-Host $text2

}

$DCDiagCheck = Invoke-Parallel -InputObject $CompS -Throttle 70 -RunspaceTimeout 300 -ScriptBlock $DCDiagBlock
$DCDiagCheck | ft -Wrap 


$DCHealthBlock ={
[CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$false)]  
    [string[]]$ComputerName #= $CompName  
     ) 

$ErrorActionPreference = "SilentlyContinue"

$props = @()

$FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
$text = " Checking for - $ComputerName"

Write-Host $FormattedDate -ForegroundColor Yellow -NoNewline 
Write-Host $text

#region GetStatusCode
Function GetStatusCode
{ 
       Param([int] $StatusCode)  
       switch($StatusCode)
       {
              #0     {"Online"}
              11001   {"Buffer Too Small"}
              11002   {"Destination Net Unreachable"}
              11003   {"Destination Host Unreachable"}
              11004   {"Destination Protocol Unreachable"}
              11005   {"Destination Port Unreachable"}
              11006   {"No Resources"}
              11007   {"Bad Option"}
              11008   {"Hardware Error"}
              11009   {"Packet Too Big"}
              11010   {"Request Timed Out"}
              11011   {"Bad Request"}
              11012   {"Bad Route"}
              11013   {"TimeToLive Expired Transit"}
              11014   {"TimeToLive Expired Reassembly"}
              11015   {"Parameter Problem"}
              11016   {"Source Quench"}
              11017   {"Option Too Big"}
              11018   {"Bad Destination"}
              11032   {"Negotiating IPSEC"}
              11050   {"General Failure"}
              default {"Failed"}
       }
} 
#endregion

#region Test-Port
function Test-Port{  
<#    
.SYNOPSIS    
    Tests port on computer.  
    
.DESCRIPTION  
    Tests port on computer. 
     
.PARAMETER computer  
    Name of server to test the port connection on.
      
.PARAMETER port  
    Port to test 
       
.PARAMETER tcp  
    Use tcp port 
      
.PARAMETER udp  
    Use udp port  
     
.PARAMETER UDPTimeOut 
    Sets a timeout for UDP port query. (In milliseconds, Default is 1000)  
      
.PARAMETER TCPTimeOut 
    Sets a timeout for TCP port query. (In milliseconds, Default is 1000)
                 
.NOTES    
    Name: Test-Port.ps1  
    Author: Boe Prox  
    DateCreated: 18Aug2010   
    List of Ports: http://www.iana.org/assignments/port-numbers  
      
    To Do:  
        Add capability to run background jobs for each host to shorten the time to scan.         
.LINK    
    https://boeprox.wordpress.org 
     
.EXAMPLE    
    Test-Port -computer 'server' -port 80  
    Checks port 80 on server 'server' to see if it is listening  
    
.EXAMPLE    
    'server' | Test-Port -port 80  
    Checks port 80 on server 'server' to see if it is listening 
      
.EXAMPLE    
    Test-Port -computer @("server1","server2") -port 80  
    Checks port 80 on server1 and server2 to see if it is listening  
    
.EXAMPLE
    Test-Port -comp dc1 -port 17 -udp -UDPtimeout 10000
    
    Server   : dc1
    Port     : 17
    TypePort : UDP
    Open     : True
    Notes    : "My spelling is Wobbly.  It's good spelling but it Wobbles, and the letters
            get in the wrong places." A. A. Milne (1882-1958)
    
    Description
    -----------
    Queries port 17 (qotd) on the UDP port and returns whether port is open or not
       
.EXAMPLE    
    @("server1","server2") | Test-Port -port 80  
    Checks port 80 on server1 and server2 to see if it is listening  
      
.EXAMPLE    
    (Get-Content hosts.txt) | Test-Port -port 80  
    Checks port 80 on servers in host file to see if it is listening 
     
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port 80  
    Checks port 80 on servers in host file to see if it is listening 
        
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port @(1..59)  
    Checks a range of ports from 1-59 on all servers in the hosts.txt file      
            
#>   
[cmdletbinding(  
    DefaultParameterSetName = '',  
    ConfirmImpact = 'low'  
)]  
    Param(  
        [Parameter(  
            Mandatory = $True,  
            Position = 0,  
            ParameterSetName = '',  
            ValueFromPipeline = $True)]  
            [array]$computer,  
        [Parameter(  
            Position = 1,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [array]$port,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$TCPtimeout=1000,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$UDPtimeout=1000,             
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$TCP,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$UDP                                    
        )  
    Begin {  
        If (!$tcp -AND !$udp) {$tcp = $True}  
        #Typically you never do this, but in this case I felt it was for the benefit of the function  
        #as any errors will be noted in the output of the report          
        $ErrorActionPreference = "SilentlyContinue"  
        $report = @()  
    }  
    Process {     
        ForEach ($c in $computer) {  
            ForEach ($p in $port) {  
                If ($tcp) {    
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes  
                    #Create object for connecting to port on computer  
                    $tcpobject = new-Object system.Net.Sockets.TcpClient  
                    #Connect to remote machine's port                
                    $connect = $tcpobject.BeginConnect($c,$p,$null,$null)  
                    #Configure a timeout before quitting  
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false)  
                    #If timeout  
                    If(!$wait) {  
                        #Close connection  
                        $tcpobject.Close()  
                        Write-Verbose "Connection Timeout"  
                        #Build report  
                        $temp.Server = $c  
                        $temp.Port = $p  
                        $temp.TypePort = "TCP"  
                        $temp.Open = $False 
                        $temp.Notes = "Connection to Port Timed Out"  
                    } Else {  
                        $error.Clear()  
                        $tcpobject.EndConnect($connect) | out-Null  
                        #If error  
                        If($error[0]){  
                            #Begin making error more readable in report  
                            [string]$string = ($error[0].exception).message  
                            $message = (($string.split(":")[1]).replace('"',"")).TrimStart()  
                            $failed = $true  
                        }  
                        #Close connection      
                        $tcpobject.Close()  
                        #If unable to query port to due failure  
                        If($failed){  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = $False 
                            $temp.Notes = "$message"  
                        } Else{  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = $True   
                            $temp.Notes = ""  
                        }  
                    }     
                    #Reset failed value  
                    $failed = $Null      
                    #Merge temp array with report              
                    $report += $temp  
                }      
                If ($udp) {  
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes                                     
                    #Create object for connecting to port on computer  
                    $udpobject = new-Object system.Net.Sockets.Udpclient
                    #Set a timeout on receiving message 
                    $udpobject.client.ReceiveTimeout = $UDPTimeout 
                    #Connect to remote machine's port                
                    Write-Verbose "Making UDP connection to remote server" 
                    $udpobject.Connect("$c",$p) 
                    #Sends a message to the host to which you have connected. 
                    Write-Verbose "Sending message to remote host" 
                    $a = new-object system.text.asciiencoding 
                    $byte = $a.GetBytes("$(Get-Date)") 
                    [void]$udpobject.Send($byte,$byte.length) 
                    #IPEndPoint object will allow us to read datagrams sent from any source.  
                    Write-Verbose "Creating remote endpoint" 
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any,0) 
                    Try { 
                        #Blocks until a message returns on this socket from a remote host. 
                        Write-Verbose "Waiting for message return" 
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
                        [string]$returndata = $a.GetString($receivebytes)
                        If ($returndata) {
                           Write-Verbose "Connection Successful"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = $True 
                            $temp.Notes = $returndata   
                            $udpobject.close()   
                        }                       
                    } Catch { 
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                            #Close connection  
                            $udpobject.Close()  
                            #Make sure that the host is online and not a false positive that it is open 
                            If (Test-Connection -comp $c -count 1 -quiet) { 
                                Write-Verbose "Connection Open"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = $True 
                                $temp.Notes = "" 
                            } Else { 
                                <# 
                                It is possible that the host is not online or that the host is online,  
                                but ICMP is blocked by a firewall and this port is actually open. 
                                #> 
                                Write-Verbose "Host maybe unavailable"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = $False 
                                $temp.Notes = "Unable to verify if port is open or if host is unavailable."                                 
                            }                         
                        } ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                            #Close connection  
                            $udpobject.Close()  
                            Write-Verbose "Connection Timeout"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = $False 
                            $temp.Notes = "Connection to Port Timed Out"                         
                        } Else {                      
                            $udpobject.close() 
                        } 
                    }     
                    #Merge temp array with report              
                    $report += $temp  
                }                                  
            }  
        }                  
    }  
    End {  
        #Generate Report  
        $report 
    }
}
#endregion

$sysname = "$($computername)"


# $pingStatus = Get-WmiObject -Query "Select * from win32_PingStatus where Address='$computername'" -ErrorAction SilentlyContinue
$pingStatus = Test-Connection $ComputerName -Count 1 -ea SilentlyContinue #| select ResponseTimeToLive,IPV4Address,StatusCode
$TTLOS = $pingStatus.ResponseTimeToLive

#region      FQDN CHECK   <3/23/2017>
       #$Uptime = $null
    try{$Resolve = [System.Net.Dns]::GetHostEntry($ComputerName)}
    catch {$Resolve = $null}
    
       if($pingStatus.StatusCode -eq 0) 
    {$PingCode = "Online"}

    Else {$PingCode = GetStatusCode( $pingStatus.StatusCode )}
              
If ($Resolve -ne $null )                                 #(($pingStatus.PrimaryAddressResolutionStatus -eq 0) -or ( $TP3389Out -eq "Open") )
{
$FQDN =  [string]$Resolve.HostName
$HostIPRe = [string]$Resolve.AddressList

}
Else{$FQDN = "Not Responding"
#$status = "Not-Active"
$HostIPRe = ""
}
#endregion

#region PortChecks 3389, 22

# Check Port 3389
$TP3389 = Test-Port -computer $ComputerName -port 3389 
# Check Port 22
$TP22 = Test-Port -computer $ComputerName -port 22

If($TP3389.open -eq "True"){$TP3389Out = "RDP"}
else {$TP3389Out = ""}
If($TP22.open -eq "True"){$TP22Out = "SSH"}
else {$TP22Out = ""}
#endregion

#region TTL based ComputerStatus,OSType Check login



If(($pingStatus.StatusCode -eq 0) -and ($TTLOS -eq $null)){
$TTL = (($pingStatus.StatusCode -eq 0) -and ($TTLOS -eq $null)) -replace "True", "Windows"
$HostIP = $pingStatus.IPV4Address


}
elseIf(($pingStatus.StatusCode -eq 0) -and ($TTLOS -ge 100) -and ($TTLOS -le 128) -or ( $TP3389Out -eq "RDP")){
$TTL = (($TTLOS -ge 100) -and ($TTLOS -le 128) -or ( $TP3389Out -eq "RDP")) -replace "True", "Windows"
$HostIP = $HostIPRe

}

elseif (($PingCode -eq "Online") -and ($TTLOS -le 99) -and ($TTLOS -ge 200) -or ( $TP22Out -eq "SSH")) {
$TTL = (($pingStatus.StatusCode -eq 0) -and ($TTLOS -le 99) -and ($TTLOS -ge 200)) -replace "False", "Non-Windows"
$HostIP = $HostIPRe


}

else {
$TTL = ""
$HostIP = $HostIPRe


}


# Below is to check the Active or Not-Active condition based on Ping and Port.
If( ($TP22Out -eq "SSH") -or ( $TP3389Out -eq "RDP") -or ($PingCode -ne "Failed" ) ){
$status = "Active"

#region WMIDateStringToDate 
function WMIDateStringToDate($Bootup) {   
    [System.Management.ManagementDateTimeconverter]::ToDateTime($Bootup)   
}

#endregion 

$OSInfo = Get-WmiObject Win32_OperatingSystem -ComputerName $sysname | select Caption, LastBootUpTime

# get Uptime calculation
                $Bootup = $OSInfo.LastBootUpTime   
                           $LastBootUpTime = WMIDateStringToDate $bootup   
                           $now = Get-Date 
                           $Uptime = $now - $lastBootUpTime   
                           $d = $Uptime.Days   
                           $h = $Uptime.Hours   
                           $m = $uptime.Minutes   
                           $ms= $uptime.Milliseconds
                           $DCUptime = "{0} days {1} hours" -f $d,$h




$DiskInfo = Get-WmiObject Win32_LogicalDisk -ComputerName $sysname | Where-Object { $_.DeviceID -eq "C:" } | Select-Object SystemName,
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } #| Out-String
#@{N="PercentFree"; E={ $pf= {"{0:P1}" -f( $_.FreeSpace / $_.Size ) }; if( $pf -lt "20.0%") { "#color"+$pf+"color#" }  else { $pf }    }} 

$ntps = w32tm /query /computer:$sysname /source

$cpusage = Get-WmiObject win32_processor -ComputerName $sysname | 
            Measure-Object -property LoadPercentage -Average | 
            Select @{Name = "CPU Average %" ; Expression =  {($_.Average)}} 

$memusage = Get-WmiObject -Class win32_operatingsystem -ComputerName $sysname | 
            Select @{Name = "Memory Usage %" ; Expression = {“{0:N2}” -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize) }}

$HotfixCheck = Get-HotFix -ComputerName $sysname | sort InstalledOn -Descending | select -First 1
$InstallDate = $HotfixCheck.InstalledOn.Date.ToString("MMM/dd/yyyy")
$HotfixID = $HotfixCheck.hotfixid

           $Results = New-Object Object
           $Results | Add-Member -Type NoteProperty -Name 'DCName' -Value $sysname 
           $Results | Add-Member -Type NoteProperty -Name 'IP Address' -Value $HostIP #$pingStatus.IPV4Address           
           $Results | Add-Member -Type NoteProperty -Name 'Status' -Value $status
           $Results | Add-Member -Type NoteProperty -Name "Operating System" -Value $OSInfo.Caption
           $Results | Add-Member -Type NoteProperty -Name "Drive" -Value $DiskInfo.Drive
           $Results | Add-Member -Type NoteProperty -Name "Size (GB)" -Value $DiskInfo.'Size (GB)'
           $Results | Add-Member -Type NoteProperty -Name "FreeSpace (GB)" -Value $DiskInfo.'FreeSpace (GB)'
           $Results | Add-Member -Type NoteProperty -Name "PercentFree" -Value $DiskInfo.'PercentFree'
           $Results | Add-Member -Type NoteProperty -Name "CPU Average %" -Value $cpusage.'CPU Average %'
           $Results | Add-Member -Type NoteProperty -Name "Memory Usage %" -Value $memusage.'Memory Usage %'
           $Results | Add-Member -Type NoteProperty -Name 'NTPSource' -Value $ntps
           $Results | Add-Member -Type NoteProperty -Name 'HotfixID' -Value $HotfixID
           $Results | Add-Member -Type NoteProperty -Name 'HotfixDate' -Value $InstallDate
           $Results | Add-Member -Type NoteProperty -Name 'Uptime' -Value $DCUptime

           $props += $Results


}
Else {

$status = "Not-Active"

           $Results = New-Object Object
           $Results | Add-Member -Type NoteProperty -Name 'DCName' -Value $sysname 
           $Results | Add-Member -Type NoteProperty -Name 'IP Address' -Value $HostIP #$pingStatus.IPV4Address
           $Results | Add-Member -Type NoteProperty -Name 'Status' -Value $status
           $Results | Add-Member -Type NoteProperty -Name "Operating System" -Value ""
           $Results | Add-Member -Type NoteProperty -Name "Drive" -Value ""
           $Results | Add-Member -Type NoteProperty -Name "Size (GB)" -Value ""
           $Results | Add-Member -Type NoteProperty -Name "FreeSpace (GB)" -Value ""
           $Results | Add-Member -Type NoteProperty -Name "PercentFree" -Value ""
           $Results | Add-Member -Type NoteProperty -Name "CPU Average %" -Value ""
           $Results | Add-Member -Type NoteProperty -Name "Memory Average %" -Value ""
           $Results | Add-Member -Type NoteProperty -Name 'NTPSource' -Value ""
           $Results | Add-Member -Type NoteProperty -Name 'HotfixID' -Value ""
           $Results | Add-Member -Type NoteProperty -Name 'HotfixDate' -Value ""
           $Results | Add-Member -Type NoteProperty -Name 'Uptime' -Value ""

           $props += $Results
          


}

<#

#>
#endregion



# Output Properties 

           
     $props      
}

$DCHealthCheck = Invoke-Parallel -InputObject $CompS -Throttle 70 -RunspaceTimeout 300 -ScriptBlock $DCHealthBlock
$DCHealthCheck | ft -Wrap -Property *

$DCServiceBlock ={
[CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$false)]  
    [string[]]$ComputerName #= $CompName  
     ) 

$ErrorActionPreference = "SilentlyContinue"

$props = @()

$FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
$text = " Checking for - $ComputerName"

Write-Host $FormattedDate -ForegroundColor Yellow -NoNewline 
Write-Host $text

#region GetStatusCode
Function GetStatusCode
{ 
       Param([int] $StatusCode)  
       switch($StatusCode)
       {
              #0     {"Online"}
              11001   {"Buffer Too Small"}
              11002   {"Destination Net Unreachable"}
              11003   {"Destination Host Unreachable"}
              11004   {"Destination Protocol Unreachable"}
              11005   {"Destination Port Unreachable"}
              11006   {"No Resources"}
              11007   {"Bad Option"}
              11008   {"Hardware Error"}
              11009   {"Packet Too Big"}
              11010   {"Request Timed Out"}
              11011   {"Bad Request"}
              11012   {"Bad Route"}
              11013   {"TimeToLive Expired Transit"}
              11014   {"TimeToLive Expired Reassembly"}
              11015   {"Parameter Problem"}
              11016   {"Source Quench"}
              11017   {"Option Too Big"}
              11018   {"Bad Destination"}
              11032   {"Negotiating IPSEC"}
              11050   {"General Failure"}
              default {"Failed"}
       }
} 
#endregion

#region Test-Port
function Test-Port{  
<#    
.SYNOPSIS    
    Tests port on computer.  
    
.DESCRIPTION  
    Tests port on computer. 
     
.PARAMETER computer  
    Name of server to test the port connection on.
      
.PARAMETER port  
    Port to test 
       
.PARAMETER tcp  
    Use tcp port 
      
.PARAMETER udp  
    Use udp port  
     
.PARAMETER UDPTimeOut 
    Sets a timeout for UDP port query. (In milliseconds, Default is 1000)  
      
.PARAMETER TCPTimeOut 
    Sets a timeout for TCP port query. (In milliseconds, Default is 1000)
                 
.NOTES    
    Name: Test-Port.ps1  
    Author: Boe Prox  
    DateCreated: 18Aug2010   
    List of Ports: http://www.iana.org/assignments/port-numbers  
      
    To Do:  
        Add capability to run background jobs for each host to shorten the time to scan.         
.LINK    
    https://boeprox.wordpress.org 
     
.EXAMPLE    
    Test-Port -computer 'server' -port 80  
    Checks port 80 on server 'server' to see if it is listening  
    
.EXAMPLE    
    'server' | Test-Port -port 80  
    Checks port 80 on server 'server' to see if it is listening 
      
.EXAMPLE    
    Test-Port -computer @("server1","server2") -port 80  
    Checks port 80 on server1 and server2 to see if it is listening  
    
.EXAMPLE
    Test-Port -comp dc1 -port 17 -udp -UDPtimeout 10000
    
    Server   : dc1
    Port     : 17
    TypePort : UDP
    Open     : True
    Notes    : "My spelling is Wobbly.  It's good spelling but it Wobbles, and the letters
            get in the wrong places." A. A. Milne (1882-1958)
    
    Description
    -----------
    Queries port 17 (qotd) on the UDP port and returns whether port is open or not
       
.EXAMPLE    
    @("server1","server2") | Test-Port -port 80  
    Checks port 80 on server1 and server2 to see if it is listening  
      
.EXAMPLE    
    (Get-Content hosts.txt) | Test-Port -port 80  
    Checks port 80 on servers in host file to see if it is listening 
     
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port 80  
    Checks port 80 on servers in host file to see if it is listening 
        
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port @(1..59)  
    Checks a range of ports from 1-59 on all servers in the hosts.txt file      
            
#>   
[cmdletbinding(  
    DefaultParameterSetName = '',  
    ConfirmImpact = 'low'  
)]  
    Param(  
        [Parameter(  
            Mandatory = $True,  
            Position = 0,  
            ParameterSetName = '',  
            ValueFromPipeline = $True)]  
            [array]$computer,  
        [Parameter(  
            Position = 1,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [array]$port,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$TCPtimeout=1000,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$UDPtimeout=1000,             
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$TCP,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$UDP                                    
        )  
    Begin {  
        If (!$tcp -AND !$udp) {$tcp = $True}  
        #Typically you never do this, but in this case I felt it was for the benefit of the function  
        #as any errors will be noted in the output of the report          
        $ErrorActionPreference = "SilentlyContinue"  
        $report = @()  
    }  
    Process {     
        ForEach ($c in $computer) {  
            ForEach ($p in $port) {  
                If ($tcp) {    
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes  
                    #Create object for connecting to port on computer  
                    $tcpobject = new-Object system.Net.Sockets.TcpClient  
                    #Connect to remote machine's port                
                    $connect = $tcpobject.BeginConnect($c,$p,$null,$null)  
                    #Configure a timeout before quitting  
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false)  
                    #If timeout  
                    If(!$wait) {  
                        #Close connection  
                        $tcpobject.Close()  
                        Write-Verbose "Connection Timeout"  
                        #Build report  
                        $temp.Server = $c  
                        $temp.Port = $p  
                        $temp.TypePort = "TCP"  
                        $temp.Open = $False 
                        $temp.Notes = "Connection to Port Timed Out"  
                    } Else {  
                        $error.Clear()  
                        $tcpobject.EndConnect($connect) | out-Null  
                        #If error  
                        If($error[0]){  
                            #Begin making error more readable in report  
                            [string]$string = ($error[0].exception).message  
                            $message = (($string.split(":")[1]).replace('"',"")).TrimStart()  
                            $failed = $true  
                        }  
                        #Close connection      
                        $tcpobject.Close()  
                        #If unable to query port to due failure  
                        If($failed){  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = $False 
                            $temp.Notes = "$message"  
                        } Else{  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = $True   
                            $temp.Notes = ""  
                        }  
                    }     
                    #Reset failed value  
                    $failed = $Null      
                    #Merge temp array with report              
                    $report += $temp  
                }      
                If ($udp) {  
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes                                     
                    #Create object for connecting to port on computer  
                    $udpobject = new-Object system.Net.Sockets.Udpclient
                    #Set a timeout on receiving message 
                    $udpobject.client.ReceiveTimeout = $UDPTimeout 
                    #Connect to remote machine's port                
                    Write-Verbose "Making UDP connection to remote server" 
                    $udpobject.Connect("$c",$p) 
                    #Sends a message to the host to which you have connected. 
                    Write-Verbose "Sending message to remote host" 
                    $a = new-object system.text.asciiencoding 
                    $byte = $a.GetBytes("$(Get-Date)") 
                    [void]$udpobject.Send($byte,$byte.length) 
                    #IPEndPoint object will allow us to read datagrams sent from any source.  
                    Write-Verbose "Creating remote endpoint" 
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any,0) 
                    Try { 
                        #Blocks until a message returns on this socket from a remote host. 
                        Write-Verbose "Waiting for message return" 
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
                        [string]$returndata = $a.GetString($receivebytes)
                        If ($returndata) {
                           Write-Verbose "Connection Successful"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = $True 
                            $temp.Notes = $returndata   
                            $udpobject.close()   
                        }                       
                    } Catch { 
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                            #Close connection  
                            $udpobject.Close()  
                            #Make sure that the host is online and not a false positive that it is open 
                            If (Test-Connection -comp $c -count 1 -quiet) { 
                                Write-Verbose "Connection Open"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = $True 
                                $temp.Notes = "" 
                            } Else { 
                                <# 
                                It is possible that the host is not online or that the host is online,  
                                but ICMP is blocked by a firewall and this port is actually open. 
                                #> 
                                Write-Verbose "Host maybe unavailable"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = $False 
                                $temp.Notes = "Unable to verify if port is open or if host is unavailable."                                 
                            }                         
                        } ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                            #Close connection  
                            $udpobject.Close()  
                            Write-Verbose "Connection Timeout"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = $False 
                            $temp.Notes = "Connection to Port Timed Out"                         
                        } Else {                      
                            $udpobject.close() 
                        } 
                    }     
                    #Merge temp array with report              
                    $report += $temp  
                }                                  
            }  
        }                  
    }  
    End {  
        #Generate Report  
        $report 
    }
}
#endregion

#region GetServiceStatus Function
Function Getservicestatus($service, $server)
{
       $st = Get-service -computername $server | where-object { $_.name -eq $service }
       if($st)
       {$servicestatus= $st.status}
       else
       {$servicestatus = "Not found"}
       
       Return $servicestatus
}
#endregion

$sysname = "$($computername)"


# $pingStatus = Get-WmiObject -Query "Select * from win32_PingStatus where Address='$computername'" -ErrorAction SilentlyContinue
$pingStatus = Test-Connection $ComputerName -Count 1 -ea SilentlyContinue #| select ResponseTimeToLive,IPV4Address,StatusCode
$TTLOS = $pingStatus.ResponseTimeToLive

#region      FQDN CHECK   <3/23/2017>
       #$Uptime = $null
    try{$Resolve = [System.Net.Dns]::GetHostEntry($ComputerName)}
    catch {$Resolve = $null}
    
       if($pingStatus.StatusCode -eq 0) 
    {$PingCode = "Online"}

    Else {$PingCode = GetStatusCode( $pingStatus.StatusCode )}
              
If ($Resolve -ne $null )                                 #(($pingStatus.PrimaryAddressResolutionStatus -eq 0) -or ( $TP3389Out -eq "Open") )
{
$FQDN =  [string]$Resolve.HostName
$HostIPRe = [string]$Resolve.AddressList

}
Else{$FQDN = "Not Responding"
#$status = "Not-Active"
$HostIPRe = ""
}
#endregion

#region PortChecks 3389, 22

# Check Port 3389
$TP3389 = Test-Port -computer $ComputerName -port 3389 
# Check Port 22
$TP22 = Test-Port -computer $ComputerName -port 22

If($TP3389.open -eq "True"){$TP3389Out = "RDP"}
else {$TP3389Out = ""}
If($TP22.open -eq "True"){$TP22Out = "SSH"}
else {$TP22Out = ""}
#endregion

#region TTL based ComputerStatus,OSType Check login



If(($pingStatus.StatusCode -eq 0) -and ($TTLOS -eq $null)){
$TTL = (($pingStatus.StatusCode -eq 0) -and ($TTLOS -eq $null)) -replace "True", "Windows"
$HostIP = $pingStatus.IPV4Address


}
elseIf(($pingStatus.StatusCode -eq 0) -and ($TTLOS -ge 100) -and ($TTLOS -le 128) -or ( $TP3389Out -eq "RDP")){
$TTL = (($TTLOS -ge 100) -and ($TTLOS -le 128) -or ( $TP3389Out -eq "RDP")) -replace "True", "Windows"
$HostIP = $HostIPRe

}

elseif (($PingCode -eq "Online") -and ($TTLOS -le 99) -and ($TTLOS -ge 200) -or ( $TP22Out -eq "SSH")) {
$TTL = (($pingStatus.StatusCode -eq 0) -and ($TTLOS -le 99) -and ($TTLOS -ge 200)) -replace "False", "Non-Windows"
$HostIP = $HostIPRe


}

else {
$TTL = ""
$HostIP = $HostIPRe


}


# Below is to check the Active or Not-Active condition based on Ping and Port.
If( ($TP22Out -eq "SSH") -or ( $TP3389Out -eq "RDP") -or ($PingCode -ne "Failed" ) ){
$status = "Active"

#region DC Services Check
    Write-Host " ..... Checking DC Services ..... " -foregroundcolor green

    $DCServices = "IsmServ","DFSR","W32time","KDC","NTDS","NetLogon","ADWS" #"NTFRS" ,"DFSR","W32time","KDC","NTDS","NetLogon","ADWS"

    $ResultsService = New-Object Object
    #$ResultsPort | Add-Member -Type NoteProperty -Name "SourceServer" -Value $LocalServer
    $ResultsService | Add-Member -Type NoteProperty -Name "DC_Name" -Value $sysname

    foreach ($DCService in $DCServices) {
    $checkDCService = Getservicestatus -service $DCService -server $sysname # Test-Port -computer $DC -port $TCPPort -TCP
    $ResultsService | Add-Member -Type NoteProperty -Name "$($DCService)" -Value $checkDCService

      }
      $props += $ResultsService
#endregion


}
Else {

$status = "Not-Active"

    $ResultsService = New-Object Object
    $ResultsService | Add-Member -Type NoteProperty -Name "DCName" -Value $sysname
    $ResultsService | Add-Member -Type NoteProperty -Name "$($DCService)" -Value ""
           $props += $Results
          


}


#endregion



# Output Properties 

           
     $props      
}

$DCServiceCheck = Invoke-Parallel -InputObject $CompS -Throttle 70 -RunspaceTimeout 300 -ScriptBlock $DCServiceBlock
$DCServiceCheck | ft -Wrap -Property *


$DCPortsBlock ={
[CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$false)]  
    [string[]]$ComputerName #= $CompName  
     ) 

$ErrorActionPreference = "SilentlyContinue"

$props = @()

$FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
$text = " Checking for - $ComputerName"

Write-Host $FormattedDate -ForegroundColor Yellow -NoNewline 
Write-Host $text

#region GetStatusCode
Function GetStatusCode
{ 
       Param([int] $StatusCode)  
       switch($StatusCode)
       {
              #0     {"Online"}
              11001   {"Buffer Too Small"}
              11002   {"Destination Net Unreachable"}
              11003   {"Destination Host Unreachable"}
              11004   {"Destination Protocol Unreachable"}
              11005   {"Destination Port Unreachable"}
              11006   {"No Resources"}
              11007   {"Bad Option"}
              11008   {"Hardware Error"}
              11009   {"Packet Too Big"}
              11010   {"Request Timed Out"}
              11011   {"Bad Request"}
              11012   {"Bad Route"}
              11013   {"TimeToLive Expired Transit"}
              11014   {"TimeToLive Expired Reassembly"}
              11015   {"Parameter Problem"}
              11016   {"Source Quench"}
              11017   {"Option Too Big"}
              11018   {"Bad Destination"}
              11032   {"Negotiating IPSEC"}
              11050   {"General Failure"}
              default {"Failed"}
       }
} 
#endregion

#region Test-Port
function Test-Port{  
<#    
.SYNOPSIS    
    Tests port on computer.  
    
.DESCRIPTION  
    Tests port on computer. 
     
.PARAMETER computer  
    Name of server to test the port connection on.
      
.PARAMETER port  
    Port to test 
       
.PARAMETER tcp  
    Use tcp port 
      
.PARAMETER udp  
    Use udp port  
     
.PARAMETER UDPTimeOut 
    Sets a timeout for UDP port query. (In milliseconds, Default is 1000)  
      
.PARAMETER TCPTimeOut 
    Sets a timeout for TCP port query. (In milliseconds, Default is 1000)
                 
.NOTES    
    Name: Test-Port.ps1  
    Author: Boe Prox  
    DateCreated: 18Aug2010   
    List of Ports: http://www.iana.org/assignments/port-numbers  
      
    To Do:  
        Add capability to run background jobs for each host to shorten the time to scan.         
.LINK    
    https://boeprox.wordpress.org 
     
.EXAMPLE    
    Test-Port -computer 'server' -port 80  
    Checks port 80 on server 'server' to see if it is listening  
    
.EXAMPLE    
    'server' | Test-Port -port 80  
    Checks port 80 on server 'server' to see if it is listening 
      
.EXAMPLE    
    Test-Port -computer @("server1","server2") -port 80  
    Checks port 80 on server1 and server2 to see if it is listening  
    
.EXAMPLE
    Test-Port -comp dc1 -port 17 -udp -UDPtimeout 10000
    
    Server   : dc1
    Port     : 17
    TypePort : UDP
    Open     : True
    Notes    : "My spelling is Wobbly.  It's good spelling but it Wobbles, and the letters
            get in the wrong places." A. A. Milne (1882-1958)
    
    Description
    -----------
    Queries port 17 (qotd) on the UDP port and returns whether port is open or not
       
.EXAMPLE    
    @("server1","server2") | Test-Port -port 80  
    Checks port 80 on server1 and server2 to see if it is listening  
      
.EXAMPLE    
    (Get-Content hosts.txt) | Test-Port -port 80  
    Checks port 80 on servers in host file to see if it is listening 
     
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port 80  
    Checks port 80 on servers in host file to see if it is listening 
        
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port @(1..59)  
    Checks a range of ports from 1-59 on all servers in the hosts.txt file      
            
#>   
[cmdletbinding(  
    DefaultParameterSetName = '',  
    ConfirmImpact = 'low'  
)]  
    Param(  
        [Parameter(  
            Mandatory = $True,  
            Position = 0,  
            ParameterSetName = '',  
            ValueFromPipeline = $True)]  
            [array]$computer,  
        [Parameter(  
            Position = 1,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [array]$port,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$TCPtimeout=1000,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$UDPtimeout=1000,             
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$TCP,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$UDP                                    
        )  
    Begin {  
        If (!$tcp -AND !$udp) {$tcp = $True}  
        #Typically you never do this, but in this case I felt it was for the benefit of the function  
        #as any errors will be noted in the output of the report          
        $ErrorActionPreference = "SilentlyContinue"  
        $report = @()  
    }  
    Process {     
        ForEach ($c in $computer) {  
            ForEach ($p in $port) {  
                If ($tcp) {    
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes  
                    #Create object for connecting to port on computer  
                    $tcpobject = new-Object system.Net.Sockets.TcpClient  
                    #Connect to remote machine's port                
                    $connect = $tcpobject.BeginConnect($c,$p,$null,$null)  
                    #Configure a timeout before quitting  
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false)  
                    #If timeout  
                    If(!$wait) {  
                        #Close connection  
                        $tcpobject.Close()  
                        Write-Verbose "Connection Timeout"  
                        #Build report  
                        $temp.Server = $c  
                        $temp.Port = $p  
                        $temp.TypePort = "TCP"  
                        $temp.Open = $False 
                        $temp.Notes = "Connection to Port Timed Out"  
                    } Else {  
                        $error.Clear()  
                        $tcpobject.EndConnect($connect) | out-Null  
                        #If error  
                        If($error[0]){  
                            #Begin making error more readable in report  
                            [string]$string = ($error[0].exception).message  
                            $message = (($string.split(":")[1]).replace('"',"")).TrimStart()  
                            $failed = $true  
                        }  
                        #Close connection      
                        $tcpobject.Close()  
                        #If unable to query port to due failure  
                        If($failed){  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = $False 
                            $temp.Notes = "$message"  
                        } Else{  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = $True   
                            $temp.Notes = ""  
                        }  
                    }     
                    #Reset failed value  
                    $failed = $Null      
                    #Merge temp array with report              
                    $report += $temp  
                }      
                If ($udp) {  
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes                                     
                    #Create object for connecting to port on computer  
                    $udpobject = new-Object system.Net.Sockets.Udpclient
                    #Set a timeout on receiving message 
                    $udpobject.client.ReceiveTimeout = $UDPTimeout 
                    #Connect to remote machine's port                
                    Write-Verbose "Making UDP connection to remote server" 
                    $udpobject.Connect("$c",$p) 
                    #Sends a message to the host to which you have connected. 
                    Write-Verbose "Sending message to remote host" 
                    $a = new-object system.text.asciiencoding 
                    $byte = $a.GetBytes("$(Get-Date)") 
                    [void]$udpobject.Send($byte,$byte.length) 
                    #IPEndPoint object will allow us to read datagrams sent from any source.  
                    Write-Verbose "Creating remote endpoint" 
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any,0) 
                    Try { 
                        #Blocks until a message returns on this socket from a remote host. 
                        Write-Verbose "Waiting for message return" 
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
                        [string]$returndata = $a.GetString($receivebytes)
                        If ($returndata) {
                           Write-Verbose "Connection Successful"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = $True 
                            $temp.Notes = $returndata   
                            $udpobject.close()   
                        }                       
                    } Catch { 
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                            #Close connection  
                            $udpobject.Close()  
                            #Make sure that the host is online and not a false positive that it is open 
                            If (Test-Connection -comp $c -count 1 -quiet) { 
                                Write-Verbose "Connection Open"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = $True 
                                $temp.Notes = "" 
                            } Else { 
                                <# 
                                It is possible that the host is not online or that the host is online,  
                                but ICMP is blocked by a firewall and this port is actually open. 
                                #> 
                                Write-Verbose "Host maybe unavailable"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = $False 
                                $temp.Notes = "Unable to verify if port is open or if host is unavailable."                                 
                            }                         
                        } ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                            #Close connection  
                            $udpobject.Close()  
                            Write-Verbose "Connection Timeout"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = $False 
                            $temp.Notes = "Connection to Port Timed Out"                         
                        } Else {                      
                            $udpobject.close() 
                        } 
                    }     
                    #Merge temp array with report              
                    $report += $temp  
                }                                  
            }  
        }                  
    }  
    End {  
        #Generate Report  
        $report 
    }
}
#endregion

#region GetServiceStatus Function
Function Getservicestatus($service, $server)
{
       $st = Get-service -computername $server | where-object { $_.name -eq $service }
       if($st)
       {$servicestatus= $st.status}
       else
       {$servicestatus = "Not found"}
       
       Return $servicestatus
}
#endregion

$sysname = "$($computername)"


# $pingStatus = Get-WmiObject -Query "Select * from win32_PingStatus where Address='$computername'" -ErrorAction SilentlyContinue
$pingStatus = Test-Connection $ComputerName -Count 1 -ea SilentlyContinue #| select ResponseTimeToLive,IPV4Address,StatusCode
$TTLOS = $pingStatus.ResponseTimeToLive

#region      FQDN CHECK   <3/23/2017>
       #$Uptime = $null
    try{$Resolve = [System.Net.Dns]::GetHostEntry($ComputerName)}
    catch {$Resolve = $null}
    
       if($pingStatus.StatusCode -eq 0) 
    {$PingCode = "Online"}

    Else {$PingCode = GetStatusCode( $pingStatus.StatusCode )}
              
If ($Resolve -ne $null )                                 #(($pingStatus.PrimaryAddressResolutionStatus -eq 0) -or ( $TP3389Out -eq "Open") )
{
$FQDN =  [string]$Resolve.HostName
$HostIPRe = [string]$Resolve.AddressList

}
Else{$FQDN = "Not Responding"
#$status = "Not-Active"
$HostIPRe = ""
}
#endregion

#region PortChecks 3389, 22

# Check Port 3389
$TP3389 = Test-Port -computer $ComputerName -port 3389 
# Check Port 22
$TP22 = Test-Port -computer $ComputerName -port 22

If($TP3389.open -eq "True"){$TP3389Out = "RDP"}
else {$TP3389Out = ""}
If($TP22.open -eq "True"){$TP22Out = "SSH"}
else {$TP22Out = ""}
#endregion

#region TTL based ComputerStatus,OSType Check login



If(($pingStatus.StatusCode -eq 0) -and ($TTLOS -eq $null)){
$TTL = (($pingStatus.StatusCode -eq 0) -and ($TTLOS -eq $null)) -replace "True", "Windows"
$HostIP = $pingStatus.IPV4Address


}
elseIf(($pingStatus.StatusCode -eq 0) -and ($TTLOS -ge 100) -and ($TTLOS -le 128) -or ( $TP3389Out -eq "RDP")){
$TTL = (($TTLOS -ge 100) -and ($TTLOS -le 128) -or ( $TP3389Out -eq "RDP")) -replace "True", "Windows"
$HostIP = $HostIPRe

}

elseif (($PingCode -eq "Online") -and ($TTLOS -le 99) -and ($TTLOS -ge 200) -or ( $TP22Out -eq "SSH")) {
$TTL = (($pingStatus.StatusCode -eq 0) -and ($TTLOS -le 99) -and ($TTLOS -ge 200)) -replace "False", "Non-Windows"
$HostIP = $HostIPRe


}

else {
$TTL = ""
$HostIP = $HostIPRe


}


# Below is to check the Active or Not-Active condition based on Ping and Port.
If( ($TP22Out -eq "SSH") -or ( $TP3389Out -eq "RDP") -or ($PingCode -ne "Failed" ) ){
$status = "Active"

#region Testing Ports

Write-Host " ..... Testing Ports - $sysname ..... " -foregroundcolor green

$ResultsPort = New-Object Object
$ResultsPort | Add-Member -Type NoteProperty -Name "DCName" -Value $sysname

#####  Required TCP/UDP port for DC communication.
$TCPPorts = "389","3268","3269","135","139","445","464","53"

######### TCP Ports
foreach ($TCPPort in $TCPPorts) {
$checkportTCP = Test-Port -computer $sysname -port $TCPPort -TCP
$ResultsPort | Add-Member -Type NoteProperty -Name "TCP_$($TCPPort)" -Value $checkportTCP.open

  }
  ######### UDP Ports
  $UDPPorts = "80","135","138","389","445","464","53"
  foreach ($UDPPort in $UDPPorts) {
$checkportUDP = Test-Port -computer $sysname -port $UDPPort -UDP
$ResultsPort | Add-Member -Type NoteProperty -Name "UDP_$($UDPPort)" -Value $checkportUDP.open
  }

$props += $ResultsPort

#endregion


}
Else {

$status = "Not-Active"

#region Testing Ports

Write-Host " ..... Testing Ports - $sysname ..... " -foregroundcolor green

$ResultsPort = New-Object Object
#$ResultsPort | Add-Member -Type NoteProperty -Name "SourceServer" -Value $LocalServer
$ResultsPort | Add-Member -Type NoteProperty -Name "DCName" -Value $sysname


######### TCP Ports
foreach ($TCPPort in $TCPPorts) {
$checkportTCP = Test-Port -computer $sysname -port $TCPPort -TCP
$ResultsPort | Add-Member -Type NoteProperty -Name "TCP_$($TCPPort)" -Value $checkportTCP.open

  }
  ######### UDP Ports
  $UDPPorts = "80","135","138","389","445","464","53"
  foreach ($UDPPort in $UDPPorts) {
$checkportUDP = Test-Port -computer $sysname -port $UDPPort -UDP
$ResultsPort | Add-Member -Type NoteProperty -Name "UDP_$($UDPPort)" -Value $checkportUDP.open
  }

$props += $ResultsPort

#endregion

}


#endregion



# Output Properties 

           
     $props      
}

$DCPortsCheck = Invoke-Parallel -InputObject $CompS -Throttle 70 -RunspaceTimeout 300 -ScriptBlock $DCPortsBlock
$DCPortsCheck | ft -Wrap -Property *


Write-Host "$(Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]")" -ForegroundColor Yellow -NoNewline
Write-Host " END"


#region HTML BODY List

$htmlBodyStyle = "<style>"
$htmlBodyStyle = $htmlBodyStyle + "BODY {color:#374141;background-color:#ffffff;font-size:10pt;font-family:'Calibri','trebuchet ms', helvetica, sans-serif;font-weight:normal;padding-:5px;margin:5px;overflow:auto;}"
$htmlBodyStyle = $htmlBodyStyle + "Table {font-family:'Verdana', Verdana, Helvetica, sans-serif;font-size: 12px;border-collapse: collapse;}"
$htmlBodyStyle = $htmlBodyStyle + "Table td, Table th {border: 2px solid #ddd;padding: 3px;text-align:left;white-space:nowrap}"
$htmlBodyStyle = $htmlBodyStyle + "Table tr:nth-child(even){background-color: #f2f2f2;}"
$htmlBodyStyle = $htmlBodyStyle + "Table tr:hover {background-color: #ddd;}"
$htmlBodyStyle = $htmlBodyStyle + "Table th {padding-top: 2px;padding-bottom: 2px;text-align: center;background-color: #2374a0;color: #f2f2f2;}"
$htmlBodyStyle = $htmlBodyStyle + "div {border: 1px solid gray;padding: 2px;}"
$htmlBodyStyle = $htmlBodyStyle + "h1 {text-align: center;color: #005580;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "h3 {text-align: left;color: #005580;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "h4 {text-align: left;color: #005580;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "p {text-align: left;letter-spacing: 2px;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "</style>"


$HTML = "<h1 align='center'> ---DC Health Check Report--- </h1></br>"
$HTML += "<h4 align='Left'><font color='#006699'> Date: $Date</font></h4></br>"

$HTML += "<h3>Object Counts</h3>"
$HTML += $ObjCounts | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "</br><h3>Domain Information</h3>"
$HTML += $DomainResults | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "</br><h3>DC Health Check</h3></br>"
$HTML += $DCHealthCheck | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "</br><h3>DCDiag Results</h3></br>"
$HTML += $DCDiagCheck | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "<h3>DC Services Check</h3>"
$HTML += $DCServiceCheck | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "</br><h3>Replication Information</h3>"
$HTML += $finalRepInfo | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "</br><h3>Ports Test</h3>"
$HTML += $DCPortsCheck| ConvertTo-HTML -head $htmlBodyStyle

$HTML = $HTML -Replace ('False', '<font color="red">False</font>')
$HTML = $HTML -Replace ('failed', '<font color="red">Failed</font>')
$HTML = $HTML -Replace ('Stopped', '<font color="red">Stopped</font>')
$HTML = $HTML -Replace ('Not found', '<font color="red">Not found</font>')
$HTML = $HTML -Replace ('passed', '<font color="green">Passed</font>')
$HTML = $HTML -Replace ('Running', '<font color="green">Running</font>')
$HTML = $HTML -Replace ('True', '<font color="green">True</font>')
$HTML = $HTML -Replace ('Active', '<font color="green">Active</font>')
$HTML = $HTML -Replace ('Not-Active', '<font color="green">Not-Active</font>')

$HTML | Out-File $HTMLFileName
#endregion 


#region EMAIL SENDING
Write-Host "Sending and email..... $(Get-date -format "dd-MMM-yyyy HH:mm:ss")" -ForegroundColor Green
#Send mail-> 
    # Add email IDs in email_id.txt file with , and in next line.
       
   ###########################################################
   $Uname = Get-Content Env:USERNAME
    $Comp = Get-Content Env:COMPUTERNAME

     #$MailTextT =  Get-Content ($SCRIPT_PARENT + "\V*.html") -ErrorAction SilentlyContinue
     
     $MailTextT =  Get-Content ($SCRIPT_PARENT + "\DC_Health_Check_Report*.html") -ErrorAction SilentlyContinue
     $Sig =  "<html><p class=MsoNormal><o:p>&nbsp;</o:p></p><B> Regards, <p> AD Team</B></p></html>"
     #$Top = "<html> This Script is executed on Server - <B>$Comp</B> by User - <b> $Uname </b></html>"
       #$Top = "<html> .</html>"
     $MailText=  $MailTextT + $Sig #$Top + $MailTextT + $Sig
        
$smtpServer = "smtp.com" # SMTP server
$smtpFrom = "from email"
$smtpTo = "to email" #
$messageSubject = "DC Health Check Report ($(get-date -UFormat %D))"
$messageBody = $MailText
$Attachment = $HTMLFileName
<# If any attachment then you can define the  $Attachment#>


$mailMessageParameters = @{
       From       = $smtpFrom
       To         = $smtpTo
       Subject    = $messageSubject
       SmtpServer = $smtpServer
       Body       = $messageBody
       Attachment = $Attachment
}

Send-MailMessage @mailMessageParameters -BodyAsHtml 

Write-Host "Email has been sent..... $(Get-date -format "dd-MMM-yyyy HH:mm:ss")" -ForegroundColor Green
#endregion



       
# Get End Time
$EndMain = (Get-Date)
$MainElapsedTime = $EndMain-$startMain
$MainElapsedTimeOut =[Math]::Round(($MainElapsedTime.TotalMinutes),3)

Write-Host "
[Total Elapsed Time]" -ForegroundColor Yellow -NoNewline 
Write-Host "  $MainElapsedTimeOut Minutes~ [ $($CompS.Count)  Devices]
"      
