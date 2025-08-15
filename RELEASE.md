## Releasing a new version

To release a new version:

1. Update the `version` constant in mac-volume.swift.
2. Update `CHANGES.md` with the correct version number.
3. Add to git, commit and push.
4. Run `./notarise.sh` to compile the `mac-volume` binary, sign and notarise it.
5. Tag with `git tag -s <version number>` and push.
6. Generate a GitHub Release and upload the `mac-volume` binary to it.
