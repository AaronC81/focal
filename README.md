# Focal

Focal is an **photo browser and manager** built with a few notable features:

- Using Focal **doesn't worsen the experience of browsing your photos on your
  file system**. No unusual file structures or separate databases to keep in
  sync - the way Focal manages photos will feel natural to browse outside of
  Focal too.

- You don't have to choose whether to keep or delete a photo. There's a **middle
  ground allowing you to keep a photo, but hide it from view by default**, for
  those shots that are too good to delete but you don't want to show off all the
  time. Focal achieves this by allowing you to _archive_ photos, hiding them
  from the main view of an album. You can choose whether to make the archive
  public or private.

- You can **keep alternative formats for images alongside the JPEGs**, like raw
  image files. These are grouped nicely together with the main image, not shown
  as duplicates.

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

(Focal creates some hidden directories for storing configuration and thumbnails
too, but you should be able to easily hide these in your file explorer.)

## Usage

This is still in very early stages, so **make sure you have backups of your
photos**! This isn't too thoroughly tested yet. It's also missing the
functionality of creating albums, but you can do this by simply creating a
directory in your library and copying photos into it. Additionally, you should
not rely on the visibility settings for provide any kind of security - these
have not been rigorously tested.

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

There's also a Dockerfile available if that's more your thing. You'll need to
run the container with `FOCAL_IMAGE_LIBRARY` set, probably to some volume mapped
to the host machine, e.g.:

```shell
docker run --env "FOCAL_IMAGE_LIBRARY=/images" -v ~/pictures/focal-library:/images -p 9292:9292 focal
```

The only supported raw image format is currently Sony Alpha Raw. If you use
something else, add the file extension and a description to the
`ALTERNATIVE_FORMATS` constant in `Focal::ImageLibrary`.

## Testing

There's a test suite which can be run with `bundle exec rackup`. This uses a 
reference library in `spec/test_library`, which is copied into `/tmp` for each
test.

These copies are cleaned up by default once tests have finished, but if you
would like to keep them around for inspection then set the environment variable
`FOCAL_KEEP_LIBRARY_TEST_COPIES`.
