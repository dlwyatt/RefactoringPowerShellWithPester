$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path
Remove-Module StringTokens -Force -ErrorAction SilentlyContinue
Import-Module $scriptRoot\StringTokens.psm1 -Force

$testStrings = @(  
    '"Double Quoted Token" Non Quoted Tokens'  
    "'Single Quoted Token'"  
    '"Double Quoted Multi-'  
    'Line Token."'  
    "Multiple`t`t Consecutive  Delimiters"  
    '"Escaped \"Embedded\" Quotes"'  
    '"Doubled ""Embedded"" Quotes"'  
)  
  
# Some different ways of calling the function.  
# Test output tokens are enclosed in <> to make  
# it clear which tokens contain embedded line breaks.  
  
Write-Host "Default Behavior"  
Write-Host   
Write-Host "Note that the output is pretty flaky, because these strings contain formats that require some extra options to handle properly."  
Write-Host  
  
$testStrings |  
Get-StringToken |  
ForEach-Object {  
    Write-Host "Token: <$_>"  
}  
  
Write-Host  
Write-Host "Single and Double quotes are legal qualifiers."  
Write-Host "Quoted tokens can span multiple lines."  
Write-Host "Consecutive delimiters are ignored."  
Write-Host "Qualifiers can be escaped with a backslash, as well as doubled, for embedding in a token."  
Write-Host  
Write-Host "This set of options is much more appropriate for the test strings, producing all of the desired tokens"  
Write-Host  
  
$testStrings |  
Get-StringToken -Qualifier '"',"'" -Escape '\' -IgnoreConsecutiveDelimiters -Span |  
ForEach-Object {  
    Write-Host "Token: <$_>"  
} 
 
 
Write-Host 
Write-Host "Demonstrating the use of the GroupLines switch to parse CSV-style input." 
Write-Host "This allows you to know how many tokens are coming from each record." 
Write-Host 
 
$csvTestStrings = @( 
    '"Header 1", "Header 2", "Header 3", "Header 4", "Header 5" 
    "Token one  
spans multiple lines",Token 2,"Token ""3"" has embedded quotes","Token 4","Token 5"' 
 
    '"Line two token one","Line two token two", "Line two token three",    "Line two token four", "Line two token  
five spans multiple lines."' 
) 
 
$i = 1 
$csvTestStrings | 
Get-StringToken -Qualifier '"' -Span -GroupLines -Delimiter ',' | 
ForEach-Object { 
    $line = $_ 
 
    Write-Host "" 
    Write-Host "Line ${i}:" 
     
    foreach ($token in $line.Tokens)  
    { 
        Write-Host "Token: <$token>" 
    } 
 
    $i++ 
} 

