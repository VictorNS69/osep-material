function Test-AMSI {
    $result = @{
        AmsiAvailable = $false
        AmsiInitialized = $false
        RegistryExists = $false
    }
    
    # Check AMSI availability
    try {
        $amsiUtils = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        if ($amsiUtils) {
            $result.AmsiAvailable = $true
            
            # Check initialization
            $initField = $amsiUtils.GetField('amsiInitFailed', 'NonPublic,Static')
            if ($initField) {
                $result.AmsiInitialized = !($initField.GetValue($null))
            }
        }
    } catch {}
    
    # Check registry
    $result.RegistryExists = Test-Path "HKLM:\SOFTWARE\Microsoft\AMSI"
    
    return [PSCustomObject]$result
}

# Run the test
Test-AMSI
