# tagler

Tagler is a command line based metadata retrieval tool for MP4 videos on OS
X. The purpose is to allow for scripted and automated bulk tagging of MP4
videos, which is much easier to do with a CLI tool vs. a GUI based tool.

Tagler is based on [Subler](https://bitbucket.org/galad87/subler/wiki/Home).
In fact, tagler is really just a CLI interface to some of Subler's
functionality. Tagler only supports tagging of MP4 files (i.e. downloading
metadata and storing them in the MP4) and can't perform any of Subler's
other operations (such as modifying subtitles). Besides processing command
line parameters, tagler contains virtually no original code. Instead, it
simply relies on functionality present in Subler.

It is written in C/Objective C for OS X, since the code it is built upon is
written in Objective C for OS X. As such, it relies on Apple's Foundation
framework and won't be easily ported to other operating systems. (As stated
above, there isn't much code in tagler to port. The actual functionality
resides in the Subler classes.)

The MP42Framework is referenced as external project (just as it is in
Subler). Subler's MetadataImporters are currently duplicated here, but are
straight copies from Subler's current code base.
