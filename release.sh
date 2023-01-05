#!/bin/bash

vercomp () {
	if [[ $1 == $2 ]]
	then
		return 0
	fi
	local IFS=.
	local i ver1=($1) ver2=($2)
	# fill empty fields in ver1 with zeros
	for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
	do
		ver1[i]=0
	done
	for ((i=0; i<${#ver1[@]}; i++))
	do
		if [[ -z ${ver2[i]} ]]
		then
			# fill empty fields in ver2 with zeros
			ver2[i]=0
		fi
		if ((10#${ver1[i]} > 10#${ver2[i]}))
		then
			return 1
		fi
		if ((10#${ver1[i]} < 10#${ver2[i]}))
		then
			return 2
		fi
	done
	return 0
}

# check if `gh` tool is installed.
if ! command -v gh &> /dev/null
then
	echo "Github CLI tool is required, but could not be found."
	echo "Install it via: $ brew install gh"
	exit 1
fi

# check if `gh` tool has auth access.
# command will return non-zero if not auth'd.
authd=$(gh auth status -t)
if [[ $? != 0 ]]; then
	echo "ex: $ gh auth login"
	exit 1
fi

# check that we're on the `main` branch
branch=$(git rev-parse --abbrev-ref HEAD)
if [ $branch != 'main' ]
then
	echo "The 'main' must be the current branch to make a release."
	echo "You are currently on: $branch"
	exit 1
fi

versionFile="./sources/Segment/Version.swift"

# get last line in version.swift
versionLine=$(tail -n 1 $versionFile)
# split at the =
version=$(cut -d "=" -f2- <<< "$versionLine")
# remove quotes and spaces
version=$(sed "s/[' \"]//g" <<< "$version")

echo "Analytics-Swift current version: $version"

# no args, so give usage.
if [ $# -eq 0 ]
then
	echo "Release automation script"
	echo ""
	echo "Usage: $ ./release.sh <version>"
	echo "   ex: $ ./release.sh \"1.0.2\""
	exit 0
fi

newVersion="${1%.*}.$((${1##*.}))"
echo "Preparing to release $newVersion..."

vercomp $newVersion $version
case $? in
	0) op='=';;
	1) op='>';;
	2) op='<';;
esac

if [ $op != '>' ]
then
	echo "New version must be greater than previous version ($version)."
	exit 1
fi

read -r -p "Are you sure you want to release $newVersion? [y/N] " response
case "$response" in
	[yY][eE][sS]|[yY])
		;;
	*)
		exit 1
		;;
esac

# get the commits since the last release...
# note: we do this here so the "Version x.x.x" commit doesn't show up in logs.
changelog=$(git log --pretty=format:"- (%an) %s" $(git describe --tags --abbrev=0 @^)..@)
tempFile=$(mktemp)
#write changelog to temp file.
echo -e "$changelog" >> $tempFile

# update sources/Segment/Version.swift
# - remove last line...
sed -i '' -e '$ d' $versionFile
# - add new line w/ new version
echo "internal let __segment_version = \"$newVersion\"" >> $versionFile

# commit the version change.
git commit -am "Version $newVersion" && git push
# gh release will make both the tag and the release itself.
gh release create $newVersion -F $tempFile -t "Version $newVersion"

# remove the tempfile.
rm $tempFile

# build up the xcframework to upload to github
./build.sh

# upload the release
gh release upload $newVersion Segment.xcframework.zip
