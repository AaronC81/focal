FROM ruby:3.0

RUN apt update && apt install imagemagick -y

WORKDIR /tmp
RUN git clone https://github.com/mattes/epeg.git
RUN cd epeg && ./autogen.sh && make && make install

# This is where "make install" puts libepeg.so.0
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"

WORKDIR /app
COPY . .
RUN bundle install
# The default installation of ImageMagick will run out of resources when trying to generate thumbnails
RUN sed -i -E 's/name="disk" value=".+"/name="disk" value="8GiB"/g' /etc/ImageMagick-6/policy.xml
CMD bundle exec rackup -E production --host 0.0.0.0 -p 9292
