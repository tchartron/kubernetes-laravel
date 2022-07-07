ARG LARAVEL_ROOT="./laravel-app"

##################################################
#####                                         ####
#               FRONTEND_SOURCES                 #
####                                          ####
##################################################
# For the frontend, we want to get all the Laravel files,
# and run a production compile
FROM node:18.4-alpine3.16 as frontend_sources

ARG LARAVEL_ROOT

WORKDIR /var/www/kubernetes-laravel

# We need to copy in the Laravel files to make everything available to our frontend compilation
COPY --chown=node $LARAVEL_ROOT .

# We want to install all the NPM packages,
# and compile the MIX bundle for production
RUN npm install && \
    npm run prod

##################################################
#####                                         ####
#               FRONTEND_SOURCES                 #
####                                          ####
##################################################

# We need an nginx container which can pass requests to our FPM container,
# as well as serve any static content.
FROM nginx:1.22-alpine as nginx

WORKDIR /var/www/kubernetes-laravel

# We need to add our NGINX template to the container for startup,
# and configuration.
COPY docker/nginx/1.22-alpine/conf/server.conf.template /etc/nginx/templates/default.conf.template

# Copy in ONLY the public directory of our project.
# This is where all the static assets will live, which nginx will serve for us.
COPY --from=frontend_sources --chown=nginx /var/www/kubernetes-laravel/public /var/www/kubernetes-laravel/public
