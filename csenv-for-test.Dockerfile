################################################################################
# [Base Stage] CSEnv for Test
# Stage Name: base_csenv-for-test
#
# *** DO NOT PUBLISH AS A DOCKER IMAGE ***
#
################################################################################
FROM mossuru777/csenv:latest AS base_csenv-for-test

# Create /var/www/html
RUN mkdir -p /var/www/html \

# Install common packages
    && apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         sudo \

# Install Node.js (current)
    && curl -fsSL https://deb.nodesource.com/setup_current.x | bash - \
    && apt-get -q -y install --no-install-recommends \
         nodejs \

# Install Google Chrome
    && apt-get -q -y install --no-install-recommends \
         gnupg \
         fonts-ipafont \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get -q -y install --no-install-recommends /tmp/google-chrome-stable_current_amd64.deb \
    && rm /tmp/google-chrome-stable_current_amd64.deb \
    && sed -i -e 's/"\$HERE\/chrome" "\$@"/"$HERE\/chrome" "--disable-gpu" "$@"/' /opt/google/chrome/google-chrome \

# Clean up Apt Cache
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*



################################################################################
# [Base Stage] CSEnv for Test with LiteSpeed
# Stage Name: base_csenv-for-test-litespeed
#
# *** DO NOT PUBLISH AS A DOCKER IMAGE ***
#
################################################################################
FROM base_csenv-for-test AS base_csenv-for-test-litespeed

# Install & Setup LiteSpeed
ENV DEBIAN_FRONTEND noninteractive
RUN wget -q -O - http://rpms.litespeedtech.com/debian/enable_lst_debian_repo.sh | bash \
    && apt-get -q -y install --no-install-recommends \
         openlitespeed \
#--- workaround for "[STDERR] PHP Notice:  Undefined index: LS_AI_MIME_TYPE in /usr/local/lsws/share/autoindex/default.php on line 299"
    && cp -a /usr/local/lsws/share/autoindex/default.php /usr/local/lsws/share/autoindex/default.php.orig \
    && sed -i -e "s@^\(\$mime_type = \$_SERVER\['LS_AI_MIME_TYPE'\]\);@\\1 ?? null;@" /usr/local/lsws/share/autoindex/default.php \
#-------------------------------------------------------------------------------
    && mv /usr/local/lsws/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf.orig \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*
COPY litespeed/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY litespeed/vhconf.conf /usr/local/lsws/conf/vhosts/www/vhconf.conf



################################################################################
# CSEnv for Test with LiteSpeed for General
# Stage Name: csenv-for-test-litespeed-general
################################################################################
FROM base_csenv-for-test-litespeed AS csenv-for-test-litespeed-general

# Copy entrypoint script
COPY litespeed/entrypoint.sh /usr/bin/

# Configure User www-data to allow sudo
RUN echo 'www-data ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-www-data \
    && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep \

# Move Perl location
    && mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl \

# Make entrypoint script executable
    && chmod +x /usr/bin/entrypoint.sh

# Switch User to www-data
WORKDIR /var/www
USER www-data

# Define entrypoint and default command (Start LiteSpeed Webserver and then watch error logs.)
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/tail", "-F", "/usr/local/lsws/logs/stderr.log", "/usr/local/lsws/logs/error.log"]

# Define mountable directories
VOLUME ["/var/www/html"]

# Expose LiteSpeed WebAdmin Port
EXPOSE 7080

# Expose LiteSpeed WebServer Port
EXPOSE 80



################################################################################
# CSEnv for Test with LiteSpeed for CircleCI
# Stage Name: csenv-for-test-litespeed-circleci
################################################################################
FROM base_csenv-for-test-litespeed AS csenv-for-test-litespeed-circleci

# Setup for CircleCI
# - Add User circleci and config to allow sudo
# - Pre-Install packages and setup for CircleCI
RUN useradd --uid=3434 --user-group --create-home circleci \
    && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
    && sudo -u circleci mkdir /home/circleci/project \
    && apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         git \
         ssh \
         tar \
         gzip \
         ca-certificates \
         nkf \
         zip \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/* \

# Move Perl location
    && mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl

# Set Environment Variables for CircleCI
ENV PATH=/home/circleci/bin:/home/circleci/.local/bin:$PATH

# Switch User to circleci
WORKDIR /home/circleci
USER circleci



################################################################################
# [Base Stage] CSEnv for Test with Apache
# Stage Name: base_csenv-for-test-apache
#
# *** DO NOT PUBLISH AS A DOCKER IMAGE ***
#
################################################################################
FROM base_csenv-for-test AS base_csenv-for-test-apache

# Copy site configuration
COPY apache/all-catch.conf /etc/apache2/sites-available/all-catch.conf

# Install Apache
RUN apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         apache2 \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/* \

# Enable site configuration
    && a2enmod cgi \
    && a2dissite 000-default \
    && a2ensite all-catch \
    && service apache2 stop



################################################################################
# CSEnv for Test with Apache for General
# Stage Name: csenv-for-test-apache-general
################################################################################
FROM base_csenv-for-test AS csenv-for-test-apache-general

# Copy entrypoint script
COPY apache/entrypoint.sh /usr/bin/

# Configure User www-data to allow sudo
RUN echo 'www-data ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-www-data \
    && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep \

# Move Perl location
    && mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl \

# Make entrypoint script executable
    && chmod +x /usr/bin/entrypoint.sh

# Switch User to www-data
WORKDIR /var/www
USER www-data

# Define default command (Start Apache Webserver and then watch error logs.)
ENTRYPOINT ["entrypoint.sh"]
CMD ["sudo", "/usr/bin/tail", "-F", "/var/log/apache2/error.log"]

# Define mountable directories
VOLUME ["/var/www/html"]

# Expose Apache WebServer Port
EXPOSE 80



################################################################################
# CSEnv for Test with Apache for CircleCI
# Stage Name: csenv-for-test-apache-circleci
################################################################################
FROM base_csenv-for-test-apache AS csenv-for-test-apache-circleci

# Setup for CircleCI
# - Add User circleci and config to allow sudo
# - Pre-Install packages and setup for CircleCI
RUN useradd --uid=3434 --user-group --create-home circleci \
    && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
    && sudo -u circleci mkdir /home/circleci/project \
    && apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         git \
         ssh \
         tar \
         gzip \
         ca-certificates \
         nkf \
         zip \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/* \

# Move Perl location
    && mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl

# Set Environment Variables for CircleCI
ENV PATH=/home/circleci/bin:/home/circleci/.local/bin:$PATH

# Switch User to circleci
WORKDIR /home/circleci
USER circleci
