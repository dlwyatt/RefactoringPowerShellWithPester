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
    }
}
