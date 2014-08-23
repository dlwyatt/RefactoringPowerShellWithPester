Refactoring PowerShell (with help from Pester)
===============================

One of the earlier PowerShell functions that I published is called [Get-StringToken](http://gallery.technet.microsoft.com/Generic-PowerShell-string-e9ccfe73).  I decided to write it after seeing several people ask about string parsing, usually with regex, delimited strings with optional quotation marks, escape characters, etc.  (Think of trying to correctly handle all of the possible valid input of a CSV file using regex, and you'll get a feel for how much of a pain in the butt that can be.)

At the time this script was written, I was fairly new to PowerShell, having worked mostly with Windows Script (VBS / JScript) and batch files for around a decade.  I'd heard of unit testing, but never applied any sort of automated testing to my scripts.  I would typically do my tests manually, or at best, write test scripts which output data to the screen, requiring me to evaluate the results, instead of reducing it to a simple "Red / Green" flag.

Since then, I've also come a long way in understanding what clean code should look like.  By choosing good names for variables and functions, and factoring the code into short, easily understood functions, anyone can come along and understand or maintain your code.

This morning, I looked over some of my old scripts and cringed.  Get-StringToken, in particular, is a single monstrous function that's around 300 lines long, not counting the comment-based help.  I thought it might be helpful to share the entire process of approaching messy code, writing unit tests for it, and then refactoring it into something that's easier to understand and maintain.  This repository is a log of that process.  I plan to make small changes to the code in each commit, followed by a separate commit which will update a log file explaining the process for the most recent change.

See the progress
===========================
To see the log of everything I've done along the way, look at the [Log.md](https://github.com/dlwyatt/RefactoringPowerShellWithPester/blob/master/Log.md) file.
