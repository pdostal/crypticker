FROM node:7-alpine
RUN apk update && apk add python make g++ git
RUN npm install -g coffee-script
WORKDIR /app
ADD . .
RUN npm install
RUN coffee -c .
CMD node app.js
