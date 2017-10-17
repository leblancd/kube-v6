FROM nginx

# Enable listening for IPv6
RUN sed -i 's/listen       80;/listen       [::]:80;/' /etc/nginx/conf.d/default.conf

# Modify welcome message
ADD custom-v6-welcome.txt /usr/share/nginx/html/index.html

# Create a script to paste hostname into the welcome message at run time
RUN echo #!/bin/sh > /bin/my_nginx
RUN echo sed -i 's/HOSTNAME/$HOSTNAME/' /usr/share/nginx/html/index.html >> /bin/my_nginx
RUN echo "nginx -g 'daemon off;'" >> /bin/my_nginx
RUN chmod +x /bin/my_nginx

# Run nginx
CMD ["sh", "/bin/my_nginx"]
