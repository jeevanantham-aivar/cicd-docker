# Use nginx:alpine as the base image
FROM nginx:alpine

# Copy the HTML and CSS files to the default nginx web directory
COPY index.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 