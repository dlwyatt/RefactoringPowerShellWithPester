#requires -Version 2.0

<#
.Synopsis
    Converts a string into individual tokens.
.DESCRIPTION
    Converts a string into tokens, with customizable behavior around delimiters and handling of qualified (quoted) strings.
.PARAMETER String
    The string to be parsed.  Can be passed in as an array of strings (with each element of the array treated as a separate line), or as a single string containing embedded `r and/or `n characters.
.PARAMETER Delimiter
    The delimiters separating each token.  May be passed as a single string or an array of string; either way, every character in the strings is treated as a delimiter.  The default delimiters are spaces and tabs.
.PARAMETER Qualifier
    The characters that can be used to qualify (quote) tokens that contain embedded delimiters.  As with delimiters, may be specified either as an array of strings, or as a single string that contains all legal qualifier characters.  Default is double quotation marks.
.PARAMETER Escape
    The characters that can be used to escape an embedded qualifier inside a qualified token.  You do not need to specify the qualifiers themselves (ie, to allow two consecutive qualifiers to embed one in the token); that behavior is handled separately by the -NoDoubleQualifiers switch.  Default is no escape characters.  Note: An escape character that is NOT followed by the active qualifier is not treated as anything special; the escape character will be included in the token.
.PARAMETER LineDelimiter
    If -Span is specified, and if the opening and closing qualifers of a token are found in different elements of the -String array, the string specified by -LineDelimiter will be injected into the token.  Defaults to "`r`n"
.PARAMETER NoDoubleQualifier
    By default, the function treats two consecutive qualifiers as one embedded qualifier character in a token.  (ie:  "a ""token"" string").  Specifying -NoDoubleQualifier disables this behavior, causing only the -Escape characters to be allowed for embedding qualifiers in a token.
.PARAMETER IgnoreConsecutiveDelimiters
    By default, if the script finds consecutive delimiters, it will output empty strings as tokens.  Specifying -IgnoreConsecutiveDelimiters treat consecutive delimiters as one (effectively only outputting non-empty tokens, unless the empty string is qualified / quoted).
.PARAMETER Span
    Passing the Span switch allows qualified tokens to contain embedded end-of-line characters.
.PARAMETER GroupLines
    Passing the GroupLines switch causes the function to return an object for each line of input.  If the Span switch is also used, multiple lines of text from the input may be merged into one output object.
    Each output object will have a Tokens collection.
.EXAMPLE
    Get-StringToken -String @("Line 1","Line`t 2",'"Line 3"')

    Tokenizes an array of strings using the function's default behavior (spaces and tabs as delimiters, double quotation marks as a qualifier, consecutive delimiters produces an empty token).  In this example, six tokens will be output.  The single quotes in the example output are not part of the tokens:

    'Line'
    '1'
    'Line'
    ''
    '2'
    'Line 3'
.EXAMPLE
    $strings | Get-StringToken -Delimiter ',' -Qualifier '"' -Span

    Pipes a string or string collection to Get-StringToken.  Text is treated as comma-delimeted, with double quotation qualifiers, and qualified tokens may span multiple lines.  In effect, CSV file format.
.EXAMPLE
    $strings | Get-StringToken -Qualifier '"' -IgnoreConsecutiveDelimeters -Escape '\' -NoDoubleQualifier

    Pipes a string or string collection to Get-StringToken.  Uses the default delimiters of tab and space.  Double quotes are the qualifier, and embedded quotes must be escaped with a backslash; placing two consecutive double quotes is disabled by the -NoDoubleQualifier argument.  Consecutive delimiters are ignored.
.INPUTS
    [System.String] - The string to be parsed.
.OUTPUTS
    [System.String] - One string for each token.
    [PSObject] - If the GroupLines switch is used, the function outputs custom objects with a Tokens property.  The Tokens property is an array of strings.
#>

function Get-StringToken
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [System.String[]] $String,

        [ValidateNotNull()]
        [System.String[]] $Delimiter = @("`t",' '),

        [ValidateNotNull()]
        [System.String[]] $Qualifier = @('"'),

        [ValidateNotNull()]
        [System.String[]] $Escape = @(),

        [ValidateNotNull()]
        [System.String] $LineDelimiter = "`r`n",
        
        [Switch] $NoDoubleQualifier,

        [Switch] $Span,

        [Switch] $GroupLines,

        [Switch] $IgnoreConsecutiveDelimiters
    )

    begin
    {
        $null = $PSBoundParameters.Remove('String')
        $parseState = New-ParseState @PSBoundParameters
    }

    process
    {
        foreach ($str in $String)
        {
            ParseInputString -String $str -ParseState $parseState
        }
    }

    end
    {
        CheckForCompletedToken -ParseState $parseState
        CheckForCompletedLineGroup -ParseState $parseState
    }
}

function New-ParseState
{
    [CmdletBinding()]
    param (
        [ValidateNotNull()]
        [System.String[]]
        $Delimiter = @("`t",' '),

        [ValidateNotNull()]
        [System.String[]]
        $Qualifier = @('"'),

        [ValidateNotNull()]
        [System.String[]]
        $Escape = @(),

        [ValidateNotNull()]
        [System.String]
        $LineDelimiter = "`r`n",
        
        [Switch]
        $NoDoubleQualifier,

        [Switch]
        $Span,

        [Switch]
        $GroupLines,

        [Switch]
        $IgnoreConsecutiveDelimiters
    )

    New-Object psobject -Property @{
        CurrentToken                            = New-Object System.Text.StringBuilder
        CurrentQualifier                        = $null
        Delimiters                              = Get-CharacterTableFromStrings -Strings $Delimiter
        Qualifiers                              = Get-CharacterTableFromStrings -Strings $Qualifier
        EscapeChars                             = Get-CharacterTableFromStrings -Strings $Escape
        DoubleQualifierIsEscape                 = -not [bool]$NoDoubleQualifier
        LineGroup                               = New-Object System.Collections.ArrayList
        GroupLines                              = [bool]$GroupLines
        ConsecutiveDelimitersProduceEmptyTokens = -not [bool]$IgnoreConsecutiveDelimiters
        Span                                    = [bool]$Span
        LineDelimiter                           = $LineDelimiter
        CurrentString                           = ''
        CurrentIndex                            = 0
    }
}

function Get-CharacterTableFromStrings
{
    [CmdletBinding()]
    param (
        [string[]] $Strings = @()
    )

    $hashTable = @{}

    foreach ($string in $Strings)
    {
        foreach ($character in $string.GetEnumerator())
        {
            $hashTable[$character] = $true
        }
    }

    return $hashTable
}

function ParseInputString($ParseState, [string] $String)
{
    $ParseState.CurrentString = $String

    if ((IsInsideQuotedToken -ParseState $ParseState) -and $ParseState.Span)
    {
        AppendLineDelimiter -ParseState $ParseState
    }
    else
    {
        CheckForCompletedToken -ParseState $ParseState
        CheckForCompletedLineGroup -ParseState $ParseState
    }

    for ($parseState.CurrentIndex = 0; $parseState.CurrentIndex -lt $String.Length; $parseState.CurrentIndex++)
    {
        if (IsInsideQuotedToken -ParseState $ParseState)
        {
            ProcessCharacterInQualifiedToken -ParseState $ParseState
        }
        else
        {
            ProcessCharacter -ParseState $ParseState
        }
    }
}

function ProcessCharacterInQualifiedToken($ParseState)
{
    $currentChar = CurrentCharacter -ParseState $ParseState

    if ((IsEndOfLine -ParseState $ParseState) -and -not $ParseState.Span)
    {
        CheckForCompletedToken -ParseState $ParseState -CheckingAtDelimiter
        CheckForCompletedLineGroup -ParseState $ParseState
        SkipEndOfLineCharacters -ParseState $ParseState
    }
    elseif (IsEscapedQualifier -ParseState $ParseState)
    {
        AppendCurrentQualifier -ParseState $ParseState
        SkipCharacter -ParseState $ParseState
    }
    elseif (IsQualifier -ParseState $ParseState -CurrentQualifierOnly)
    {
        CompleteCurrentToken -ParseState $ParseState
        SkipExtraTextAfterClosingQualifier -ParseState $ParseState
    }
    else
    {
        AppendStringToCurrentToken -ParseState $ParseState -String $currentChar
    }
}

function ProcessCharacter($ParseState)
{
    $currentChar = CurrentCharacter -ParseState $ParseState

    if (IsOpeningQualifier -ParseState $ParseState)
    {
        SetCurrentQualifier -ParseState $ParseState -Qualifier $currentChar
    }
    elseif (IsDelimiter -ParseState $ParseState)
    {
        CheckForCompletedToken -ParseState $ParseState -CheckingAtDelimiter
    }
    elseif (IsEndOfLine -ParseState $ParseState)
    {
        CheckForCompletedToken -ParseState $ParseState
        CheckForCompletedLineGroup -ParseState $ParseState
    }
    else
    {
        AppendStringToCurrentToken -ParseState $ParseState -String $currentChar
    }
}

function CheckForCompletedToken($ParseState, [switch] $CheckingAtDelimiter)
{
    if ($ParseState.CurrentToken.Length -gt 0 -or
        ($CheckingAtDelimiter -and $ParseState.ConsecutiveDelimitersProduceEmptyTokens))
    {
        CompleteCurrentToken -ParseState $ParseState
    }
}

function CompleteCurrentToken($ParseState)
{
    if ($ParseState.GroupLines)
    {
        $null = $ParseState.LineGroup.Add($ParseState.CurrentToken.ToString())
    }
    else
    {
        $ParseState.CurrentToken.ToString()
    }

    SetCurrentQualifier -ParseState $ParseState -Qualifier $null
}

function CheckForCompletedLineGroup($ParseState)
{
    if ($parseState.GroupLines -and $parseState.LineGroup.Count -gt 0)
    {
        CompleteCurrentLineGroup -ParseState $parseState
    }
}

function CompleteCurrentLineGroup($ParseState)
{
    New-Object psobject -Property @{
        Tokens = $ParseState.LineGroup.ToArray()
    }

    $ParseState.LineGroup.Clear()
}

function IsOpeningQualifier($ParseState, [uint32] $Offset = 0)
{
    return (IsOnlyWhitespace -String $ParseState.CurrentToken) -and (IsQualifier -ParseState $ParseState -Offset $Offset)
}

function IsOnlyWhitespace([string] $String)
{
    return $String -notmatch '\S'
}

function IsQualifier($ParseState, [uint32] $Offset = 0, [switch] $CurrentQualifierOnly)
{
    if (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset $Offset)
    {
        return $false
    }

    $char = $ParseState.CurrentString.Chars($ParseState.CurrentIndex + $Offset)

    if ($CurrentQualifierOnly)
    {
        return $char -eq $ParseState.CurrentQualifier
    }
    else
    {
        return $ParseState.Qualifiers.ContainsKey($char)
    }
}

function IsDelimiter($ParseState, [uint32] $Offset = 0)
{
    if (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset $Offset)
    {
        return $false
    }

    $char = $ParseState.CurrentString.Chars($ParseState.CurrentIndex + $Offset)
    return $ParseState.Delimiters.ContainsKey($char)
}

function IsEndOfLine($ParseState, [uint32] $Offset = 0)
{
    if (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset $Offset)
    {
        return $false
    }

    $char = $ParseState.CurrentString.Chars($ParseState.CurrentIndex + $Offset)
    return $char -eq "`n" -or $char -eq "`r"
}

function IsEscapedQualifier($ParseState, [uint32] $Offset = 0)
{
    if (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset ($Offset + 1))
    {
        return $false
    }

    $currentChar = $ParseState.CurrentString.Chars($ParseState.CurrentIndex + $Offset)

    return (IsQualifier -ParseState $ParseState -Offset 1 -CurrentQualifierOnly) -and (IsEscape -ParseState $ParseState)
}

function IsEscape($ParseState, [uint32] $Offset = 0)
{
    if (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset $Offset)
    {
        return $false
    }

    $char = $ParseState.CurrentString.Chars($ParseState.CurrentIndex + $Offset)

    return $ParseState.EscapeChars.ContainsKey($char) -or
           ($ParseState.DoubleQualifierIsEscape -and (IsQualifier -ParseState $ParseState -Offset $Offset -CurrentQualifierOnly))
}

function IsEndOfLineOrDelimiter($ParseState, [uint32] $Offset = 0)
{
    if (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset $Offset)
    {
        return $false
    }

    $char = $ParseState.CurrentString.Chars($ParseState.CurrentIndex + $Offset)
    return $char -eq "`r" -or $char -eq "`n" -or (IsDelimiter -ParseState $ParseState -Offset $Offset)
}

function IsInsideQuotedToken($ParseState)
{
    return $ParseState.CurrentQualifier -ne $null
}

function SkipExtraTextAfterClosingQualifier($ParseState)
{
    while (-not (IsOutsideCurrentStringBoundaries -ParseState $ParseState -Offset 1) -and
           -not (IsEndOfLineOrDelimiter -ParseState $ParseState -Offset 1))
    {
        SkipCharacter -ParseState $ParseState
    }

    if (IsDelimiter -ParseState $ParseState -Offset 1)
    {
        SkipCharacter -ParseState $ParseState
    }
}

function SkipEndOfLineCharacters($ParseState)
{
    while (IsEndOfLine -ParseState $ParseState -Offset 1)
    {
        SkipCharacter -ParseState $ParseState
    }
}

function AppendCurrentQualifier($ParseState)
{
    AppendStringToCurrentToken -ParseState $ParseState -String $ParseState.CurrentQualifier
}

function CurrentCharacter($ParseState)
{
    if ($ParseState.CurrentIndex -ge $ParseState.CurrentString.Length)
    {
        return $null
    }

    return $ParseState.CurrentString.Chars($ParseState.CurrentIndex)
}

function AppendLineDelimiter($ParseState)
{
    AppendStringToCurrentToken -ParseState $ParseState -String $ParseState.LineDelimiter
}

function AppendStringToCurrentToken($ParseState, [string] $String)
{
    $null = $ParseState.CurrentToken.Append($String)
}

function SetCurrentQualifier($ParseState, [Nullable[char]] $Qualifier)
{
    $ParseState.CurrentQualifier = $Qualifier
    $ParseState.CurrentToken.Length = 0
}

function SkipCharacter($ParseState)
{
    $ParseState.CurrentIndex++
}

function IsOutsideCurrentStringBoundaries($ParseState, [uint32] $Offset = 0)
{
    $string = $ParseState.CurrentString
    $position = $ParseState.CurrentIndex + $Offset

    return [string]::IsNullOrEmpty($string) -or $position -ge $string.Length
}