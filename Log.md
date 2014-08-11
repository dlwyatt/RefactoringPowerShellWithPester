####Commit [b4e87fbc](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/b4e87fbc9a841fa383fa84fe1992c930d8f835b1)

Here we go!  The `Get-StringToken` function is in the [StringTokens.psm1](https://github.com/dlwyatt/RefactoringPowerShellWithPester/blob/b4e87fbc9a841fa383fa84fe1992c930d8f835b1/StringTokens.psm1) script module, and [Tester.ps1](https://github.com/dlwyatt/RefactoringPowerShellWithPester/blob/b4e87fbc9a841fa383fa84fe1992c930d8f835b1/Tester.ps1) (if you can even call that a "test") is demonstration code which was copied and pasted pretty much verbatim onto the TechNet Script Gallery page where this code was uploaded.  Initial observations:

- Tester.ps1 has to go.  It's going to be replaced with a proper suite of unit tests using Pester.  For this, I'll be using the latest Beta version of Pester v3 (currently available from https://github.com/pester/Pester/tree/Beta).  If Pester v3 is released by the time this refactoring log is finished, that link will have changed.
- `Get-StringToken` itself is a single function around 350 lines long, 300 if you ignore the comment-based help.  Once we understand everything that it does and have a suite of tests to ensure its behavior remains consistent, we'll start to break that code up into much smaller, easy to understand functions.
- One thing that the current version of `Get-StringToken` has going for it are comments next to many of the conditional statements.  These will help in understanding what the heck is going in in this 300-line blob of code, but eventually, we're going to get rid of those comments and replace them with code that is so easy to take in at a glance, it doesn't need to be commented anyway.

####Commit [d6f865b1](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/d6f865b19de7006414d2ad9fec6798c3eaad54fb) - Beginning to write Pester tests

Before making any changes to the existing code, I want to have a complete suite of unit tests documenting and verifying its behavior.  I started by reading the Comment-Based Help of `Get-StringToken` and by reading the existing Tester.ps1 script.  While these were not automated tests, they still had valuable example code and documentation of what each parameter of `Get-StringToken` was supposed to accomplish.

Based on this documented behavior, I was able to determine that if you only pass in a string (or array of strings) to Get-StringToken, it should have the following behavior:

- Strings are delimited by tabs and spaces (in addition to line endings)
- Consecutive delimiters should produce an empty token in between each pair.
- Tokens can contain delimiters if they are surrounded with a pair of double quotes.
- If a token does not begin with a double quote, any double quote characters found within the token are just treated as literals.
- Inside a quoted string, you can embed a literal quotation mark by placing two consecutive quotation marks.
- Quoted tokens cannot contain multiple lines.
 
You can see the first few Pester tests in [StringTokens.Tests.ps1](https://github.com/dlwyatt/RefactoringPowerShellWithPester/blob/d6f865b19de7006414d2ad9fec6798c3eaad54fb/StringTokens.Tests.ps1).  To execute these tests, I use the `Invoke-Pester` command, producing the following output:

```posh
Invoke-Pester

<#
Executing all tests in 'C:\GitHub\RefactoringPowerShellWithPester'
Describing Get-StringToken (public API)
   Context When using the default behavior and only passing in strings.
    [+] Uses only space and tab as delmiters within each line 527ms
    [+] Uses double quotation marks as delmiters 70ms
    [+] Produces empty tokens when multiple consecutive delimiters are found 9ms
    [+] Treats two consecutive quotation marks inside a quoted string as an escaped quotation mark 5ms
    [+] Does not treat quotation marks inside a non-quoted token as anything special 9ms
    [+] Does not allow multi-line quoted tokens 6ms
Tests completed in 629ms
Passed: 6 Failed: 0
#>
```

I may think of other tests for this "default behavior" context as time goes on, but for now, it's a good start.  Next steps:  look more closely at each of the other parameters to Get-StringToken, and write more tests which verify the output when they're used.  Note that I'm not touching the ugly code at all yet.  I'm not going to do that until I have a complete suite of tests for all of the code.  Speaking of which, here's how I can use Pester's code coverage analysis feature (new to the v3.0 beta) to get an idea of how much progress I'm making:

```posh
Invoke-Pester -CodeCoverage .\StringTokens.psm1

<#
... Normal test output, as above.

Code coverage report:
Covered 64.42 % of 104 analyzed commands in 1 file.

Missed commands:

File              Function        Line Command
----              --------        ---- -------
StringTokens.psm1 Get-StringToken  118 $item.GetEnumerator()
StringTokens.psm1 Get-StringToken  120 $escapeChars[$character] = $true
StringTokens.psm1 Get-StringToken  126 $doubleQualifierIsEscape = $false
StringTokens.psm1 Get-StringToken  145 if ($currentQualifer -ne $null -and $Span)...
StringTokens.psm1 Get-StringToken  147 $null = $currentToken.Append($LineDelimiter)
StringTokens.psm1 Get-StringToken  152 if ($GroupLines)...
StringTokens.psm1 Get-StringToken  154 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  158 Write-Output $currentToken.ToString()
StringTokens.psm1 Get-StringToken  161 $currentToken.Length = 0
StringTokens.psm1 Get-StringToken  162 $currentQualifer = $null
StringTokens.psm1 Get-StringToken  168 Write-Output (New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  168 New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  169 Tokens = $lineGroup.ToArray()
StringTokens.psm1 Get-StringToken  172 $lineGroup.Clear()
StringTokens.psm1 Get-StringToken  188 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  201 Write-Output (New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  201 New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  202 Tokens = $lineGroup.ToArray()
StringTokens.psm1 Get-StringToken  205 $lineGroup.Clear()
StringTokens.psm1 Get-StringToken  228 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  243 $i++
StringTokens.psm1 Get-StringToken  278 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  293 if ($currentToken.Length -gt 0)...
StringTokens.psm1 Get-StringToken  295 if ($GroupLines)...
StringTokens.psm1 Get-StringToken  297 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  301 Write-Output $currentToken.ToString()
StringTokens.psm1 Get-StringToken  304 $currentToken.Length = 0
StringTokens.psm1 Get-StringToken  305 $currentQualifer = $null
StringTokens.psm1 Get-StringToken  308 if ($GroupLines -and $lineGroup.Count -gt 0)...
StringTokens.psm1 Get-StringToken  310 Write-Output (New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  310 New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  311 Tokens = $lineGroup.ToArray()
StringTokens.psm1 Get-StringToken  314 $lineGroup.Clear()
StringTokens.psm1 Get-StringToken  338 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  348 Write-Output (New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  348 New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  349 Tokens = $lineGroup.ToArray()

#>
```

64 percent... not too bad, considering I haven't tested any of the optional parameters to the function yet.  Keep in mind, though, that this just tells me how much code in the module was _executed_ during the tests; it's no guarantee that I've actually written enough assertions to consider all of that code _tested_.

#### Commit [87c85c1b](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/87c85c1b8c1e7ac98f093d364a9277476cb0b290#diff-d41d8cd98f00b204e9800998ecf8427e) - Testing the `-Escape` parameter

Starting to write tests around each of the optional parameters; I picked `-Escape` as the lucky first contestant.  According to the documentation, examples, and what dim memory I have of writing this code, I gave the user a couple of options for passing in the list of escape characters.  You could choose to pass in an array (e.g.: `-Escape @('\', '#')`), or a single string containing the characters (or whatever combination of the two.)  Why I felt this was a good idea at the time, I don't know, but now it's part of the public API, and that's how it will stay.  It just means there's more behavior to test.

I also realized that in the "default behavior" tests, I hadn't verified that no characters work as escape characters, other than doubling up the qualifier (quote).  I added a test for this, but it was very slow to run at first (using a full set of 0..65535 for the characters to test), so I limited it to just the basic ASCII range of 0..127.

Not much difference in the code coverage metrics from this; up about another 2% to 66.35.

#### Commit [df856165](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/df856165488205a931e0a242d12b3a992fba44fc) - Testing the `-Delimiter` parameter

Not much to see here.  Tests are just about identical to those for the `-Escape` parameter, as `-Delimiter` allows the same options of passing by array or in a single string.  Code coverage remains the same at 66.35%, proving my earlier point that just because the code executed doesn't mean I've actually tested all of the behavior.  A safer way to say it is that there is 33.65% of the code that I absolutely _have not tested_ yet, and 66.35% of the code _may_ have been tested.

#### Commit [b57aafdf](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/b57aafdf83c83258155d230181a49f7f735a9cb8#diff-d41d8cd98f00b204e9800998ecf8427e) - Testing the `-Qualifier` parameter

More of the same type of new tests, this time for `-Qualifier`.  Coverage still at 66.35%.

#### Commit [5fa24f2b](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/5fa24f2b87cf12411642af0a5a2bc851449a6778#diff-d41d8cd98f00b204e9800998ecf8427e) - Testing the `-NoDoubleQualifier` switch

Another straightforward test, though while writing this, I came across another bit of behavior to add to the "defaults" tests.  If you have a qualified (aka quoted) token, any text between the closing qualifier and the next delimiter is discarded.  For example, passing in a string of `'"Token One"Garbage "Token Two"` results in receiving an result of `@('Token One', 'Token Two)`.  This is a type of malformed input, and apparently that's how I decided to deal with it.  I'm not sure I like that now, but I can change it later.  For now, this is about testing the existing behavior.

Coverage up to 68.27%.

#### Commit [2a83d0c5](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/2a83d0c572b19c33cbf837e451331be8472c31b1#diff-d41d8cd98f00b204e9800998ecf8427e) - Testing the `-Span` and `-LineDelimiter` parameters

I tested these two together since `-LineDelimiter` only matters if the `-Span` switch is also used.  Nothing too crazy going on here.  Coverage up to 70.19%.

#### Commit [dc8b5d65](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/dc8b5d65126d77db9cb9d49d3407cac4d4e41d0a#diff-d41d8cd98f00b204e9800998ecf8427e) - Testing the `-IgnoreConsecutiveDelimiters` switch

Not much to see here, small and simple test.  Coverage metric unchanged at 70.19%.

I'm really getting sick of copying and pasting this same loop to test array equality.  I was going to wait to change that until the Pester update to address it is merged in, but I think I'll just add an Assert-ArraysAreEqual function into this test script for now in the next commit.

#### Commit [42fe4229](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/42fe42291adb1422d192bea738d4329657d03dae#diff-d41d8cd98f00b204e9800998ecf8427e) - Refactoring the test code a bit

Much better!  Cleaned up all those annoying duplicated bits with calls to Assert-ArraysAreEqual.  Now to move on with writing more tests.

#### Commit [84375a2c](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/84375a2c2419e2e483c1b1072884f836a5c8bc22) - Testing the `-GroupLines` switch

This is the last of the optional parameters on the list.  Code coverage is up to 93.27%; next step is to take a closer look at the lines that it says I missed, and see if I need to add some more tests around those edges.

```posh
Invoke-Pester -CodeCoverage .\StringTokens.psm1

<#
Code coverage report:
Covered 93.27 % of 104 analyzed commands in 1 file.

Missed commands:

File              Function        Line Command
----              --------        ---- -------
StringTokens.psm1 Get-StringToken  158 Write-Output $currentToken.ToString()
StringTokens.psm1 Get-StringToken  188 $null = $lineGroup.Add($currentToken.ToString())
StringTokens.psm1 Get-StringToken  201 Write-Output (New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  201 New-Object psobject -Property @{...
StringTokens.psm1 Get-StringToken  202 Tokens = $lineGroup.ToArray()
StringTokens.psm1 Get-StringToken  205 $lineGroup.Clear()
StringTokens.psm1 Get-StringToken  301 Write-Output $currentToken.ToString()
#>
```

#### Commit [3474bbaa](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/3474bbaa71b1fbac24c3ce0fd27ab988c5ab2db9#diff-d41d8cd98f00b204e9800998ecf8427e) - Coverage report up to 100%

The missing commands in the coverage report all had to do with edge cases around encountering the end of a string or an EOL character within a quoted token, with and without the `-GroupLines` switch.  This is a form of malformed input, but something the function handles gracefully by just assuming that the user meant to close the quoted token before the end of the line.

Now we can start to look at the actual code of StringTokens.psm1 and decide how to refactor it.  That's a project for another day, though; it's time for bed.

#### Commit [9d3df736](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/9d3df73601c334dbe599398131a055a803d71548) - Moving state / option variables into a single object

This is looking ahead a bit.  I know that I want to extract methods from the body of `Get-StringToken`, and it will be easier to pass around a single state variable to these methods than it would be to pass around all of the various individual variables.  This also abstracts those details from the `Get-StringToken` function itself, so they can change later without affecting that part fo the code.

Notice that nothing's using the `$parseState` varible yet; in fact, I haven't changed any of the code that would affect a test (and they're all still passing.)  Refactoring should be done in small steps, and sometimes that means adding new code which isn't used yet.

Next steps:  Change references to the various variables initialized in the `begin` block to property references on `$parseState` instead.  Once those are all done, I should be able to delete the rest of the `begin` block (leaving only the call to `New-ParseState`), freeing me up to start to extract out code from the rest of the function easily.

#### Commit [334985df](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/334985df90ae28be887ea79c5109096e751d6317) - Replacing `$delimiters` with `$parseState.Delimiters`

Small, easy change, all tests still work.  Next, I'll remove the `$delimiters` variable initialization code from the `begin` block of `Get-StringToken`.  If I haven't missed anything, that variable should no longer be used anyway, and nothing will miss it.

#### Commit [68bd52fe](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/68bd52fe1994da715da71c606237c6cf97599a0d) - Removing the old `$delimiters` variable

Success:  deleted those 9 lines of code, and all tests still worked.

The next few refactoring steps are going to be more of the same:  Updating a reference to an old variable with a reference to a $parseState property instead, then removing the old variable.  Because writing these log file updates takes much longer than the refactoring itself, and because these steps will all be repeating the same task, I'll combine them into a single commit and log update.  (However, I'll still be running the Pester test script after each change.)

#### Commit [086b8cfb](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/086b8cfb01d3e07d7a4f0282d92093222b4f7bae) - Completing the transition to using `$parseState`

The `begin` block of `Get-StringToken` has been completely extracted, and the rest of the function now only refers to `$parseState`.  More to come on that later, but for now, this makes it very easy to extract out whole bits of code into their own functions where appropriate.

#### Commit [6080863c](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/6080863c836c650d5f9b7f30ea3d7b6b6c9b7895) - More `$parseState` transition

The previous update only covered getting rid of the variables that were contained in the `begin` block.  `$parseState` also contains several properties which come directly from parameters passed to `Get-StringToken` which I forgot to update; this has been corrected.

#### Commit [5f17f97f](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/5f17f97f29d2c9e23cdde546977a4fe7f35c2510) - Extracted duplicate code into `CompleteCurrentToken` method

Now we're cooking!  This block of code was repeated 5 times nearly verbatim, and has been replaced with 5 calls to a single function:

```posh
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
```

Thanks to going to the trouble of setting up the `$parseState` variable, I only had to define a single parameter to this function (and didn't rely on automatically resolving variables in the parent scope, which I generally try to avoid.)

#### Commit [bf597d7f](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/bf597d7f773a5132a412e9897448568755a90c4b) - Make that 6 times...

Replaced another block of that duplicated code with a call to `CompleteCurrentToken`.

#### Commit [1ece1150](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/1ece11501dc990fa793cb9d92f0e91ada6d6a872) - Extracted more duplicate code into `CompleteCurrentLineGroup` method

Same idea, different duplication.

#### Commit [70357b1d](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/70357b1dd135c7b5b3e041a2795b696a06a98a24) - Reaping the benefits already
Now that some of the duplicate code has been refactored into easier to read bits, this jumped out at me:

```posh
    process
    {
        foreach ($str in $String)
        {
            # If the last $str value was in the middle of building a token when the end of the string was reached,
            # handle it before parsing the current $str.
            if ($parseState.CurrentToken.Length -gt 0)
            {
                if ($parseState.CurrentQualifier -ne $null -and $parseState.Span)
                {
                    $null = $parseState.CurrentToken.Append($parseState.LineDelimiter)
                }

                else
                {
                    CompleteCurrentToken -ParseState $parseState
                }
            }

            if ($parseState.GroupLines -and $parseState.LineGroup.Count -gt 0)
            {
                CompleteCurrentLineGroup -ParseState $parseState
            }
```

We're completing the current line group even if the start of this string happened to be in the middle of a quoted token with the `Span` option enabled.  However, because this only happens if the quoted multi-line token is not the first token in a line group, the original test suite didn't properly test this condition, but it does now!  (And fails; fix coming in the next commit.)  To do:  Make sure the test code also tests this condition with embedded EOL characters in the string, just in case.)

#### Commit [237f2e2d](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/237f2e2d3a00c927b6a0ab13ed278022f28c8ee7) - Fix for the bug identified in previous commit

Here's the revised block of code, with logic that doesn't suck:
```posh
    process
    {
        foreach ($str in $String)
        {
            # If the last $str value was in the middle of building a token when the end of the string was reached,
            # handle it before parsing the current $str.
            if ($parseState.CurrentQualifier -ne $null -and $parseState.Span)
            {
                $null = $parseState.CurrentToken.Append($parseState.LineDelimiter)
            }
            else
            {
                if ($parseState.CurrentToken.Length -gt 0)
                {
                    CompleteCurrentToken -ParseState $parseState
                }

                if ($parseState.GroupLines -and $parseState.LineGroup.Count -gt 0)
                {
                    CompleteCurrentLineGroup -ParseState $parseState
                }
            }
```

Now, those two `if` statements containing the calls to `CompleteCurrentToken` and `CompleteCurrentLineGroup` are also duplicated quite a bit; more method extraction coming right up!

#### Commit [6aa72eb5](https://github.com/dlwyatt/RefactoringPowerShellWithPester/commit/6aa72eb58c3c9ecfefc33a8a809cda75be61dc830) - More duplicate code extraction

There were several instances of calls to `CompleteCurrentToken` or `CompleteCurrentLineGroup` instead `if` statements that were identical, or nearly so.  These have been extracted into methods called `CheckForCompletedToken` and `CheckForCompletedLineGroup`.  Note the `-CheckingAtDelimiter` switch to `CheckForCompletedToken` ; this was needed due to the slightly different conditional logic used in some of the old code blocks.  When you're checking for a completed token at a delimiter, it's okay to output an empty token if the `-IgnoreConsecutiveDelimiters` switch wasn't set.  Speaking of which, using `-not $ParseState.IgnoreConsecutiveDelimiters` in a conditional is not as easy to read as something that's a positive assertion.  This is easy to fix by just flipping the meaning of the flag on the `$parseState` object and giving it a different name.  Because we've now moved the only reference to that `IgnoreConsecutiveDelimiters` property into a new method, this change is easily made (and will be the next commit.)
