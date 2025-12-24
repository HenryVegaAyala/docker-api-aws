FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --only=production && \
    apk add --no-cache curl

COPY index.js .

EXPOSE 3000

CMD ["node", "index.js"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

