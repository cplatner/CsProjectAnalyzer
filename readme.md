# CsProjectAnalyzer

A PowerShell script to look at Microsoft Visual Studio solutions,
especially large, unruly ones. Lists all the files that are on disk but not in the
project; list all the files that are in the project, but are missing on disk.

This was written to analyze a large set of solutions and projects that had really 
gotten out of control.  Files had been added and removed from external source 
control, files had been moved around in projects, etc.  Also, some of the 
projects used an older version of Visual Studio, and in the process of updating,
the project files were messed up further.

This project was completed a long time ago (2014), and I haven't really looked
at it since.  Not sure I would run the CsProjectFixer.ps1, since it can write files.

