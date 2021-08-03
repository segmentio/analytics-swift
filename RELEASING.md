Releasing
=========

Use `release.sh` to perform releases.  This script will perform all the safety checks as well
as update Version.swfit, commit the change, and create tag + release.  History since the last
released version will be used as the changelog for the release.

ex: $ ./release.sh 1.1.1
 