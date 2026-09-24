# command:  gemget
# purpose:  Download files over Gemini, one URL or a list of them.
# why:      The catalogue's Gemini downloader: wget's role, for saving pages,
#           files or a list of them from capsules.
# see:      gmni, curl

## Use
Give it URLs; each is saved under its own name in the current folder,
with a progress bar. `-d` chooses the folder, `-o` names a single file.

## Examples
    gemget gemini://example.org/file.txt           # save one file
    gemget -d ~/gemini gemini://a/x gemini://b/y   # several, into a folder
    gemget -o index.gmi gemini://example.org/      # a page, under a chosen name
    gemget -f urls.txt -d saved                    # every URL in a file
    gemget -e gemini://example.org/dir/            # add .gmi to pages without one

## Options
-o, --output PATH      the file name, for a single URL
-d, --directory DIR    the folder to save into
-f, --input-file FILE  read URLs from FILE, one a line
-e, --add-extension    add .gmi to pages that have no extension
-m, --max-size SIZE    skip anything larger
-q, --quiet            no progress bar
-i, --insecure         do not check the certificate

## Notes
- It fetches exactly the URLs given; it does not follow a page's links
  to mirror a whole capsule.
