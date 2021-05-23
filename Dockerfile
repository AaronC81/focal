FROM ruby:3.0
RUN apt update && apt install imagemagick -y
WORKDIR /app
COPY . .
RUN bundle install
# The default installation of ImageMagick will run out of resources when trying to generate thumbnails
RUN sed -i -E 's/name="disk" value=".+"/name="disk" value="8GiB"/g' /etc/ImageMagick-6/policy.xml
CMD bundle exec rackup
