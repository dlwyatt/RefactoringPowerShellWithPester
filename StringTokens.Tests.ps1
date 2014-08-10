Remove-Module StringTokens -Force -ErrorAction SilentlyContinue

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path
Import-Module $scriptRoot\StringTokens.psm1 -Force -ErrorAction Stop

Describe 'Get-StringToken (public API)' {
    Context 'When using the default behavior and only passing in strings.' {
        It 'Uses only space and tab as delmiters within each line' {
            $expectedDelimiters = [char[]](" ", "`t", "`r", "`n")
            $chars = [char[]](0..65535)

            filter RemoveDelimiters { if (-not $expectedDelimiters -contains $_) { $_ } }
            $charsMinusDelimiters = $chars | RemoveDelimiters

            $line = -join $charsMinusDelimiters

            $result = @(Get-StringToken -String $line)
            $result.Count | Should Be (1)
        }

        It 'Uses double quotation marks as delmiters' {
            $lines = @(
                'One "Two Three"'
                "'Four'"
            )

            $expected = 'One', 'Two Three', "'Four'"
            $result = @(Get-StringToken -String $lines)

            # TODO:  Change these separate assertions into a simpler $result | Should BeExactly $expected
            # if / when PR#175 is merged into Pester.

            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Produces empty tokens when multiple consecutive delimiters are found' {
            $line = "One`t`tTwo Three"
            $expected = 'One', '', 'Two', 'Three'
            $result = @(Get-StringToken -String $line)

            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Treats two consecutive quotation marks inside a quoted string as an escaped quotation mark' {
            $line = '"One""Two" Three'
            $expected = 'One"Two', 'Three'
            $result = @(Get-StringToken -String $line)

            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Does not treat quotation marks inside a non-quoted token as anything special' {
            $line = 'One"Two"Three'
            $expected = 'One"Two"Three'
            $result = @(Get-StringToken -String $line)

            $result.Count | Should Be (1)
            $result[0] | Should BeExactly $expected
        }
        
        It 'Does not allow multi-line quoted tokens' {
            $lines = "`"One`r`nTwo`""
            $expected = 'One', 'Two"'
            $result = @(Get-StringToken -String $lines)

            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Does not use any escape characters other than a double quotation mark' {
            $charsToIgnore = [char[]]("`r", "`n", '"')

            # This test is quite slow, so I've limited it to just the basic ASCII range instead of
            # a full 16-bit character set.
            $chars = [char[]](0..127)

            foreach ($char in $chars)
            {
                if ($charsToIgnore -contains $char) { continue }

                $string = "`"$char`" `""
                $result = @(Get-StringToken -String $string)

                $result[0] | Should Be $char
            }
        }

        It 'Skips text after the closing qualifier up until the next delimiter' {
            $string = '"This is a test"ThisIs"Garbage" SecondToken'
            $expected = 'This is a test', 'SecondToken'
            $result = @(Get-StringToken -String $string)

            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }
    }

    Context 'When using the -Escape parameter' {
        It 'Allows the specified characters to escape qualifiers, passed as an array or as a string' {
            $escapeChars = [char[]](91..95)
            $string = -join $(
                '"Begin'

                foreach ($char in $escapeChars)
                {
                    $char + '"'
                }

                'End"'
            )

            $expected = 'Begin' + '"' * $escapeChars.Count + 'End'

            $result = @(Get-StringToken -String $string -Escape $escapeChars)
            $result.Count | Should Be (1)
            $result | Should Be $expected

            $escapeCharsAsString = -join $escapeChars

            $result = @(Get-StringToken -String $string -Escape $escapeCharsAsString)
            $result.Count | Should Be (1)
            $result | Should Be $expected
        }

        It 'Does not treat escape characters as anything special if they are not followed by a qualifier' {
            $escapeChar = '\'
            $string = '"One\"Two\Three"'
            $expected = 'One"Two\Three'

            $result = @(Get-StringToken -String $string -Escape $escapeChar)

            $result.Count | Should Be (1)
            $result | Should Be $expected
        }
    }

    Context 'When using the -Delimiter parameter' {
        It 'Allows the specified characters to be used as delimiters, passed in by array or in a single string' {
            $delimiters = '|', '/', '\'
            $string = 'One|Two/Three\Four'
            $expected = 'One', 'Two', 'Three', 'Four'

            $result = @(Get-StringToken -String $string -Delimiter $delimiters)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }

            $delimitersAsString = -join $delimiters
            $result = @(Get-StringToken -String $string -Delimiter $delimitersAsString)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'No longer treats the default delimiters of tab / space as delimiters if the user explicitly specifies them' {
            $delimiter = ','
            $string = "One Two`tThree,Four"
            $expected = "One Two`tThree", 'Four'

            $result = @(Get-StringToken -String $string -Delimiter $delimiter)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Still produces empty tokens between consecutive delimiters when explicitly specified' {
            $delimiter = ','
            $string = 'One,,Two'
            $expected = 'One', '', 'Two'

            $result = @(Get-StringToken -String $string -Delimiter $delimiter)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }
    }

    Context 'When using the -Qualifier parameter' {
        It 'Allows the specified qualifiers to be used, passed in by array or by string' {
            $qualifiers = '"', "#", '|'
            $string = '"One One" #Two Two# |Three Three|'
            $expected = 'One One', 'Two Two', 'Three Three'

            $result = @(Get-StringToken -String $string -Qualifier $qualifiers)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }

            $qualifiersAsString = -join $qualifiers
            $result = @(Get-StringToken -String $string -Qualifier $qualifiersAsString)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Only uses matching qualifiers to enclose a single token; other qualifiers are treated as literals within that token' {
            $qualifiers = '#|'
            $string = '#One | One# |Two # Two|'
            $expected = 'One | One', 'Two # Two'

            $result = @(Get-StringToken -String $string -Qualifier $qualifiers)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'No longer treats the default qualifer (double quotation mark) as a qualifier when the user explicitly specifies others' {
            $qualifiers = '#'
            $string = '"One Two"'
            $expected = '"One', 'Two"'

            $result = @(Get-StringToken -String $string -Qualifier $qualifiers)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }
    }

    Context 'When using the -NoDoubleQualifier parameter' {
        It 'Should not treat a doubled qualifier as an escaped qualifier within the token' {
            $string = '"One""Garbage" Two'
            $expected = 'One', 'Two'

            $result = @(Get-StringToken -String $string -NoDoubleQualifier)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }
    }

    Context 'When using the -Span and -LineDelimiter parameter' {
        It 'Allows quoted tokens to span multiple lines via embedded EOL characters' {
            $string = "`"One`r`nTwo`" Three"
            $expected = "One`r`nTwo", 'Three'

            $result = @(Get-StringToken -String $string -Span)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Allows quoted tokens to span multiple lines across input strings, using a default separator of CRLF' {
            $strings = "`"One", "Two`" Three"
            $expected = "One`r`nTwo", 'Three'

            $result = @($strings | Get-StringToken -Span)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Allows quoted tokens to span multiple lines across input strings, using a user-specified line separator' {
            $lineDelimiter = '|'
            $strings = "`"One", "Two`" Three"
            $expected = "One|Two", 'Three'

            $result = @($strings | Get-StringToken -Span -LineDelimiter $lineDelimiter)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }

        It 'Only uses the -LineDelimiter value when spanning lines across input string boundaries, not embedded EOL chars' {
            $lineDelimiter = '|'
            $string = "`"One`r`nTwo`" Three"
            $expected = "One`r`nTwo", 'Three'

            $result = @($string | Get-StringToken -Span -LineDelimiter $lineDelimiter)
            $result.Count | Should Be $expected.Count
            for ($i = 0; $i -lt $result.Count; $i++)
            {
                $result[$i] | Should BeExactly $expected[$i]
            }
        }
    }
}
