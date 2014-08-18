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

    # If the last $String value was in the middle of building a token when the end of the string was reached,
    # handle it before parsing the current $String.
    if ($ParseState.CurrentQualifier -ne $null -and $ParseState.Span)
    {
        $null = $ParseState.CurrentToken.Append($ParseState.LineDelimiter)
    }
    else
    {
        CheckForCompletedToken -ParseState $ParseState
        CheckForCompletedLineGroup -ParseState $ParseState
    }

    for ($parseState.CurrentIndex = 0; $parseState.CurrentIndex -lt $String.Length; $parseState.CurrentIndex++)
    {
        if ($ParseState.CurrentQualifier)
        {
            ProcessCharacterInQualifiedToken -ParseState $ParseState
        }

        else
        {
            ProcessCharacter -ParseState $ParseState
        } # -not $currentQualifier

    } # end for $parseState.CurrentIndex = 0 to $str.Length
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

    $ParseState.CurrentToken.Length = 0
    $ParseState.CurrentQualifier = $null
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

function ProcessCharacterInQualifiedToken($ParseState)
{
    $currentChar = $ParseState.CurrentString.Chars($ParseState.CurrentIndex)

    # Line breaks in qualified token.
    if (($currentChar -eq "`n" -or $currentChar -eq "`r") -and -not $ParseState.Span)
    {
        CheckForCompletedToken -ParseState $ParseState -CheckingAtDelimiter
        CheckForCompletedLineGroup -ParseState $ParseState

        # We're not including the line breaks in the token, so eat the rest of the consecutive line break characters.
        while ($ParseState.CurrentIndex+1 -lt $ParseState.CurrentString.Length -and ($ParseState.CurrentString.Chars($ParseState.CurrentIndex+1) -eq "`r" -or $ParseState.CurrentString.Chars($ParseState.CurrentIndex+1) -eq "`n"))
        {
            $ParseState.CurrentIndex++
        }
    }

    # Embedded, escaped qualifiers
    elseif (($ParseState.EscapeChars.ContainsKey($currentChar) -or ($currentChar -eq $ParseState.CurrentQualifier -and $ParseState.DoubleQualifierIsEscape)) -and
             $ParseState.CurrentIndex+1 -lt $ParseState.CurrentString.Length -and $ParseState.CurrentString.Chars($ParseState.CurrentIndex+1) -eq $ParseState.CurrentQualifier)
    {
        $null = $ParseState.CurrentToken.Append($ParseState.CurrentQualifier)
        $ParseState.CurrentIndex++
    }

    # Closing qualifier
    elseif ($currentChar -eq $ParseState.CurrentQualifier)
    {
        CompleteCurrentToken -ParseState $ParseState

        # Eat any non-delimiter, non-EOL text after the closing qualifier, plus the next delimiter.  Sets the loop up
        # to begin processing the next token (or next consecutive delimiter) next time through.  End-of-line characters
        # are left alone, because eating them can interfere with the GroupLines switch behavior.
        while ($ParseState.CurrentIndex+1 -lt $ParseState.CurrentString.Length -and $ParseState.CurrentString.Chars($ParseState.CurrentIndex+1) -ne "`r" -and $ParseState.CurrentString.Chars($ParseState.CurrentIndex+1) -ne "`n" -and -not $ParseState.Delimiters.ContainsKey($ParseState.CurrentString.Chars($ParseState.CurrentIndex+1)))
        {
            $ParseState.CurrentIndex++
        }

        if ($ParseState.CurrentIndex+1 -lt $ParseState.CurrentString.Length -and $ParseState.Delimiters.ContainsKey($ParseState.CurrentString.Chars($ParseState.CurrentIndex+1)))
        {
            $ParseState.CurrentIndex++
        }
    }

    # Token content
    else
    {
        $null = $ParseState.CurrentToken.Append($currentChar)
    }
}

function ProcessCharacter($ParseState)
{
    $currentChar = $ParseState.CurrentString.Chars($ParseState.CurrentIndex)

    # Opening qualifier
    if ($ParseState.CurrentToken.ToString() -match '^\s*$' -and $ParseState.Qualifiers.ContainsKey($currentChar))
    {
        $ParseState.CurrentQualifier = $currentChar
        $ParseState.CurrentToken.Length = 0
    }

    # Delimiter
    elseif ($ParseState.Delimiters.ContainsKey($currentChar))
    {
        CheckForCompletedToken -ParseState $ParseState -CheckingAtDelimiter
    }

    # Line breaks (not treated quite the same as delimiters)
    elseif ($currentChar -eq "`n" -or $currentChar -eq "`r")
    {
        CheckForCompletedToken -ParseState $ParseState
        CheckForCompletedLineGroup -ParseState $ParseState
    }

    # Token content
    else
    {
        $null = $ParseState.CurrentToken.Append($currentChar)
    }
}
