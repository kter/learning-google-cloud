FROM nginx:alpine

# Copy Nginx configuration
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy Laravel public files
COPY public /var/www/public

# Set working directory
WORKDIR /var/www

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]