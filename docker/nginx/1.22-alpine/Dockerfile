ARG LARAVEL_ROOT="./laravel-app"

##################################################
#####                                         ####
#               FRONTEND_SOURCES                 #
####                                          ####
##################################################
FROM node:18.4-alpine3.16 as frontend_sources

ARG LARAVEL_ROOT

WORKDIR /var/www/kubernetes-laravel

COPY --chown=node $LARAVEL_ROOT .

# Install npm dependencies and run mix production (TODO : switch to Vite)
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

# Nginx template
COPY docker/nginx/1.22-alpine/conf/server.conf.template /etc/nginx/templates/default.conf.template

# Copy only the public directory
COPY --from=frontend_sources --chown=nginx /var/www/kubernetes-laravel/public /var/www/kubernetes-laravel/public
