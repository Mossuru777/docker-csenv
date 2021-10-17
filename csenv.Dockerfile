################################################################################
# CSEnv
# Stage Name: csenv
################################################################################
FROM perl:5.26.3-buster
MAINTAINER Mossuru777 "mossuru777@gmail.com"

COPY perl/cpanfile /tmp/

# Setup
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Asia/Tokyo
RUN apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         sed \
         locales \
         tzdata \
    && sed -i -e 's/^# *\(ja_JP.UTF-8.*\)/\1/' /etc/locale.gen \
    && locale-gen \

# Install ImageMagick & PerlMagick
    && apt-get -q -y autoremove \
      imagemagick \
      imagemagick-6.q16 \
      imagemagick-6-common \
    && apt-get -y install --no-install-recommends \
         libgif7 \
         libgif-dev \
         libpng16-16 \
         libpng-dev \
    && curl -sSL https://github.com/ImageMagick/ImageMagick6/archive/refs/tags/6.9.10-86.tar.gz -o /tmp/imagemagick-6.9.10-86.tar.gz \
    && echo '82c585b4d1fa599a5fd510342c552c20e6b0edab4d837a62aaaed34b5b356890 /tmp/imagemagick-6.9.10-86.tar.gz' | sha256sum -c - \
    && mkdir -p /usr/src/imagemagick \
    && tar --strip-components=1 -xaf /tmp/imagemagick-6.9.10-86.tar.gz -C /usr/src/imagemagick \
    && cd /usr/src/imagemagick \
    && ./configure LDFLAGS="-L/usr/local/lib/perl5/5.26.3/x86_64-linux-gnu/CORE" --enable-shared --with-perl=/usr/local/bin/perl \
    && make -j$(nproc) \
    && make install \
    && cd /root \
    && rm -fr /usr/src/imagemagick \
    && ldconfig \

# Clean up Apt Cache
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/* \

# Install CPAN modules
    && cpanm --notest --installdeps /tmp \
    && rm -fr /root/.cpanm /tmp/**
