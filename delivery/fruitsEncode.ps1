# encrypts or decrypts text using a Caesar cipher with a user-specified shift value, converting each character to its ASCII code and representing encrypted output as a concatenated string of 3-digit numbers
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("encrypt", "decrypt")]
    [string]$mode,

    [Parameter(Mandatory=$true)]
    [int]$caesar,

    [Parameter(Mandatory=$true)]
    [string]$text
)

# Enable strict mode to catch common errors
Set-StrictMode -Version Latest

# Error handling function
function Write-ErrorAndExit {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit $ExitCode
}

try {
    # Validate Caesar shift is non-negative
    if ($caesar -lt 0) {
        Write-ErrorAndExit "Caesar shift must be a non-negative integer. Received: $caesar"
    }

    # Process based on operation
    if ($mode -eq "encrypt") {
        Write-Host "Encrypting with Caesar shift: +$caesar" -ForegroundColor Yellow
        
        # Validate input text is not empty
        if ([string]::IsNullOrEmpty($text)) {
            Write-ErrorAndExit "Input text cannot be empty for encryption"
        }
        
        # Convert string to char array and apply encryption
        $resultChars = @()
        foreach ($char in $text.ToCharArray()) {
            $asciiValue = [int]$char
            # Apply Caesar encryption (shift forward) with modulo 256 wrap-around
            $encryptedValue = ($asciiValue + $caesar) % 256
            $resultChars += $encryptedValue.ToString("000")
        }
        
        # Join the numbers into a single string
        $result = -join $resultChars
        
        Write-Host "`nEncrypted result (as number string):" -ForegroundColor Green
        Write-Host $result -ForegroundColor Cyan
    }
    else { # decrypt mode
        Write-Host "Decrypting with Caesar shift: -$caesar" -ForegroundColor Yellow
        
        # Validate input for decryption
        if ([string]::IsNullOrEmpty($text)) {
            Write-ErrorAndExit "Input text cannot be empty for decryption"
        }
        
        # Check if the input string length is a multiple of 3
        if ($text.Length % 3 -ne 0) {
            Write-ErrorAndExit "Invalid input for decryption: Length ($($text.Length)) is not a multiple of 3. Encrypted text should consist of 3-digit groups."
        }
        
        # Split input into 3-digit groups
        $numberArray = @()
        for ($i = 0; $i -lt $text.Length; $i += 3) {
            if ($i + 2 -lt $text.Length) {
                $numberArray += $text.Substring($i, 3)
            }
        }
        
        # Convert numbers to characters and apply decryption
        $resultChars = @()
        foreach ($numStr in $numberArray) {
            # Validate that the substring is a valid number
            if ($numStr -match '^\d{3}$') {
                $asciiValue = [int]$numStr
                
                # Validate ASCII value range (0-255)
                if ($asciiValue -lt 0 -or $asciiValue -gt 255) {
                    Write-ErrorAndExit "Invalid ASCII value: $asciiValue (must be between 0 and 255)"
                }
                
                # Apply Caesar decryption (shift backward) with wrap-around
                $decryptedValue = ($asciiValue - $caesar + 256) % 256
                $resultChars += [char]$decryptedValue
            }
            else {
                Write-ErrorAndExit "Invalid number format: '$numStr' is not a valid 3-digit number"
            }
        }
        
        # Join characters into final string
        $result = -join $resultChars
        
        Write-Host "`nDecrypted result:" -ForegroundColor Green
        Write-Host $result -ForegroundColor Cyan
    }
}
catch {
    # Handle any unexpected errors
    Write-ErrorAndExit "An unexpected error occurred: $($_.Exception.Message)"
}
