# Focal

Focal is an **photo browser and manager** built around a few key principles:

- Using Focal **should not worsen the experience of browsing your photos on your
  file system**. No unusual file structures or separate databases to keep in
  sync - the way Focal manages photos will feel natural to browse outside of
  Focal too.

- You shouldn't have to choose whether to keep or delete a photo. There should
  be a **middle ground allowing you to keep a photo, but hide it from view by
  default**, for those shots that are too good to delete but you don't want to
  show off all the time.

## Structure

Focal doesn't use a database - albums are directories containing photos. Photos
can be _archived_, which hides them from the default view but still keeps them
around for later.

```
Library
├── Album A
│   ├── Archived
│   │   └── Geese3.jpg
│   ├── Geese1.jpg
│   └── Geese2.jpg
└── Album B
    └── Ducks1.jpg
```

## Usage

**This isn't ready to use yet!** The core browsing functionality works, but it's
totally unstyled, and you can't manage much from the web yet.

Still, if you'd like to run it:

1. You'll need a relatively modern Ruby (I'm using 3.0, but later versions of
   2.x should be fine)
2. `bundle install`
3. Set the environment variable `FOCAL_IMAGE_LIBRARY` to a directory path which
   contains album directories
4. At the root of your image library, create a file named `.FocalAuthentication`
   and put a SHA256 hex-encoded password hash in there. (You can generate this
   using `echo "desired-password" | ruby -e "require 'digest'; puts Digest::SHA2.hexdigest(gets.chomp)"`.)
5. `bundle exec rackup`

## Testing

There's a test suite which can be run with `bundle exec rackup`. This uses a 
reference library in `spec/test_library`, which is copied into `/tmp` for each
test.

These copies are cleaned up by default once tests have finished, but if you
would like to keep them around for inspection then set the environment variable
`FOCAL_KEEP_LIBRARY_TEST_COPIES`.
